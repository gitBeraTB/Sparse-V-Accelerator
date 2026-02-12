# Makefile - Ayrılmış Dosyalar ve Gerçek Veri İçin

# Simülatör ve Dil Ayarları
SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# HDL Klasörünün Yolu (Test klasörünün bir üstündeki HDL klasörü)
HDL_DIR = $(PWD)/../HDL

# ----------------------------------------------------
# KAYNAK DOSYALAR (Sıralama Çok Önemli!)
# ----------------------------------------------------

# 1. Önce Paket Derlenmeli (Diğerleri bunu kullanıyor)
VERILOG_SOURCES += $(HDL_DIR)/sparse_pkg.sv

# 2. Alt Modüller
VERILOG_SOURCES += $(HDL_DIR)/sparse_processing_element.sv
VERILOG_SOURCES += $(HDL_DIR)/sparse_core.sv
VERILOG_SOURCES += $(HDL_DIR)/gelu_pwl_lut.sv

# 3. En Son Tepe Modül
VERILOG_SOURCES += $(HDL_DIR)/sparse_inference_engine.sv
# ----------------------------------------------------

# Test Ayarları
COCOTB_TEST_MODULES = test_engine
TOPLEVEL = sparse_inference_engine

# Derleyici Parametreleri (SystemVerilog 2012 aktif)
COMPILE_ARGS += -I$(HDL_DIR) -g2012

# Simülasyon sırasında .mem dosyasını bulabilmesi için
# (Eğer hafıza dosyası Test klasöründeyse Icarus genellikle bulur)

# Cocotb Standart Makefile'ı Çağır
include $(shell cocotb-config --makefiles)/Makefile.sim