# Docker Basics Series — Sample Code

This folder contains all sample code for the Docker Basics series.

## The Task App

Throughout this series, we build a simple **Task App** — a task management system with:

- **API** (Node.js/Express) — REST endpoints for managing tasks
- **Worker** (Python) — Background job processor that handles task notifications
- **Redis** — Message queue between API and Worker
- **PostgreSQL** — Persistent storage for tasks

This setup demonstrates real-world Docker patterns:
- Building custom images with Dockerfiles
- Multi-stage builds for production optimization
- Container networking and service discovery
- Volume management for data persistence
- Docker Compose for multi-container orchestration

## Folder Structure

```
docker-basic/
├── 01-first-container/     # Chapter 1: Basic container commands
├── 02-images/              # Chapter 2: Working with images
├── 03-dockerfile/          # Chapter 3: Writing Dockerfiles
├── 04-containers/          # Chapter 4: Managing containers
├── 05-networking/          # Chapter 5: Docker networking
├── 06-volumes/             # Chapter 6: Volumes and persistence
├── 07-compose/             # Chapter 7: Docker Compose
├── 08-full-app/            # Chapter 8: Complete Task App
└── task-app/               # The main application code
    ├── api/                # Node.js API service
    ├── worker/             # Python worker service
    └── docker-compose.yml  # Full stack orchestration
```

## Quick Start

If you want to jump ahead and see the final result:

```bash
cd task-app
docker compose up -d
```

Then open http://localhost:3000 to use the Task App.

## Requirements

- Docker Engine 24+ or Docker Desktop
- Docker Compose V2 (included with Docker Desktop)
- ~2GB disk space for images
