NAME = usb_sniffer
OUT_DIR = bin
FIRMWARE_DIR = firmware
FPGA_DIR = fpga
SOFTWARE_DIR = software

UNAME := $(shell uname)

ifeq ($(UNAME), Linux)
	BIN_EXT =
	BIN_OS = linux
	EXTCAP_PATH = ~/.local/lib/wireshark/extcap
	UDEV_FILE = $(OUT_DIR)/90-$(NAME).rules
else ifeq ($(UNAME), Darwin)
	BIN_EXT =
	BIN_OS = macos
	EXTCAP_PATH = ~/.local/lib/wireshark/extcap
else
	BIN_EXT = .exe
	BIN_OS = win
	EXTCAP_PATH = $(APPDATA)/Wireshark/extcap/
endif

BIN = $(NAME)_$(BIN_OS)$(BIN_EXT)

.PHONY: software firmware fpga install install-udev prog-init prog-eeprom prog-fpga clean test

all: software firmware | fpga

install: software | $(EXTCAP_PATH)
	cp $(OUT_DIR)/$(BIN) $(EXTCAP_PATH)/$(NAME)$(BIN_EXT)

install-udev: | $(UDEV_FILE)
	ifeq ($(UNAME), Linux)
		cp $(UDEV_FILE) /etc/udev/rules.d/
	endif

prog-init: software firmware fpga
	echo 'Programming SRAM:'
	$(OUT_DIR)/$(BIN) --mcu-sram $(OUT_DIR)/$(NAME).bin
	sleep 5
	echo 'Programming EEPROM:'
	$(MAKE) prog-eeprom
	sleep 5
	echo 'Programming FPGA:'
	$(MAKE) prog-fpga

prog-eeprom: software firmware
	$(OUT_DIR)/$(BIN) --mcu-eeprom $(OUT_DIR)/$(NAME).bin

prog-fpga: software fpga
	$(OUT_DIR)/$(BIN) --fpga-flash $(OUT_DIR)/$(NAME)_impl.jed

test: software
	$(OUT_DIR)/$(BIN) --test

software: $(OUT_DIR)/$(BIN)

firmware: $(OUT_DIR)/$(NAME).bin

fpga: $(OUT_DIR)/$(NAME)_impl.jed

$(EXTCAP_PATH):
	mkdir -p $(EXTCAP_PATH)

$(OUT_DIR)/$(BIN): $(SOFTWARE_DIR)/*.c $(SOFTWARE_DIR)/*.h
	$(MAKE) -C $(SOFTWARE_DIR) BIN=$(BIN)
	mv $(SOFTWARE_DIR)/$(BIN) $(OUT_DIR)/

$(OUT_DIR)/$(NAME).bin: $(FIRMWARE_DIR)/*.c $(FIRMWARE_DIR)/*.h
	$(MAKE) -C $(FIRMWARE_DIR) OUT=$(NAME).bin
	mv $(FIRMWARE_DIR)/$(NAME).bin $(OUT_DIR)/

$(OUT_DIR)/$(NAME)_impl.jed: $(FPGA_DIR)/*.v
# I don't know how a jed file gets built, so just warn the user
	echo 'FPGA source files are newer than output file! Please rebuild!'

clean:
	$(MAKE) -C $(FIRMWARE_DIR) OUT=$(NAME).bin clean
	$(MAKE) -C $(SOFTWARE_DIR) BIN=$(BIN) clean
	rm -f $(OUT_DIR)/$(BIN) $(OUT_DIR)/$(NAME).bin