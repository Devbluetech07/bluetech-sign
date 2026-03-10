FROM golang:alpine

WORKDIR /app

# Instala dependências do sistema necessárias para CGO e extensões (opcional dependo das libs)
RUN apk add --no-cache gcc musl-dev

COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Build do servidor
RUN go build -o main .

EXPOSE 3001

CMD ["./main"]
