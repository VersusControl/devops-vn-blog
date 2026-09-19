const http = require('node:http');
const { readFile, writeFile, mkdir } = require('node:fs/promises');
const { dirname } = require('node:path');

const port = Number(process.env.PORT || 3000);
const taskStorePath = process.env.TASK_STORE_PATH || '/tmp/tasks.json';
const message = process.env.APP_MESSAGE || 'Tasks are ready.';
const apiToken = process.env.API_TOKEN;

async function readTasks() {
  try {
    return JSON.parse(await readFile(taskStorePath, 'utf8'));
  } catch (error) {
    if (error.code === 'ENOENT') return [];
    throw error;
  }
}

async function saveTasks(tasks) {
  await mkdir(dirname(taskStorePath), { recursive: true });
  await writeFile(taskStorePath, JSON.stringify(tasks, null, 2));
}

function send(response, statusCode, body) {
  response.writeHead(statusCode, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = '';
    request.on('data', (chunk) => { body += chunk; });
    request.on('end', () => {
      try { resolve(JSON.parse(body || '{}')); } catch { reject(new Error('Request body must be JSON.')); }
    });
  });
}

const server = http.createServer(async (request, response) => {
  try {
    if (request.method === 'GET' && request.url === '/healthz') {
      return send(response, 200, { status: 'ok' });
    }
    if (request.method === 'GET' && request.url === '/') {
      return send(response, 200, { message, tasks: await readTasks() });
    }
    if (request.method === 'POST' && request.url === '/tasks') {
      if (apiToken && request.headers.authorization !== `Bearer ${apiToken}`) {
        return send(response, 401, { error: 'A valid bearer token is required.' });
      }
      const { title } = await readBody(request);
      if (typeof title !== 'string' || !title.trim()) {
        return send(response, 400, { error: 'title is required.' });
      }
      const tasks = await readTasks();
      const task = { id: String(Date.now()), title: title.trim(), completed: false };
      tasks.push(task);
      await saveTasks(tasks);
      return send(response, 201, task);
    }
    return send(response, 404, { error: 'Not found.' });
  } catch (error) {
    console.error(error);
    return send(response, 500, { error: 'Internal server error.' });
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Task API listening on port ${port}`);
});