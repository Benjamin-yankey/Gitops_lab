.PHONY: help install test lint build run clean deploy destroy

help:
	@echo "Available commands:"
	@echo "  make install    - Install dependencies"
	@echo "  make test       - Run tests"
	@echo "  make lint       - Run linter"
	@echo "  make build      - Build Docker image"
	@echo "  make run        - Run application locally"
	@echo "  make clean      - Clean up resources"
	@echo "  make deploy     - Deploy infrastructure"
	@echo "  make destroy    - Destroy infrastructure"

install:
	npm ci

test:
	npm test

lint:
	npm run lint

build:
	docker build -t cicd-node-app:latest .

run:
	npm start

clean:
	rm -rf node_modules coverage
	docker system prune -af

deploy:
	cd terraform && terraform init && terraform apply

destroy:
	cd terraform && terraform destroy

.DEFAULT_GOAL := help
