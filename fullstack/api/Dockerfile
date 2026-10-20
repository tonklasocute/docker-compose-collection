# syntax=docker/dockerfile:1
# Go API: same service as ../../go-api (copied so this template is self-contained)

FROM golang:1.27.2-alpine3.24 AS base
WORKDIR /src
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

FROM base AS test
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    go vet ./... && go test ./...

FROM base AS build
ARG VERSION=dev
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux go build -trimpath \
      -ldflags="-s -w -X github.com/tonklasocute/docker-compose-collection/fullstack/api/internal/httpapi.Version=${VERSION}" \
      -o /out/api ./cmd/api

FROM gcr.io/distroless/static-debian13:nonroot@sha256:516757106de35205efb70b91ba03f6f1298424a0678c603255cf2852a7000087 AS final
COPY --from=build /out/api /app/api
# Numeric so Kubernetes' runAsNonRoot can verify it (65532 = "nonroot")
USER 65532:65532
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 CMD ["/app/api", "healthcheck"]
ENTRYPOINT ["/app/api"]
