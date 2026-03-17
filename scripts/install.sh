#!/usr/bin/env bash
# Set up the Bible study tool:
#   - Creates .venv
#   - Installs Python dependencies
#   - Symlinks scripts/bs to ~/bin/bs for easy access

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "==> Creating virtual environment..."
python3 -m venv "$PROJECT_DIR/.venv"

echo "==> Installing dependencies..."
"$PROJECT_DIR/.venv/bin/pip" install --quiet --upgrade pip
"$PROJECT_DIR/.venv/bin/pip" install --quiet -r "$PROJECT_DIR/requirements.txt"

echo "==> Making scripts executable..."
chmod +x "$SCRIPT_DIR/bs"

# Prefer ~/.local/bin if it's already on PATH, fall back to ~/bin
if [[ ":$PATH:" == *":$HOME/.local/bin:"* ]]; then
  BIN_DIR="$HOME/.local/bin"
else
  BIN_DIR="$HOME/bin"
fi

if [[ ! -d "$BIN_DIR" ]]; then
  mkdir -p "$BIN_DIR"
  echo "==> Created $BIN_DIR"
fi

LINK="$BIN_DIR/bs"
if [[ -L "$LINK" || -f "$LINK" ]]; then
  rm "$LINK"
fi
ln -s "$SCRIPT_DIR/bs" "$LINK"
echo "==> Linked: bs -> $LINK"

# Check if ~/bin is on PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  echo "NOTE: Add $BIN_DIR to your PATH if not already set."
  echo "  Add this to ~/.zshrc:"
  echo '  export PATH="$HOME/bin:$PATH"'
fi

echo ""
echo "==> Setup complete!"
echo ""
echo "Create a .env file in $PROJECT_DIR with:"
echo "  ESV_API_KEY=your_key_here"
echo "  BIBLE_LLM_PROVIDER=mlx"
echo "  MLX_MODEL_PATH=mlx-community/Mistral-7B-Instruct-v0.3-4bit"
echo ""
echo "Then run: bs \"John 3:16\""
