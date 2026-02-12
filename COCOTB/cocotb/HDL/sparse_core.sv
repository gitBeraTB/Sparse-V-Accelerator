`timescale 1ns / 1ps

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