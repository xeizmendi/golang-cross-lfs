# golang parameters
ARG GO_VERSION=1.20.8

# OS-X SDK parameters
ARG OSX_SDK=MacOSX13.0.sdk
ARG OSX_SDK_SUM=614e6cd5443c1c8329c018e3a94f69cf6d6ef8a0d32e1f1531ca6e4dfb39b0e8

# osxcross parameters
ARG OSX_VERSION_MIN=10.13
ARG OSX_CROSS_COMMIT=50e86ebca7d14372febd0af8cd098705049161b9

FROM debian:bookworm AS base

ENV OSX_CROSS_PATH=/osxcross

FROM base AS osx-sdk
ARG OSX_SDK
ARG OSX_SDK_SUM

COPY ${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"
RUN echo "${OSX_SDK_SUM}"  "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c -

FROM base AS osx-cross-base
ARG DEBIAN_FRONTEND=noninteractive
# Install deps
RUN set -x; echo "Starting image build for Debian Bullseye" \
 && dpkg --add-architecture arm64                      \
 && dpkg --add-architecture armel                      \
 && dpkg --add-architecture armhf                      \
 && dpkg --add-architecture i386                       \
 && dpkg --add-architecture mips                       \
 && dpkg --add-architecture mipsel                     \
 && dpkg --add-architecture powerpc                    \
 && dpkg --add-architecture ppc64el                    \
 && apt-get update                                     \
 && apt-get install -y -q                              \
        curl                                           \
        ca-certificates                                \
 && mkdir -pm755 /etc/apt/keyrings                     \
 && curl -s -o /etc/apt/keyrings/winehq-archive.key    \
        https://dl.winehq.org/wine-builds/winehq.key   \
 && curl -s -o /etc/apt/sources.list.d/winehq-bullseye.sources \
        https://dl.winehq.org/wine-builds/debian/dists/bullseye/winehq-bullseye.sources \
 && apt-get update                                     \
 && apt-get install -y -q --install-recommends         \
        winehq-stable                                  \
 && apt-get install -y -q                              \
        autoconf                                       \
        automake                                       \
        autotools-dev                                  \
        bc                                             \
        binfmt-support                                 \
        binutils-multiarch                             \
        binutils-multiarch-dev                         \
        build-essential                                \
        clang                                          \
        crossbuild-essential-arm64                     \
        crossbuild-essential-armel                     \
        crossbuild-essential-armhf                     \
        crossbuild-essential-mipsel                    \
        crossbuild-essential-ppc64el                   \
        devscripts                                     \
        gdb                                            \
        git-core                                       \
        libtool                                        \
        llvm                                           \
        mercurial                                      \
        multistrap                                     \
        patch                                          \
        software-properties-common                     \
        subversion                                     \
        wget                                           \
        xz-utils                                       \
        cmake                                          \
        qemu-user-static                               \
        libxml2-dev                                    \
        lzma-dev                                       \
        openssl                                        \
        mingw-w64                                      \
        libssl-dev                                     \
 &&	apt -y autoremove \
 &&	apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM osx-cross-base AS osx-cross
ARG OSX_CROSS_COMMIT
WORKDIR "${OSX_CROSS_PATH}"
# install osxcross:
RUN git clone https://github.com/tpoechtrager/osxcross.git . \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && rm -rf ./.git
COPY --from=osx-sdk "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ARG OSX_VERSION_MIN
RUN UNATTENDED=yes OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM golang:${GO_VERSION}-bullseye AS go-base

FROM osx-cross-base AS final
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH
ENV PATH /usr/local/go/bin:$PATH
ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
ENV HOME /go
ENV XDG_CACHE_HOME /go/.cache
WORKDIR $GOPATH
ENV GOLANG_VERSION ${GO_VERSION}
COPY --from=go-base /usr/local/go /usr/local/go
RUN groupadd -g 1001 testgroup \
 && useradd -u 1000 -U -G testgroup -d /home/testuser -m -s /bin/sh testuser
