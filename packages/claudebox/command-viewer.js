#!/usr/bin/env node

const fs = require('fs');
const readline = require('readline');
const { spawn } = require('child_process');

// ANSI color constants
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  grey: '\x1b[90m',
  yellow: '\x1b[33m',
  orange: '\x1b[38;5;208m',
  reset: '\x1b[0m'
};

// Logging function for logic errors
function logError(context, message) {
  process.stderr.write(`${colors.yellow}[${context}] ${message}${colors.reset}\n`);
}

// Display functions for command output
function displayCommandHeader(cmd) {
  const date = new Date(cmd.startTimestamp);
  const timestamp = `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  
  const promptColor = cmd.wrapped ? colors.green : colors.grey;
  const commandColor = cmd.wrapped ? '' : colors.grey;
  const sourceInfo = !cmd.wrapped && cmd.source ? `[${cmd.source}] ` : '';
  
  const prompt = `${promptColor}[${timestamp}] ${sourceInfo}$ ${colors.reset}`;
  process.stdout.write(`${prompt}${commandColor}${cmd.cmd}${colors.reset}\n`);
  
  // Update terminal title when displaying command
  setTerminalTitle(`[${cmd.num}] ${cmd.cmd}`);
}

function displayOutput(type, data) {
  if (type === 'stderr') {
    process.stdout.write(`${colors.orange}${data}${colors.reset}`);
  } else {
    process.stdout.write(data);
  }
}

function displayExit(cmd) {
  let lastLine = "";

  if (cmd.exitCode !== 0) {
    lastLine += `${colors.red}✗ Exit code: ${cmd.exitCode}${colors.reset} `;
  }

  // Display elapsed time
  const elapsed = cmd.endTimestamp - cmd.startTimestamp;
  const seconds = (elapsed / 1000).toFixed(2);
  lastLine += `${colors.grey}⏱ Elapsed: ${seconds}s${colors.reset}`;

  process.stdout.write(lastLine + `\n`);
}

// Set terminal title
function setTerminalTitle(title) {
  process.stdout.write(`\x1b]0;${title}\x07`);
}


// Command state object
class Command {
  constructor(entry) {
    this.num = entry.num;
    this.cmd = entry.cmd;
    this.wrapped = entry.wrapped;
    this.source = entry.source;
    this.startTimestamp = entry.timestamp;
    this.endTimestamp = null;
    this.output = []; // Array of {type: 'stdout'|'stderr', data: string}
    this.exitCode = null;
    this.displayed = false;
  }

  isComplete() {
    return this.exitCode !== null;
  }

  replay() {
    if (this.displayed) return;
    this.displayed = true;

    // Display command header
    displayCommandHeader(this);

    // Display output in order
    this.output.forEach(item => {
      displayOutput(item.type, item.data);
    });

    // Display exit status if command has completed
    if (this.exitCode !== null) {
      displayExit(this);
    }
  }
}

// Process a log entry
function processEntry(entry) {
  switch (entry.type) {
    case 'cmd': {
      const cmd = new Command(entry);
      commands.set(entry.num, cmd);
      
      // If this is the next command in sequence, we can start streaming it
      if (entry.num === currentCommandNum) {
        // This is the command we're waiting for
        cmd.replay()
      } else if (entry.num < currentCommandNum) {
        // Command arrived late - we've already moved past it
        logError('cmd', `Command ${entry.num} arrived after currentCommandNum ${currentCommandNum}`);
      }
      break;
    }

    case 'stdout':
    case 'stderr': {
      const cmd = commands.get(entry.num);
      if (cmd) {
        // Stream immediately if this is the current command
        if (entry.num === currentCommandNum) {
          if (!cmd.displayed) {
            cmd.replay()
          }
          // Stream the output
          displayOutput(entry.type, entry.data);
        } else {
          cmd.output.push({type: entry.type, data: entry.data});
        }
      } else {
        logError(entry.type, `Received ${entry.type} for unknown command ${entry.num}`);
      }
      break;
    }

    case 'exit': {
      const cmd = commands.get(entry.num);
      if (cmd) {
        cmd.exitCode = entry.exitCode;
        cmd.endTimestamp = entry.timestamp;
        
        // If this is the current command
        if (entry.num === currentCommandNum) {
          // Ensure command header is displayed if it hasn't been yet
          if (!cmd.displayed) {
            cmd.replay();
          } else {
            // Just show exit status
            displayExit(cmd);
          }
          commands.delete(cmd.num);
          // Move to next command
          displayNextCommands();
        }
      } else {
        // Exit event for a command we haven't seen yet
        // This can happen when commands complete very quickly
        logError('exit', `Received exit for unknown command ${entry.num} with code ${entry.exitCode}`);
      }
      break;
    }

    case 'error': {
      // Display errors immediately
      console.error(`${colors.red}❌ ${entry.context}: ${entry.message}${colors.reset}`);
      break;
    }

    case 'process_exit': {
      // Display process exit message
      const exitMsg = entry.signal 
        ? `Process terminated with signal ${entry.signal}` 
        : `Process exited with code ${entry.exitCode}`;
      console.log(`\n${colors.grey}─── ${exitMsg} ───${colors.reset}\n`);
      setTerminalTitle('claudebox - session ended');
      
      // Flush any buffered output and exit
      if (process.stdout.write) {
        process.stdout.write('', () => {
          process.exit(0);
        });
      } else {
        process.exit(0);
      }
      break;
    }
  }
}

// Display any buffered complete commands in order
function displayNextCommands() {
  currentCommandNum++;
  
  // Display all complete commands in sequence
  while (commands.has(currentCommandNum)) {
    const cmd = commands.get(currentCommandNum);
    if (cmd.isComplete()) {
      cmd.replay();
      // Clean up old commands to save memory
      commands.delete(cmd.num);
      currentCommandNum++;
    } else {
      // This command is not complete yet, wait for it
      break;
    }
  }
  
  // If no more commands, clear the title
  if (!commands.has(currentCommandNum)) {
    setTerminalTitle('claudebox - idle');
  }
}

// Start tailing the file
function tailFile() {
  // Use tail -F to follow the file from the beginning (and retry if it doesn't exist)
  const tail = spawn('tail', ['-F', '-n', '+1', logFile]);

  // Process each line from tail
  const rl = readline.createInterface({
    input: tail.stdout,
    crlfDelay: Infinity
  });

  rl.on('line', (line) => {
    if (line.trim()) {
      try {
        const entry = JSON.parse(line);
        processEntry(entry);
      } catch (e) {
        logError('parse', `Failed to parse JSON: ${e.message} - Line: ${line}`);
      }
    }
  });

  // Handle tail process errors
  tail.on('error', (err) => {
    console.error('Failed to start tail:', err);
    process.exit(1);
  });

  // Handle exit
  process.on('exit', (_code) => {
    tail.kill();
  });
}

// ===== Global State =====
const commands = new Map(); // num -> command data
let currentCommandNum = 1; // The command we're currently waiting for or displaying

// ===== Main Program =====

// Parse command line arguments
const args = process.argv.slice(2);
const logFile = args[0];

if (!logFile) {
  console.error('Usage: command-viewer <logfile>');
  process.exit(1);
}

// Handle uncaught errors
process.on('uncaughtException', (err) => {
  console.error('Uncaught exception:', err);
  process.exit(1);
});

// Start with a more engaging header
const termWidth = process.stdout.columns || 80;
const boxWidth = Math.min(termWidth - 2, 60); // Cap at 60 chars for readability
const title = 'ClaudeBox';

console.log(colors.green + '╔' + '═'.repeat(boxWidth - 2) + '╗' + colors.reset);
console.log(colors.green + '║' + colors.reset + title.padStart((boxWidth + title.length) / 2).padEnd(boxWidth - 2) + colors.green + '║' + colors.reset);
console.log(colors.green + '╚' + '═'.repeat(boxWidth - 2) + '╝' + colors.reset);

// Normal mode - tail the file
setTerminalTitle('claudebox - starting');

// Keep process running
process.stdin.resume();

tailFile();
