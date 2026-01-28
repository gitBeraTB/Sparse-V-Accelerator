`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/25/2026 02:54:48 PM
// Design Name: 
// Module Name: axi_sparse_wrapper
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

// File: axi_sparse_wrapper.sv
// Description: AXI4-Lite Wrapper for the Sparse Matrix Accelerator.
//              Provides a memory-mapped interface for RISC-V processors to control
//              the accelerator and read/write data.

`include "sparse_pkg.sv"

module axi_sparse_wrapper # (
    parameter int AXI_DATA_WIDTH = 32,
    parameter int AXI_ADDR_WIDTH = 6 // 64-byte address space
)(
    input  logic                      aclk,
    input  logic                      aresetn, // Active-Low Reset

    // --- AXI4-Lite Slave Interface ---
    // Write Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    // Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0] s_axi_wdata,
    input  logic [3:0]                s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    // Write Response Channel
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,
    // Read Address Channel
    input  logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    // Read Data Channel
    output logic [AXI_DATA_WIDTH-1:0] s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready
);
    import sparse_pkg::*;

    // --- Register Map Definitions ---
    // 0x00: Control Register (Bit 0: Start, Bit 1: Done)
    logic [31:0] reg_ctrl;
    // 0x04 - 0x10: Input Activation Vector (4 Elements)
    logic [31:0] reg_act [0:3];
    // 0x14 - 0x20: Result Registers (Read Only)
    logic signed [31:0] reg_res [0:3];

    // --- Core Signals ---
    logic core_en;
    logic core_start;
    logic [3:0] latency_counter; // Counter for operation latency
    logic operation_done;
    
    activation_vec_t core_act_vec;
    logic signed [19:0] core_psum [0:3];
    
    // Internal Weight Memory (Pre-loaded for demo purposes)
    sparse_packet_t w_rows [0:3]; 
    logic [7:0] mem_weights [0:1023];
    logic [1:0] mem_indices [0:1023];

    // --- State Machine States ---
    typedef enum logic [1:0] {IDLE, COMPUTE, DONE} state_t;
    state_t current_state;

    // AXI Helper Signal
    logic aw_en;

    // -------------------------------------------------------------------------
    // 1. AXI WRITE LOGIC (Processor -> FPGA)
    // -------------------------------------------------------------------------
    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_awready <= 0;
            s_axi_wready  <= 0;
            s_axi_bvalid  <= 0;
            s_axi_bresp   <= 0;
            aw_en         <= 1;
            reg_ctrl      <= 0; // Clear Control Register
            for(int i=0; i<4; i++) reg_act[i] <= 0;
        end else begin
            // Handshake Logic
            if (~s_axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
                s_axi_awready <= 1;
                s_axi_wready  <= 1;
            end else begin
                s_axi_awready <= 0;
                s_axi_wready  <= 0;
            end

            // Write Data to Registers
            if (s_axi_awready && s_axi_wready) begin
                case (s_axi_awaddr[5:2]) // Address decoding (Word aligned)
                    4'h0: reg_ctrl      <= s_axi_wdata; // Write to Control Reg
                    4'h1: reg_act[0]    <= s_axi_wdata; // Write Act 0
                    4'h2: reg_act[1]    <= s_axi_wdata; // Write Act 1
                    4'h3: reg_act[2]    <= s_axi_wdata; // Write Act 2
                    4'h4: reg_act[3]    <= s_axi_wdata; // Write Act 3
                    default: ; 
                endcase
                s_axi_bvalid <= 1; // Signal Write Response
            end else if (s_axi_bready && s_axi_bvalid) begin
                s_axi_bvalid <= 0; 
            end
            
            // Auto-clear Start Bit after operation completes
            if (operation_done) begin
                reg_ctrl[0] <= 0; // Clear Start bit
                reg_ctrl[1] <= 1; // Set Done bit
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. CORE CONTROL LOGIC (Simple FSM)
    // -------------------------------------------------------------------------
   assign core_start = reg_ctrl[0]; // Start bit from CPU

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            current_state <= IDLE;
            latency_counter <= 0;
            operation_done <= 0;
            core_en <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    operation_done <= 0;
                    if (core_start) begin
                        current_state <= COMPUTE;
                        core_en <= 1; // Motoru çalıştır (Sadece 1 cycle)
                        latency_counter <= 0;
                    end
                end

                COMPUTE: begin
                    core_en <= 0; // <--- KRİTİK HAMLE: Enable'ı hemen kapat!
                    // Böylece PE sadece 1 kez toplama yapar, sonra sonucu tutar.
                    
                    // Yine de işlemciyi "işim bitmedi" diye bekletmeye devam et (Latency Simülasyonu)
                    if (latency_counter >= 9) begin
                        current_state <= DONE;
                    end else begin
                        latency_counter <= latency_counter + 1;
                    end
                end

                DONE: begin
                    operation_done <= 1;
                    current_state <= IDLE;
                end
            endcase
        end
    end

    // Map AXI Registers to Core Inputs
    assign core_act_vec[0] = reg_act[0][7:0];
    assign core_act_vec[1] = reg_act[1][7:0];
    assign core_act_vec[2] = reg_act[2][7:0];
    assign core_act_vec[3] = reg_act[3][7:0];

    // Instantiate the Sparse Core
    sparse_core u_core (
        .clk      (aclk),
        .rst_n    (aresetn),
        .en       (core_en),
        .w_rows   (w_rows),
        .act_vec  (core_act_vec),
        .psum_out (core_psum)
    );

    // Map Core Outputs to AXI Registers (Sign Extension)
    always_comb begin
        for(int i=0; i<4; i++) begin
            // Extend 20-bit result to 32-bit AXI register
            reg_res[i] = 32'(signed'(core_psum[i])); 
        end
    end
    
    // Load Weights from Memory File (Simulation Only)
    initial begin
        $readmemh("weights_nz.mem", mem_weights);
        $readmemb("indices.mem", mem_indices);
    end
    
    // Connect Memory to Core Interface
    always_comb begin
         for (int i = 0; i < 4; i++) begin
            w_rows[i].val_0 = mem_weights[2*i];
            w_rows[i].val_1 = mem_weights[2*i + 1];
            w_rows[i].idx_0 = mem_indices[2*i];
            w_rows[i].idx_1 = mem_indices[2*i + 1];
        end
    end

    // -------------------------------------------------------------------------
    // 3. AXI READ LOGIC (FPGA -> Processor)
    // -------------------------------------------------------------------------
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr_reg;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            s_axi_arready <= 0;
            s_axi_rvalid  <= 0;
            s_axi_rdata   <= 0;
        end else begin
            // Read Address Handshake
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1;
                s_axi_araddr_reg <= s_axi_araddr;
            end else begin
                s_axi_arready <= 0;
            end

            // Read Data Logic
            if (s_axi_arready && s_axi_arvalid && ~s_axi_rvalid) begin
                s_axi_rvalid <= 1;
                case (s_axi_araddr[5:2]) 
                    4'h0: s_axi_rdata <= reg_ctrl;     // Read Status
                    4'h5: s_axi_rdata <= reg_res[0];   // Read Result 0
                    4'h6: s_axi_rdata <= reg_res[1];   // Read Result 1
                    4'h7: s_axi_rdata <= reg_res[2];   // Read Result 2
                    4'h8: s_axi_rdata <= reg_res[3];   // Read Result 3
                    default: s_axi_rdata <= 32'hDEADBEEF; // Error Code
                endcase
            end else if (s_axi_rready && s_axi_rvalid) begin
                s_axi_rvalid <= 0;
            end
        end
    end

endmodule