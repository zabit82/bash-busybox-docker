FROM debian:12 AS deb-builder
RUN apt update
RUN apt install -y build-essential wget curl tar gzip autoconf git bzip2

FROM deb-builder AS build-bash
RUN mkdir /build
RUN curl -s http://ftp.gnu.org/gnu/bash/bash-5.2.37.tar.gz -o /build/bash.tar.gz
RUN cd /build; tar xzf bash.tar.gz
WORKDIR /build/bash-5.2.37
RUN ./configure --bindir=/bin/ --enable-static-link
RUN make

FROM deb-builder AS build-busybox
RUN mkdir /build
RUN curl -s https://busybox.net/downloads/busybox-1.37.0.tar.bz2 -o /build/busybox.tar.bz2
RUN cd /build; tar xjf busybox.tar.bz2 ; cd /build/busybox-1.37.0
WORKDIR /build/busybox-1.37.0
RUN make defconfig
RUN echo "CONFIG_STATIC=y" >> .config
RUN make

FROM alpine:3.21 as reference
RUN apk add --no-cache ca-certificates tzdata
RUN mkdir -p /relocate/bin /relocate/sbin /relocate/etc /relocate/etc/ssl /relocate/usr/bin /relocate/usr/sbin /relocate/usr/share
RUN cp -pr /tmp /relocate
RUN cp -pr /etc/passwd /etc/group /etc/hostname /etc/hosts /etc/shadow /etc/protocols /etc/services /etc/nsswitch.conf /relocate/etc
RUN cp -pr /usr/share/ca-certificates /relocate/usr/share
RUN cp -pr /usr/share/zoneinfo /relocate/usr/share
RUN cp -pr /etc/ssl/cert.pem /relocate/etc/ssl
RUN cp -pr /etc/ssl/certs /relocate/etc/ssl



FROM scratch
COPY --from=reference /relocate /
COPY --from=build-bash /build/bash-5.2.37/bash /bin/bash
SHELL ["/bin/bash", "-c"]
COPY --from=build-busybox /build/busybox-1.37.0/busybox /bin/busybox
WORKDIR /bin/
RUN busybox --install
