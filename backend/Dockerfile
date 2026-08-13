# --- build stage ---
FROM golang:1.25-alpine AS builder
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w -X main.version=${VERSION}" -o /out/api ./cmd/api

# --- final stage ---
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/api /api

USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
