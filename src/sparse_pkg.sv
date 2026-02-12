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
// File: sparse_pkg.sv
// Description: Global type definitions and structs for the Sparse Accelerator IP.
//              Defines the data widths, weight packet structures, and vector types.

`timescale 1ns / 1ps

package sparse_pkg;

    // Parametreleri 'localparam' yaptık, derleyici için daha nettir.
    localparam DATA_WIDTH = 8;
    localparam PSUM_WIDTH = 20;
    localparam IDX_WIDTH  = 2;

    // --- STRUCT TANIMI ---
    // Burada parametre kullanmak yerine doğrudan sayıları (8 ve 2) yazdık.
    // Bu, derleyicinin "DATA_WIDTH nedir?" diye kafasının karışmasını önler.
    typedef struct packed {
        logic [7:0] val_0; 
        logic [7:0] val_1; 
        logic [1:0] idx_0; 
        logic [1:0] idx_1; 
    } sparse_packet_t;

    // --- VEKTÖR TANIMI (DÜZELTİLMİŞ) ---
    // 'signed' kelimesini şimdilik kaldırdık (gerekirse sonra ekleriz).
    // [3:0][7:0] formatı: 4 tane 8-bitlik sayı.
    // Bu format %100 SystemVerilog uyumludur ve Icarus sever.
    typedef logic [3:0][7:0] activation_vec_t;

endpackage