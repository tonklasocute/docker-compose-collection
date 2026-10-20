# syntax=docker/dockerfile:1

# Stages:
#   base   Go toolchain + downloaded modules (shared, cached)
#   dev    hot reload with air; source is bind-mounted by compose (profile: dev)
#   test   go vet + go test             (docker build --target test .)
#   build  static, stripped binary
#   final  distroless/static, non-root, ~2 MB base + the binary

FROM golang:1.27.2-alpine3.24 AS base
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

FROM base AS dev
RUN --mount=type=cache,target=/go/pkg/mod go install github.com/air-verse/air@v1.67.4
# Runs as root on purpose: the bind-mounted source is owned by your host user,
# and air must write tmp/ next to it. The final stage below is non-root.
CMD ["air", "-c", ".air.toml"]

FROM base AS test
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go vet ./... && go test ./...

FROM base AS build
ARG VERSION=dev
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -trimpath \
      -ldflags="-s -w -X github.com/tonklasocute/docker-compose-collection/go-api/internal/httpapi.Version=${VERSION}" \
      -o /out/api ./cmd/api

# static-debian13 has CA certificates, tzdata and a "nonroot" user (65532),
# and nothing else: no shell, no package manager.
FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=build /out/api /app/api
# Numeric so Kubernetes' runAsNonRoot can verify it (65532 = "nonroot")
USER 65532:65532
EXPOSE 8080
# No curl in this image: the binary checks itself (see cmd/api/main.go)
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD ["/app/api", "healthcheck"]
ENTRYPOINT ["/app/api"]
