# 使用一个稳定的基础镜像
FROM ubuntu:jammy

# 设置环境变量，避免交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# 第一部分：安装所有系统依赖项
# 将所有依赖安装放在一个或少数几个RUN指令中，以充分利用Docker层缓存。
# 只有当这些依赖需要变动时，这一层才会重新构建。
# ==============================================================================
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    cmake make gcc g++ pkg-config libfftw3-dev libmbedtls-dev \
    libsctp-dev libyaml-cpp-dev libgtest-dev libzmq3-dev \
    software-properties-common net-tools iputils-ping git && \
    # 清理apt缓存以减小镜像体积
    rm -rf /var/lib/apt/lists/*

# ==============================================================================
# 第二部分：安装UHD驱动
# 同样，这也是一个独立的、不常变动的步骤，适合单独一层。
# ==============================================================================
RUN add-apt-repository ppa:ettusresearch/uhd && \
    apt-get update && \
    apt-get -y install --no-install-recommends libuhd-dev uhd-host && \
    # 下载驱动镜像文件
    /usr/lib/uhd/utils/uhd_images_downloader.py && \
    rm -rf /var/lib/apt/lists/*

# ==============================================================================
# 第三部分：编译和安装 srsRAN_Project
# ==============================================================================
# 设置工作目录
WORKDIR /srsran_project

# 将你仓库中的所有代码（由GitHub Actions检出）复制到镜像的工作目录中
# 这是关键一步！当你的代码变动时，只有这一层及之后的缓存会失效。
COPY . .

# 创建构建目录并编译
RUN mkdir build && \
    cd build && \
    cmake ../ -DENABLE_EXPORT=ON -DENABLE_ZEROMQ=ON && \
    make -j$(nproc) && \
    make install && \
    # 更新动态链接库缓存
    ldconfig

# 设置UHD驱动镜像文件的环境变量
ENV UHD_IMAGES_DIR=/usr/share/uhd/images/

# 设置默认的启动命令
# 注意：CMD中的路径可能需要根据实际情况调整
# 这里假设 srsran_init.sh 是在仓库根目录
CMD cd /mnt/srsran && /mnt/srsran/srsran_init.sh
# 或者如果脚本在仓库根目录且有执行权限
# WORKDIR /srsran_project
# CMD ["./srsran_init.sh"]