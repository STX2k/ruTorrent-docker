ARG ALPINE_VERSION=3.16.2
ARG RTORRENT_VERSION=0.9.8
ARG LIBTORRENT_VERSION=0.13.8
ARG XMLRPC_VERSION=01.59.00
ARG RUTORRENT_VERSION=3.10
ARG RUTORRENT_REVISION=d1024b0c946402d16ff078974393121bd83b118d
ARG MKTORRENT_VERSION=1.1
ARG NGINX_VERSION=1.23.1
ARG NGINX_DAV_VERSION=3.0.0
ARG OVERLAY_VERSION=2.2.0.3
ARG NGINX_UID=102
ARG NGINX_GID=102

FROM --platform=${BUILDPLATFORM:-linux/amd64} alpine:${ALPINE_VERSION} AS download
RUN apk --update --no-cache add curl git tar subversion

ARG OVERLAY_VERSION
WORKDIR /dist/s6
RUN curl -sSL "https://github.com/just-containers/s6-overlay/releases/download/v${OVERLAY_VERSION}/s6-overlay-amd64.tar.gz" | tar -xz

ARG XMLRPC_VERSION
WORKDIR /dist/xmlrpc-c
RUN svn checkout "http://svn.code.sf.net/p/xmlrpc-c/code/release_number/${XMLRPC_VERSION}/" .

ARG LIBTORRENT_VERSION
WORKDIR /dist/libtorrent
RUN git clone --branch v${LIBTORRENT_VERSION} "https://github.com/rakshasa/libtorrent" .

ARG RTORRENT_VERSION
WORKDIR /dist/rtorrent
RUN git clone --branch v${RTORRENT_VERSION} "https://github.com/rakshasa/rtorrent" .

ARG MKTORRENT_VERSION
WORKDIR /dist/mktorrent
RUN git clone --branch v${MKTORRENT_VERSION} "https://github.com/esmil/mktorrent" .

ARG RUTORRENT_REVISION
WORKDIR /dist/rutorrent
RUN git clone "https://github.com/Novik/ruTorrent" . \
  && git reset --hard $RUTORRENT_REVISION \
  && rm -rf .git* conf/users plugins/geoip plugins/_cloudflare share

WORKDIR /dist/rutorrent-geoip2
RUN git clone "https://github.com/Micdu70/geoip2-rutorrent" . && rm -rf .git*

WORKDIR /dist/rutorrent-filemanager
RUN git clone "https://github.com/nelu/rutorrent-filemanager" . && rm -rf .git*

WORKDIR /dist/rutorrent-theme-material
RUN git clone "https://github.com/TrimmingFool/ruTorrent-MaterialDesign" . && rm -rf .git*

WORKDIR /dist/rutorrent-theme-quick
RUN git clone "https://github.com/TrimmingFool/club-QuickBox" . && rm -rf .git*

WORKDIR /dist/rutorrent-ratio
RUN git clone "https://github.com/Gyran/rutorrent-ratiocolor" . && rm -rf .git*

WORKDIR /dist/geoip2-rutorrent
RUN git clone "https://github.com/Micdu70/geoip2-rutorrent" . && rm -rf .git*

WORKDIR /dist/mmdb
RUN curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-City.mmdb" \
  && curl -SsOL "https://github.com/crazy-max/geoip-updater/raw/mmdb/GeoLite2-Country.mmdb"

ARG NGINX_VERSION
ARG NGINX_DAV_VERSION
WORKDIR /dist/nginx
RUN curl -sSL "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" | tar xz --strip 1
RUN git clone --branch v${NGINX_DAV_VERSION} "https://github.com/arut/nginx-dav-ext-module" nginx-dav-ext

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} AS compile

RUN apk --update --no-cache add \
    autoconf \
    automake \
    curl \
    curl-dev \
    binutils \
    brotli-dev \
    build-base \
    cppunit-dev \
    fftw-dev \
    gd-dev \
    geoip-dev \
    libnl3 \
    libnl3-dev \
    libtool \
    libxslt-dev \
    linux-headers \
    ncurses-dev \
    nghttp2-dev \
    openssl-dev \
    pcre-dev \
    tar \
    tree \
    zlib-dev

ENV DIST_PATH="/dist"
COPY --from=download /dist /tmp

WORKDIR /tmp/xmlrpc-c
RUN ./configure
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/libtorrent
RUN ./autogen.sh
RUN ./configure --with-posix-fallocate
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/rtorrent
RUN ./autogen.sh
RUN ./configure --with-xmlrpc-c --with-ncurses
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

WORKDIR /tmp/mktorrent
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)

ARG NGINX_UID
ARG NGINX_GID
WORKDIR /tmp/nginx
RUN addgroup -g ${NGINX_UID} -S nginx
RUN adduser -S -D -H -u ${NGINX_GID} -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx
RUN ./configure \
  --prefix=/usr/lib/nginx \
  --sbin-path=/sbin/nginx \
  --pid-path=/var/pid/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --http-log-path=/dev/stdout \
  --error-log-path=/dev/stderr \
  --pid-path=/var/pid/nginx.pid \
  --user=nginx \
  --group=nginx \
  --with-file-aio \
  --with-pcre-jit \
  --with-threads \
  --with-poll_module \
  --with-select_module \
  --with-stream_ssl_module \
  --with-http_addition_module \
  --with-http_auth_request_module \
  --with-http_degradation_module \
  --with-http_flv_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-mail_ssl_module \
  --with-http_mp4_module \
  --with-http_random_index_module \
  --with-http_realip_module \
  --with-http_secure_link_module \
  --with-http_slice_module \
  --with-http_ssl_module \
  --with-http_stub_status_module \
  --with-http_sub_module \
  --with-http_v2_module \
  --with-mail=dynamic \
  --with-stream=dynamic \
  --with-http_geoip_module=dynamic \
  --with-http_image_filter_module=dynamic \
  --with-http_xslt_module=dynamic \
RUN make -j $(nproc)
RUN make install -j $(nproc)
RUN make DESTDIR=${DIST_PATH} install -j $(nproc)
RUN tree ${DIST_PATH}

ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION} as builder

COPY --from=compile /dist /
COPY --from=download /dist/s6 /
COPY --from=download /dist/mmdb /var/mmdb
COPY --from=download --chown=nobody:nogroup /dist/rutorrent /var/www/rutorrent
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-material /var/www/rutorrent/plugins/theme/themes/MaterialDesign
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-theme-quick /var/www/rutorrent/plugins/theme/themes/QuickBox
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-ratio /var/www/rutorrent/plugins/ratiocolor
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-filemanager /var/www/rutorrent/plugins/filemanager
COPY --from=download --chown=nobody:nogroup /dist/rutorrent-geoip2 /var/www/rutorrent/plugins/geoip2

ENV TZ="UTC" \
  PUID="1000" \
  PGID="1000"

ARG NGINX_UID
ARG NGINX_GID
RUN echo "@314 http://dl-cdn.alpinelinux.org/alpine/v3.14/main" >> /etc/apk/repositories
RUN apk --update --no-cache add \
    apache2-utils \
    bash \
    bind-tools \
    binutils \
    brotli \
    ca-certificates \
    coreutils \
    curl \
    curl-dev \
    dhclient \
    ffmpeg \
    findutils \
    geoip \
    grep \
    gzip \
    libstdc++ \
    mediainfo \
    ncurses \
    openssl \
    pcre \
    php8 \
    php8-dev \
    php8-bcmath \
    php8-cli \
    php8-ctype \
    php8-curl \
    php8-fpm \
    php8-json \
    php8-mbstring \
    php8-openssl \
    php8-opcache \
    php8-pecl-apcu \
    php8-pear \
    php8-phar \
    php8-posix \
    php8-session \
    php8-sockets \
    php8-xml \
    php8-zip \
    php8-zlib \
    python3 \
    py3-pip \
    p7zip \
    shadow \
    sox \
    tar \
    tzdata \
    unzip \
    unrar@314 \
    util-linux \
    zip \
    zlib \
  && ln -s /usr/lib/nginx/modules /etc/nginx/modules \
  && addgroup -g ${NGINX_UID} -S nginx \
  && adduser -S -D -H -u ${NGINX_GID} -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
  && pip3 install --upgrade pip \
  && pip3 install cfscrape cloudscraper \
  && addgroup -g ${PGID} rtorrent \
  && adduser -D -H -u ${PUID} -G rtorrent -s /bin/sh rtorrent \
  && curl --version \
  && rm -rf /tmp/* /var/cache/apk/*

COPY rootfs /

VOLUME [ "/config", "/data", "/passwd" ]

ENTRYPOINT [ "/init" ]

HEALTHCHECK --interval=30s --timeout=20s --start-period=10s CMD /usr/local/bin/healthcheck