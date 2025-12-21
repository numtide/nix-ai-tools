#!/usr/bin/env node
// claudebox - Run Claude Code in YOLO mode with transparency
// Shows all commands Claude executes in a tmux split pane

const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const process = require("process");

// Get terminal size
function getTerminalSize() {
  try {
    const output = execSync("stty size 2>/dev/null", {
      encoding: "utf8",
      stdio: ["inherit", "pipe", "pipe"],
    });
    const [rows, cols] = output.trim().split(/\s+/).map(Number);
    return { rows: rows || 24, cols: cols || 80 };
  } catch {
    return { rows: 24, cols: 80 };
  }
}

// Parse command-line arguments
function parseArgs(args) {
  const { rows, cols } = getTerminalSize();

  // Default split direction based on terminal dimensions
  // If terminal is very wide (at least 3x as wide as tall), use horizontal split
  const defaultSplit = cols >= rows * 3 ? "horizontal" : "vertical";

  const options = {
    splitDirection: defaultSplit,
    loadTmuxConfig: true,
    enableMonitor: true,
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];

    switch (arg) {
      case "--no-monitor":
        options.enableMonitor = false;
        i++;
        break;

      case "--split-direction":
        if (i + 1 >= args.length) {
          console.error("Error: --split-direction requires a value");
          process.exit(1);
        }
        options.splitDirection = args[i + 1];
        if (
          options.splitDirection !== "horizontal" &&
          options.splitDirection !== "vertical"
        ) {
          console.error(
            "Error: --split-direction must be 'horizontal' or 'vertical'"
          );
          process.exit(1);
        }
        i += 2;
        break;

      case "--no-tmux-config":
        options.loadTmuxConfig = false;
        i++;
        break;

      case "-h":
      case "--help":
        showHelp();
        process.exit(0);
        break;

      default:
        console.error(`Unknown option: ${arg}`);
        console.error("Use --help for usage information");
        process.exit(1);
    }
  }

  return options;
}

function showHelp() {
  console.log(`Usage: claudebox [OPTIONS]

Options:
  --no-monitor                            Skip tmux monitoring pane (run Claude directly)
  --split-direction horizontal|vertical   Set tmux split direction (default: based on terminal size)
  --no-tmux-config                        Don't load user tmux configuration
  -h, --help                              Show this help message

Examples:
  claudebox                               # Run with default settings
  claudebox --no-monitor                  # Run without monitoring pane
                                            Commands are still logged to /tmp/claudebox-commands-*.log
  claudebox --split-direction vertical
  claudebox --no-tmux-config              # Use default tmux settings`);
}

// Get git repo root, falling back to current directory
function getRepoRoot(projectDir) {
  try {
    return execSync("git rev-parse --show-toplevel 2>/dev/null", {
      encoding: "utf8",
      cwd: projectDir,
    }).trim();
  } catch {
    return projectDir;
  }
}

// Sanitize session name - tmux treats '.' and ':' as special characters
function sanitizeSessionPrefix(name) {
  return name.replace(/[./:]/g, "_");
}

// Generate random hex string
function randomHex(length) {
  const chars = "0123456789abcdef";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars[Math.floor(Math.random() * chars.length)];
  }
  return result;
}

// Resolve real path (following symlinks)
function realpath(p) {
  return fs.realpathSync(p);
}

// Check if a path exists
function pathExists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

// Check if path is a file
function isFile(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

// Check if path is a directory
function isDirectory(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

// Build bubblewrap arguments
function buildBwrapArgs(options) {
  const {
    claudeHome,
    claudeConfig,
    claudeJson,
    sessionName,
    shareTree,
    repoRoot,
    logfile,
    loadTmuxConfig,
  } = options;

  const home = process.env.HOME;
  const user = process.env.USER;
  const pathEnv = process.env.PATH;
  const xdgConfigHome = process.env.XDG_CONFIG_HOME || path.join(home, ".config");

  const args = [
    "--dev",
    "/dev",
    "--proc",
    "/proc",
    "--ro-bind-try",
    "/usr",
    "/usr",
    "--ro-bind-try",
    "/bin",
    "/bin",
    "--ro-bind-try",
    "/lib",
    "/lib",
    "--ro-bind-try",
    "/lib64",
    "/lib64",
    "--ro-bind",
    "/etc",
    "/etc",
    "--ro-bind",
    "/nix",
    "/nix",
    "--bind",
    "/nix/var/nix/daemon-socket",
    "/nix/var/nix/daemon-socket",
    "--tmpfs",
    "/tmp",
    "--bind",
    claudeHome,
    home,
    "--bind",
    claudeConfig,
    path.join(home, ".claude"),
    "--bind",
    claudeJson,
    path.join(home, ".claude.json"),
    "--unshare-all",
    "--share-net",
    "--ro-bind",
    "/run",
    "/run",
    "--setenv",
    "HOME",
    home,
    "--setenv",
    "SESSION_NAME",
    sessionName,
    "--setenv",
    "USER",
    user,
    "--setenv",
    "PATH",
    pathEnv,
    "--setenv",
    "TMUX_TMPDIR",
    "/tmp",
    "--setenv",
    "TMPDIR",
    "/tmp",
    "--setenv",
    "TEMPDIR",
    "/tmp",
    "--setenv",
    "TEMP",
    "/tmp",
    "--setenv",
    "TMP",
    "/tmp",
  ];

  // Mount tmux configuration
  if (loadTmuxConfig) {
    const tmuxConf = path.join(home, ".tmux.conf");
    if (isFile(tmuxConf)) {
      args.push("--ro-bind", tmuxConf, path.join(home, ".tmux.conf"));
    }

    const tmuxConfigDir = path.join(xdgConfigHome, "tmux");
    if (isDirectory(tmuxConfigDir)) {
      args.push("--ro-bind", tmuxConfigDir, path.join(home, ".config", "tmux"));
    }
  }

  // Mount parent directory tree if working under home
  if (shareTree !== repoRoot) {
    args.push("--ro-bind", shareTree, shareTree);
  }

  // Git repo root gets full write access (YOLO mode)
  args.push("--bind", repoRoot, repoRoot);

  // Add logfile environment and mount
  args.push("--setenv", "CLAUDEBOX_LOG_FILE", logfile);
  args.push("--bind", logfile, logfile);

  return args;
}

// Main function
function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  // Prevent running monitoring mode inside tmux
  if (options.enableMonitor && process.env.TMUX) {
    console.error(
      "Error: claudebox monitoring mode cannot be run inside a tmux session."
    );
    console.error("       Use 'claudebox --no-monitor' to run inside tmux.");
    process.exit(1);
  }

  const projectDir = process.cwd();
  const repoRoot = getRepoRoot(projectDir);
  const sessionPrefix = sanitizeSessionPrefix(path.basename(repoRoot));
  const sessionId = randomHex(8);
  const sessionName = `${sessionPrefix}-${sessionId}`;

  // Create isolated home directory
  const claudeHome = `/tmp/${sessionName}`;

  // Cleanup on exit
  const cleanup = () => {
    try {
      fs.rmSync(claudeHome, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }
  };

  process.on("exit", cleanup);
  process.on("SIGINT", () => {
    cleanup();
    process.exit(130);
  });
  process.on("SIGTERM", () => {
    cleanup();
    process.exit(143);
  });

  fs.mkdirSync(claudeHome, { recursive: true });

  // Claude config directories
  const home = process.env.HOME;
  const claudeConfig = path.join(home, ".claude");
  fs.mkdirSync(claudeConfig, { recursive: true });
  const claudeJson = path.join(home, ".claude.json");

  // Prepare tmux configuration directories
  fs.mkdirSync(path.join(claudeHome, ".config", "tmux"), { recursive: true });

  // Ensure Claude is initialized before sandboxing
  if (!pathExists(claudeJson)) {
    console.log("Initializing Claude configuration...");
    try {
      execSync("claude --help", { stdio: "ignore" });
    } catch {
      // Ignore initialization errors
    }
  }

  // Smart filesystem sharing
  const realRepoRoot = realpath(repoRoot);
  const realHome = realpath(home);

  let shareTree;
  if (realRepoRoot.startsWith(realHome + "/")) {
    // Share entire top-level directory as read-only
    const relPath = realRepoRoot.slice(realHome.length + 1);
    const topDir = relPath.split("/")[0];
    shareTree = path.join(realHome, topDir);
  } else {
    // Only share current repo/project directory
    shareTree = realRepoRoot;
  }

  // Define log file path
  const logfile = `/tmp/claudebox-commands-${sessionName}.log`;

  // Create log file on host
  fs.writeFileSync(logfile, "");

  // Determine split flag
  const splitFlag = options.splitDirection === "vertical" ? "-v" : "-h";

  // Build bubblewrap arguments
  const bwrapArgs = buildBwrapArgs({
    claudeHome,
    claudeConfig,
    claudeJson,
    sessionName,
    shareTree,
    repoRoot,
    logfile,
    loadTmuxConfig: options.loadTmuxConfig,
  });

  // Launch Claude
  if (options.enableMonitor) {
    // Launch tmux with Claude in left pane, commands in right
    const tmuxScript = `
cd '${projectDir}'
tmux new-session -d -s '${sessionName}' -n main 'claude --dangerously-skip-permissions' 2>/dev/null
tmux set-option -t '${sessionName}' history-limit 50000
tmux split-window -d ${splitFlag} -t '${sessionName}:main' "exec command-viewer '${logfile}'"
exec tmux attach -t '${sessionName}'
`;

    const child = spawn("bwrap", [...bwrapArgs, "bash", "-c", tmuxScript], {
      stdio: "inherit",
    });

    child.on("close", (code) => {
      process.exit(code || 0);
    });
  } else {
    // No monitoring - run Claude directly
    const directScript = `
cd '${projectDir}'
echo 'claudebox: Commands logged to ${logfile}' >&2
echo 'claudebox: Use tail -f ${logfile} to monitor in another terminal' >&2
exec claude --dangerously-skip-permissions
`;

    const child = spawn("bwrap", [...bwrapArgs, "bash", "-c", directScript], {
      stdio: "inherit",
    });

    child.on("close", (code) => {
      process.exit(code || 0);
    });
  }
}

main();
