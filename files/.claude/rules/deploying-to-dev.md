# Deploying to Dev

Any time I'm about to deploy to a `dev` environment — or change its config or infrastructure — remind me to post in `#deployment-dev` and offer to draft it. The channel is `deployment-dev`, singular, id `C09FRHW41DG`.

Post *before* the deploy, not after. The channel is how everyone else knows why dev just changed under them.

Draft it and show it to me. Never send without an explicit yes from me.

## Format

One line, present tense, backticks around service and environment names, Linear ID bare so the Linear bot picks it up and threads:

```
Deploying `transactions/orchestrator-charge` to `dev` for PLAT-1086
Deploying `admin/orchestrator-payment-credentials-upsert` to `dev` for PLAT-1093 (<PR url>)
Deploying `insights-api` to `dev` from latest `development` branch
```

Variants that come up:

- **Several services at once** — one line of intro, then a bulleted list of backticked names.
- **Multi-step change** (secrets, IAM, then code) — numbered steps in the parent message, then reply in thread as each lands.
- **Not a code deploy** — post it anyway: env var changes, Flyway migrations, RDS changes, org flags flipped for testing. Say what and why.
- **Downtime or anything disruptive** — `@here` and name the blast radius. Only then.

## Afterwards

Reply in the thread when it's done — "Deployment complete, verified X" — or if it failed or got rolled back. An unanswered deploy message reads as still in flight.
