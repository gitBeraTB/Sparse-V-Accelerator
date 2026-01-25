`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 05:41:12 PM
// Design Name: 
// Module Name: tb_sparse_pe
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


module tb_sparse_pe;
    import sparse_pkg::*; // Veri tiplerini al

    logic clk, rst_n, en;
    sparse_packet_t w_pkt;
    activation_vec_t act_vec;
    logic signed [19:0] psum;

    // Bellekler (Colab çıktılarını buraya yükleyeceğiz)
    logic [7:0] mem_weights [0:1023]; // weights_nz.mem
    logic [1:0] mem_indices [0:1023]; // indices.mem

    // DUT (Design Under Test)
    sparse_processing u_pe (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .w_pkt(w_pkt),
        .act_vec(act_vec),
        .psum(psum)
    );

    // Saat Sinyali
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // 1. Dosyaları Oku (Dosya yollarını kontrol edin!)
        $readmemh("weights_nz.mem", mem_weights); // Hex formatında
        $readmemb("indices.mem", mem_indices);    // Binary formatında
        
        // Simülasyon Başlat
        rst_n = 0; en = 0;
        #20 rst_n = 1;
        #10 en = 1;

        // TEST SENARYOSU: İlk satırı test edelim
        // Colab çıktısına göre ilk satır ağırlıkları: 6 ve 15
        // İndeksler: 2 ve 3
        
        // Donanıma paketle
        w_pkt.val_0 = mem_weights[0]; // 6 gelecek
        w_pkt.val_1 = mem_weights[1]; // 15 gelecek
        w_pkt.idx_0 = mem_indices[0]; // 2 gelecek
        w_pkt.idx_1 = mem_indices[1]; // 3 gelecek

        // Rastgele Girişler Verelim (Hepsi 10 olsun)
        // Beklenen: (6 * 10) + (15 * 10) = 60 + 150 = 210
        act_vec[0] = 10; 
        act_vec[1] = 10; 
        act_vec[2] = 10; // Bu seçilmeli (idx=2)
        act_vec[3] = 10; // Bu seçilmeli (idx=3)

        #20; // Clock cycle bekle
        
        $display("Input Act: %p", act_vec);
        $display("Weights: %d, %d", $signed(w_pkt.val_0), $signed(w_pkt.val_1));
        $display("Indices: %d, %d", w_pkt.idx_0, w_pkt.idx_1);
        $display("Result (PSUM): %d (Beklenen: 210)", $signed(psum));

        #50 $finish;
    end

endmodule
