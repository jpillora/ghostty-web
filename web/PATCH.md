# How the Patch Works

`patches/ghostty-wasm-api.patch` adds a complete terminal emulator C API to Ghostty's `lib-vt` library. Ghostty already ships lower-level APIs (SGR parser, key encoder, OSC parser) but does **not** yet expose a full terminal emulator through its C/WASM API. This patch fills that gap.

## Why a Patch?

Mitchell Hashimoto (Ghostty's author) is [working on libghostty](https://mitchellh.com/writing/libghostty-is-coming), which will eventually provide an official terminal API. Until that ships, this patch adds the minimum API surface needed to run a terminal emulator in the browser. The patch is designed to be temporary and to shrink as libghostty matures.

## Lifecycle

The patch is applied **temporarily** during the WASM build and reverted afterward:

```
1. git apply patches/ghostty-wasm-api.patch     # Apply
2. zig build lib-vt -Dtarget=wasm32-freestanding # Build WASM
3. git apply -R patches/ghostty-wasm-api.patch   # Revert
4. rm -f <new files created by patch>            # Clean up
```

This keeps the ghostty submodule clean at all times.

## Files Modified

### 1. `.gitignore` (1 line added)

Adds `node_modules/` to Ghostty's `.gitignore` — prevents noise if `bun install` is accidentally run inside the submodule.

### 2. `include/ghostty/vt.h` (2 lines added)

Adds `#include <ghostty/vt/terminal.h>` to the top-level header and a documentation reference for the terminal API group.

### 3. `include/ghostty/vt/terminal.h` (NEW — ~285 lines)

C header defining the entire terminal API. This is the public contract:

**Types:**
- `GhosttyTerminal` — opaque `void*` handle
- `GhosttyTerminalConfig` — config struct (scrollback limit, fg/bg/cursor colors, 16-color palette)
- `GhosttyCell` — 16-byte cell struct (codepoint, pre-resolved RGB colors, flags, width, hyperlink_id, grapheme_len)
- `GhosttyDirty` — enum: none/partial/full

**Functions:**

| Group | Function | Purpose |
|-------|----------|---------|
| **Lifecycle** | `ghostty_terminal_new(cols, rows)` | Create terminal with defaults |
| | `ghostty_terminal_new_with_config(cols, rows, config)` | Create with custom config |
| | `ghostty_terminal_free(term)` | Destroy terminal |
| | `ghostty_terminal_resize(term, cols, rows)` | Resize |
| | `ghostty_terminal_write(term, data, len)` | Write data (parses VT sequences) |
| **RenderState** | `ghostty_render_state_update(term)` | Update render snapshot, returns dirty state |
| | `ghostty_render_state_get_viewport(term, buf, size)` | Get ALL viewport cells in ONE call |
| | `ghostty_render_state_get_cols/rows(term)` | Get dimensions |
| | `ghostty_render_state_get_cursor_x/y/visible(term)` | Get cursor state |
| | `ghostty_render_state_get_bg/fg_color(term)` | Get default colors (0xRRGGBB) |
| | `ghostty_render_state_is_row_dirty(term, y)` | Check if row needs redraw |
| | `ghostty_render_state_mark_clean(term)` | Mark all rows as clean |
| | `ghostty_render_state_get_grapheme(term, row, col, buf, size)` | Get grapheme cluster codepoints |
| **Modes** | `ghostty_terminal_is_alternate_screen(term)` | Check alternate screen |
| | `ghostty_terminal_has_mouse_tracking(term)` | Check mouse tracking |
| | `ghostty_terminal_get_mode(term, mode, is_ansi)` | Query arbitrary mode |
| **Scrollback** | `ghostty_terminal_get_scrollback_length(term)` | History line count |
| | `ghostty_terminal_get_scrollback_line(term, offset, buf, size)` | Read history line |
| | `ghostty_terminal_get_scrollback_grapheme(...)` | Grapheme from history |
| | `ghostty_terminal_is_row_wrapped(term, y)` | Check soft-wrap |
| **Hyperlinks** | `ghostty_terminal_get_hyperlink_uri(term, row, col, buf, size)` | Get OSC 8 URI from viewport |
| | `ghostty_terminal_get_scrollback_hyperlink_uri(...)` | Get OSC 8 URI from history |
| **Responses** | `ghostty_terminal_has_response(term)` | Check pending DSR/DA responses |
| | `ghostty_terminal_read_response(term, buf, size)` | Read response bytes |

### 4. `src/lib_vt.zig` (~39 lines added)

Adds `@export` declarations for all new terminal functions. This is what makes them appear as WASM exports. The exports are added inside the existing `comptime` block that handles all lib-vt symbol exports.

### 5. `src/terminal/c/main.zig` (~44 lines added)

Registers the new `terminal` module in the C API dispatch table. Adds `pub const` aliases mapping the C function names to the Zig implementation functions.

### 6. `src/terminal/c/terminal.zig` (NEW — ~1,123 lines)

The Zig implementation. This is the core of the patch.

#### ResponseHandler (~260 lines)

A VT stream handler that processes escape sequences and generates responses. It handles every terminal action that Ghostty's stream parser emits:

- **Cursor movement** — up, down, left, right, absolute positioning, save/restore
- **Erase operations** — display (above/below/complete/scrollback), line (left/right/complete)
- **Scroll** — up, down, insert/delete lines
- **Text attributes** — SGR (bold, italic, underline, etc.), charset configuration
- **Modes** — set/reset/save/restore for all DEC and ANSI modes
- **Screen switching** — alternate screen buffer (modes 47, 1047, 1049)
- **Hyperlinks** — OSC 8 start/end
- **Semantic prompts** — shell integration markers
- **DSR responses** — Device Status Report (operating status, cursor position)
- **DA responses** — Device Attributes (primary: VT220+color, secondary: version)
- **Kitty keyboard** — push/pop/set keyboard modes
- **Tabs** — set, clear, horizontal tab forward/back

Actions that don't affect terminal state or require responses (bell, clipboard, notifications, etc.) are intentionally no-ops.

#### TerminalWrapper struct

Owns the full terminal state:

```zig
const TerminalWrapper = struct {
    alloc: Allocator,
    terminal: Terminal,           // Ghostty's Terminal instance
    handler: ResponseHandler,     // VT action handler
    stream: ResponseStream,       // VT byte stream parser
    render_state: RenderState,    // Cached render snapshot
    response_buffer: ArrayList(u8), // DSR/DA response queue
    last_screen_is_alternate: bool, // Screen switch detection
};
```

#### Lifecycle functions

- `new` / `newWithConfig` — allocates `TerminalWrapper`, initializes `Terminal` with colors/scrollback, enables grapheme clustering (mode 2027), disables linefeed mode
- `free` — tears down everything in correct order
- `resize` — delegates to `Terminal.resize`
- `write` — feeds bytes through the `ResponseStream` parser

#### RenderState API

The key performance optimization. Instead of crossing the WASM boundary per-cell or per-row:

1. `renderStateUpdate` — calls `RenderState.update` to snapshot the terminal. Detects screen switches (normal ↔ alternate) and forces full redraws.
2. `renderStateGetViewport` — reads ALL cells directly from the terminal's active page list, resolving styles and colors inline:
   - Looks up each cell's `style_id` in the page's style table
   - Resolves palette/RGB/default colors to concrete RGB values
   - Maps bold/italic/underline/etc. flags to a single `u8`
   - Reads grapheme cluster length from the page's grapheme map
   - Writes 16-byte `GhosttyCell` structs to the output buffer

#### Scrollback API

Uses Ghostty's page-based history. `getScrollbackLine` pins into the history region (y=0 is oldest) and fills cells the same way as viewport reading — resolving styles, colors, graphemes.

#### Hyperlink API

For cells with `hyperlink=true`, looks up the hyperlink ID from the page, gets the entry from the hyperlink set, and copies the URI bytes from page memory.

### 7. `src/terminal/render.zig` (~10 lines changed)

Fixes the `RenderState.update` method to provide default colors (black background, light gray foreground) when none are explicitly configured. Without this, the WASM build would skip color initialization and leave colors unresolved.

**Before:**
```zig
bg_fg: {
    const bg = t.colors.background.get() orelse break :bg_fg;
    const fg = t.colors.foreground.get() orelse break :bg_fg;
```

**After:**
```zig
{
    const default_bg: color.RGB = .{ .r = 0, .g = 0, .b = 0 };
    const default_fg: color.RGB = .{ .r = 204, .g = 204, .b = 204 };
    const bg = t.colors.background.get() orelse default_bg;
    const fg = t.colors.foreground.get() orelse default_fg;
```

## How to Update the Patch

When the Ghostty submodule is updated and the patch no longer applies cleanly:

1. Apply the old patch manually, resolving conflicts
2. Or re-create the patch from scratch using the same approach (the two new files are self-contained)
3. Test: `./scripts/build-wasm.sh`
4. Regenerate: `cd ghostty && git diff > ../patches/ghostty-wasm-api.patch`
5. Include untracked new files: `git diff` only covers modifications — for new files, use `git diff --cached` after staging, or `git diff HEAD` with a temporary commit

The safest approach:

```bash
cd ghostty
git apply ../patches/ghostty-wasm-api.patch   # Apply old patch as starting point
# Make fixes for API changes
git add -A
git diff --cached > ../patches/ghostty-wasm-api.patch
git reset HEAD .                               # Unstage
git checkout .                                 # Revert tracked changes
rm -f include/ghostty/vt/terminal.h src/terminal/c/terminal.zig  # Remove new files
```

## Design Decisions

**Why pre-resolve colors?** Palette lookups require access to the page's style table and palette array, which live in WASM memory. Resolving to RGB during the viewport read eliminates per-cell palette lookups on the TypeScript side.

**Why one viewport call?** Each WASM function call has overhead. Reading 80x24=1,920 cells individually would mean 1,920 boundary crossings per frame. The bulk `get_viewport` call does it in ONE crossing.

**Why a response buffer?** Some escape sequences (DSR, DA) require the terminal to "reply" with bytes that should be sent back to the PTY. The response buffer queues these replies so TypeScript can read and emit them via `onData`.

**Why detect screen switches?** When switching between normal and alternate screen (e.g., entering/exiting vim), the RenderState cache from the previous screen is stale. The patch detects this and forces a full re-snapshot.
