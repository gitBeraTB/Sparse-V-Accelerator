`timescale 1ns / 1ps

package sparse_pkg;
    localparam DATA_WIDTH = 8;
    localparam PSUM_WIDTH = 20;
    
    typedef struct packed {
        logic [7:0] val_0; 
        logic [7:0] val_1; 
        logic [1:0] idx_0; 
        logic [1:0] idx_1; 
    } sparse_packet_t;

    typedef logic [7:0] int8_t;
    typedef int8_t [3:0] activation_vec_t;
endpackage