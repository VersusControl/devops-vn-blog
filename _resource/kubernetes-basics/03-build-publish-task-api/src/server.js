const http = require('node:http');

const port = Number(process.env.PORT || 3000);
const tasks = [];
let nextTaskId = 1;

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
}

function readJson(request) {
  return new Promise((resolve, reject) => {
    let body = '';

    request.on('data', (chunk) => {
      body += chunk;
    });
    request.on('end', () => {
      try {
        resolve(JSON.parse(body || '{}'));
      } catch {
        reject(new Error('Request body must be valid JSON.'));
      }
    });
  });
}

function createServer() {
  return http.createServer(async (request, response) => {
    try {
      if (request.method === 'GET' && request.url === '/healthz') {
        return sendJson(response, 200, { status: 'ok' });
      }

      if (request.method === 'GET' && request.url === '/tasks') {
        return sendJson(response, 200, { tasks });
      }

      if (request.method === 'POST' && request.url === '/tasks') {
        const { title } = await readJson(request);

        if (typeof title !== 'string' || !title.trim()) {
          return sendJson(response, 400, { error: 'title is required.' });
        }

        const task = { id: nextTaskId, title: title.trim(), completed: false };
        nextTaskId += 1;
        tasks.push(task);
        return sendJson(response, 201, task);
      }

      return sendJson(response, 404, { error: 'Not found.' });
    } catch (error) {
      if (error.message === 'Request body must be valid JSON.') {
        return sendJson(response, 400, { error: error.message });
      }

      console.error(error);
      return sendJson(response, 500, { error: 'Internal server error.' });
    }
  });
}

if (require.main === module) {
  createServer().listen(port, '0.0.0.0', () => {
    console.log(`Task API listening on port ${port}`);
  });
}

module.exports = { createServer };