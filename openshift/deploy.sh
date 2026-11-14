#!/usr/bin/env bash
# Build the Flutter web app locally and deploy it to the current OpenShift project.
# Prereq: `oc login ...`, `oc project <name>`, flutter on PATH.
# Required env: SUPABASE_URL, SUPABASE_ANON_KEY
# Optional env: SUPABASE_STORAGE_URL, BACKEND_URL (defaults to the cricket-backend Route)
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SUPABASE_URL:?SUPABASE_URL is required}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required}"

if [ -z "${BACKEND_URL:-}" ]; then
  BACKEND_URL="https://$(oc get route cricket-backend -o jsonpath='{.spec.host}')"
fi
echo "==> Using BACKEND_URL=$BACKEND_URL"

flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=SUPABASE_STORAGE_URL="${SUPABASE_STORAGE_URL:-}" \
  --dart-define=BACKEND_URL="$BACKEND_URL"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp openshift/Dockerfile nginx.conf "$STAGE/"
cp -r build/web "$STAGE/web"

echo "==> Applying manifests"
oc apply -f openshift/frontend.yaml

echo "==> Building image"
oc start-build cricket-frontend --from-dir="$STAGE" --follow --wait
oc rollout status deployment/cricket-frontend --timeout=5m

echo "Frontend URL: https://$(oc get route cricket-frontend -o jsonpath='{.spec.host}')"
