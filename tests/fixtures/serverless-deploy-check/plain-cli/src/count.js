#!/usr/bin/env node
const { readFileSync } = require("node:fs");

const file = process.argv[2];
if (!file) {
  console.error("usage: label-count <file.csv>");
  process.exit(2);
}
const rows = readFileSync(file, "utf8").split("\n").filter((line) => line.trim() !== "");
console.log(Math.max(rows.length - 1, 0));
