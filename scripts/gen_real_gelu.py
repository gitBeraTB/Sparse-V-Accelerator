import numpy as np

def gelu_func(x):
    return 0.5 * x * (1 + np.tanh(np.sqrt(2 / np.pi) * (x + 0.044715 * x**3)))

def to_fixed(val, bits=16, frac=8):
    scale = 2**frac
    val_int = int(round(val * scale))
    if val_int > 32767: val_int = 32767
    if val_int < -32768: val_int = -32768
    return val_int & 0xFFFF

def generate_lut():
    print("GELU Tablosu Oluşturuluyor...")
    with open("gelu_lut.mem", "w") as f:
        # 0..511 Adres -> Q8.8 Formatında (Input/256.0)
        for i in range(512):
            if i < 256: input_int = i
            else:       input_int = i - 512
            
            x_val = input_int / 256.0
            y_val = gelu_func(x_val)
            
            # Slope 0, sadece Intercept (Y değeri) yazıyoruz.
            hex_slope = "0000"
            hex_intercept = to_fixed(y_val, 16, 8)
            
            f.write(f"{hex_slope}{hex_intercept:04x}\n")
    print("Dosya hazır: gelu_lut.mem")

if __name__ == "__main__":
    generate_lut()