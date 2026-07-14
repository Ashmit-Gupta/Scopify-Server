#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin" "$HOME/.local/aws-cli" /tmp/aws-install
cd /tmp/aws-install

echo "==> Downloading AWS CLI v2..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip

echo "==> Extracting..."
rm -rf aws
if command -v unzip >/dev/null 2>&1; then
  unzip -qo awscliv2.zip
else
  python3 -c 'import zipfile,shutil; shutil.rmtree("aws", ignore_errors=True); zipfile.ZipFile("awscliv2.zip").extractall(".")'
fi

echo "==> Installing AWS CLI to ~/.local (no sudo)..."
./aws/install -i "$HOME/.local/aws-cli" -b "$HOME/.local/bin" --update

if ! grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"
aws --version

echo "==> Downloading Session Manager plugin..."
curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o session-manager-plugin.deb

echo "==> Extracting plugin (no sudo)..."
rm -rf smp-extract
mkdir -p smp-extract
cd smp-extract
ar x ../session-manager-plugin.deb
tar xf data.tar.gz
PLUGIN_BIN="$(find . -type f -name session-manager-plugin | head -1)"
echo "Found: $PLUGIN_BIN"
cp "$PLUGIN_BIN" "$HOME/.local/bin/session-manager-plugin"
chmod +x "$HOME/.local/bin/session-manager-plugin"

session-manager-plugin --version
echo
echo "OK. Binaries:"
which aws
which session-manager-plugin
echo
echo "Run: source ~/.bashrc"
echo "Then: aws --version && session-manager-plugin --version"
