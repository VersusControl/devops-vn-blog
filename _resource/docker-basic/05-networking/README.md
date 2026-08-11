# Chapter 5: Docker Networking

Examples and commands for container networking.

## Network types

- **bridge** — Default. Containers on same bridge can communicate.
- **host** — Container uses host's network directly.
- **none** — No networking.
- **overlay** — Multi-host networking (Swarm).

## Commands

```bash
# List networks
docker network ls

# Create a custom network
docker network create my-network

# Run container on a network
docker run -d --name web --network my-network nginx

# Connect running container to network
docker network connect my-network my-container

# Disconnect from network
docker network disconnect my-network my-container

# Inspect network
docker network inspect my-network

# Remove network
docker network rm my-network
```

## Example: Two containers communicating

```bash
# Create network
docker network create app-net

# Run Redis
docker run -d --name redis --network app-net redis:7-alpine

# Run app that connects to Redis
docker run -d --name app --network app-net \
  -e REDIS_HOST=redis \
  my-app:v1
```
