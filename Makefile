SHELL := /bin/zsh

.PHONY: up down run migrate

up:
	docker compose up -d

down:
	docker compose down

run:
	cd server && set -a && . ./.env && set +a && go run ./cmd/api

migrate:
	cd server && set -a && . ./.env && set +a && go run ./cmd/migrate
