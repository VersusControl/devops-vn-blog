# Kubernetes Basics Chapter 3 Resource

This folder contains a reader-run build and GHCR publish example for the shared Task API in
`../task-api`. The script does not contain a credential and does not publish unless you supply
your own GitHub owner and token.

## Build and test locally

```sh
cd ../task-api
docker build -t task-api:0.1.0 .
docker run --rm -p 3000:3000 task-api:0.1.0
```

In another terminal, run:

```sh
curl --fail http://localhost:3000/healthz
```

## Prepare a GHCR push

Set a GitHub user or organization and a personal access token with `write:packages`, then run:

```sh
export GHCR_OWNER="YOUR_GITHUB_USER_OR_ORGANIZATION"
export GHCR_TOKEN="YOUR_GITHUB_PAT"
./build-and-push.sh
```

The script builds from the shared Task API source, tags `ghcr.io/$GHCR_OWNER/task-api:0.1.0`,
logs in through standard input, and executes `docker push`. Review the script before running it
because it creates or updates a remote package.