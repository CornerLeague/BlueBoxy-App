#!/bin/bash

# Simple Swift validation script to check for basic compilation issues
# This is a workaround since full Xcode is not available

echo "🔍 Validating Swift files for basic syntax errors..."

SWIFT_FILES_DIR="/Users/newmac/Desktop/BlueBoxy/BlueBoxy"
ERRORS_FOUND=0

# Function to check if a Swift file has basic syntax issues
check_swift_file() {
    local file="$1"
    echo "Checking: $(basename "$file")"
    
    # Check for basic syntax issues using swiftc
    if command -v swiftc >/dev/null 2>&1; then
        # Try to parse the Swift file
        if ! swiftc -parse "$file" 2>/dev/null; then
            echo "⚠️ Syntax issues found in: $(basename "$file")"
            ERRORS_FOUND=$((ERRORS_FOUND + 1))
        fi
    else
        # Basic checks without swiftc
        # Check for unbalanced braces
        local open_braces=$(grep -o '{' "$file" | wc -l)
        local close_braces=$(grep -o '}' "$file" | wc -l)
        
        if [ "$open_braces" -ne "$close_braces" ]; then
            echo "⚠️ Unbalanced braces in: $(basename "$file") (Open: $open_braces, Close: $close_braces)"
            ERRORS_FOUND=$((ERRORS_FOUND + 1))
        fi
        
        # Check for unbalanced parentheses
        local open_parens=$(grep -o '(' "$file" | wc -l)
        local close_parens=$(grep -o ')' "$file" | wc -l)
        
        if [ "$open_parens" -ne "$close_parens" ]; then
            echo "⚠️ Unbalanced parentheses in: $(basename "$file") (Open: $open_parens, Close: $close_parens)"
            ERRORS_FOUND=$((ERRORS_FOUND + 1))
        fi
        
        # Check for basic import and struct/class syntax
        if ! grep -q "import SwiftUI\|import Foundation\|import UIKit" "$file"; then
            if grep -q "struct\|class\|enum" "$file"; then
                echo "⚠️ Missing import statement in: $(basename "$file")"
                ERRORS_FOUND=$((ERRORS_FOUND + 1))
            fi
        fi
    fi
}

# Find and check all Swift files
find "$SWIFT_FILES_DIR" -name "*.swift" -type f | while read -r file; do
    check_swift_file "$file"
done

echo "✅ Swift validation complete!"

if [ $ERRORS_FOUND -eq 0 ]; then
    echo "🎉 No obvious syntax errors found!"
    exit 0
else
    echo "❌ Found $ERRORS_FOUND potential issues"
    exit 1
fi