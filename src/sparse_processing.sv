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


// File: sparse_pe.sv
// Description: Processing Element (PE) logic for Structured Sparsity.
//              Performs Multiply-Accumulate (MAC) operations using indirect indexing.

`include "sparse_pkg.sv"

module sparse_processing (
    input  logic                      clk,      // System Clock
    input  logic                      rst_n,    // Active-Low Reset
    input  logic                      en,       // Enable Signal
    input  sparse_pkg::sparse_packet_t w_in,    // Compressed Weight Packet Input
    input  sparse_pkg::activation_vec_t act_vec,// Full Input Activation Vector
    output logic signed [19:0]        psum_out  // Partial Sum Output
);
    // Import package for easy access to types
    import sparse_pkg::*;

    // --- Internal Signals ---
    logic signed [DATA_WIDTH-1:0] op_a_0, op_a_1; // Selected Activations
    logic signed [DATA_WIDTH-1:0] op_w_0, op_w_1; // Weights
    
    // Intermediate multiplication results
    logic signed [19:0] mult_0;
    logic signed [19:0] mult_1;

    // --- Combinational Logic: Indirect Indexing ---
    // Selects the correct input activation based on the sparsity index stored in the weight packet.
    always_comb begin
        // MUX 1: Select activation for the first non-zero weight
        op_a_0 = act_vec[w_in.idx_0];
        op_w_0 = signed'(w_in.val_0);

        // MUX 2: Select activation for the second non-zero weight
        op_a_1 = act_vec[w_in.idx_1];
        op_w_1 = signed'(w_in.val_1);
        
        // Parallel Multiplication (Combinational)
        mult_0 = op_a_0 * op_w_0;
        mult_1 = op_a_1 * op_w_1;
    end

    // --- Sequential Logic: Accumulation ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            psum_out <= 0;
        end else if (en) begin
            // Accumulate the results of the two parallel multiplications
            psum_out <= psum_out + mult_0 + mult_1;
        end
    end

endmodule