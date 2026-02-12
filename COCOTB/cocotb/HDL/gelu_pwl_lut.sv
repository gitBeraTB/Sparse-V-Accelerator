module gelu_pwl_lut (
    input  logic               clk,
    input  logic               rst_n,
    input  logic signed [15:0] data_in,
    input  logic               valid_in,
    output logic signed [15:0] data_out,
    output logic               valid_out
);
    logic [31:0] rom_memory [0:511]; 

    // --- 1. DOSYADAN OKUMA ---
     initial begin
        
        $readmemh("/Users/berathmac/Documents/RISC-V/Sparse-V-Accelerator/COCOTB/cocotb/HDL/gelu_lut.mem", rom_memory);

        //$display("-----------------------------------------");
        //$display("GELU HAFIZA KONTROLU:");
        //$display("Adres 0: %h", rom_memory[0]);
        //$display("Adres 50: %h", rom_memory[50]);
        //$display("Adres 100: %h", rom_memory[100]);
        //$display("-----------------------------------------");
    end
    logic [8:0] lut_addr;
    logic       addr_valid;
    logic [7:0] fractional_part; // Interpolasyon için

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lut_addr <= 0; addr_valid <= 0; fractional_part <= 0;
        end else begin
            // Q8.8 formatında:
            // Tam sayı kısmı ([15:8]) ve sign biti adres olur (basitlestirilmis)
            // Ondalık kısmı ([7:0]) interpolasyon için saklanır
            lut_addr        <= data_in[8:0]; 
            fractional_part <= 0; 
            addr_valid      <= valid_in;
        end
    end

    logic signed [15:0] slope;
    logic signed [15:0] intercept;
    logic [7:0]  frac_d1;
    logic        stage2_valid;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slope <= 0; intercept <= 0; stage2_valid <= 0; frac_d1 <= 0;
        end else begin
            if (addr_valid) begin
                // Bellekten Slope ve Intercept çek
                slope     <= rom_memory[lut_addr][31:16];
                intercept <= rom_memory[lut_addr][15:0];
            end
            frac_d1      <= fractional_part;
            stage2_valid <= addr_valid;
        end
    end

    // --- 2. HESAPLAMA (Y = M*x + C) ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0; valid_out <= 0;
        end else begin
            if (stage2_valid) begin
                // Basit PWL Hesabı: Intercept + (Slope * Fractional)
                // Not: Q8.8 çarpma işlemi hassasiyet gerektirir.
                // Şimdilik "Staircase" (Merdiven) modu: Sadece Intercept verelim.
                // Eğer bu değer değişiyorsa, tablodan doğru okuyoruz demektir!
                
                // data_out <= intercept + ((slope * frac_d1) >>> 8); // İleri seviye
                
                data_out  <= intercept; // ŞİMDİLİK BUNU KULLAN (Garanti Yöntem)
                valid_out <= 1;
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule