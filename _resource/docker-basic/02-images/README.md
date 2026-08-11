# Chapter 2: Working with Images

Commands for managing Docker images.

## Commands covered

```bash
# Search for images
docker search nginx

# Pull an image
docker pull nginx:1.25

# Pull a specific architecture
docker pull --platform linux/amd64 nginx:1.25

# List images
docker images

# Inspect an image
docker inspect nginx:1.25

# View image history (layers)
docker history nginx:1.25

# Tag an image
docker tag nginx:1.25 my-nginx:v1

# Remove an image
docker rmi nginx:1.25

# Remove all unused images
docker image prune -a
```

## Simple Dockerfile example

```dockerfile
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/
EXPOSE 80
```

## Build an image

```bash
docker build -t my-web:v1 .
```
