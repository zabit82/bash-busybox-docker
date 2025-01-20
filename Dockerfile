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

FROM scratch
COPY --from=build-bash /build/bash-5.2.37/bash /bin/bash
SHELL ["/bin/bash", "-c"]
COPY --from=build-busybox /build/busybox-1.37.0/busybox /bin/busybox
WORKDIR /bin/
RUN busybox mkdir -p /usr/{bin,sbin,share,local} /sbin /etc/ssl /var
RUN busybox --install
RUN rm -rf /linuxrc
RUN touch /etc/shadow /etc/passwd /etc/group
RUN echo root:!:18768:0:99999:7::: > /etc/shadow
RUN echo root:x:0: > /etc/group
RUN root:x:0:0:root:/root:/bin/bash > /etc/passwd

