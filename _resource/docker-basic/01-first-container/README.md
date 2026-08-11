# Chapter 1: First Container

Basic commands to get started with Docker.

## Commands covered

```bash
# Check Docker installation
docker version
docker info

# Run your first container
docker run hello-world

# Run an interactive container
docker run -it ubuntu bash

# Run a detached container
docker run -d nginx

# List running containers
docker ps

# List all containers
docker ps -a

# Stop a container
docker stop <container_id>

# Remove a container
docker rm <container_id>

# Pull an image
docker pull redis

# List images
docker images
```
