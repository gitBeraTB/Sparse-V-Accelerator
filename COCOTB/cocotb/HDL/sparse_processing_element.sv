`timescale 1ns / 1ps

module sparse_processing_element import sparse_pkg::*; (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    input  sparse_packet_t   w_packet,
    input  activation_vec_t  act_vec,
    output logic signed [19:0] psum_out 
);

    // Sinyal Tanımları
    logic signed [19:0] accumulator;
    
    logic [1:0] clean_idx0, clean_idx1;
    logic signed [7:0] clean_w0, clean_w1;
    logic signed [7:0] raw_a0, raw_a1;
    logic signed [7:0] clean_a0, clean_a1;
    logic signed [15:0] prod0, prod1;

    // Giriş Temizleme (X gelirse 0 yap)
    assign clean_idx0 = (^w_packet.idx_0 === 1'bx) ? 2'b00 : w_packet.idx_0;
    assign clean_idx1 = (^w_packet.idx_1 === 1'bx) ? 2'b00 : w_packet.idx_1;
    assign clean_w0   = (^w_packet.val_0 === 1'bx) ? 8'sd0 : $signed(w_packet.val_0);
    assign clean_w1   = (^w_packet.val_1 === 1'bx) ? 8'sd0 : $signed(w_packet.val_1);

    // Aktivasyon Okuma
    assign raw_a0 = $signed(act_vec[clean_idx0]);
    assign raw_a1 = $signed(act_vec[clean_idx1]);

    // Aktivasyon Temizleme
    assign clean_a0 = (^raw_a0 === 1'bx) ? 8'sd0 : raw_a0;
    assign clean_a1 = (^raw_a1 === 1'bx) ? 8'sd0 : raw_a1;

    // Çarpma
    assign prod0 = clean_w0 * clean_a0;
    assign prod1 = clean_w1 * clean_a1;

    // Biriktirme (Sequential)
   always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 20'sd0;
            psum_out    <= 20'sd0; 
        end else if (en) begin
            // HATA BURADAYDI:
            // Eski Kod: psum_out <= accumulator; (Eski değeri veriyordu: 0)
            
            // DÜZELTME:
            // Yeni hesaplanan toplamı hem hafızaya hem çıkışa veriyoruz.
            accumulator <= accumulator + prod0 + prod1;
            psum_out    <= accumulator + prod0 + prod1; // <--- KRİTİK DEĞİŞİKLİK
            
            // Debug mesajını da güncelleyelim
            // $display("PE DEBUG: InputW=%d | Prod=%d | NewOut=%d", clean_w0, prod0, (accumulator + prod0 + prod1));
        end
    end

endmodule