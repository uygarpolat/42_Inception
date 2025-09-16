SHELL := /bin/sh

COMPOSE_FILE := srcs/docker-compose.yml
PROJECT_NAME := inception

DATA_DIR := $(HOME)/data

.PHONY: all prepare build up down logs clean fclean re data-clean doctor

all: build

prepare:
	@echo "Preparing local data directories at $(DATA_DIR)..."
	mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

build: prepare
	@echo "Building Docker images..."
	docker compose -f $(COMPOSE_FILE) build

up: build
	@echo "Starting services..."
	docker compose -f $(COMPOSE_FILE) up -d

down:
	@echo "Stopping services..."
	docker compose -f $(COMPOSE_FILE) down

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

clean:
	@echo "Cleaning up containers and images..."
	docker compose -f $(COMPOSE_FILE) down --rmi all --volumes --remove-orphans

fclean: clean
	@echo "Full cleanup completed (containers, images, volumes, networks)"
	@echo "Note: Data directories preserved. Use 'make data-clean' to remove them."

re: fclean all

data-clean:
	@echo "Removing data directories..."
	@echo "This will permanently delete all WordPress and MariaDB data!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress; \
		echo "Data directories removed."; \
	else \
		echo "Operation cancelled."; \
	fi

doctor:
	@echo "==> Doctor: checking Docker and Compose...";
	@docker --version >/dev/null 2>&1 || { echo "[FAIL] docker not found"; exit 1; };
	@docker compose version >/dev/null 2>&1 || docker-compose version >/dev/null 2>&1 || { echo "[FAIL] docker compose/plugin not found"; exit 1; };
	@echo "[OK] Docker and Compose present";
	@echo "==> Doctor: checking Docker rootless mode...";
	@if docker info 2>/dev/null | grep -iq '^ *rootless: *true'; then \
		echo "[FAIL] Rootless Docker detected (cannot bind privileged ports like 443). Use the system Docker daemon."; \
	else \
		echo "[OK] Rootful Docker (can bind 443)"; \
	fi;
	@echo "==> Doctor: checking hosts mapping for upolat.42.fr...";
	@grep -q "upolat.42.fr" /etc/hosts && echo "[OK] hosts entry present" || echo "[WARN] Add to /etc/hosts: 127.0.0.1 upolat.42.fr";
	@echo "==> Doctor: checking .env presence...";
	@if [ -f $(dir $(COMPOSE_FILE)).env ]; then \
		echo "[OK] .env found at $(dir $(COMPOSE_FILE)).env"; \
	elif [ -f .env ]; then \
		echo "[OK] .env found at ./ .env (note: compose resolves env_file relative to $(dir $(COMPOSE_FILE)))"; \
	else \
		echo "[FAIL] .env missing (required at $(dir $(COMPOSE_FILE)).env)"; \
	fi;
	@echo "==> Doctor: checking port 443...";
	@if ! ss -tln 2>/dev/null | grep -q ":443"; then \
		echo "[OK] port 443 is free"; \
	else \
		if docker compose -f $(COMPOSE_FILE) ps 2>/dev/null | grep -q "443->443/tcp"; then \
			echo "[OK] port 443 is in use by this stack (nginx)"; \
		else \
			echo "[WARN] port 443 is in use by another process (stop it before 'make up')"; \
		fi; \
	fi;
	@echo "==> Doctor: verifying compose file and network...";
	@grep -q "networks:" $(COMPOSE_FILE) && echo "[OK] networks declared in compose" || { echo "[FAIL] no networks section in compose"; exit 1; };
	@echo "==> Doctor: running docker compose ps...";
	@docker compose -f $(COMPOSE_FILE) ps || true;
	@if docker compose -f $(COMPOSE_FILE) ps 2>/dev/null | grep -E "(nginx|wordpress|mariadb)" | grep -q "Up"; then \
		echo "[OK] services are running (Up)"; \
	else \
		echo "[WARN] services are not running; run 'make up'"; \
	fi;
	@echo "Doctor finished. Review WARN/FAIL items above."

