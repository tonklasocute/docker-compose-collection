# Loki's official image is distroless: no shell, no wget, so a Docker
# healthcheck has nothing to run. Add a single static busybox binary and
# use only its wget applet. Everything else is the upstream image as-is.
FROM busybox:1.38.0-musl AS busybox

FROM grafana/loki:3.7.8
COPY --from=busybox /bin/busybox /usr/local/bin/busybox
