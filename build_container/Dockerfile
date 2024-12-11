FROM base-image-ubuntu:22.04-ustc AS base22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc g++ vim gdb && \
    rm -rf /var/lib/apt/lists/*

# 安装基本依赖环境
RUN apt-get update && \
    apt-get install -y --no-install-recommends flex bison bc libssl-dev libncurses-dev clang gcc-riscv64-linux-gnu g++-riscv64-linux-gnu llvm libreadline-dev && \
    apt-get install -y --no-install-recommends build-essential gcc-doc libsdl2-dev && \
    apt-get install -y --no-install-recommends git help2man perl python3 make autoconf g++ flex bison ccache && \
    apt-get install -y --no-install-recommends libgoogle-perftools-dev numactl perl-doc && \
    apt-get install -y --no-install-recommends libfl2 && \
    apt-get install -y --no-install-recommends libfl-dev && \
    apt-get install -y --no-install-recommends zlib1g zlib1g-dev && \
    apt-get install -y --no-install-recommends llvm-dev && \
    rm -rf /var/lib/apt/lists/*
# zlibc #ubuntu 22.04 is error

# 修复环境问题：gnu/stubs-ilp32.h: No such file or directory
#   ref. https://ysyx.oscc.cc/docs/ics-pa/2.2.html#%E8%BF%90%E8%A1%8C%E7%AC%AC%E4%B8%80%E4%B8%AAc%E7%A8%8B%E5%BA%8F
RUN sed -i 's|\(^# include <gnu/stubs-ilp32.h>$\)|//\1|' /usr/riscv64-linux-gnu/include/gnu/stubs.h


# 配置用户信息
RUN localedef -c -f UTF-8 -i zh_CN zh_CN.utf8
ENV LANG zh_CN.utf8
RUN git config --global user.name "oz1010" && \
    git config --global user.email "uu90909@gmail.com" && \
    git config --global core.pager "" && \
    git config --global alias.lm "log --color --date=format:'%Y-%m-%d %H:%M:%S' --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Cblue %s %Cgreen(%cd) %C(bold blue)<%an>%Creset'"

# sh cmake-3.31.1-linux-x86_64.sh --prefix=/opt/cmake-3.31.1
