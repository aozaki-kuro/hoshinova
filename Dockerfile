# Cache dependencies
FROM node:16 as web-deps
WORKDIR /src/web
COPY web/package.json web/yarn.lock ./
RUN yarn install --frozen-lockfile

# Create base image for building Rust
FROM rust:1.62-alpine AS rust-builder
RUN apk add --no-cache wget
WORKDIR /app
RUN wget https://github.com/HoloArchivists/hoshinova/releases/download/v0.2.4/hoshinova-aarch64-unknown-linux-musl -O /app/hoshinova
RUN chmod +x /app/hoshinova

# Build the web app
FROM node:16 AS web-builder
WORKDIR /src/web
COPY web .
COPY --from=web-deps /src/web/node_modules /src/web/node_modules
COPY --from=ts-bind /src/web/src/bindings /src/web/src/bindings
RUN yarn build

# Build ytarchive
FROM golang:1.20-alpine AS ytarchive-builder
WORKDIR /src
RUN set -ex; \
    apk add --no-cache git; \
    git clone https://github.com/Kethsar/ytarchive.git; \
    cd ytarchive; \
    git checkout b40d0a1fb70e59aff2c8642f265d3cd653c1a75d; \
    go build .

FROM alpine AS runner
WORKDIR /app
RUN apk add --no-cache ffmpeg
COPY --from=ytarchive-builder /src/ytarchive/ytarchive /usr/local/bin/ytarchive

USER 1000
COPY --from=rust-builder --chown=1000:1000 \
  /app/hoshinova \
  /app/hoshinova

CMD ["/app/hoshinova"]
