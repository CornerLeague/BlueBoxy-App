#!/bin/bash

echo "🔐 Setting up development API keys securely..."
echo ""
echo "⚠️  IMPORTANT: Never commit API keys to version control!"
echo "This script stores your keys in the macOS Keychain for secure access."
echo ""

# Function to store key in keychain
store_key() {
    local service="$1"
    local account="$2"
    local key="$3"
    
    if [ -n "$key" ]; then
        security add-generic-password -s "$service" -a "$account" -w "$key" -U 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✅ Stored $account key"
        else
            echo "ℹ️  Updated existing $account key"
            security delete-generic-password -s "$service" -a "$account" 2>/dev/null
            security add-generic-password -s "$service" -a "$account" -w "$key" -U
        fi
    else
        echo "❌ No key provided for $account"
    fi
}

# Prompt for API keys (more secure than passing as arguments)
echo "Please enter your API keys (they will not be displayed):"
echo ""

echo -n "OpenAI API Key: "
read -s OPENAI_KEY
echo ""

echo -n "XAI API Key: "
read -s XAI_KEY
echo ""

echo -n "Session Secret: "
read -s SESSION_SECRET
echo ""

# Store in keychain
store_key "BlueBoxy" "openai_api_key" "$OPENAI_KEY"
store_key "BlueBoxy" "xai_api_key" "$XAI_KEY"
store_key "BlueBoxy" "session_secret" "$SESSION_SECRET"

echo ""
echo "✅ API keys stored securely in Keychain!"
echo ""
echo "Your app will now read these keys from the Keychain instead of"
echo "storing them in plain text files."
echo ""
echo "To remove these keys later, run:"
echo "  security delete-generic-password -s BlueBoxy -a openai_api_key"
echo "  security delete-generic-password -s BlueBoxy -a xai_api_key"
echo "  security delete-generic-password -s BlueBoxy -a session_secret"