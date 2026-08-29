#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
env_file="${root_dir}/.env"
mode="${1:-testflight}"

if [[ ! -f "${env_file}" ]]; then
  print -u2 "missing .env; copy .env.example and fill the release values"
  exit 1
fi

required=(
  ADMOB_APP_ID
  ADMOB_BANNER_AD_UNIT_ID
  ADMOB_INTERSTITIAL_AD_UNIT_ID
  APPLE_DEVELOPMENT_TEAM
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_KEY_PATH
  MATCH_GIT_URL
  MATCH_PASSWORD
  MATCH_KEYCHAIN_PASSWORD
  FASTLANE_USER
)

if [[ "${mode}" == "firebase" ]]; then
  required+=(
    FIREBASE_IOS_APP_ID
    FIREBASE_SERVICE_CREDENTIALS_JSON
  )
fi

missing=0
for key in "${required[@]}"; do
  value="$(sed -n -E "s/^${key}=//p" "${env_file}" | tail -n 1)"
  if [[ -z "${value}" ]]; then
    print -u2 "missing ${key}"
    missing=1
  fi
done

if [[ "${missing}" -ne 0 ]]; then
  exit 1
fi

key_path="$(sed -n -E 's/^APP_STORE_CONNECT_KEY_PATH=//p' "${env_file}" | tail -n 1)"
if [[ ! -f "${key_path}" ]]; then
  print -u2 "APP_STORE_CONNECT_KEY_PATH does not point to a readable .p8 file"
  exit 1
fi

print "${mode} release configuration is complete"
