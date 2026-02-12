import numpy as np

def gelu_func(x):
    # Tam hassasiyetli GELU fonksiyonu
    return 0.5 * x * (1 + np.tanh(np.sqrt(2 / np.pi) * (x + 0.044715 * x**3)))

def to_fixed(val, bits=16, frac=8):
    # Float -> Fixed Point (Q8.8) dönüşümü
    scale = 2**frac
    val_int = int(round(val * scale))
    if val_int < 0:
        val_int = (1 << bits) + val_int
    return val_int & ((1 << bits) - 1)

def generate_lut():
    print("Gerçek GELU Tablosu Oluşturuluyor...")
    
    with open("gelu_lut.mem", "w") as f:
        # 512 satır (Giriş aralığı: -4.0 ile +4.0 arası gibi düşün)
        # Adres 0-511. Her adres bir giriş değerini temsil eder.
        
        for i in range(512):
            # 1. Giriş değerini belirle (Q8.8 formatında adres)
            # 9 bit adres -> Q8.8 degeri (Kabaca -4 ile +4 arasi map edilebilir ama basit tutalim)
            # Basitlik için: Adresin kendisi giriş değerimiz olsun (0.00, 0.01, ... 1.99)
            
            x_val = i / 256.0 # Q8.8 mantığı (256 = 1.0)
            
            # Eğer negatif sayıları simüle etmek istiyorsak sign extension gerekir ama 
            # şimdilik pozitif bölgeye bakalım.
            
            # 2. Y (Intercept) değerini hesapla
            y_val = gelu_func(x_val)
            
            # 3. Slope (Eğim) hesapla (Türev mantığı veya bir sonraki nokta farkı)
            next_y = gelu_func(x_val + (1/256.0))
            slope_val = (next_y - y_val) * 256.0 # Delta Y / Delta X
            
            # 4. Hex'e çevir
            hex_slope = to_fixed(slope_val, 16, 8)
            hex_intercept = to_fixed(y_val, 16, 8)
            
            # 5. Dosyaya yaz (Üst 16 bit: Slope, Alt 16 bit: Intercept)
            f.write(f"{hex_slope:04x}{hex_intercept:04x}\n")
            
    print("Dosya hazır: gelu_lut.mem")

if __name__ == "__main__":
    generate_lut()