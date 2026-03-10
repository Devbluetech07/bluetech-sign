FROM golang:alpine AS build

WORKDIR /app

COPY go.mod ./
RUN go mod download

COPY . .
RUN go build -o main .

FROM alpine:latest
WORKDIR /app
COPY --from=build /app/main /app/main

EXPOSE 3000
CMD ["/app/main"]
