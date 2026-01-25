`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/24/2026 06:14:11 PM
// Design Name: 
// Module Name: tb_sparse_core
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

module tb_sparse_core;
    import sparse_pkg::*;

    logic clk, rst_n, en;
    sparse_packet_t w_rows [0:3]; // 4 PE için 4 ayrı paket
    activation_vec_t act_vec;
    logic signed [19:0] psum_out [0:3];

    // Bellekler
    logic [7:0] mem_weights [0:1023];
    logic [1:0] mem_indices [0:1023];

    // DUT (Core Modülü)
    sparse_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .w_rows(w_rows),
        .act_vec(act_vec),
        .psum_out(psum_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Dosyaları yükle
        $readmemh("weights_nz.mem", mem_weights);
        $readmemb("indices.mem", mem_indices);
        
        rst_n = 0; en = 0;
        #20 rst_n = 1;
        
        // --- VERİ DAĞITIMI (LOADING) ---
        // Bellekteki düz veriyi, PE'lere (Satırlara) dağıtıyoruz.
        // Her satır 2 ağırlık (val_0, val_1) kullanıyor.
        for (int i = 0; i < 4; i++) begin
            // i. Satır için bellek adresleri: 2*i ve 2*i + 1
            w_rows[i].val_0 = mem_weights[2*i];
            w_rows[i].val_1 = mem_weights[2*i + 1];
            w_rows[i].idx_0 = mem_indices[2*i];
            w_rows[i].idx_1 = mem_indices[2*i + 1];
        end

        // --- TEST SENARYOSU ---
        // Tüm girişler 10 olsun.
        act_vec[0] = 10; act_vec[1] = 10; act_vec[2] = 10; act_vec[3] = 10;
        
        #10 en = 1;
        #20; // Sonucun hesaplanmasını bekle

        // --- SONUÇLARI GÖSTER ---
        $display("--- 4x4 Matris Çarpımı Sonuçları ---");
        for (int i = 0; i < 4; i++) begin
             $display("Row %0d Output: %d", i, $signed(psum_out[i]));
        end
        
        // Python çıktısına göre beklenen değerleri kontrol edelim:
        // Row 0: 210 (Zaten doğruladık)
        // Row 1: (16*10 + 8*10) = 240
        // Row 2: (-5*10 + -5*10) = -100
        // Row 3: (-19*10 + -17*10) = -360
        
        #50 $finish;
    end
endmodule