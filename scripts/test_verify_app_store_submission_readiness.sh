#!/usr/bin/env bash
set -euo pipefail

for entitlements_path in SendFit/SendFit.entitlements ShareExtension/ShareExtension.entitlements; do
  application_group="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$entitlements_path" 2>/dev/null || true)"
  if [[ "$application_group" != "group.com.sendfit.app" ]]; then
    echo "Missing SendFit App Group entitlement in $entitlements_path." >&2
    exit 1
  fi
done

output=""
status=0
output="$(asdf exec bundle exec ruby scripts/verify_app_store_submission_readiness.rb 2>&1)" || status=$?

printf '%s\n' "$output"

if [[ "$output" == *"NoMethodError"* ]]; then
  echo "Readiness verifier raised an unexpected Ruby API error." >&2
  exit 1
fi

case "$status" in
  0)
    [[ "$output" == *"App Store submission readiness is complete."* ]]
    ;;
  1)
    [[ "$output" == *"App Store submission is not ready; complete:"* ]]
    ;;
  *)
    echo "Readiness verifier exited unexpectedly with status $status." >&2
    exit 1
    ;;
esac
