# oauth2-proxy on ALB after NGINX Ingress

Two working patterns for keeping OIDC authentication after moving from the
retired NGINX Ingress Controller to the AWS Load Balancer Controller, plus the
app and proxy workloads the Ingress manifests expect.

Companion repo for the article. Deploy one pattern, verify it, tear it down.

| | Solution 1 | Solution 2 |
|---|---|---|
| Who authenticates | oauth2-proxy, in reverse-proxy mode | the ALB itself, native OIDC |
| Ingress backend | `oauth2-proxy:4180` | `my-app:8080` |
| Identity reaches the app as | `X-Auth-Request-*` | `x-amzn-oidc-*` |
| You keep | your existing oauth2-proxy config | one less component to run |

## Before you start

- An EKS cluster you can throw away, and `kubectl` pointed at it
- The AWS Load Balancer Controller installed (see the article's step 1)
- An ACM certificate for the hostname you'll use
- An OIDC application registered with your IdP. **Solution 2 requires the
  callback `https://<your-host>/oauth2/idpresponse` to be registered**, which is
  a fixed path you cannot change
- **Solution 1 only:** the cluster/node security group must allow TCP 4180 from
  the ALB security group. Without it the targets never pass health checks

Tested on: _fill this in after your run — EKS version, controller chart version,
oauth2-proxy image_

## Run it

```bash
cp .env.example .env     # fill in host, certificate, IdP details
./scripts/deploy.sh 1    # or: ./scripts/deploy.sh 2
./scripts/verify.sh
./scripts/cleanup.sh     # deletes the Ingress first, which removes the ALB
```

`my-app` is an echo server: it returns every request header as JSON, so a
browser request after sign-in shows you exactly which identity headers arrived.
That is the fastest way to see the difference between the two patterns.

## When it doesn't work

| Symptom | Cause |
|---|---|
| Targets unhealthy, requests time out | 4180 not allowed from the ALB security group (Solution 1) |
| Sign-in loops forever | Callback URL not registered with the IdP, or host mismatch |
| App gets no identity | Wrong header expected: see the table above |
| 200 instead of a redirect | Ingress still points at the app rather than oauth2-proxy (Solution 1) |

## Cost

An internal ALB runs about $16–20/month plus LCU charges, so tear it down when
you are finished. `cleanup.sh` removes the Ingress first, which is what actually
deletes the load balancer.
