# 09 — Amazon Cognito (Authentication & Authorization)

> Managed user sign-up, sign-in, and access control for web/mobile apps and APIs. Cognito is how your **HRMS login** works without you building (and securing) your own auth system — and it's a core **Developer Associate** topic.

**By the end you can:**
- Distinguish User Pools (authentication) from Identity Pools (authorization to AWS).
- Explain the JWT tokens Cognito issues and how to validate them.
- Protect an API Gateway / ALB with a Cognito authorizer.
- Add MFA, social/enterprise federation, groups, and Lambda triggers.

**Prerequisites:** [01 — Lambda](01-lambda-core-concepts.md), [02 — API Gateway](02-api-gateway.md), [Phase 02 — IAM & Security](../02-iam-security/README.md).

---

## 1. The two halves of Cognito

```
┌─────────────────────────────┐        ┌──────────────────────────────────┐
│        USER POOL            │        │          IDENTITY POOL           │
│   "Who are you?" (authN)    │        │  "What AWS can you touch?" (authZ)│
│                             │        │                                  │
│ • Sign-up / sign-in         │        │ • Exchanges a token for          │
│ • User directory            │        │   TEMPORARY AWS credentials      │
│ • Issues JWTs (ID/access)   │ ─────► │   (via STS) for an IAM role      │
│ • MFA, password policy      │        │ • Lets the app call S3, DynamoDB │
│ • Hosted UI, federation     │        │   directly with scoped creds     │
└─────────────────────────────┘        └──────────────────────────────────┘
```

| | **User Pool** | **Identity Pool (Federated Identities)** |
|---|---|---|
| Purpose | **Authentication** (verify identity) | **Authorization** to AWS resources |
| Output | JWT tokens (ID, access, refresh) | Temporary AWS credentials (STS) |
| Use it for | Login to your app/API | App calling AWS services directly |

💡 Most apps need a **User Pool** (login). You add an **Identity Pool** only when the client must call AWS services (e.g., upload straight to S3) with temporary credentials.

---

## 2. User Pool tokens (the JWTs)

After sign-in, Cognito returns three JWTs:

| Token | Contains | Use it to |
|---|---|---|
| **ID token** | User identity claims (email, name, `cognito:groups`) | Identify the user in your app/UI |
| **Access token** | Scopes/groups, `client_id` | Authorize API calls (send as `Authorization` header) |
| **Refresh token** | Long-lived opaque token | Get new ID/access tokens without re-login |

- ID/access tokens are **short-lived** (default 1h); refresh tokens last days–months (configurable).
- 🔒 **Validate JWTs** on the backend: check signature against the pool's JWKS, `iss` (issuer = your pool), `aud`/`client_id`, `exp`, and `token_use`.
- ⚠️ Never trust claims without verifying the signature — anyone can decode (but not forge) a JWT.

---

## 3. App clients & sign-in flows

- **App client** = an entry point (web SPA, mobile, server) with its own settings; public clients have **no secret**, confidential (server) clients can have one.
- **SRP (Secure Remote Password)** — passwords are never sent over the wire; the recommended flow.
- **Hosted UI** — Cognito's ready-made, customizable sign-in/sign-up pages (OAuth2 `/authorize`, `/token`). Fastest path; supports OAuth2 flows (Authorization Code + PKCE for SPAs).
- **OAuth2 grants:** Authorization Code (+ PKCE) for browser/mobile; Client Credentials for machine-to-machine.

```
SPA  ──/authorize──►  Hosted UI  ──login──►  redirect with code
SPA  ──/token (PKCE)──►  Cognito  ──►  ID + access + refresh tokens
SPA  ──Authorization: Bearer <access>──►  API Gateway (Cognito authorizer)
```

---

## 4. Protecting an API

**API Gateway — Cognito authorizer** (REST API):
```
Client → API Gateway → [Cognito User Pool authorizer validates the JWT] → Lambda
```
The authorizer checks the token signature/expiry automatically; your Lambda receives verified claims in the request context. (HTTP APIs use a **JWT authorizer** pointing at the pool's issuer URL.)

**ALB authentication:** an ALB listener rule can `authenticate-cognito` before forwarding — login enforced at the load balancer, no app code.

**Lambda authorizer:** for custom logic beyond a plain Cognito check (e.g., per-tenant rules), validate the Cognito JWT inside a Lambda authorizer.

---

## 5. MFA, security & password policy
- **MFA:** SMS or TOTP (authenticator app); set **required** or **optional**. TOTP is preferred (SMS is phishable/SIM-swappable).
- **Advanced security (threat protection):** detects compromised credentials and risky sign-ins (adaptive auth), can require MFA on risk.
- **Password policy:** length/complexity, and account recovery flows.
- **Account takeover / brute-force:** Cognito throttles and (with advanced security) blocks suspicious attempts.

---

## 6. Groups, RBAC & customization
- **Groups** map users to roles; the group appears in the token as `cognito:groups` and can map to an IAM role (with Identity Pools) → **RBAC**.
- **Custom attributes** extend the user profile (e.g., `custom:employeeId`, `custom:department`) — great for HRMS.
- **Lambda triggers** customize the lifecycle: `PreSignUp`, `PostConfirmation`, `PreTokenGeneration` (add custom claims), `PreAuthentication`, `CustomMessage`, `Migrate User` (import from a legacy DB on first login).

---

## 7. Federation (social & enterprise)
- **Social IdPs:** Google, Facebook, Apple, Amazon.
- **Enterprise:** SAML 2.0 and OIDC (e.g., corporate Okta/Azure AD) → users sign in with existing company credentials.
- Cognito normalizes all of these into the same User Pool tokens, so your app handles one token format regardless of how the user logged in.

---

## 8. HRMS example

```
Employees ─► React SPA (Hosted UI / Authorization Code + PKCE)
                 │  gets ID + access tokens
                 ▼
        API Gateway (HTTP API, JWT authorizer → HRMS user pool)
                 │  verified claims: sub, email, cognito:groups=[hr-admin]
                 ▼
        Lambda (checks group for /payroll write) ─► DynamoDB / RDS
```
- HR admins are in the `hr-admin` group → only they hit payroll write routes (checked from the token claim).
- A `PreTokenGeneration` trigger injects `custom:employeeId` so the backend doesn't need an extra lookup.
- MFA (TOTP) required for the `hr-admin` group via advanced security.

🔒 The app **never stores passwords** — Cognito does, with hashing, MFA, lockout, and breach detection you'd otherwise have to build and audit.

---

## 9. Limits & quotas (exam-relevant)
| Item | Note |
|---|---|
| Users per pool | Effectively unlimited (millions) |
| ID/Access token validity | 5 min – 24 h (default 1 h) |
| Refresh token validity | 1 h – 10 years (default 30 days) |
| App clients per pool | 1,000 (default) |
| MFA | SMS, TOTP |
| Pricing | Per Monthly Active User (MAU); generous free tier |

---

## 10. Best practices ⚠️
- Validate JWT signature + `iss`/`aud`/`exp`/`token_use` on every request — don't just decode.
- Use **Authorization Code + PKCE** for SPAs/mobile; avoid the deprecated implicit flow.
- Prefer **TOTP MFA** over SMS; turn on **advanced security** for sensitive apps.
- Keep access tokens short-lived; use refresh tokens to renew.
- Store tokens securely on the client (avoid localStorage for high-value apps; prefer in-memory/secure cookies).
- Use **groups → IAM roles** for least-privilege when the client calls AWS directly.

---

## 11. Quick reference
```
User Pool      → authentication (login) → ID/Access/Refresh JWTs
Identity Pool  → authorization to AWS → temporary STS credentials + IAM role
Hosted UI      → ready-made OAuth2 sign-in pages
Authorizer     → API Gateway (Cognito/JWT) or ALB authenticate-cognito
Groups         → cognito:groups claim → RBAC / IAM role mapping
Triggers       → PreSignUp / PostConfirmation / PreTokenGeneration / MigrateUser
Federation     → Google/Apple/SAML/OIDC → unified pool tokens
MFA            → TOTP (preferred) / SMS; + advanced security (adaptive)
```

**Official docs:** https://docs.aws.amazon.com/cognito/ · Verifying JWTs: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-tokens-verifying-a-jwt.html

---

*Next: [10 — Interview Questions](10-interview-questions.md). Back to [Serverless README](README.md). Related: [Phase 02 — IAM & Security](../02-iam-security/README.md).*
