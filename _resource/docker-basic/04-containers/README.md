# Chapter 4: Managing Containers

Commands and examples for container management.

## Common commands

```bash
# Run a container with a name
docker run -d --name my-nginx nginx

# View container logs
docker logs my-nginx
docker logs -f my-nginx  # follow
docker logs --tail 100 my-nginx  # last 100 lines

# Execute command in running container
docker exec -it my-nginx bash
docker exec my-nginx cat /etc/nginx/nginx.conf

# Copy files to/from container
docker cp myfile.txt my-nginx:/tmp/
docker cp my-nginx:/etc/nginx/nginx.conf ./

# View container resource usage
docker stats

# Inspect container details
docker inspect my-nginx

# View container processes
docker top my-nginx

# Pause/unpause
docker pause my-nginx
docker unpause my-nginx

# Restart a container
docker restart my-nginx

# Resource limits
docker run -d --name limited --memory=512m --cpus=0.5 nginx
```
