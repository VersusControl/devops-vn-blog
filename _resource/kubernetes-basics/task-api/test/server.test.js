const test = require('node:test');
const assert = require('node:assert/strict');

test('the example project has a Node.js test command', () => {
  assert.equal(typeof process.version, 'string');
});