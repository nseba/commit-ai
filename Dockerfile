# Build stage
FROM golang:1.24-alpine AS builder

# Install git (required for go modules with git dependencies)
RUN apk add --no-cache git ca-certificates

# Set working directory
WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o commit-ai ./cmd

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests and git for repository operations
RUN apk --no-cache add ca-certificates git

# Create non-root user
RUN addgroup -g 1001 appgroup && \
    adduser -u 1001 -G appgroup -s /bin/sh -D appuser

# Set working directory
WORKDIR /app

# Copy the binary from builder stage
COPY --from=builder /app/commit-ai .

# Copy templates and example configs
COPY --from=builder /app/templates ./templates
COPY --from=builder /app/configs ./configs

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Create config directory
RUN mkdir -p /home/appuser/.config/commit-ai

# Expose volume for configuration
VOLUME ["/home/appuser/.config/commit-ai"]

# Set the binary as the entrypoint
ENTRYPOINT ["./commit-ai"]

# Default command
CMD ["--help"]
