#!/usr/bin/env bash
# Prove it works: unauthenticated requests redirect, and the app sees the identity headers.
set -euo pipefail
cd "$(dirname "$0")/.."
source .env

echo "==> ingress and ALB"
kubectl get ingress -o wide

echo -e "\n==> target health (empty or unhealthy usually means the 4180 security group rule)"
kubectl get endpoints my-app oauth2-proxy 2>/dev/null || true

echo -e "\n==> unauthenticated request: expect 302 to your IdP, not 200"
curl -sS -o /dev/null -w '  status: %{http_code}\n  redirect: %{redirect_url}\n' "https://${APP_HOST}/"

echo -e "\n==> after signing in through a browser, confirm which headers reach the app:"
echo "   Solution 1 sets X-Auth-Request-User / X-Auth-Request-Email"
echo "   Solution 2 sets x-amzn-oidc-identity / x-amzn-oidc-accesstoken / x-amzn-oidc-data"
echo "   echo-server prints every header it received, so the browser response shows you directly."
