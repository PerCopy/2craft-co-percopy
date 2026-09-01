FROM ghcr.io/shopify/toxiproxy:2.12.0
# Base image is FROM scratch — add static busybox for healthcheck HTTP probe (§5.1)
COPY --from=busybox:1.38-musl /bin/busybox /bin/busybox
COPY toxiproxy.json /config/toxiproxy.json
