FROM golang:1.25.1-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /notes-api ./cmd/api

FROM alpine:3.20

WORKDIR /app
COPY --from=builder /notes-api /app/notes-api

ENV PORT=8000
EXPOSE 8000

CMD ["/app/notes-api"]
