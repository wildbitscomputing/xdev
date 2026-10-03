TASS ?= 64tass
TASSFLAGS ?= -C -Wall -Werror -x --verbose-list
FOENIXMGR ?= foenixmgr
TARGET ?= f256k
FLASH_ADDRESS ?= 380000

SRCS = xdev.s kernel_api.s mmu.s term.s file.s crc32.s pcopy.s

.PHONY: all flash clean
.DELETE_ON_ERROR:

all: xdev.bin xdev.lst

# Grouped outputs also rebuild when just the listing has been removed.
xdev.bin xdev.lst &: $(SRCS) Makefile
	$(TASS) $(TASSFLAGS) -I . -b -L xdev.lst -o xdev.bin xdev.s

flash: xdev.bin
	$(FOENIXMGR) flash --address $(FLASH_ADDRESS) --flash-sector 01 --target $(TARGET) xdev.bin

clean:
	rm -f xdev.bin xdev.lst
