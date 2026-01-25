`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 06:12:27 PM
// Design Name: 
// Module Name: sparse_core
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

`include "sparse_pkg.sv"

module sparse_core (
    input  logic clk,
    input  logic rst_n,
    input  logic en,
    
    // 4 Satırlık Ağırlık Verisi (Her satır için bir paket)
    // Python çıktısındaki 4 satırı buraya besleyeceğiz
    input  sparse_pkg::sparse_packet_t w_rows [0:3], 
    
    // Tek bir Giriş Vektörü (4 PE'ye de aynı veri gider - Broadcast)
    input  sparse_pkg::activation_vec_t act_vec,
    
    // 4 adet Çıkış (Sütun Sonucu)
    output logic signed [19:0] psum_out [0:3]
);
    
    // 4 adet PE'yi oluştur (Parallel Processing)
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_pe_array
            sparse_processing u_pe (
                .clk     (clk),
                .rst_n   (rst_n),
                .en      (en),
                .w_pkt   (w_rows[i]), // Her PE kendi satırını alır
                .act_vec (act_vec),   // Hepsi aynı girişi alır
                .psum    (psum_out[i])
            );
        end
    endgenerate

endmodule