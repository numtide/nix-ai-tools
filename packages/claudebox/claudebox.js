#!/usr/bin/env node
// claudebox - Run Claude Code in YOLO mode with transparency
// Shows all commands Claude executes in a tmux split pane

const { execSync, spawn } = require("child_process");
const fs = require("fs");
const path = require("path");
const process = require("process");

// =============================================================================
// Utility Functions
// =============================================================================

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

function sanitizeSessionPrefix(name) {
  return name.replace(/[./:]/g, "_");
}

function randomHex(length) {
  const chars = "0123456789abcdef";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars[Math.floor(Math.random() * chars.length)];
  }
  return result;
}

function realpath(p) {
  return fs.realpathSync(p);
}

function pathExists(p) {
  try {
    fs.accessSync(p);
    return true;
  } catch {
    return false;
  }
}

function isFile(p) {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

function isDirectory(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

// =============================================================================
// Sandbox Interface
// =============================================================================

/**
 * Abstract sandbox interface.
 * Each platform implements this to provide process isolation.
 */
class Sandbox {
  constructor(config) {
    this.config = config;
  }

  /**
   * Returns the command and arguments to execute a script in the sandbox.
   * @param {string} script - The bash script to run
   * @returns {{ cmd: string, args: string[], env: object }}
   */
  wrap(_script) {
    throw new Error("Sandbox.wrap() must be implemented by subclass");
  }

  /**
   * Spawn a process inside the sandbox.
   * @param {string} script - The bash script to run
   * @returns {ChildProcess}
   */
  spawn(script) {
    const { cmd, args, env } = this.wrap(script);
    return spawn(cmd, args, { stdio: "inherit", env });
  }

  /**
   * Create the appropriate sandbox for the current platform.
   * @param {object} config - Sandbox configuration
   * @returns {Sandbox}
   */
  static create(config) {
    const platform = process.platform;

    switch (platform) {
      case "linux":
        return new BubblewrapSandbox(config);
      case "darwin":
        return new SeatbeltSandbox(config);
      default:
        throw new Error(
          `Unsupported platform: ${platform}. Supported: linux, darwin (macOS)`
        );
    }
  }
}

// =============================================================================
// Linux: Bubblewrap Sandbox
// =============================================================================

class BubblewrapSandbox extends Sandbox {
  wrap(script) {
    const {
      claudeHome,
      claudeConfig,
      claudeJson,
      sessionName,
      shareTree,
      repoRoot,
      logfile,
      loadTmuxConfig,
      allowSshAgent,
      allowGpgAgent,
      allowXdgRuntime,
    } = this.config;

    const home = process.env.HOME;
    const user = process.env.USER;
    const pathEnv = process.env.PATH;
    const xdgConfigHome = process.env.XDG_CONFIG_HOME || path.join(home, ".config");

    const args = [
      // Basic filesystem
      "--dev", "/dev",
      "--proc", "/proc",
      "--ro-bind-try", "/usr", "/usr",
      "--ro-bind-try", "/bin", "/bin",
      "--ro-bind-try", "/lib", "/lib",
      "--ro-bind-try", "/lib64", "/lib64",
      "--ro-bind", "/etc", "/etc",

      // Selective /run mounts - avoid exposing /run/user/$UID (XDG runtime)
      "--ro-bind-try", "/run/systemd/resolve", "/run/systemd/resolve", // DNS resolver (stub-resolv.conf)
      "--ro-bind-try", "/run/current-system", "/run/current-system",
      "--ro-bind-try", "/run/booted-system", "/run/booted-system",
      "--ro-bind-try", "/run/opengl-driver", "/run/opengl-driver",
      "--ro-bind-try", "/run/opengl-driver-32", "/run/opengl-driver-32",
      "--ro-bind-try", "/run/nixos", "/run/nixos",
      "--ro-bind-try", "/run/wrappers", "/run/wrappers",

      // Nix store (read-only) and daemon socket (read-write)
      "--ro-bind", "/nix", "/nix",
      "--bind", "/nix/var/nix/daemon-socket", "/nix/var/nix/daemon-socket",

      // Isolated temp filesystem
      "--tmpfs", "/tmp",

      // Isolated home with Claude config mounted
      "--bind", claudeHome, home,
      "--bind", claudeConfig, path.join(home, ".claude"),
      "--bind", claudeJson, path.join(home, ".claude.json"),

      // Namespace isolation with network sharing
      "--unshare-all",
      "--share-net",

      // Environment variables
      "--setenv", "HOME", home,
      "--setenv", "USER", user,
      "--setenv", "PATH", pathEnv,
      "--setenv", "SESSION_NAME", sessionName,
      "--setenv", "CLAUDEBOX_LOG_FILE", logfile,
      "--setenv", "TMPDIR", "/tmp",
      "--setenv", "TEMPDIR", "/tmp",
      "--setenv", "TEMP", "/tmp",
      "--setenv", "TMP", "/tmp",
      "--setenv", "TMUX_TMPDIR", "/tmp",
    ];

    // Mount tmux configuration if requested
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

    // Mount parent directory tree as read-only if needed
    if (shareTree !== repoRoot) {
      args.push("--ro-bind", shareTree, shareTree);
    }

    // Project directory gets full write access (YOLO mode)
    args.push("--bind", repoRoot, repoRoot);

    // Mount logfile
    args.push("--bind", logfile, logfile);

    // XDG runtime directory access (opt-in)
    const xdgRuntimeDir = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;

    if (allowXdgRuntime) {
      // Mount entire XDG runtime directory
      if (isDirectory(xdgRuntimeDir)) {
        args.push("--ro-bind", xdgRuntimeDir, xdgRuntimeDir);
        args.push("--setenv", "XDG_RUNTIME_DIR", xdgRuntimeDir);
      }
    } else {
      // Selective socket access
      if (allowSshAgent && process.env.SSH_AUTH_SOCK) {
        const sock = process.env.SSH_AUTH_SOCK;
        if (pathExists(sock)) {
          args.push("--ro-bind", sock, sock);
          args.push("--setenv", "SSH_AUTH_SOCK", sock);
        }
      }

      if (allowGpgAgent) {
        const gpgDir = path.join(xdgRuntimeDir, "gnupg");
        if (isDirectory(gpgDir)) {
          args.push("--ro-bind", gpgDir, gpgDir);
        }
      }
    }

    // Add the script to execute
    args.push("bash", "-c", script);

    return {
      cmd: "bwrap",
      args,
      env: process.env,
    };
  }
}

// =============================================================================
// macOS: Seatbelt Sandbox (sandbox-exec)
// =============================================================================

class SeatbeltSandbox extends Sandbox {
  wrap(script) {
    const { repoRoot, logfile, sessionName } = this.config;

    // Load base policy from environment
    const seatbeltProfile = process.env.CLAUDEBOX_SEATBELT_PROFILE;
    if (!seatbeltProfile || !pathExists(seatbeltProfile)) {
      throw new Error(
        "Seatbelt profile not found. Set CLAUDEBOX_SEATBELT_PROFILE environment variable."
      );
    }

    const basePolicy = fs.readFileSync(seatbeltProfile, "utf8");

    // Canonicalize paths (macOS symlinks: /var -> /private/var, /tmp -> /private/tmp)
    const canonicalRepoRoot = realpath(repoRoot);
    const tmpdir = process.env.TMPDIR || "/tmp";
    const canonicalTmpdir = realpath(tmpdir);
    const canonicalSlashTmp = realpath("/tmp");

    // Build dynamic policy
    const writablePaths = [
      '(subpath (param "PROJECT_DIR"))',
      '(subpath (param "TMPDIR"))',
      '(subpath (param "LOGFILE_DIR"))',
    ];

    if (canonicalTmpdir !== canonicalSlashTmp) {
      writablePaths.push('(subpath (param "SLASH_TMP"))');
    }

    const dynamicPolicy = `
; Allow read-only file operations
(allow file-read*)

; Allow writes to project and temp directories
(allow file-write*
  ${writablePaths.join("\n  ")})

; Network access for Claude API
(allow network-outbound)
(allow network-inbound)
(allow system-socket)
`;

    const fullPolicy = basePolicy + "\n" + dynamicPolicy;

    // Build sandbox-exec arguments
    const args = [
      "-p", fullPolicy,
      `-DPROJECT_DIR=${canonicalRepoRoot}`,
      `-DTMPDIR=${canonicalTmpdir}`,
      `-DLOGFILE_DIR=${path.dirname(logfile)}`,
    ];

    if (canonicalTmpdir !== canonicalSlashTmp) {
      args.push(`-DSLASH_TMP=${canonicalSlashTmp}`);
    }

    args.push("--", "bash", "-c", script);

    // Environment variables (sandbox-exec inherits env, unlike bwrap)
    const env = {
      ...process.env,
      SESSION_NAME: sessionName,
      CLAUDEBOX_LOG_FILE: logfile,
    };

    return {
      cmd: "/usr/bin/sandbox-exec",
      args,
      env,
    };
  }
}

// =============================================================================
// CLI Argument Parsing
// =============================================================================

function parseArgs(args) {
  const { rows, cols } = getTerminalSize();
  const defaultSplit = cols >= rows * 3 ? "horizontal" : "vertical";

  const options = {
    splitDirection: defaultSplit,
    loadTmuxConfig: true,
    enableMonitor: true,
    allowSshAgent: false,
    allowGpgAgent: false,
    allowXdgRuntime: false,
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
        if (!["horizontal", "vertical"].includes(options.splitDirection)) {
          console.error("Error: --split-direction must be 'horizontal' or 'vertical'");
          process.exit(1);
        }
        i += 2;
        break;

      case "--no-tmux-config":
        options.loadTmuxConfig = false;
        i++;
        break;

      case "--allow-ssh-agent":
        options.allowSshAgent = true;
        i++;
        break;

      case "--allow-gpg-agent":
        options.allowGpgAgent = true;
        i++;
        break;

      case "--allow-xdg-runtime":
        options.allowXdgRuntime = true;
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
  --allow-ssh-agent                       Allow access to SSH agent socket
  --allow-gpg-agent                       Allow access to GPG agent socket
  --allow-xdg-runtime                     Allow full XDG runtime directory access
  -h, --help                              Show this help message

Security:
  By default, claudebox blocks access to /run/user/$UID (XDG runtime directory)
  which contains DBus, audio, display, and other sensitive sockets.
  Use --allow-* flags to selectively enable access to specific services.

Examples:
  claudebox                               # Run with default settings
  claudebox --no-monitor                  # Run without monitoring pane
  claudebox --allow-ssh-agent             # Allow SSH agent for git operations
  claudebox --allow-xdg-runtime           # Allow full XDG runtime access`);
}

// =============================================================================
// Main
// =============================================================================

function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  // Prevent running monitoring mode inside tmux
  if (options.enableMonitor && process.env.TMUX) {
    console.error("Error: claudebox monitoring mode cannot be run inside a tmux session.");
    console.error("       Use 'claudebox --no-monitor' to run inside tmux.");
    process.exit(1);
  }

  // Session setup
  const projectDir = process.cwd();
  const repoRoot = getRepoRoot(projectDir);
  const sessionPrefix = sanitizeSessionPrefix(path.basename(repoRoot));
  const sessionId = randomHex(8);
  const sessionName = `${sessionPrefix}-${sessionId}`;

  // Create isolated home directory
  const home = process.env.HOME;
  const claudeHome = `/tmp/${sessionName}`;

  // Cleanup handler
  const cleanup = () => {
    try {
      fs.rmSync(claudeHome, { recursive: true, force: true });
    } catch {
      // Ignore cleanup errors
    }
  };

  process.on("exit", cleanup);
  process.on("SIGINT", () => { cleanup(); process.exit(130); });
  process.on("SIGTERM", () => { cleanup(); process.exit(143); });

  fs.mkdirSync(claudeHome, { recursive: true });

  // Claude config directories
  const claudeConfig = path.join(home, ".claude");
  fs.mkdirSync(claudeConfig, { recursive: true });
  const claudeJson = path.join(home, ".claude.json");

  // Prepare tmux config directory in isolated home
  fs.mkdirSync(path.join(claudeHome, ".config", "tmux"), { recursive: true });

  // Initialize Claude if needed
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
    const relPath = realRepoRoot.slice(realHome.length + 1);
    const topDir = relPath.split("/")[0];
    shareTree = path.join(realHome, topDir);
  } else {
    shareTree = realRepoRoot;
  }

  // Log file setup
  const logfile = `/tmp/claudebox-commands-${sessionName}.log`;
  fs.writeFileSync(logfile, "");

  // Create sandbox
  let sandbox;
  try {
    sandbox = Sandbox.create({
      claudeHome,
      claudeConfig,
      claudeJson,
      sessionName,
      shareTree,
      repoRoot,
      logfile,
      loadTmuxConfig: options.loadTmuxConfig,
      allowSshAgent: options.allowSshAgent,
      allowGpgAgent: options.allowGpgAgent,
      allowXdgRuntime: options.allowXdgRuntime,
    });
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }

  // Build script and launch
  const splitFlag = options.splitDirection === "vertical" ? "-v" : "-h";

  const script = options.enableMonitor
    ? `
cd '${projectDir}'
tmux new-session -d -s '${sessionName}' -n main 'claude --dangerously-skip-permissions' 2>/dev/null
tmux set-option -t '${sessionName}' history-limit 50000
tmux split-window -d ${splitFlag} -t '${sessionName}:main' "exec command-viewer '${logfile}'"
exec tmux attach -t '${sessionName}'
`
    : `
cd '${projectDir}'
echo 'claudebox: Commands logged to ${logfile}' >&2
echo 'claudebox: Use tail -f ${logfile} to monitor in another terminal' >&2
exec claude --dangerously-skip-permissions
`;

  const child = sandbox.spawn(script);
  child.on("close", (code) => process.exit(code || 0));
}

main();
