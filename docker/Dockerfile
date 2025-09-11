FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    qemu-user \
    qemu-user-static \
    file \
    findutils \
    time \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# pin lit so 
RUN python3 -m pip install --break-system-packages "lit>=18,<22"

WORKDIR /workspace

# Shallow clone at the tag (faster + deterministic)
RUN git clone --depth 1 --branch llvmorg-20.1.8 https://github.com/llvm/llvm-test-suite.git

RUN mkdir -p /workspace/build

COPY build-x86.sh /workspace/
COPY run-x86-tests.sh /workspace/
COPY run-x86-bench-csv.sh /workspace/
COPY run-x86-bench-csv.sh /workspace/

RUN chmod +x /workspace/*.sh

CMD ["/bin/bash"]
