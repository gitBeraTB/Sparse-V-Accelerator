`timescale 1ns / 1ps

module sparse_inference_engine import sparse_pkg::*; (
    input  logic                      clk,
    input  logic                      rst_n,
    input  logic                      en,
    input  sparse_packet_t            w_rows [0:3],
    input  activation_vec_t           act_vec,
    output logic signed [15:0]        result_data [0:3],
    output logic                      result_valid
);

    logic signed [3:0][19:0] core_psum_packed;
    
    sparse_core u_core (
        .clk             (clk),
        .rst_n           (rst_n),
        .en              (en),
        .w_rows          (w_rows),
        .act_vec         (act_vec),
        .psum_out_packed (core_psum_packed)
    );

    logic core_valid;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) core_valid <= 0;
        else        core_valid <= en;
    end

    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_gelu_channels
            logic signed [15:0] scaled_data;
            logic               scaled_valid;
            
            // Core'dan gelen veriyi kırp (Scaling)
            assign scaled_data = core_psum_packed[i][15:0];
            assign scaled_valid = core_valid;

           // always @(posedge clk) begin
             //   if (i == 0 && scaled_valid && scaled_data != 0) begin
               //     $display("TOP DEBUG: Core'dan Gelen Veri = %d (Hex: %h)", scaled_data, scaled_data);
                // end
            // end

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