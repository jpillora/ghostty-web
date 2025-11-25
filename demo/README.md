# @ghostty-web/demo

Cross-platform demo server for [ghostty-web](https://github.com/coder/ghostty-web) terminal emulator.

## Quick Start

```bash
npx @ghostty-web/demo
```

This starts a local web server with a fully functional terminal connected to your shell.
Works on **Linux**, **macOS**, and **Windows**.

## What it does

- Starts an HTTP server on port 8080 (configurable via `PORT` env var)
- Starts a WebSocket server on port 3001 for PTY communication
- Opens a real shell session (bash, zsh, cmd.exe, or PowerShell)
- Provides full PTY support (colors, cursor positioning, resize, etc.)

## Usage

```bash
# Default (port 8080)
npx @ghostty-web/demo

# Custom port
PORT=3000 npx @ghostty-web/demo
```

Then open http://localhost:8080 in your browser.

## Features

- 🖥️ Real shell sessions with full PTY support
- 🎨 True color (24-bit) and 256 color support
- ⌨️ Full keyboard support including special keys
- 📐 Dynamic terminal resizing
- 🔄 Auto-reconnection on disconnect
- 🌐 Cross-platform (Linux, macOS, Windows)

## Security Warning

⚠️ **This server provides full shell access.**

Only use for local development and demos. Do not expose to untrusted networks.

## License

MIT
