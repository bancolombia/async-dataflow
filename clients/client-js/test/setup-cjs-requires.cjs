/* eslint-disable */
// Wraps CJS-only requires so mocha (running in ESM mode) loads them via
// require() rather than import(). Files with a .cjs extension are always
// treated as CommonJS by mocha's requireOrImport helper.
require('source-map-support/register');
require('jsdom-global/register');
