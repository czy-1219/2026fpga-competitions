#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
tool=${RISCV_TOOLCHAIN:-/home/zhengzihao/toolchains/riscv/usr/bin/riscv64-unknown-elf-}
"${tool}gcc" -march=rv32im -mabi=ilp32 -O2 -ffreestanding -fno-builtin -fwrapv -fno-strict-aliasing -nostdlib -nostartfiles -Wl,-T,link.ld -Wl,-Map,nonconv.map -o nonconv.elf start.S nonconv.c -lgcc
"${tool}size" nonconv.elf
"${tool}objcopy" -O binary nonconv.elf nonconv.bin
python3 - <<'PY'
from pathlib import Path
b=Path('nonconv.bin').read_bytes()
assert len(b)<14336
b=b.ljust(16384,b'\0')
Path('nonconv.mem').write_text(''.join(f'{int.from_bytes(b[i:i+4],"little"):08x}\n' for i in range(0,len(b),4)))
PY
