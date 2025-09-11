# LLVM Test-Suite Runner (x86_64 + QEMU)
This repo provides a script to:
- Build LLVM’s `SingleSource/Benchmarks`
- Run them under **QEMU (x86_64)** or natively
- Collect **time + space metrics** into a CSV


## Environment Setup
This repo and script has been tested on:
- [x] Ubuntu 24.04.3 LTS (Noble)
- [ ] Ubuntu 24.04 LTS (Noble Numbat) (Ubuntu Server)

## Quick Start

```bash
git clone <this-repo-url>
cd llvm-ts-runner
chmod +x run.sh
./run.sh          # default: build + run benchmarks under QEMU
./run.sh --native # run natively instead of QEMU



