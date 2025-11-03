#!/usr/bin/env bun

import path from "path"
import fs from "fs"

const OPENCODE_TUI_PATH = process.env.OPENCODE_TUI_PATH || ""
const OPENCODE_VERSION = process.env.OPENCODE_VERSION || "1.0.11"
const TARGET = process.env.TARGET || `bun-${process.platform}-${process.arch}`
const OUTFILE = process.env.OUTFILE || "opencode"

const rootDir = process.cwd()
const packageDir = path.resolve(rootDir, "packages/opencode")

// Change to package directory for correct relative paths
process.chdir(packageDir)

// Dynamically import the solid plugin from node_modules
const solidPluginModule = await import(path.resolve(rootDir, "./node_modules/@opentui/solid/scripts/solid-plugin.ts"))
const solidPlugin = solidPluginModule.default

const parserWorker = fs.realpathSync(path.resolve(rootDir, "./node_modules/@opentui/core/parser.worker.js"))

await Bun.build({
  conditions: ["browser"],
  tsconfig: "./tsconfig.json",
  plugins: [solidPlugin],
  sourcemap: "external",
  compile: {
    target: TARGET as any,
    outfile: path.resolve(rootDir, OUTFILE),
    execArgv: [`--user-agent=opencode/${OPENCODE_VERSION}`, `--env-file=""`, `--`],
  },
  entrypoints: ["./src/index.ts", parserWorker, "./src/cli/cmd/tui/worker.ts"],
  define: {
    OPENCODE_VERSION: `'${OPENCODE_VERSION}'`,
    OPENCODE_TUI_PATH: `'${OPENCODE_TUI_PATH}'`,
    OTUI_TREE_SITTER_WORKER_PATH: "/$bunfs/root/" + path.relative(packageDir, parserWorker),
    OPENCODE_CHANNEL: `'latest'`,
  },
})

console.log(`Built ${OUTFILE} for ${TARGET}`)
