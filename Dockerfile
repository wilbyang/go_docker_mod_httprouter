# https://raw.githubusercontent.com/syntaqx/sandbox/
# Use Alphine instead of Scratch as it's be hardened
# Accept image version tags to be set as a build arguments
ARG GO_VERSION=1.11
ARG ALPINE_VERSION=3.8

# Throw-away builder container
FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder

# Install build and runtime dependencies
# - Git is required for fetching Go dependencies
# - Certificate-Authority certificates are required to call HTTPs endpoints
RUN apk add --no-cache git ca-certificates

# Normalize the base environment
# - CGO_ENABLED: to build a statically linked executable
# - GO111MODULE: force go module behavior and ignore any vendor directories
ENV CGO_ENABLED=0 GO111MODULE=on

# Set the builder working directory
WORKDIR /go/src/github.com/syntaqx/sandbox

# Fetch modules first. Module dependencies are less likely to change per build,
# so we benefit from layer caching
ADD ./go.mod ./go.sum* ./
RUN go mod download

# Import the remaining source from the context
COPY . /go/src/github.com/syntaqx/sandbox

# Build a statically linked executable
RUN go build -installsuffix cgo -ldflags '-s -w' -o ./bin/app

# Runtime container
FROM alpine:${ALPINE_VERSION}

# Copy the binary and sources from the builder stage
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder /go/src/github.com/syntaqx/sandbox/bin/app ./app

# Create a non-root runtime user
RUN addgroup -S sandbox && adduser -S -G sandbox sandbox && chown -R sandbox:sandbox ./app
USER sandbox

# Document the service listening port(s)
EXPOSE 8080

# Define the containers executable entrypoint
ENTRYPOINT ["./app"]