# Flutter Installation Guide

## Install Flutter on macOS

### Option 1: Using Homebrew (Recommended)
```bash
# Install Flutter
brew install --cask flutter

# Verify installation
flutter doctor
```

### Option 2: Manual Installation
1. Download Flutter SDK from https://docs.flutter.dev/get-started/install/macos
2. Extract the file to desired location (e.g., ~/development)
3. Add Flutter to PATH:
   ```bash
   export PATH="$PATH:`pwd`/flutter/bin"
   ```
4. Add to your shell profile (~/.zshrc or ~/.bash_profile):
   ```bash
   export PATH="$PATH:$HOME/development/flutter/bin"
   ```

### Post-Installation Steps
```bash
# Check for any missing dependencies
flutter doctor

# Accept Android licenses (if developing for Android)
flutter doctor --android-licenses

# Install Xcode (for iOS development)
# Download from Mac App Store

# Install CocoaPods (for iOS dependencies)
sudo gem install cocoapods
```

## After Installing Flutter

Return to this project directory and run:
```bash
cd /Users/derek/Workspace/NAWGJApp
flutter pub get
```

Then you're ready to start development!
