const cp = require('child_process');
const fs = require('fs');

// Store original functions before patching
const originalSpawn = cp.spawn;
const originalExec = cp.exec;
const originalExecSync = cp.execSync;
const originalExecFile = cp.execFile;

// Track command numbers for ordering
let commandCounter = 0;

// Unset NODE_OPTIONS to prevent child Node processes from inheriting command logging
delete process.env.NODE_OPTIONS;

// Error handler that displays in Claude's UI
function handleError(error, context) {
  const errorMsg = `[claudebox error in ${context}]: ${error.message || error}`;
  console.error(errorMsg);
  // Also log errors as JSON
  writeLogEntry({
    type: 'error',
    context,
    message: error.message || error.toString(),
    timestamp: Date.now()
  });
}

// Helper to capture and log output from child processes
function wrapChildProcess(child, commandNum) {
  if (!child || !child.stdout || !child.stderr) return child;

  // Capture stdout
  child.stdout.on('data', (data) => {
    writeLogEntry({
      num: commandNum,
      type: 'stdout',
      data: data.toString(),
      timestamp: Date.now()
    });
  });

  // Capture stderr
  child.stderr.on('data', (data) => {
    writeLogEntry({
      num: commandNum,
      type: 'stderr',
      data: data.toString(),
      timestamp: Date.now()
    });
  });

  // Track exit status
  let exitCode = null;
  let exitLogged = false;

  // Helper to log exit once we have the code
  function logExit(code) {
    if (exitLogged) return;
    exitLogged = true;

    // Normalize exit code (null means 0 in Node.js)
    const finalCode = code === null || code === undefined ? 0 : code;

    writeLogEntry({
      num: commandNum,
      type: 'exit',
      exitCode: finalCode,
      timestamp: Date.now()
    });
  }

  // The 'exit' event provides the exit code
  child.on('exit', (code, signal) => {
    exitCode = code;
    // If we already got 'close', log now
    if (child.stdout.destroyed && child.stderr.destroyed) {
      logExit(exitCode);
    }
  });

  // The 'close' event fires when all streams are closed
  // It also provides exit code as the first parameter
  child.on('close', (code) => {
    // Use the code from close if we don't have one from exit
    if (exitCode === null && code !== null) {
      exitCode = code;
    }
    logExit(exitCode);
  });

  return child;
}

function parseCommand(command) {
  // Extract the actual command from Claude's bash wrapper
  // Pattern: bash -c -l ... eval "ACTUAL_COMMAND" < /dev/null && pwd -P >| /tmp/...
  // We know the pattern ends with < /dev/null && pwd -P >| /tmp/
  // So we can match everything between eval and that ending

  // Match eval followed by either ' or ", capture everything until the known ending pattern
  // This avoids complex quote parsing by using the known structure
  const evalMatch = command.match(/eval\s+["'](.+?)["']\s*\\?<\s*\/dev\/null\s*&&\s*pwd/);

  return {
    actualCommand: evalMatch ? evalMatch[1] : command,
    isWrapped: !!evalMatch
  };
}

// Use explicit log file path if provided, otherwise construct from session name
const commandLog = process.env.CLAUDEBOX_LOG_FILE || `/tmp/claudebox-commands-${process.env.SESSION_NAME || 'unknown'}.log`;

// Initialize the command log file immediately (only if it doesn't exist)
try {
  if (!fs.existsSync(commandLog)) {
    fs.writeFileSync(commandLog, '');
  }
} catch (e) {
  // Ignore errors
}

// Helper function to write JSON log entries
function writeLogEntry(entry) {
  try {
    fs.appendFileSync(commandLog, JSON.stringify(entry) + '\n');
  } catch (e) {
    // Ignore if file doesn't exist or other errors
  }
}


function logCommand(command, source = '') {
  try {
    const { actualCommand, isWrapped } = parseCommand(command);

    // Skip empty commands
    if (!actualCommand || actualCommand.trim() === '') return 0;

    // Get unique command number
    const commandNum = ++commandCounter;

    // Write command entry
    writeLogEntry({
      num: commandNum,
      type: 'cmd',
      cmd: actualCommand,
      wrapped: isWrapped,
      source: source || undefined,
      timestamp: Date.now()
    });

    return commandNum;
  } catch (error) {
    handleError(error, 'logCommand');
    return 0;
  }
}

// Wrap all patches in try-catch to ensure Claude continues to work even if our wrapper fails
try {
  // Patch spawn
  cp.spawn = function (cmd, args = [], options) {
    const fullCommand = [cmd, ...args].map(String).join(' ');
    const commandNum = logCommand(fullCommand, 'spawn');
    const child = originalSpawn.call(this, cmd, args, options);
    return wrapChildProcess(child, commandNum);
  };

  // Patch exec
  cp.exec = function (command, options, callback) {
    // Handle different argument patterns
    if (typeof options === 'function') {
      callback = options;
      options = undefined;
    }
    const commandNum = logCommand(command, 'exec');
    const child = originalExec.call(this, command, options, callback);
    return wrapChildProcess(child, commandNum);
  };

  // Patch execSync
  cp.execSync = function (command, options) {
    const commandNum = logCommand(command, 'execSync');

    let result;
    let exitCode = 0;
    try {
      result = originalExecSync.call(this, command, options);
      // Log successful output
      if (result) {
        const output = result.toString();
        if (output) {
          writeLogEntry({
            num: commandNum,
            type: 'stdout',
            data: output,
            timestamp: Date.now()
          });
        }
      }
      // Log successful exit
      writeLogEntry({
        num: commandNum,
        type: 'exit',
        exitCode: 0,
        timestamp: Date.now()
      });
    } catch (error) {
      exitCode = error.status || 1;
      // Log error output
      if (error.stderr) {
        writeLogEntry({
          num: commandNum,
          type: 'stderr',
          data: error.stderr.toString(),
          timestamp: Date.now()
        });
      }
      writeLogEntry({
        num: commandNum,
        type: 'exit',
        exitCode: exitCode,
        timestamp: Date.now()
      });
      throw error; // Re-throw the original error
    }

    return result;
  };

  // Patch execFile
  cp.execFile = function (file, args, options, callback) {
    // Handle various argument patterns for execFile
    let actualArgs = [];

    if (typeof args === 'function') {
      actualArgs = [];
    } else if (Array.isArray(args)) {
      actualArgs = args;
    } else if (typeof args === 'object' && args !== null && !Array.isArray(args)) {
      // args is actually options
      actualArgs = [];
    }

    const fullCommand = [file, ...actualArgs].map(String).join(' ');
    const commandNum = logCommand(fullCommand, 'execFile');
    const child = originalExecFile.apply(this, arguments);
    return wrapChildProcess(child, commandNum);
  };
} catch (error) {
  handleError(error, 'initialization');
}

// Log when the Node process exits
process.on('exit', (code) => {
  writeLogEntry({
    type: 'process_exit',
    exitCode: code === null || code === undefined ? 0 : code,
    timestamp: Date.now()
  });
});

// Also handle other termination signals
process.on('SIGINT', () => {
  writeLogEntry({
    type: 'process_exit',
    signal: 'SIGINT',
    timestamp: Date.now()
  });
  process.exit(130); // Standard exit code for SIGINT
});

process.on('SIGTERM', () => {
  writeLogEntry({
    type: 'process_exit',
    signal: 'SIGTERM',
    timestamp: Date.now()
  });
  process.exit(143); // Standard exit code for SIGTERM
});
