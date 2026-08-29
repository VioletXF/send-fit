#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
icon="$repo_root/SendFit/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
[[ -f "$icon" ]] || { print -u2 "missing $icon"; exit 1; }
dimensions=$(sips -g pixelWidth -g pixelHeight "$icon")
[[ "$dimensions" == *"pixelWidth: 1024"* && "$dimensions" == *"pixelHeight: 1024"* ]] || {
  print -u2 "AppIcon-1024.png must be 1024 by 1024 pixels"
  exit 1
}
print "App icon is a 1024 by 1024 PNG."
