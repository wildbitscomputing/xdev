# xdev

Cross-development firmware for the Foenix F256Jr and F256K, used with FoenixMgr.
It runs before the next firmware program and checks for a request in RAM:

- `CROSSDEV`: launch a PGX or PGZ program uploaded by FoenixMgr.
- `COPYFILE`: verify a file uploaded to RAM and write it to the SD card (drive 0).
- No request: continue booting with kernel firmware block `$42`.

## Build

Requires [64tass](https://sourceforge.net/projects/tass64/) and GNU Make 4.3 or
newer. From this directory:

```sh
make          # build xdev.bin and the assembly listing xdev.lst
make clean    # remove generated output
```

The build selects the 65C02 CPU, enables case-sensitive symbols, and treats
assembler warnings as errors. Override `TASS` to select another 64tass executable
or `TASSFLAGS` to change the assembler flags. No Windows tools are needed.

The source uses native 64tass syntax; it is no longer Merlin32 source. The port
replaces Merlin directives, local labels, bank-byte extraction, and table loops.
The generated image is exactly 8 KiB, with a kernel module header and a load
address of `$A000`. Assembly fails if the module exceeds that block.

## Firmware integration

xdev occupies flash sector `$01` (one 8 KiB block, kernel firmware block `$41`)
and hands normal boot to kernel block `$42`. `update.csv` contains `01,xdev.bin`
for the firmware updater, matching this layout.

```sh
make flash    # build and program only flash sector 01 using FoenixMgr
```

The flash target defaults to `--target f256k` and stages the image in RAM at
`$380000`, matching pexec's flash workflow. Override `TARGET`, `FLASH_ADDRESS`,
or `FOENIXMGR` as needed, for example
`make flash FOENIXMGR='foenixmgr --port /dev/ttyUSB0'`. Plain `make` only builds.

FoenixMgr places an eight-byte request signature at zero-page address `$80`.
For `CROSSDEV`, the entry address is at `$88`. xdev clears the signature and
restores physical block 5 in CPU slot 5 before jumping to the program.

For `COPYFILE`, the transfer at physical address `$010000` contains a
NUL-terminated filename, a four-byte little-endian CRC32, a three-byte
little-endian file length, then the file data. The maximum length is `$06FC00`
(447 KiB). The CRC uses polynomial `$EDB88320`, an initial value of zero, and no
final XOR. PCopy waits for reset after completion or an error.

## Source layout

- `xdev.s`: module header, request detection, and program launch.
- `pcopy.s`: transfer validation and SD-card copying.
- `mmu.s`: banked-memory access and mapping restoration.
- `file.s`: wrappers for asynchronous kernel file operations.
- `crc32.s`: transfer checksum calculation.
- `term.s`: text output and number formatting.
- `kernel_api.s`: kernel entry points and argument definitions.
