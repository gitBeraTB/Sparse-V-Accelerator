import numpy as np
import os
from sklearn.neural_network import MLPClassifier
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

# --- AYARLAR ---
BLOCK_SIZE = 4        
NUM_ROWS = 4          
NUM_COLS = 4          

def int8_to_hex(val):
    """INT8 değerini Hex stringe (Two's Complement) çevirir."""
    val = int(val)
    if val < 0: val = (1 << 8) + val
    return f"{val & 0xFF:02x}"

def train_and_export():
    print("--- 1. Scikit-Learn ile Rakam Tanıma Modeli Eğitiliyor ---")
    
    # 1. Veri Yükle (load_digits: 8x8 piksellik el yazısı rakamlar)
    digits = load_digits()
    X, y = digits.data, digits.target
    
    # Veriyi ölçekle (0-16 arası değerleri standartlaştır)
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Eğitim/Test ayır
    X_train, X_test, y_train, y_test = train_test_split(X_scaled, y, test_size=0.2, random_state=42)
    
    # 2. Modeli Kur ve Eğit (MLP - Multi Layer Perceptron)
    # 64 giriş -> 128 gizli nöron -> 10 çıkış
    mlp = MLPClassifier(hidden_layer_sizes=(128,), max_iter=50, random_state=1)
    mlp.fit(X_train, y_train)
    
    accuracy = mlp.score(X_test, y_test)
    print(f"Model Eğitildi! Doğruluk Oranı: %{accuracy*100:.2f}")

    print("\n--- 2. Ağırlıklar ve Gerçek Bir Giriş Resmi Alınıyor ---")
    
    # İlk katmanın ağırlıklarını al (coefs_[0]: 64x128)
    # Transpose alıyoruz (128x64) ki satır satır işleyelim
    dense_weights = mlp.coefs_[0].T 
    
    # Test setinden rastgele bir '5' veya '7' gibi bir resim seçelim
    sample_idx = 0
    input_image = X_test[sample_idx]
    actual_label = y_test[sample_idx]
    print(f"Seçilen Resim Etiketi (Gerçek): {actual_label}")

    # --- DONANIM KESİTİ (4x4 TILE) ---
    # Matrisin dolu (sıfır olmayan) bir bölgesini seçelim
    start_row = 10 
    start_col = 20 
    
    w_tile = dense_weights[start_row:start_row+NUM_ROWS, start_col:start_col+NUM_COLS]
    x_tile = input_image[start_col:start_col+NUM_COLS]
    
    print("\n--- 3. Quantization (Float -> INT8) ---")
    # Ağırlıkları ve girişleri -127...+127 arasına sığdır
    max_w = np.max(np.abs(dense_weights))
    max_x = np.max(np.abs(input_image))
    
    scale_w = 127.0 / (max_w if max_w > 0 else 1)
    scale_x = 127.0 / (max_x if max_x > 0 else 1)
    
    w_int8 = np.round(w_tile * scale_w).astype(np.int8)
    x_int8 = np.round(x_tile * scale_x).astype(np.int8)
    
    print("Quantized Giriş Vektörü:", x_int8)
    print("Quantized Ağırlık Matrisi:\n", w_int8)

    print("\n--- 4. 2:4 Structured Sparsity ve Paketleme ---")
    packed_weights = []
    packed_indices = []
    golden_results = []
    
    for r in range(NUM_ROWS):
        row = w_int8[r]
        
        # En büyük 2 elemanı bul (Mutlak değer)
        top2_idx = np.argsort(np.abs(row))[-2:]
        top2_idx = np.sort(top2_idx) # İndeksleri sıralı tut
        
        val0 = row[top2_idx[0]]
        val1 = row[top2_idx[1]]
        idx0 = top2_idx[0]
        idx1 = top2_idx[1]
        
        packed_weights.extend([val0, val1])
        packed_indices.extend([idx0, idx1])
        
        # Doğrulama Hesabı (Golden Reference)
        # Sadece seçilen (sparse) elemanlarla çarpım yapıyoruz
        res = (int(val0) * int(x_int8[idx0])) + (int(val1) * int(x_int8[idx1]))
        golden_results.append(res)

    print("\n--- 5. Dosyalar Oluşturuluyor ---")
    output_dir = os.path.join(os.path.dirname(__file__), '../sim')
    if not os.path.exists(output_dir): os.makedirs(output_dir)
    
    with open(os.path.join(output_dir, "weights_nz.mem"), "w") as fw:
        for val in packed_weights:
            fw.write(f"{int8_to_hex(val)}\n")
            
    with open(os.path.join(output_dir, "indices.mem"), "w") as fi:
        for idx in packed_indices:
            fi.write(f"{idx:02b}\n")

    print(f"Dosyalar güncellendi: {output_dir}")
    
    print("\n" + "="*60)
    print(" >>> AŞAĞIDAKİ KODU 'tb_axi_sparse_wrapper.sv' İÇİNE YAPIŞTIR <<<")
    print("="*60)
    
    # Verilog Kodu Çıktısı
    axi_addrs = ["6'h04", "6'h08", "6'h0C", "6'h10"]
    print("// 1. Giriş Vektörünü Yükle (Python'dan gelen gerçek veriler)")
    for i in range(4):
        print(f"axi_write({axi_addrs[i]}, 32'd{x_int8[i]});")
        
    print("\n// 4. Sonuçları Oku ve Karşılaştır")
    res_addrs = ["6'h14", "6'h18", "6'h1C", "6'h20"]
    for i in range(4):
        print(f"axi_read({res_addrs[i]}); // Row {i} Beklenen: {golden_results[i]}")
    print("="*60)

if __name__ == "__main__":
    train_and_export()