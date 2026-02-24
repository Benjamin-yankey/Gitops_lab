# Makefile for managing common project tasks
.PHONY: help install test lint build run clean deploy destroy

# Display available commands with descriptions
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

# Install project dependencies using npm ci (clean install)
install:
	npm ci

# Execute unit tests using Jest
test:
	npm test

# Run code linting to ensure consistent style
lint:
	npm run lint

# Build the Docker container image locally
build:
	docker build -t cicd-node-app:latest .

# Run the application in the current shell
run:
	npm start

# Remove temporary files and prune unused Docker resources
clean:
	rm -rf node_modules coverage
	docker system prune -af

# Initialize and apply Terraform infrastructure configurations
deploy:
	cd terraform && terraform init && terraform apply

# Destroy all Terraform-managed infrastructure resources
destroy:
	cd terraform && terraform destroy

# Set help as the default goal when running 'make' without arguments
.DEFAULT_GOAL := help
