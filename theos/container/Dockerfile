FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash python3 ca-certificates git make perl rsync zip unzip ccache patch tar \
    clang gcc g++ binutils curl pkg-config fakeroot xz-utils file autoconf automake libtool llvm-dev \
    libtinfo6 libxml2 libuuid1 libbsd0 zlib1g && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
ENV THEOS=/root/theos
WORKDIR /workspace/theos
