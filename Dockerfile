# syntax=docker/dockerfile:1

ARG DEB_BASE=debian:12
ARG BASH_VERSION=5.2.37
ARG BASH_SHA256=9599b22ecd1d5787ad7d3b7bf0c59f312b3396d1e281175dd1f8a4014da621ff
ARG BUSYBOX_VERSION=1.37.0
ARG BUSYBOX_SHA256=3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4

FROM ${DEB_BASE} AS deb-builder
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    build-essential wget curl tar gzip bzip2 autoconf git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

FROM deb-builder AS build-bash
ARG BASH_VERSION
ARG BASH_SHA256
RUN mkdir /build \
    && wget --tries=5 --timeout=60 -c -O /build/bash.tar.gz https://ftp.gnu.org/gnu/bash/bash-${BASH_VERSION}.tar.gz \
    && echo "${BASH_SHA256}  /build/bash.tar.gz" | sha256sum -c - \
    && tar xzf /build/bash.tar.gz -C /build
WORKDIR /build/bash-${BASH_VERSION}
RUN ./configure --bindir=/bin/ --enable-static-link \
    && make -j"$(nproc)"

FROM deb-builder AS build-busybox
ARG BUSYBOX_VERSION
ARG BUSYBOX_SHA256
RUN mkdir /build \
    && wget --tries=5 --timeout=60 -c -O /build/busybox.tar.bz2 https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2 \
    && echo "${BUSYBOX_SHA256}  /build/busybox.tar.bz2" | sha256sum -c - \
    && tar xjf /build/busybox.tar.bz2 -C /build
WORKDIR /build/busybox-${BUSYBOX_VERSION}
# Применяем конфигурацию по умолчанию, гарантируем статическую линковку и
# отключаем SHA1/SHA256 HWACCEL, вызывающие сбой компиляции на non-x86/ARM64 в BusyBox 1.37.0
RUN make defconfig \
    && sed -i 's/.*CONFIG_STATIC.*/CONFIG_STATIC=y/' .config \
    && sed -i 's/CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' .config \
    && sed -i 's/CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' .config \
    && yes "" | make oldconfig \
    && make -j"$(nproc)"

FROM alpine:3.24 AS reference
# NB: alpine RUN использует busybox-ash, который не поддерживает
# brace expansion ({a,b,c}) — пути указываются явно.
RUN apk add --no-cache ca-certificates tzdata \
    && mkdir -p /relocate/bin /relocate/sbin /relocate/etc/ssl \
    /relocate/usr/bin /relocate/usr/sbin /relocate/usr/share \
    && cp -pr /etc/passwd /etc/group /etc/hostname /etc/hosts \
    /etc/protocols /etc/services /etc/nsswitch.conf /relocate/etc \
    && cp -pr /usr/share/ca-certificates /usr/share/zoneinfo /relocate/usr/share \
    && cp -pr /etc/ssl/cert.pem /etc/ssl/certs /relocate/etc/ssl \
    && echo 'root:*:18000:0:99999:7:::' > /relocate/etc/shadow \
    && chmod 600 /relocate/etc/shadow

FROM scratch
ARG BASH_VERSION
ARG BUSYBOX_VERSION
LABEL org.opencontainers.image.title="bash-busybox" \
    org.opencontainers.image.version="${BASH_VERSION}-${BUSYBOX_VERSION}"
COPY --from=reference /relocate /
COPY --from=build-bash /build/bash-${BASH_VERSION}/bash /bin/bash
SHELL ["/bin/bash", "-c"]
COPY --from=build-busybox /build/busybox-${BUSYBOX_VERSION}/busybox /bin/busybox
WORKDIR /bin/
RUN busybox --install
