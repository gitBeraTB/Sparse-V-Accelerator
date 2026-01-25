`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 05:39:37 PM
// Design Name: 
// Module Name: sparse_processing
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


`include "sparse_pkg.sv" // Paketi dahil et

module sparse_processing (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,      // Enable sinyali
    
    // Paket (Pkg) dosyasındaki özel tipleri kullanıyoruz
    input  sparse_pkg::sparse_packet_t  w_pkt,   // Sıkıştırılmış Ağırlıklar + İndeksler
    input  sparse_pkg::activation_vec_t act_vec, // 4 tane giriş verisi (Dense)
    
    output logic signed [19:0] psum   // Partial Sum (Taşmayı önlemek için geniş)
);
    // Paketi import et ki içindeki parametrelere erişebilelim
    import sparse_pkg::*; 

    // Ara sinyaller (Signed işlem yapmak kritik!)
    logic signed [DATA_WIDTH-1:0] op_w0, op_w1;
    logic signed [DATA_WIDTH-1:0] op_a0, op_a1;
    logic signed [2*DATA_WIDTH:0] mult0, mult1; // Çarpım sonucu 16-bit + 1 sign

    // 1. AŞAMA: OPERAND SEÇİMİ (Multiplexer Logic)
    // İndeksler (idx_0, idx_1) mux'ları kontrol eder.
    always_comb begin
        // Ağırlıkları paket içinden çıkar
        op_w0 = signed'(w_pkt.val_0);
        op_w1 = signed'(w_pkt.val_1);

        // İndekse göre doğru aktivasyonu seç (Sparse Logic)
        // Eğer idx_0 = 2 ise, act_vec[2] seçilir. Sıfır olanlar hiç işlenmez.
        op_a0 = signed'(act_vec[w_pkt.idx_0]);
        op_a1 = signed'(act_vec[w_pkt.idx_1]);
    end

    // 2. AŞAMA: ARİTMETİK İŞLEM (Sequential Logic)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum  <= '0;
            mult0 <= '0;
            mult1 <= '0;
        end else if (en) begin
            // Çarpmaları yap
            mult0 <= op_w0 * op_a0;
            mult1 <= op_w1 * op_a1;
            
            // Topla (Adder Tree)
            psum  <= mult0 + mult1;
        end
    end

endmodule