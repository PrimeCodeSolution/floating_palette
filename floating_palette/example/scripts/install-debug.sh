#!/bin/bash
# Build debug, kill running instance, replace /Applications/example.app, and launch.
set -e

cd "$(dirname "$0")/.."

echo "==> Killing running example app..."
pkill -x example 2>/dev/null || true
sleep 1

echo "==> Building macOS debug..."
flutter build macos --debug

echo "==> Installing to /Applications..."
rm -rf /Applications/example.app
cp -R build/macos/Build/Products/Debug/example.app /Applications/example.app

echo "==> Launching..."
open /Applications/example.app

echo "==> Done. Use Console.app to view logs (filter: 'example')."
