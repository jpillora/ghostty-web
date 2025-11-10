#!/bin/bash
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           Ghostty WASM Terminal - Demo Runner                 ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if ghostty-vt.wasm exists
if [ ! -f "ghostty-vt.wasm" ]; then
    echo -e "${YELLOW}⚠️  ghostty-vt.wasm not found${NC}"
    echo ""
    echo "Building WASM from Ghostty source..."
    echo ""
    
    # Check if zig is installed
    if ! command -v zig &> /dev/null; then
        echo -e "${RED}❌ Zig not found${NC}"
        echo ""
        echo "Install Zig 0.15.2+ first:"
        echo "  curl -L -o /tmp/zig-0.15.2.tar.xz \\"
        echo "    https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz"
        echo "  tar xf /tmp/zig-0.15.2.tar.xz -C /tmp"
        echo "  sudo cp -r /tmp/zig-x86_64-linux-0.15.2 /usr/local/zig-0.15.2"
        echo "  sudo ln -sf /usr/local/zig-0.15.2/zig /usr/local/bin/zig"
        echo ""
        exit 1
    fi
    
    # Check zig version
    ZIG_VERSION=$(zig version)
    echo "Found Zig: $ZIG_VERSION"
    echo ""
    
    # Check if ghostty source exists
    if [ ! -d "/tmp/ghostty" ]; then
        echo "Cloning Ghostty repository..."
        git clone https://github.com/ghostty-org/ghostty.git /tmp/ghostty
        echo ""
    fi
    
    # Build WASM
    echo "Building ghostty-vt.wasm..."
    cd /tmp/ghostty
    zig build lib-vt -Dtarget=wasm32-freestanding -Doptimize=ReleaseSmall
    
    # Copy to project
    cd - > /dev/null
    cp /tmp/ghostty/zig-out/bin/ghostty-vt.wasm .
    
    echo -e "${GREEN}✅ Built ghostty-vt.wasm ($(du -h ghostty-vt.wasm | cut -f1))${NC}"
    echo ""
fi

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found${NC}"
    exit 1
fi

echo -e "${GREEN}✅ ghostty-vt.wasm ready${NC}"
echo ""
echo "Starting HTTP server on port 8000..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🌐 Open in your browser:"
echo ""
echo "     http://localhost:8000/examples/sgr-demo.html"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start HTTP server
python3 -m http.server 8000
