# golang parameters
ARG GO_VERSION=1.16.3

# OS-X SDK parameters
ARG OSX_SDK=MacOSX10.15.sdk
ARG OSX_SDK_SUM=42829ecf867af21de530ceba255d4c01e468f35607715d9e5f63a1f8fa5f6a03

# osxcross parameters
ARG OSX_VERSION_MIN=10.12
ARG OSX_CROSS_COMMIT=2733413b6847c1489d6230f062d3293e6f42a021

FROM debian:buster AS base

ARG APT_MIRROR
RUN sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list
ENV OSX_CROSS_PATH=/osxcross

FROM base AS osx-sdk
ARG OSX_SDK
ARG OSX_SDK_SUM

COPY ${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"
RUN echo "${OSX_SDK_SUM}"  "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c -

FROM base AS osx-cross-base
ARG DEBIAN_FRONTEND=noninteractive
# Install deps
RUN set -x; echo "Starting image build for Debian Buster" \
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
        curl                                           \
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

FROM golang:${GO_VERSION}-buster AS go-base

FROM osx-cross-base AS final
ARG DEBIAN_FRONTEND=noninteractive

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH
ENV PATH /usr/local/go/bin:$PATH
ENV GOPATH /go
ENV PATH $GOPATH/bin:$PATH
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH
ENV GOLANG_VERSION ${GO_VERSION}
COPY --from=go-base /usr/local/go /usr/local/go
