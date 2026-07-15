# Configure AWS Systems Manager Session Manager to land as ubuntu (not ssm-user).
#
# SSM IGNORES /etc/passwd shell and often skips .bashrc — OS-only Ansible cannot
# force the logged-in user. This updates the regional document
# SSM-SessionManagerRunShell (Run As → ubuntu).
#
# Usage (WSL / laptop with AWS creds, region ap-south-1):
#   bash scripts/configure-ssm-run-as-ubuntu.sh
#   # then exit any open SSM session and start a NEW one

set -euo pipefail

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI not found in PATH. Run this from WSL where 'aws ssm start-session' works."
  exit 127
fi

REGION="${AWS_REGION:-ap-south-1}"
DOC_NAME="SSM-SessionManagerRunShell"
CONTENT_FILE="$(mktemp)"

cleanup() { rm -f "$CONTENT_FILE"; }
trap cleanup EXIT

cat > "$CONTENT_FILE" <<'EOF'
{
  "schemaVersion": "1.0",
  "description": "Scopify Session Manager preferences — sessions run as ubuntu",
  "sessionType": "Standard_Stream",
  "inputs": {
    "s3BucketName": "",
    "s3KeyPrefix": "",
    "s3EncryptionEnabled": true,
    "cloudWatchLogGroupName": "",
    "cloudWatchEncryptionEnabled": true,
    "cloudWatchStreamingEnabled": true,
    "idleSessionTimeout": "20",
    "maxSessionDuration": "",
    "kmsKeyId": "",
    "runAsEnabled": true,
    "runAsDefaultUser": "ubuntu",
    "shellProfile": {
      "windows": "",
      "linux": ""
    }
  }
}
EOF

echo "==> Region: $REGION"
echo "==> Ensuring Session Manager preferences use runAsDefaultUser=ubuntu"

if aws ssm describe-document --name "$DOC_NAME" --region "$REGION" >/dev/null 2>&1; then
  echo "==> Updating existing $DOC_NAME"
  OUT="$(aws ssm update-document \
    --name "$DOC_NAME" \
    --content "file://${CONTENT_FILE}" \
    --document-version '$LATEST' \
    --region "$REGION" \
    --output json)"
  NEW_VER="$(echo "$OUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['DocumentDescription']['DocumentVersion'])" 2>/dev/null \
    || echo "$OUT" | sed -n 's/.*"DocumentVersion"[ ]*:[ ]*"\([^"]*\)".*/\1/p' | head -1)"
  if [ -z "${NEW_VER:-}" ]; then
    echo "Updated; set default version manually if needed."
    echo "$OUT"
  else
    echo "==> Setting default version to $NEW_VER"
    aws ssm update-document-default-version \
      --name "$DOC_NAME" \
      --document-version "$NEW_VER" \
      --region "$REGION" >/dev/null
  fi
else
  echo "==> Creating $DOC_NAME"
  aws ssm create-document \
    --name "$DOC_NAME" \
    --content "file://${CONTENT_FILE}" \
    --document-type Session \
    --document-format JSON \
    --region "$REGION" >/dev/null
fi

echo ""
echo "Done. Exit any open SSM session, then:"
echo "  aws ssm start-session --target <instance-id> --region $REGION"
echo "  whoami   # expect: ubuntu"
echo ""
echo "One-shot override (works even before prefs):"
echo "  aws ssm start-session --target <instance-id> --region $REGION \\"
echo "    --document-name AWS-StartInteractiveCommand \\"
echo "    --parameters command=\"sudo -iu ubuntu\""
