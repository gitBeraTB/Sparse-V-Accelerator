`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 05:38:03 PM
// Design Name: 
// Module Name: sparse_pkg
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
package sparse_pkg;

    // Veri genişlikleri
    parameter int DATA_WIDTH = 8;  // INT8 Quantization
    parameter int IDX_WIDTH  = 2;  // 4 elemanlı blok için 2-bit indeks yeterli
    parameter int BLOCK_SIZE = 4;  // 4'lü bloklar (2:4 Sparsity)

    // Kullanıcı tanımlı türler (Struct)
    
    // Sıkıştırılmış Ağırlık Çifti (Bir PE'ye giren veri)
    // Donanım belleğinden tek seferde bu paketi okuyacağız.
    typedef struct packed {
        logic [DATA_WIDTH-1:0] val_0; // 1. Non-zero değer
        logic [DATA_WIDTH-1:0] val_1; // 2. Non-zero değer
        logic [IDX_WIDTH-1:0]  idx_0; // 1. Değerin konumu
        logic [IDX_WIDTH-1:0]  idx_1; // 2. Değerin konumu
    } sparse_packet_t;

    // Aktivasyon Vektörü (Düzgün/Dense veri)
    // İşlemciye giren 4 adet giriş verisi
    typedef logic [DATA_WIDTH-1:0] activation_vec_t [0:BLOCK_SIZE-1];

endpackage
