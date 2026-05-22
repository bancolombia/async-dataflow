/* eslint-disable */
// Test-only CommonJS resolver shim.
// In production, src/async-client.ts uses `await import("./transport/sse-transport.js")`
// (with .js extension) so the published ESM build is strict-ESM compliant.
// Under ts-node + mocha (CommonJS), the source files have .ts extensions, so
// require('./transport/sse-transport.js') would fail. This hook strips the .js
// suffix for relative imports originating from src/, letting ts-node resolve
// them to the corresponding .ts files.
const Module = require('module');
const path = require('path');

const originalResolveFilename = Module._resolveFilename;

Module._resolveFilename = function (request, parent, ...rest) {
    if (
        typeof request === 'string' &&
        request.endsWith('.js') &&
        request.startsWith('.') &&
        parent &&
        typeof parent.filename === 'string' &&
        parent.filename.includes(`${path.sep}src${path.sep}`)
    ) {
        try {
            return originalResolveFilename.call(
                this,
                request.slice(0, -3),
                parent,
                ...rest
            );
        } catch {
            // Fall through to original resolution.
        }
    }
    return originalResolveFilename.call(this, request, parent, ...rest);
};
