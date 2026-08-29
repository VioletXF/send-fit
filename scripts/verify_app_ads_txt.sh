#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
env_file="${root_dir}/.env"
app_ads_file="${root_dir}/docs/app-ads.txt"

if [[ ! -f "${env_file}" ]]; then
  print -u2 "missing .env"
  exit 1
fi

app_id="$(sed -n -E 's/^ADMOB_APP_ID=//p' "${env_file}" | tail -n 1)"
publisher_id="${app_id#ca-app-}"
publisher_id="${publisher_id%%~*}"
expected="google.com, ${publisher_id}, DIRECT, f08c47fec0942fa0"

if [[ "${app_id}" != ca-app-pub-*~* || ! -f "${app_ads_file}" || "$(<"${app_ads_file}")" != "${expected}" ]]; then
  print -u2 "app-ads.txt does not match the configured AdMob publisher"
  exit 1
fi

print "app-ads.txt matches the configured AdMob publisher"
