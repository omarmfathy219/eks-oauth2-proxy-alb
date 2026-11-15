#!/usr/bin/env bash
# Delete everything. The Ingress goes first: that is what removes the ALB.
set -euo pipefail
cd "$(dirname "$0")/.."
kubectl delete ingress my-app-alb my-app-alb-oidc --ignore-not-found
echo "waiting for the controller to delete the ALB..."
sleep 20
kubectl delete -f manifests/10-oauth2-proxy.yaml --ignore-not-found
kubectl delete -f manifests/00-app.yaml --ignore-not-found
kubectl delete secret oauth2-proxy alb-oidc-secret --ignore-not-found
echo "gone. check the console for stray load balancers before you walk away:"
echo "  aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'"
