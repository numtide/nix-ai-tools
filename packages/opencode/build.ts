#!/usr/bin/env bun

import path from "path"
import fs from "fs"

const OPENCODE_TUI_PATH = process.env.OPENCODE_TUI_PATH || ""
const OPENCODE_VERSION = process.env.OPENCODE_VERSION || "1.0.11"
const TARGET = process.env.TARGET || `bun-${process.platform}-${process.arch}`
const OUTFILE = process.env.OUTFILE || "opencode"

const dir = process.cwd()

// Dynamically import the solid plugin from node_modules
const solidPluginModule = await import(path.resolve(dir, "./node_modules/@opentui/solid/scripts/solid-plugin.ts"))
const solidPlugin = solidPluginModule.default

const parserWorker = fs.realpathSync(path.resolve(dir, "./node_modules/@opentui/core/parser.worker.js"))

await Bun.build({
  conditions: ["browser"],
  tsconfig: "./packages/opencode/tsconfig.json",
  plugins: [solidPlugin],
  sourcemap: "external",
  compile: {
    target: TARGET as any,
    outfile: OUTFILE,
    execArgv: [`--user-agent=opencode/${OPENCODE_VERSION}`, `--env-file=""`, `--`],
  },
  entrypoints: ["./packages/opencode/src/index.ts", parserWorker, "./packages/opencode/src/cli/cmd/tui/worker.ts"],
  define: {
    OPENCODE_VERSION: `'${OPENCODE_VERSION}'`,
    OPENCODE_TUI_PATH: `'${OPENCODE_TUI_PATH}'`,
    OTUI_TREE_SITTER_WORKER_PATH: "/$bunfs/root/" + path.relative(dir, parserWorker),
    OPENCODE_CHANNEL: `'latest'`,
  },
})

console.log(`Built ${OUTFILE} for ${TARGET}`)
