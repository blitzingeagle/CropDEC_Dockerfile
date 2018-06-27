FROM nvidia/cuda:8.0-cudnn7-devel-ubuntu16.04

# Setup environment variables

ENV OPENCV_VERSION 3.2.0
ENV OPENCV_PACKAGES libswscale-dev libjpeg-dev libpng-dev libtiff-dev libjasper-dev libdc1394-22-dev

ENV FFMPEG_VERSION 3.3.2
ENV FFMPEG_DEV_PACKAGES libavcodec-dev libavfilter-dev libavformat-dev libavresample-dev libavutil-dev libpostproc-dev libswresample-dev libswscale-dev libass-dev libwebp-dev libvorbis-dev zlib1g-dev libx264-dev libxvidcore-dev
ENV BUILD_PACKAGES build-essential yasm autoconf automake libtool pkg-config git wget unzip texinfo

ENV CAFFE_PACKAGES libprotobuf-dev libleveldb-dev libsnappy-dev libhdf5-serial-dev protobuf-compiler gfortran libjpeg62 libfreeimage-dev python-dev \
    python-pip python-scipy python-matplotlib python-scikits-learn ipython python-h5py python-leveldb python-networkx python-nose python-pandas \
    python-dateutil python-protobuf python-yaml python-gflags python-skimage python-sympy cython \
    libgoogle-glog-dev libbz2-dev libxml2-dev libxslt-dev libffi-dev libssl-dev libgflags-dev liblmdb-dev libboost1.58-all-dev libatlas-base-dev

ENV WORKSPACE /workspace

RUN mkdir $WORKSPACE
WORKDIR $WORKSPACE

# Install some dependency packages

# OpenCV
RUN apt-get update && \
    apt-get install -y $BUILD_PACKAGES $OPENCV_PACKAGES $FFMPEG_DEV_PACKAGES && \
    apt-get remove -y cmake

# Python3
RUN apt-get install -y python3-dev python3-pip

# Caffe
RUN apt-get install -y software-properties-common python-software-properties build-essential pkg-config bc && \
    add-apt-repository -y ppa:boost-latest/ppa && \
    apt-get install -y $CAFFE_PACKAGES

# Clean
RUN add-apt-repository -y --remove ppa:boost-latest/ppa && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install custom, accelerated FFMPEG

RUN cd /usr/local/src && \
    git clone https://github.com/FFmpeg/FFmpeg.git ffmpeg && \
    cd /usr/local/src/ffmpeg && \
    git checkout n$FFMPEG_VERSION && \
    ./configure \
      --build-suffix=-ffmpeg --toolchain=hardened --libdir=/usr/lib/x86_64-linux-gnu --incdir=/usr/include/x86_64-linux-gnu --cc=cc --cxx=g++ \
      --enable-gpl --enable-shared --disable-stripping --enable-avresample \
      --enable-avisynth --enable-libass --enable-libvorbis \
      --enable-libwebp --enable-libxvid \
      --enable-libdc1394 --enable-libx264 --enable-nonfree \
      --enable-cuda --enable-cuvid --enable-nvenc --enable-nonfree --enable-libnpp \
      --extra-cflags=-I/usr/local/cuda/include --extra-ldflags=-L/usr/local/cuda/lib64 && \
    make -j $(nproc) && \
    make install

# Upgrade CMake

RUN cd /usr/local/src && \
    wget http://www.cmake.org/files/v3.5/cmake-3.5.1.tar.gz && \
    tar xf cmake-3.5.1.tar.gz && \
    cd cmake-3.5.1 && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    rm /usr/local/src/cmake-3.5.1.tar.gz

# Install OpenCV

RUN cd /usr/local/src && \
    git clone https://github.com/opencv/opencv.git && \
    cd opencv && \
    git checkout $OPENCV_VERSION && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_INSTALL_PREFIX=/usr \
          -D BUILD_EXAMPLES=OFF \
          -D CUDA_GENERATION=Auto \
          -D WITH_IPP=OFF -D WITH_TBB=ON \
          -D WITH_FFMPEG=ON -D WITH_V4L=OFF \
          -D ENABLE_FAST_MATH=1 -D CUDA_FAST_MATH=1 -D WITH_CUBLAS=1 \
          -D WITH_VTK=OFF -D WITH_OPENGL=OFF -D WITH_QT=OFF .. && \
    make && make install

# Setup darknet

RUN cd /usr/local/src && \
    git clone -b v2.0 https://github.com/blitzingeagle/darknet.git --recurse-submodules && \
    cd darknet/json-c && \
    sh autogen.sh && ./configure && make && make install && make check

ENV DARKNET_PATH /usr/local/src/darknet
ENV LD_LIBRARY_PATH=/usr/local/lib:${PATH}

RUN cd $DARKNET_PATH && \
    make && \
    cd /usr/local/bin && ln -s $DARKNET_PATH/darknet darknet

# Setup CropYOLO

RUN cd $WORKSPACE && \
    git clone -b release https://github.com/blitzingeagle/CropYOLO.git && \
    cd CropYOLO && \
    pip3 install -r requirements.txt && \
    cp cfg/* $DARKNET_PATH/cfg/ && \
    cp data/* $DARKNET_PATH/data/

# Setup ImageDEC

RUN pip install -U leveldb

RUN cd $WORKSPACE && \
    git clone -b release https://github.com/blitzingeagle/ImageDEC.git && \
    cd ImageDEC/caffe && \
    cp Makefile_ubuntu16_04.config.example Makefile.config && \
    make -j"$(nproc)" all && \
    make pycaffe && \
    export PATH=$(pwd)/build/tools:$PATH && \
    export PYTHONPATH=$(pwd)/python:$PYTHONPATH

COPY . $WORKSPACE
