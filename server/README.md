# notes-api (Cloudflare Worker + Turso)

Hono API running on Cloudflare Workers, backed by Turso (libSQL) through Drizzle.
Deployed with the `cf` CLI. Needs Node 22.18+ (`cf` cannot load its config under Bun).

```sh
npm run dev        # cf dev, reads secrets from .dev.vars
npm run typecheck
npm run deploy     # cf deploy
npm run db:generate && npm run db:migrate   # schema changes (needs TURSO_* env vars)
```

Secrets (`.dev.vars` locally, `cf workers secrets update` once deployed):
`TURSO_DATABASE_URL`, `TURSO_AUTH_TOKEN`, `JWT_SECRET`.

First deploy of a new Worker: `cf deploy --secrets-file <file>` with `NAME=value` lines.
