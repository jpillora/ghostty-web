# Ghostty WASM Terminal

A terminal emulator that integrates [Ghostty's](https://github.com/ghostty-org/ghostty) VT100 parser via WebAssembly.

## What This Is

This repository provides a **foundation for building web-based terminals** using Ghostty's production-tested VT100 parser compiled to WebAssembly.

**What's implemented:**
- ✅ TypeScript wrapper for libghostty-vt WASM API
- ✅ SGR parser (ANSI colors and text styles)
- ✅ Key encoder (keyboard events → escape sequences)
- ✅ Demo showing parser in action

**What's missing (TODO):**
- ❌ Terminal screen buffer
- ❌ Canvas rendering
- ❌ VT100 state machine
- ❌ PTY connection
- ❌ Scrollback, selection, clipboard

## Quick Start

```bash
./run-demo.sh
# Opens: http://localhost:8000/examples/sgr-demo.html
```

The script will automatically:
1. Check if `ghostty-vt.wasm` exists
2. Build it from Ghostty source if needed
3. Start an HTTP server
4. Show you the URL to open

## Usage

```typescript
import { Ghostty, SgrAttributeTag, KeyAction, Key, Mods } from './lib/ghostty.ts';

// Load WASM
const ghostty = await Ghostty.load('./ghostty-vt.wasm');

// Parse colors (ESC[1;31m → Bold + Red)
const parser = ghostty.createSgrParser();
for (const attr of parser.parse([1, 31])) {
  if (attr.tag === SgrAttributeTag.BOLD) console.log('Bold!');
  if (attr.tag === SgrAttributeTag.FG_8) console.log('Red:', attr.color);
}

// Encode keyboard (Ctrl+A → 0x01)
const encoder = ghostty.createKeyEncoder();
const bytes = encoder.encode({
  action: KeyAction.PRESS,
  key: Key.A,
  mods: Mods.CTRL,
});
// Send bytes to PTY
```

## Why This Approach?

**DON'T** re-implement VT100 parsing from scratch (years of work, thousands of edge cases).

**DO** use Ghostty's proven parser:
- ✅ Battle-tested by thousands of users
- ✅ Handles all VT100/ANSI quirks correctly
- ✅ Modern features (RGB colors, Kitty keyboard protocol)
- ✅ Get bug fixes and updates for free

**You build**: Screen buffer, rendering, UI (the "easy" parts in TypeScript)  
**Ghostty handles**: VT100 parsing (the hard part via WASM)

## Architecture

```
Your Terminal (TypeScript)
├─ Screen buffer (2D array)
├─ Canvas rendering
├─ Keyboard/mouse events
└─ PTY connection
    │
    ▼
Ghostty WASM (this repo)
├─ Parse colors: ESC[1;31m → Bold + Red
└─ Encode keys: Ctrl+A → 0x01
    │
    ▼
libghostty-vt.wasm (122 KB)
└─ Production VT100 parser
```

## Files

- `lib/ghostty.ts` - TypeScript wrapper for WASM
- `lib/types.ts` - Type definitions
- `examples/sgr-demo.html` - Interactive demo
- `AGENTS.md` - Implementation guide for building the terminal

## Building

Requires:
- **Zig 0.15.2+** (to build WASM)
- **Ghostty source** (from GitHub)

```bash
# Install Zig 0.15.2
curl -L -o zig-0.15.2.tar.xz \
  https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz
tar xf zig-0.15.2.tar.xz
sudo cp -r zig-x86_64-linux-0.15.2 /usr/local/zig-0.15.2
sudo ln -sf /usr/local/zig-0.15.2/zig /usr/local/bin/zig

# Clone Ghostty
git clone https://github.com/ghostty-org/ghostty.git
cd ghostty

# Build WASM (~20 seconds)
zig build lib-vt -Dtarget=wasm32-freestanding -Doptimize=ReleaseSmall
# Output: zig-out/bin/ghostty-vt.wasm (122 KB)
```

## Next Steps

See **[AGENTS.md](./AGENTS.md)** for:
- How to implement the terminal
- Code examples for screen buffer, rendering
- VT100 state machine guide
- Testing instructions

## Links

- [Ghostty Terminal](https://github.com/ghostty-org/ghostty)
- [libghostty-vt API](https://github.com/ghostty-org/ghostty/tree/main/include/ghostty/vt)
- [VT100 Reference](https://vt100.net/docs/vt100-ug/)

## License

See cmux LICENSE (AGPL-3.0)
