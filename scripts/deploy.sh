#!/usr/bin/env bash
# Deploy one of the two patterns. Usage: ./scripts/deploy.sh 1|2
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f .env ] || { echo "copy .env.example to .env and fill it in"; exit 1; }
source .env
solution="${1:?pick a solution: 1 (oauth2-proxy reverse proxy) or 2 (ALB native OIDC)}"

render() { sed -e "s|\${CERT_ARN}|$CERT_ARN|g" -e "s|\${APP_HOST}|$APP_HOST|g" -e "s|\${OIDC_ISSUER}|$OIDC_ISSUER|g" "$1"; }

echo "==> the app itself"
kubectl apply -f manifests/00-app.yaml

if [ "$solution" = "1" ]; then
  echo "==> oauth2-proxy (needs a cookie secret: 32 random bytes, base64)"
  kubectl create secret generic oauth2-proxy \
    --from-literal=issuer="$OIDC_ISSUER" \
    --from-literal=client-id="$OIDC_CLIENT_ID" \
    --from-literal=client-secret="$OIDC_CLIENT_SECRET" \
    --from-literal=cookie-secret="$(openssl rand -base64 32 | head -c 32 | base64)" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl apply -f manifests/10-oauth2-proxy.yaml
  kubectl rollout status deploy/oauth2-proxy --timeout=120s
  render manifests/20-ingress-solution-1.yaml | kubectl apply -f -
else
  echo "==> the secret the ALB reads for OIDC"
  kubectl create secret generic alb-oidc-secret \
    --from-literal=clientId="$OIDC_CLIENT_ID" \
    --from-literal=clientSecret="$OIDC_CLIENT_SECRET" \
    --dry-run=client -o yaml | kubectl apply -f -
  render manifests/30-ingress-solution-2.yaml | kubectl apply -f -
fi

kubectl rollout status deploy/my-app --timeout=120s
echo "==> waiting for the ALB (this takes a few minutes the first time)"
for _ in $(seq 1 60); do
  host=$(kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
  [ -n "${host:-}" ] && { echo "ALB: $host"; break; }
  sleep 10
done
echo "point $APP_HOST at that ALB, then run ./scripts/verify.sh"
