#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "Eterlotto ML - migracion local a DEV/PRD"

if [[ -f .env && ! -f .env.dev ]]; then
  mv .env .env.dev
  echo "OK: .env -> .env.dev"
elif [[ -f .env && -f .env.dev ]]; then
  echo "AVISO: existen .env y .env.dev; no se sobrescribio ninguno."
fi

if [[ ! -f .env.dev ]]; then
  cp .env.dev.example .env.dev
  echo "AVISO: se creo .env.dev desde la plantilla. Completa credenciales DEV."
fi

add_env_if_missing() {
  local name="$1" value="$2"
  if ! grep -qE "^${name}=" .env.dev; then
    printf '\n%s=%s\n' "$name" "$value" >> .env.dev
  fi
}

add_env_if_missing APP_ENV dev
add_env_if_missing SMTP_ENABLED true
add_env_if_missing SMTP_HOST smtp.gmail.com
add_env_if_missing SMTP_PORT 587
add_env_if_missing SMTP_STARTTLS true
add_env_if_missing SMTP_USER ''
add_env_if_missing SMTP_PASSWORD ''
add_env_if_missing SMTP_FROM ''
add_env_if_missing SMTP_TO ''
add_env_if_missing FIREBASE_CREDENTIALS_FILE '.secrets/firebase_credentials.json'

mkdir -p .secrets
if [[ -f config/firebase_credentials.json && ! -f .secrets/firebase_credentials.json ]]; then
  mv config/firebase_credentials.json .secrets/firebase_credentials.json
  echo "OK: Firebase movido a .secrets/firebase_credentials.json"
elif [[ -f config/firebase_credentials.json && -f .secrets/firebase_credentials.json ]]; then
  echo "AVISO: hay dos credenciales Firebase; revisalas antes de borrar una."
fi

echo "Migracion DEV completada. Revisa DEV_PRD.md."
