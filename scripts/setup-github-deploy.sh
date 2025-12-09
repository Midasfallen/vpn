#!/bin/bash

set -e

echo "🚀 Setting up GitHub Actions Deployment..."

# 1. Generate SSH key
echo "1️⃣  Generating SSH key..."
SSH_KEY_PATH="$HOME/.ssh/github_deploy_key"
if [ -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key already exists at $SSH_KEY_PATH"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping SSH key generation"
        exit 0
    fi
fi

ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "github-actions"
echo "✅ SSH key generated: $SSH_KEY_PATH"

# 2. Show public key
echo ""
echo "2️⃣  Public key to add to server:"
echo "================================================"
cat "$SSH_KEY_PATH.pub"
echo "================================================"

echo ""
echo "3️⃣  Run this command on production server:"
echo "================================================"
echo "cat >> ~/.ssh/authorized_keys << 'EOF'"
cat "$SSH_KEY_PATH.pub"
echo "EOF"
echo "chmod 600 ~/.ssh/authorized_keys"
echo "================================================"

# 3. Copy private key to clipboard (macOS)
if [ "$(uname)" = "Darwin" ]; then
    cat "$SSH_KEY_PATH" | pbcopy
    echo ""
    echo "✅ Private key copied to clipboard (macOS)"
    echo "   Paste it in GitHub Secrets as PROD_SSH_KEY"
fi

# 4. Linux alternative
if [ "$(uname)" = "Linux" ]; then
    echo ""
    echo "📋 Private key content (copy to GitHub Secrets):"
    cat "$SSH_KEY_PATH"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Add public key to ~/.ssh/authorized_keys on production"
echo "2. Add PROD_SSH_KEY to GitHub Secrets"
echo "3. Add PROD_ENV_FILE to GitHub Secrets"
echo "4. Test: gh workflow run deploy.yaml"
