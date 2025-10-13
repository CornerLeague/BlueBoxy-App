#!/bin/bash

echo "🧹 Cleaning Xcode build cache and fixing references..."

# 1. Clean all Xcode derived data
echo "Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/BlueBoxy-*

# 2. Clean local build artifacts
echo "Cleaning local build artifacts..."
cd /Users/newmac/Desktop/BlueBoxy
rm -rf build .build DerivedData

# 3. Ensure no .gitkeep files exist
echo "Ensuring no .gitkeep files exist..."
find . -name ".gitkeep" -type f -delete

# 4. Clear Xcode module cache
echo "Clearing Xcode module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 5. Reset Git index (in case files are tracked in git)
echo "Resetting Git index for deleted files..."
git rm --cached -r . 2>/dev/null || true
git add . 2>/dev/null || true

# 6. Try to clean specific problematic references
echo "Cleaning problematic file references..."

# Create a backup of the project file
cp BlueBoxy.xcodeproj/project.pbxproj BlueBoxy.xcodeproj/project.pbxproj.backup

# Remove any phantom .gitkeep references (though there shouldn't be any)
sed -i '' '/\.gitkeep/d' BlueBoxy.xcodeproj/project.pbxproj 2>/dev/null || true

echo "✅ Cleanup complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Product > Clean Build Folder (Cmd+Shift+K)"
echo "3. Try building again"
echo ""
echo "If issues persist, try:"
echo "- Closing Xcode completely"
echo "- Running this script again"  
echo "- Reopening the project"