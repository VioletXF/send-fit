#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
for document in \
  "$repo_root/docs/APP_STORE_PRIVACY_POLICY.md" \
  "$repo_root/docs/APP_STORE_SUPPORT.md" \
  "$repo_root/docs/APP_STORE_REVIEW_NOTES.md"; do
  [[ -s "$document" ]] || { print -u2 "missing $document"; exit 1; }
done

print "App Store policy, support, and review documents are present."
