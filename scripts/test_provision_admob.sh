#!/bin/zsh
set -euo pipefail

repo_root=${0:A:h:h}
set +e
output=$(ADMOB_OAUTH_CLIENT_ID= ruby "$repo_root/scripts/provision_admob.rb" provision 2>&1)
exit_status=$?
set -e

[[ $exit_status -eq 1 ]] || { print -u2 "expected exit status 1, got $exit_status"; exit 1; }
[[ $output == *"ADMOB_OAUTH_CLIENT_ID is required; add it to .env"* ]] || {
  print -u2 "expected missing-client-ID guard, got: $output"
  exit 1
}

script="$repo_root/scripts/provision_admob.rb"
! grep -Fq 'TCPServer.open("127.0.0.1", 0)' "$script" || {
  print -u2 "loopback listener must not reserve a port before WEBrick binds it"
  exit 1
}
grep -Fq 'Port: 0' "$script" || {
  print -u2 "loopback listener must let the operating system assign its port"
  exit 1
}

print "provisioning guard test passed"
