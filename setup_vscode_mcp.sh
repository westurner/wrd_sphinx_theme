#!/bin/bash

echo "========================================="
echo "   VS Code MCP & npx Verification Check  "
echo "========================================="

echo "[1] Checking for npx across different contexts..."

check_npx() {
  local context=$1
  local cmd=$2

  echo "-> Checking $context..."
  if $cmd >/dev/null 2>&1; then
    echo "   ✅ Success: '$cmd' responded with $($cmd)"
  else
    echo "   ❌ Failed or unavailable: '$cmd'"
  fi
}

# 1. Devcontainer / Current environment
check_npx "Current Environment (Devcontainer)" "npx -v"

# 2. Host (If inside flatpak, accessible via flatpak-spawn --host)
if command -v flatpak-spawn >/dev/null 2>&1; then
  check_npx "Host OS (via flatpak-spawn)" "flatpak-spawn --host npx -v"
else
  echo "-> Checking Host OS (via flatpak-spawn)..."
  echo "   ⚠️ flatpak-spawn not found in this environment; skipping."
fi

# 3. Flatpak Sandbox (If running inside the flatpak)
if [ -f /.flatpak-info ]; then
  check_npx "VS Code Flatpak Sandbox" "npx -v"
else
  echo "-> Checking VS Code Flatpak Sandbox..."
  echo "   ⚠️ Not currently running inside a Flatpak sandbox (/.flatpak-info not found)."
fi

echo ""
echo "[2] Testing MCP server execution (chrome-devtools-mcp) in current env..."
echo "Running npx to fetch and start the MCP server..."

# We pipe /dev/null to stdin and restrict to a 5-second timeout because an MCP server will normally hang waiting for JSON-RPC over stdio.
# Exit code 124 from timeout means it successfully stayed alive waiting for input.
timeout 5 npx -y chrome-devtools-mcp@latest < /dev/null
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
  echo "✅ MCP server successfully started and listened for input!"
elif [ $EXIT_CODE -eq 0 ]; then
  echo "✅ MCP server execution completed successfully."
else
  echo "⚠️ MCP server exited with code $EXIT_CODE."
  echo "Note: Non-zero exits (like 1) can occur if the server immediately shuts down when stdin is empty, which still proves npx successfully ran the package."
fi

echo ""
echo "========================================="
echo "Diagnostics Summary:"
echo "If this script succeeds but VS Code still throws:"
echo "'Error spawn npx ENOENT'"
echo ""
echo "It means VS Code's LocalProcess extension host is running the MCP server"
echo "on your HOST OS, outside of this Dev Container."
echo ""
echo "Fixes:"
echo "1. Install Node.js on your physical host machine."
echo "2. Edit your HOST's Global VS Code settings.json to use the absolute path to npx on your host (e.g., /usr/local/bin/npx or npx.cmd on Windows)."
echo "========================================="
