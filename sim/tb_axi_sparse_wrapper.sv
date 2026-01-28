`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/25/2026 02:56:49 PM
// Design Name: 
// Module Name: tb_axi_sparse_wrapper
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


// Dosya: tb_axi_sparse_wrapper.sv
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/25/2026 02:56:49 PM
// Design Name: 
// Module Name: tb_axi_sparse_wrapper
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


// Dosya: tb_axi_sparse_wrapper.sv
`timescale 1ns / 1ps

module tb_axi_sparse_wrapper;

    // Parametreler
    localparam int AXI_DATA_WIDTH = 32;
    localparam int AXI_ADDR_WIDTH = 6;

    // Sinyaller
    logic clk;
    logic rst_n;

    int cycle_count = 0;      // Genel sayaç
    int start_time = 0;       // Başlangıç zamanı
    int end_time = 0;         // Bitiş zamanı
    int latency_cycles = 0;   // Toplam geçen cycle

// Sürekli çalışan bir cycle sayacı
    always @(posedge clk) begin
        if (rst_n) cycle_count++;
    end

    // AXI Arayüz Sinyalleri
    logic [AXI_ADDR_WIDTH-1:0] s_axi_awaddr;
    logic                      s_axi_awvalid;
    logic                      s_axi_awready;
    logic [AXI_DATA_WIDTH-1:0] s_axi_wdata;
    logic [3:0]                s_axi_wstrb;
    logic                      s_axi_wvalid;
    logic                      s_axi_wready;
    logic [1:0]                s_axi_bresp;
    logic                      s_axi_bvalid;
    logic                      s_axi_bready;
    logic [AXI_ADDR_WIDTH-1:0] s_axi_araddr;
    logic                      s_axi_arvalid;
    logic                      s_axi_arready;
    logic [AXI_DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0]                s_axi_rresp;
    logic                      s_axi_rvalid;
    logic                      s_axi_rready;

    // DUT (Design Under Test)
    axi_sparse_wrapper #(
        .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
        .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH)
    ) u_dut (
        .aclk(clk),
        .aresetn(rst_n),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // Clock Generation
    initial clk = 0;
    always #5 clk = ~clk;

    // --- AXI YAZMA GÖREVİ (Processor Write Emulation) ---
    task axi_write(input logic [5:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1;
            s_axi_wstrb   <= 4'b1111;
            s_axi_bready  <= 1;

            // Handshake bekle
            wait(s_axi_awready && s_axi_wready);
            
            @(posedge clk);
            s_axi_awvalid <= 0;
            s_axi_wvalid  <= 0;

            // Cevap bekle
            wait(s_axi_bvalid);
            @(posedge clk);
            s_axi_bready  <= 0;
        end
    endtask

    // --- AXI OKUMA GÖREVİ (Processor Read Emulation) ---
    task axi_read(input logic [5:0] addr);
        begin
            @(posedge clk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1;
            s_axi_rready  <= 1;

            // Adres kabul edilene kadar bekle
            wait(s_axi_arready);
            @(posedge clk);
            s_axi_arvalid <= 0;

            // Veri gelene kadar bekle
            wait(s_axi_rvalid);
            @(posedge clk);
            // Gelen veriyi ekrana yaz
            $display("Read Address: 0x%h, Data: %d (Hex: %h)", addr, $signed(s_axi_rdata), s_axi_rdata);
            s_axi_rready <= 0;
        end
    endtask

    // --- ANA TEST SENARYOSU ---
    initial begin
        // Reset
        rst_n = 0;
        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_arvalid = 0; s_axi_rready = 0;
        #20 rst_n = 1;
        #10;

        $display("--- Simulation Start UP ---");

        // 1. Giriş Vektörünü Yükle (Input Loading)
        // İşlemci sırayla 0x04, 0x08, 0x0C, 0x10 adreslerine yazıyor.
        // Hepsi 10 olsun.
        $display("-> Writing Input Vectors...");
        axi_write(6'h04, -58);
        axi_write(6'h08, -64);
        axi_write(6'h0C, -28);
        axi_write(6'h10, -6);

        $display("--- Performance Test Begins ---");

        // 1. Başlangıç Zamanını Kaydet
         start_time = cycle_count; 

        // 2. İşlemi Başlat (Start Bit)
        // Control Register (0x00) bit-0'ı 1 yap.
        $display("-> Starting Core...");
        axi_write(6'h00, 32'd1);

        // 3. Hesaplama için bekle
       #100;
        end_time = cycle_count;
        latency_cycles = end_time - start_time;

        $display("Total Cycles: %0d Clock Cycles (Approximation)", latency_cycles);

        // 4. Sonuçları Oku (Reading Results)
        // 0x14, 0x18, 0x1C, 0x20 adreslerinden oku.
        $display("-> Reading Results...");
        axi_read(6'h14); // Beklenen:  1384
        axi_read(6'h18); // Beklenen: -4224
        axi_read(6'h1C); // Beklenen: -4682
        axi_read(6'h20); // Beklenen: -10058

        $display("Hardware Latency: ~%0d Cycles", (end_time - start_time));
        $display("--- SIMULATION FINISHED ---");
        #20 $finish;
    end

endmodule