# I used multistage buil to minimal the output. => mTaghadosi
# Stage 1: Building the Go application
FROM golang:latest AS builder
WORKDIR /app
COPY go.mod .
COPY go.sum .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o build/golang-webserver_amd64

# Stage 2: Creating minimal runtime image
FROM scratch
WORKDIR /app
COPY --from=builder /app/build/golang-webserver_amd64 .
EXPOSE 8080
CMD ["./golang-webserver_amd64"]
