.PHONY: run build test tidy

run:
	go run ./cmd/server

build:
	CGO_ENABLED=0 GOOS=linux go build -o bin/api_restaurant ./cmd/server

test:
	go test ./...

tidy:
	go mod tidy
