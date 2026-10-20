# syntax=docker/dockerfile:1
# Keycloak "optimized" image: `kc.sh build` bakes the build-time options
# (database vendor, health and metrics endpoints) into the server once, here,
# instead of re-augmenting on every container start. Starts in a few seconds.

FROM quay.io/keycloak/keycloak:26.8.1 AS builder
ENV KC_DB=postgres \
    KC_HEALTH_ENABLED=true \
    KC_METRICS_ENABLED=true
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:26.8.1 AS final
COPY --from=builder /opt/keycloak/ /opt/keycloak/
# The base image's non-root user (uid 1000), stated explicitly
USER 1000
EXPOSE 8080 9000
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
CMD ["start", "--optimized", "--import-realm"]
