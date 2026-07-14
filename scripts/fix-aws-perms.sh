#!/usr/bin/env bash
set -eu
chmod -R u+x /home/ashmit/.local/aws-cli
chmod +x /home/ashmit/.local/bin/session-manager-plugin
if ! grep -q '.local/bin' /home/ashmit/.bashrc 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/ashmit/.bashrc
fi
export PATH="$HOME/.local/bin:$PATH"
echo "=== versions ==="
aws --version
session-manager-plugin --version
echo "=== paths ==="
which aws
which session-manager-plugin
