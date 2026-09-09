# syntax=docker/dockerfile:1.7
FROM node:22-alpine AS dependencies
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
	--mount=type=secret,id=npmrc,target=/root/.npmrc,required=false \
	npm ci --omit=dev

FROM node:22-alpine
WORKDIR /app
COPY --from=dependencies /app/node_modules ./node_modules
COPY src ./src
USER node
CMD ["node", "src/index.js"]
