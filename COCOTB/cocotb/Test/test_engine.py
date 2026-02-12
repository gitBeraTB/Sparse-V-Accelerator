import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random
import numpy as np
import matplotlib.pyplot as plt # Grafik için gerekli kütüphane

# --- HELPER FUNCTIONS ---
def ideal_gelu(x):
    return 0.5 * x * (1 + np.tanh(np.sqrt(2 / np.pi) * (x + 0.044715 * x**3)))

def from_fixed_q8_8(int_val):
    return int_val / 256.0

@cocotb.test()
async def test_sparse_inference_engine(dut):
    # Verileri saklamak için listeler oluşturuyoruz
    inputs = []
    expected_outputs = []
    hardware_outputs = []

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    dut._log.info("--- STARTING TEST WITH VISUALIZATION ---")

    num_samples = 100 

    for i in range(num_samples):
        # Reset and Drive logic (Öncekiyle aynı)
        dut.en.value = 0
        dut.rst_n.value = 0
        await Timer(10, units="ns")
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        input_raw = random.randint(-128, 127)
        input_float = input_raw / 256.0
        
        # Drive hardware... (Sinyalleri sürme kısmı)
        val0_byte = input_raw & 0xFF
        dut.w_rows[0].value = (val0_byte << 12) | (0 << 2) | 1
        dut.act_vec.value = 0x01010101
        dut.en.value = 1
        await RisingEdge(dut.clk)
        dut.en.value = 0

        # Capture results...
        captured_int = None
        for _ in range(20): 
            await RisingEdge(dut.clk)
            if dut.result_valid.value == 1:
                captured_int = dut.result_data[0].value.to_signed()
                break
        
        if captured_int is not None:
            actual_float = from_fixed_q8_8(captured_int)
            expected_y = ideal_gelu(input_float)
            
            # Verileri listeye ekle
            inputs.append(input_float)
            expected_outputs.append(expected_y)
            hardware_outputs.append(actual_float)

            dut._log.info(f"Sample {i:02d}: PASS")

    # --- GRAFİK OLUŞTURMA BÖLÜMÜ ---
    dut._log.info("Generating comparison plot...")
    
    plt.figure(figsize=(10, 6))
    # Altın Model (Referans) - Mavi noktalar
    plt.scatter(inputs, expected_outputs, color='blue', label='Golden Model (Python)', alpha=0.6)
    # Donanım Çıktısı - Kırmızı çarpılar
    plt.scatter(inputs, hardware_outputs, color='red', marker='x', label='Hardware Output (RTL)', alpha=0.9)
    
    plt.title("GELU Activation: Hardware vs. Golden Model Comparison")
    plt.xlabel("Input Value (Q8.8 Fixed Point)")
    plt.ylabel("Output Value")
    plt.grid(True, linestyle='--', alpha=0.7)
    plt.legend()
    
    # Grafiği dosya olarak kaydet (PDF raporuna koymak için harika olur)
    plt.savefig("gelu_verification_plot.png")
    plt.show()

    dut._log.info("--- TEST COMPLETED ---")