# Chapter 6: Volumes and Persistence

Examples for data persistence with Docker.

## Volume types

- **Named volumes** — Managed by Docker, best for persistence
- **Bind mounts** — Map host directory to container
- **tmpfs** — In-memory, temporary storage

## Commands

```bash
# Create a volume
docker volume create my-data

# List volumes
docker volume ls

# Inspect volume
docker volume inspect my-data

# Run with named volume
docker run -d --name db \
  -v my-data:/var/lib/postgresql/data \
  postgres:16

# Run with bind mount
docker run -d --name web \
  -v $(pwd)/html:/usr/share/nginx/html:ro \
  nginx

# Run with tmpfs
docker run -d --name app \
  --tmpfs /tmp \
  my-app

# Remove volume
docker volume rm my-data

# Remove all unused volumes
docker volume prune
```

## Example: PostgreSQL with persistent data

```bash
# Create volume
docker volume create pgdata

# Run PostgreSQL
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16

# Data persists after container removal
docker rm -f postgres
docker run -d --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -v pgdata:/var/lib/postgresql/data \
  -p 5432:5432 \
  postgres:16
# Your data is still there!
```
