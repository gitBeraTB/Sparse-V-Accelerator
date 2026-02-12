`timescale 1ns / 1ps

// Paketi içeri alıyoruz
module sparse_inference_engine import sparse_pkg::*; (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      en,

    // --- Sparse Core Inputs ---
    input  sparse_packet_t            w_rows [0:3],
    input  activation_vec_t           act_vec,

    // --- Outputs ---
    output logic signed [15:0]        result_data [0:3],
    output logic                      result_valid
);

    // =========================================================================
    // 1. AŞAMA: SPARSE CORE (Şimdilik Boşta)
    // =========================================================================
    
    logic signed [19:0] core_psum_out [0:3];
    
    sparse_core u_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .en       (en),
        .w_rows   (w_rows),
        .act_vec  (act_vec),
        .psum_out (core_psum_out)
    );

    // =========================================================================
    // 2. AŞAMA: PARALEL GELU (ZORLA SIFIR BESLEME TESTİ)
    // =========================================================================
    
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_gelu_channels
            
            // --- BYPASS LOGIC ---
            logic signed [15:0] scaled_data;
            logic               scaled_valid;
            
            // BURASI KRİTİK: Core'dan gelen veriyi kullanmıyoruz!
            // Zorla 0 (Sıfır) gönderiyoruz.
            assign scaled_data  = 16'sd0; 
            
            // Valid sinyalini sürekli 1 yapıyoruz
            assign scaled_valid = 1'b1;

            // --- GELU Unit Instance ---
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