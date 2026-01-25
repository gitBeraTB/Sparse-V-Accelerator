import numpy as np
import os


def int8_to_hex(val):
    """
    INT8 değerini 2 haneli Hex stringe çevirir (Two's Complement destekli).
    Örn: -5 -> 'fb', 10 -> '0a'
    """
    val = int(val)
    if val < 0:
        val = (1 << 8) + val  # Negatif sayıları 8-bit unsigned gibi göster
    return f"{val & 0xFF:02x}"


def apply_2_4_sparsity_and_pack(weight_matrix):
    """
    Bu fonksiyon:
    1. Matrisi 4'lü bloklara böler.
    2. Her blokta mutlak değeri en küçük 2 elemanı budar (sıfır yapar).
    3. Donanım için sıkıştırılmış veriyi (Non-zero değerler ve Indeksler) hazırlar.
    """
    rows, cols = weight_matrix.shape

    # Donanım belleğine yazılacak listeler
    packed_weights = []  # Sıkıştırılmış ağırlıklar (Sadece Non-Zero)
    packed_indices = []  # Bu ağırlıkların orijinal konumları (2-bit)

    # Görsel doğrulama için sparse matris kopyası
    sparse_matrix = np.zeros_like(weight_matrix)

    print(f"--- İşlem Başlıyor: {rows}x{cols} Matris ---")

    for r in range(rows):
        for c in range(0, cols, 4):
            # 1. 4'lü bloğu al
            block = weight_matrix[r, c:c + 4]

            # 2. Mutlak değerlerine göre sırala ve en büyük 2'sinin indeksini bul
            # argsort küçükten büyüğe sıralar, son 2'si en büyüklerdir.
            abs_block = np.abs(block)
            top_2_indices = np.argsort(abs_block)[-2:]
            top_2_indices = np.sort(top_2_indices)  # İndeks sırasını koru

            # 3. Sıkıştırılmış veriyi oluştur
            nz_val_0 = block[top_2_indices[0]]
            nz_val_1 = block[top_2_indices[1]]

            idx_0 = top_2_indices[0]
            idx_1 = top_2_indices[1]

            # Listelere ekle
            packed_weights.append(nz_val_0)
            packed_weights.append(nz_val_1)
            packed_indices.append(idx_0)
            packed_indices.append(idx_1)

            # 4. Sparse Matrisi güncelle (Görsel kontrol için)
            sparse_matrix[r, c + idx_0] = nz_val_0
            sparse_matrix[r, c + idx_1] = nz_val_1

    return sparse_matrix, packed_weights, packed_indices


def generate_files():
    # 1. Rastgele Ağırlık Matrisi Oluştur (Float) - 4x4
    # Gerçek senaryoda burası eğitilmiş modelden (model.get_weights()) gelir.
    np.random.seed(42)
    float_weights = np.random.randn(4, 4) * 10

    # 2. INT8 Quantization Simülasyonu
    int8_weights = np.round(float_weights).astype(np.int8)

    print("Orijinal INT8 Matris:")
    print(int8_weights)
    print("-" * 30)

    # 3. Sparsity Uygula ve Paketle
    sparse_mat, pkg_weights, pkg_indices = apply_2_4_sparsity_and_pack(int8_weights)

    print("2:4 Sparse Matris (Budanmış):")
    print(sparse_mat)
    print("-" * 30)

    # 4. Çıktı klasörünü belirle (sim klasörüne yazmak mantıklı olabilir)
    # Eğer bu script 'scripts' klasöründeyse, bir üstteki 'sim' klasörüne yazsın.
    output_dir = os.path.join(os.path.dirname(__file__), '../sim')
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    weights_path = os.path.join(output_dir, "weights_nz.mem")
    indices_path = os.path.join(output_dir, "indices.mem")

    # 5. SystemVerilog .mem Dosyalarını Oluştur
    with open(weights_path, "w") as f_w, open(indices_path, "w") as f_i:
        for w, idx in zip(pkg_weights, pkg_indices):
            # Ağırlığı Hex yaz (örn: -5 -> fb)
            f_w.write(f"{int8_to_hex(w)}\n")
            # İndeksi Binary yaz (2-bit, örn: 3 -> 11)
            f_i.write(f"{idx:02b}\n")

    print(f"DOSYALAR OLUŞTURULDU: {output_dir}")
    print("1. weights_nz.mem")
    print("2. indices.mem")


if __name__ == "__main__":
    generate_files()