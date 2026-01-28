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

// File: sparse_core.sv
// Description: Core module implementing a systolic-like array of 4 Processing Elements.
//              Handles parallel processing of 4 rows of the weight matrix.

`include "sparse_pkg.sv"

module sparse_core (
    input  logic                      clk,      // System Clock
    input  logic                      rst_n,    // Active-Low Reset
    input  logic                      en,       // Core Enable Signal
    
    // Weight Memory Interface (Input for 4 rows)
    input  sparse_pkg::sparse_packet_t w_rows [0:3],
    
    // Broadcast Input Vector (Sent to all PEs)
    input  sparse_pkg::activation_vec_t act_vec,
    
    // Output Interface (Partial Sums for each row)
    output logic signed [19:0]        psum_out [0:3]
);
    // --- PE Instantiation ---
    // Generate 4 Parallel Processing Elements
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : pe_array
            sparse_processing u_pe (
                .clk      (clk),
                .rst_n    (rst_n),
                .en       (en),
                .w_in     (w_rows[i]), // Unique weight row for each PE
                .act_vec  (act_vec),   // Shared input vector
                .psum_out (psum_out[i])// Unique output for each PE
            );
        end
    endgenerate

endmodule