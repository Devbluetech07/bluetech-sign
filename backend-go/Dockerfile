# Stage 1: Build
FROM golang:alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Stage 2: Production
FROM alpine:latest AS runner
RUN apk --no-cache add ca-certificates tzdata wget
WORKDIR /root/
ENV GIN_MODE=release
COPY --from=builder /app/main .
EXPOSE 3001
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3001/health || exit 1
CMD ["./main"]
