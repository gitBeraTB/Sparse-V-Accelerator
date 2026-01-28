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

package sparse_pkg;

    // --- Configuration Parameters ---
    parameter int DATA_WIDTH = 8;   // Input/Weight bit-width (INT8)
    parameter int PSUM_WIDTH = 20;  // Accumulator bit-width (to prevent overflow)
    parameter int IDX_WIDTH  = 2;   // Index width for 2:4 sparsity (2 bits)

    // --- Type Definitions ---

    // Structure for a compressed weight packet (2 Non-Zero values + 2 Indices)
    // This represents a compressed block from a 4-element row.
    typedef struct packed {
        logic [DATA_WIDTH-1:0] val_0; // First Non-Zero Value
        logic [DATA_WIDTH-1:0] val_1; // Second Non-Zero Value
        logic [IDX_WIDTH-1:0]  idx_0; // Index of the first value (0-3)
        logic [IDX_WIDTH-1:0]  idx_1; // Index of the second value (0-3)
    } sparse_packet_t;

    // Array type for the Input Activation Vector (4 elements)
    typedef logic signed [DATA_WIDTH-1:0] activation_vec_t [0:3];

endpackage