`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/25/2026 02:54:48 PM
// Design Name: 
// Module Name: axi_sparse_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


// Dosya: axi_sparse_wrapper.sv
`include "sparse_pkg.sv"

module axi_sparse_wrapper # (
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_ADDR_WIDTH = 6 // 64 byte adres alanı yeterli
)(
    input  logic                      aclk,
    input  logic                      aresetn, // Active Low Reset

    // --- AXI4-Lite Slave Interface ---
    // Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    // Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [3:0]                s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    // Write Response Channel
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    // Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    // Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready
);
    import sparse_pkg::*;

    // --- Register Tanımları ---
    logic [31:0] reg_ctrl;  // 0x00
    logic [31:0] reg_act [0:3]; // 0x04 - 0x10
    logic signed [31:0] reg_res [0:3]; // 0x14 - 0x20 (Çıkışlar)

    // --- Core Sinyalleri ---
    logic core_en;
    activation_vec_t core_act_vec;
    logic signed [19:0] core_psum [0:3];
    
    // Ağırlık Bellekleri (Şimdilik Core içinde sabit varsayıyoruz veya önceden yüklü)
    // Gerçek tasarımda AXI üzerinden buraya da yazılabilir.
    sparse_packet_t w_rows [0:3]; 
    
    // Geçici olarak ağırlıkları burada manuel bağlıyoruz (Test amaçlı)
    // İleride burası da AXI bellek alanına bağlanabilir.
    // NOT: Bu kısım normalde bir BRAM Controller olurdu.
    logic [7:0] mem_weights [0:1023];
    logic [1:0] mem_indices [0:1023];

    // --- AXI State Machine Sinyalleri ---
    logic aw_en;

    // -------------------------------------------------------------------------
    // 1. AXI WRITE OPERASYONLARI (İşlemci -> FPGA)
    // -------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 0;
            aw_en         <= 1;
            reg_ctrl      <= 0;
            for(int i=0; i<4; i++) reg_act[i] <= 0;
        end else begin
            // Handshake Logic (Basitleştirilmiş)
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1;
                s_axi_wready  <= 1;
            end else begin
                s_axi_awready <= 0;
                s_axi_wready  <= 0;
            end

            // Write Logic
            if (s_axi_awready && s_axi_wready) begin
                case (s_axi_awaddr[5:2]) // 4-byte aligned adres (0, 4, 8...)
                    4'h0: reg_ctrl      <= s_axi_wdata; // 0x00
                    4'h1: reg_act[0]    <= s_axi_wdata; // 0x04
                    4'h2: reg_act[1]    <= s_axi_wdata; // 0x08
                    4'h3: reg_act[2]    <= s_axi_wdata; // 0x0C
                    4'h4: reg_act[3]    <= s_axi_wdata; // 0x10
                    default: ; 
                endcase
                
                s_axi_bvalid <= 1; // Yazma tamamlandı
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 0; 
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. CORE BAĞLANTISI
    // -------------------------------------------------------------------------
    
    // Core'u Başlat (Control register Bit-0)
    assign core_en = reg_ctrl[0]; 

    // Girişleri Bağla (32-bit register -> 8-bit input)
    assign core_act_vec[0] = reg_act[0][7:0];
    assign core_act_vec[1] = reg_act[1][7:0];
    assign core_act_vec[2] = reg_act[2][7:0];
    assign core_act_vec[3] = reg_act[3][7:0];

    // Core Modülünü Çağır
    sparse_core u_core (
        .clk      (aclk),
        .rst_n    (aresetn),
        .en       (core_en),
        .w_rows   (w_rows),     // Aşağıda yükleyeceğiz
        .act_vec  (core_act_vec),
        .psum_out (core_psum)
    );

    // Çıkışları Registerlara Bağla (Sign Extension yaparak)
    always_comb begin
        for(int i=0; i<4; i++) begin
            reg_res[i] = 32'(signed'(core_psum[i])); 
        end
    end
    
    // --- WEIGHT LOADING (Simülasyon İçin Kritik) ---
    // AXI Wrapper sentezlendiğinde .mem dosyaları görünmeyebilir, 
    // ama simülasyon için initial blokla yükleyip kablolayalım.
    initial begin
        $readmemh("weights_nz.mem", mem_weights);
        $readmemb("indices.mem", mem_indices);
    end
    
    always_comb begin
         for (int i = 0; i < 4; i++) begin
            w_rows[i].val_0 = mem_weights[2*i];
            w_rows[i].val_1 = mem_weights[2*i + 1];
            w_rows[i].idx_0 = mem_indices[2*i];
            w_rows[i].idx_1 = mem_indices[2*i + 1];
        end
    end

    // -------------------------------------------------------------------------
    // 3. AXI READ OPERASYONLARI (FPGA -> İşlemci)
    // -------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
        end else begin
            // Address Handshake
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1;
                s_axi_araddr_reg <= s_axi_araddr; // Adresi sakla
            end else begin
                s_axi_arready <= 0;
            end

            // Data Read Logic
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1;
                case (s_axi_araddr[5:2]) // Basit adres çözme
                    4'h0: s_axi_rdata <= reg_ctrl;     // Status oku
                    4'h5: s_axi_rdata <= reg_res[0];   // 0x14 -> Index 5
                    4'h6: s_axi_rdata <= reg_res[1];   // 0x18 -> Index 6
                    4'h7: s_axi_rdata <= reg_res[2];   // 0x1C -> Index 7
                    4'h8: s_axi_rdata <= reg_res[3];   // 0x20 -> Index 8
                    default: s_axi_rdata <= 32'hDEADBEEF; // Hatalı adres
                endcase
            end else if (s_axi_rready && s_axi_rvalid) begin
                s_axi_rvalid <= 0;
            end
        end
    end
    
    // Geçici değişkenler
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr_reg;

endmodule