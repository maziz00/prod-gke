# Multi-stage build for a minimal, secure container image.
#
# Stage 1 (builder): compiles a statically linked binary — no runtime C dependencies.
# Stage 2 (runtime): distroless/static — no shell, no package manager, no OS CVEs.
# Final image size: ~6MB. Attack surface: near zero.

# ── Build Stage ─────────────────────────────────────────────────────────────
FROM golang:1.22-alpine AS builder

WORKDIR /build

# Download dependencies before copying source — improves Docker layer caching.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# CGO_ENABLED=0: produce a fully static binary (required for distroless runtime).
# -ldflags="-s -w": strip debug symbols and DWARF info (reduces binary size ~30%).
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o /server .

# ── Runtime Stage ────────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

# Copy only the compiled binary — no source, no build tools.
COPY --from=builder /server /server

EXPOSE 8080

# nonroot user (uid=65532) from the distroless base — never run as root.
USER nonroot:nonroot

ENTRYPOINT ["/server"]
