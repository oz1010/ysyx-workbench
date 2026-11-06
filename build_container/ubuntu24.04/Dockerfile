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
    apt-get install -y --no-install-recommends ripgrep bsdextrautils scons && \
    apt-get install -y --no-install-recommends zstd liblz4-dev && \
    rm -rf /var/lib/apt/lists/*
# zlibc #ubuntu 22.04 is error

# 修复环境问题：gnu/stubs-ilp32.h: No such file or directory
#   ref. https://ysyx.oscc.cc/docs/ics-pa/2.2.html#%E8%BF%90%E8%A1%8C%E7%AC%AC%E4%B8%80%E4%B8%AAc%E7%A8%8B%E5%BA%8F
RUN sed -i 's|\(^# include <gnu/stubs-ilp32.h>$\)|//\1|' /usr/riscv64-linux-gnu/include/gnu/stubs.h

# 手动安装verilator 5.030
# ADD extra/verilator-5.030.tgz /usr/local
# 已经安装到了tar xvf ~/oss-cad-suite-linux-x64-20250624.tgz -C /root/tools

# 安装依赖java环境
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl wget gpg apt-transport-https && \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null && \
    echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | tee /etc/apt/sources.list.d/adoptium.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends temurin-17-jdk && \
    rm -rf /var/lib/apt/lists/*
# 手动安装scala-cli，安装到/root/tools/scala/bin，https://github.com/VirtusLab/scala-cli/releases scala-cli-x86_64-pc-linux.gz
# 手动配置mill加速，构建时未挂载主目录
# mkdir -p ~/.config/coursier
# cat > ~/.config/coursier/mirror.properties << 'EOF'
# central.from=https://repo1.maven.org/maven2
# central.to=https://maven.aliyun.com/repository/central
# EOF
# 手动安装mill，https://maven.aliyun.com/repository/central/com/lihaoyi/mill-dist/1.1.10/mill-1.1.10
# 手动安装firtool，https://github.com/llvm/circt/releases firrtl-bin-linux-x64.tar.gz，配置环境变量 
# 测试用例，https://github.com/chipsalliance/chisel/releases chisel-example.scala，scala-cli chisel-example.scala --jvm system


# 配置用户信息
RUN localedef -c -f UTF-8 -i zh_CN zh_CN.utf8
ENV LANG zh_CN.utf8
RUN git config --global user.name "oz1010" && \
    git config --global user.email "uu90909@gmail.com" && \
    git config --global core.pager "" && \
    git config --global alias.lm "log --color --date=format:'%Y-%m-%d %H:%M:%S' --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Cblue %s %Cgreen(%cd) %C(bold blue)<%an>%Creset'" && \
    git config --global credential.helper ""

# 配置root用户登陆
# 配置弱密码 echo 'root:rootpassword' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
EXPOSE 22
EXPOSE 9876
CMD ["/usr/sbin/sshd", "-D"]
