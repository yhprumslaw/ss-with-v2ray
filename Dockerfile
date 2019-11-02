FROM golang:alpine AS golang

# Build v2ray-plugin
RUN apk add --no-cache git build-base \
    && mkdir -p /go/src/github.com/shadowsocks \
    && cd /go/src/github.com/shadowsocks \
    && git clone https://github.com/shadowsocks/v2ray-plugin.git \
    && cd v2ray-plugin \
    && V2RAY_PLUGIN_VERSION=$(git describe --abbrev=0 --tags) \
    && git checkout $V2RAY_PLUGIN_VERSION \
    && go get -d \
    && go build

FROM alpine

# LABEL maintainer=""


# Build shadowsocks-libev
RUN set -ex \
    # Install dependencies
    && apk add --no-cache --virtual .build-deps \
               autoconf \
               automake \
               build-base \
               libev-dev \
               libtool \
               linux-headers \
               udns-dev \
               libsodium-dev \
               mbedtls-dev \
               pcre-dev \
               tar \
               udns-dev \
               c-ares-dev \
               git \
    # Build shadowsocks-libev
    && mkdir -p /tmp/build-shadowsocks-libev \
    && cd /tmp/build-shadowsocks-libev \
    && git clone https://github.com/shadowsocks/shadowsocks-libev.git \
    && cd shadowsocks-libev \
    && SHADOWSOCKS_LIBEV_VERSION=$(git describe --abbrev=0 --tags) \
    && git checkout $SHADOWSOCKS_LIBEV_VERSION \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && ./configure --disable-documentation \
    && make install \
    && ssRunDeps="$( \
        scanelf --needed --nobanner /usr/local/bin/ss-server \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .ss-rundeps $ssRunDeps \
    && cd / \
    && rm -rf /tmp/build-shadowsocks-libev \
    # Delete dependencies
    && apk del .build-deps

# Copy v2ray-plugin
COPY --from=golang /go/src/github.com/shadowsocks/v2ray-plugin/v2ray-plugin /usr/local/bin

# Shadowsocks environment variables
ENV SERVER_ADDR 0.0.0.0
ENV SERVER_ADDR_IPV6 [::0]
ENV SERVER_PORT 8388
ENV PASSWORD ChangeMe!!!
ENV METHOD chacha20-ietf-poly1305
ENV TIMEOUT 86400
ENV DNS_ADDRS 8.8.8.8,8.8.4.4
ENV ARGS -u

EXPOSE $SERVER_PORT/tcp $SERVER_PORT/udp

# Start shadowsocks-libev server
CMD exec ss-server \
    -s $SERVER_ADDR \
    -p $SERVER_PORT \
    -k $PASSWORD \
    -m $METHOD \
    -t $TIMEOUT \
    -d $DNS_ADDRS \
    --reuse-port \
    --no-delay \
    $ARGS