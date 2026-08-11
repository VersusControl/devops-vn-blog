# Chapter 8: Building the Complete Task App

This chapter brings everything together.

See the main `task-app/` folder at the root of docker-basic for:
- Node.js API service
- Python worker service
- PostgreSQL database
- Redis message queue
- Docker Compose orchestration

## Quick start

```bash
cd ../task-app
docker compose up -d
```

## Test the API

```bash
# Create a task
curl -X POST http://localhost:3000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Learn Docker", "description": "Complete the Docker series"}'

# List tasks
curl http://localhost:3000/tasks

# Health check
curl http://localhost:3000/health
```

## Watch the worker

```bash
docker compose logs -f worker
```
