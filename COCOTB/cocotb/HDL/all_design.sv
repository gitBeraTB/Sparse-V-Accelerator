`timescale 1ns / 1ps

// ==========================================
// 1. PAKET (PACKAGE)
// ==========================================
package sparse_pkg;
    localparam DATA_WIDTH = 8;
    localparam PSUM_WIDTH = 20;
    
    typedef struct packed {
        logic [7:0] val_0; 
        logic [7:0] val_1; 
        logic [1:0] idx_0; 
        logic [1:0] idx_1; 
    } sparse_packet_t;

    typedef logic [7:0] int8_t;
    typedef int8_t [3:0] activation_vec_t;
endpackage

// ==========================================
// 2. PROCESSING ELEMENT (FIXED & CLEAN)
// ==========================================
module sparse_processing_element import sparse_pkg::*; (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  sparse_packet_t   w_packet,
    input  activation_vec_t  act_vec,
    output logic signed [19:0] psum_out 
);

    // --- 1. Sinyal Tanımları (En Tepede!) ---
    logic signed [19:0] accumulator;
    
    // Ara kablolar (Wires)
    logic [1:0] clean_idx0, clean_idx1;
    logic signed [7:0] clean_w0, clean_w1;
    logic signed [7:0] raw_a0, raw_a1;
    logic signed [7:0] clean_a0, clean_a1;
    logic signed [15:0] prod0, prod1;

    // --- 2. Giriş Temizleme (X-Savar) ---
    // Eğer indeks veya ağırlık X ise 0 kabul et.
    assign clean_idx0 = (^w_packet.idx_0 === 1'bx) ? 2'b00 : w_packet.idx_0;
    assign clean_idx1 = (^w_packet.idx_1 === 1'bx) ? 2'b00 : w_packet.idx_1;
    
    assign clean_w0   = (^w_packet.val_0 === 1'bx) ? 8'sd0 : $signed(w_packet.val_0);
    assign clean_w1   = (^w_packet.val_1 === 1'bx) ? 8'sd0 : $signed(w_packet.val_1);

    // --- 3. Aktivasyon Okuma ve Temizleme ---
    assign raw_a0 = $signed(act_vec[clean_idx0]);
    assign raw_a1 = $signed(act_vec[clean_idx1]);

    // Aktivasyonun kendisi X ise 0 yap
    assign clean_a0 = (^raw_a0 === 1'bx) ? 8'sd0 : raw_a0;
    assign clean_a1 = (^raw_a1 === 1'bx) ? 8'sd0 : raw_a1;

    // --- 4. Çarpma İşlemi (Combinational) ---
    assign prod0 = clean_w0 * clean_a0;
    assign prod1 = clean_w1 * clean_a1;

    // --- 5. Biriktirme (Sequential) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 20'sd0;
            psum_out    <= 20'sd0; 
        end else if (en) begin
            // Önceden hesaplanmış çarpımları topla
            accumulator <= accumulator + prod0 + prod1;
            psum_out    <= accumulator;
        end
    end

endmodule

// ==========================================
// 3. SPARSE CORE (PACKED)
// ==========================================
module sparse_core import sparse_pkg::*; (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  sparse_packet_t   w_rows [0:3],
    input  activation_vec_t  act_vec,
    output logic signed [3:0][19:0] psum_out_packed 
);
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_pe
            logic signed [19:0] pe_result;
            
            sparse_processing_element u_pe (
                .clk      (clk),
                .rst_n    (rst_n),
                .en       (en),
                .w_packet (w_rows[i]),
                .act_vec  (act_vec),
                .psum_out (pe_result)
            );
            
            assign psum_out_packed[i] = pe_result;
        end
    endgenerate
endmodule

// ==========================================
// 4. GELU LUT (MANUEL)
// ==========================================
module gelu_pwl_lut (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [15:0] data_in,
    input  logic               valid_in,
    output logic signed [15:0] data_out,
    output logic               valid_out
);
    logic [31:0] rom_memory [0:511]; 

    initial begin
        integer k;
        for (k = 0; k < 512; k = k + 1) rom_memory[k] = 32'h00010000;
    end

    logic [8:0] lut_addr;
    logic       addr_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lut_addr <= 0; addr_valid <= 0;
        end else begin
            lut_addr <= data_in[8:0]; addr_valid <= valid_in;
        end
    end

    logic signed [15:0] slope;
    logic               stage2_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slope <= 0; stage2_valid <= 0;
        end else begin
            if (addr_valid) slope <= rom_memory[lut_addr][31:16];
            stage2_valid <= addr_valid;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0; valid_out <= 0;
        end else begin
            if (stage2_valid) begin
                data_out <= slope; valid_out <= 1;
            end else valid_out <= 0;
        end
    end
endmodule

// ==========================================
// 5. TEPE MODÜL (INFERENCE ENGINE)
// ==========================================
module sparse_inference_engine import sparse_pkg::*; (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      en,
    input  sparse_packet_t            w_rows [0:3],
    input  activation_vec_t           act_vec,
    output logic signed [15:0]        result_data [0:3],
    output logic                      result_valid
);

    logic signed [3:0][19:0] core_psum_packed;
    
    sparse_core u_core (
        .clk             (clk),
        .rst_n           (rst_n),
        .en              (en),
        .w_rows          (w_rows),
        .act_vec         (act_vec),
        .psum_out_packed (core_psum_packed)
    );

    logic core_valid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) core_valid <= 0;
        else        core_valid <= en;
    end

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_gelu_channels
            logic signed [15:0] scaled_data;
            logic               scaled_valid;
            
            assign scaled_data  = core_psum_packed[i][19:4];
            assign scaled_valid = core_valid;

            logic signed [15:0] gelu_out_wire;
            logic               gelu_valid_wire;

            gelu_pwl_lut u_gelu (
                .clk       (clk),
                .rst_n     (rst_n),
                .data_in   (scaled_data),
                .valid_in  (scaled_valid),
                .data_out  (gelu_out_wire),
                .valid_out (gelu_valid_wire)
            );

            assign result_data[i] = gelu_out_wire;
            if (i == 0) assign result_valid = gelu_valid_wire;
        end
    endgenerate
endmodule