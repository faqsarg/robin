# Robin — DevOps Technical Challenge

A minimal full-stack app (frontend → API → database), containerized and deployed to AWS with
Terraform and a GitHub Actions CI/CD pipeline.

## Live URLs

> _Filled in once deployed to AWS._

- Frontend: TBD
- Backend: TBD

## Architecture

> _Diagram added once the AWS infrastructure is in place._

## Stack

| Layer    | Choice                          | Why |
|----------|----------------------------------|-----|
| Frontend | Static HTML + vanilla JS, served by nginx | The app itself isn't what's being evaluated — kept it dependency-free, no build step |
| Backend  | Go                                | Compiles to a static binary, tiny final image, no runtime needed |
| Database | PostgreSQL                        | Simple, well-known, free-tier eligible on RDS |
| Local DB | `postgres:16-alpine` container (docker-compose only) | Lets the whole stack run locally without touching AWS. In the cloud this is replaced by a managed RDS instance — same backend code, only the connection env vars change |

## Running locally

```bash
cp .env.example .env
docker compose up -d --build
```

- Frontend: http://localhost:3000
- Backend (direct): http://localhost:8080

## Decisions and why

> _This section grows as each part of the project is built — see the PRs for the reasoning
> behind each one in context._

### Backend
- Go, compiled to a static binary (`CGO_ENABLED=0`) in a multi-stage Dockerfile, final image is
  `gcr.io/distroless/static-debian12:nonroot` — no shell, no package manager, runs as a non-root
  user by default. Final image is ~12MB.
- Three endpoints: `/health` (liveness), `/version` (returns the git SHA injected at build time
  via `-ldflags`, used later to visually confirm the CI/CD pipeline actually deployed a new
  version), `/api/quote` (reads a random row from Postgres — a real DB round-trip, not a mock).
- DB credentials are read entirely from environment variables, nothing hardcoded. Locally they
  come from `.env` (gitignored); in AWS they'll come from Secrets Manager via the ECS task
  definition.
- Seeding is idempotent (only inserts if the table is empty), so restarting the container never
  duplicates rows.
- Graceful shutdown on SIGTERM — ECS sends SIGTERM on deploys/scale-in and expects the container
  to exit cleanly within the stop timeout.

### Frontend
- No framework, no build step: a single `index.html` with vanilla JS. The app's complexity isn't
  what's being evaluated, so this keeps the Dockerfile trivial and the image small (~48MB, mostly
  the nginx base).
- Served by `nginxinc/nginx-unprivileged` instead of the default `nginx` image — runs as a
  non-root user on port 8080 out of the box.
- nginx proxies `/api/*` and `/version` to the backend container via a templated config
  (`envsubst`). This proxy only matters locally: docker-compose has no load balancer, so the
  browser can only reach nginx. In AWS, the ALB routes those same paths directly to the backend
  target group, bypassing the frontend container entirely — same paths, same code, no changes
  needed between environments.

### Infrastructure
- TBD (next step)

### CI/CD
- TBD

## What I'd improve with more time

> _Filled in at the end._

## Use of AI tools

Used Claude (Claude Code) as a pair-programmer throughout, in an interactive back-and-forth
rather than "generate everything and accept it" — this section is updated as the project
progresses.

**What it was used for so far:**
- Generating first drafts of the Go API, Dockerfiles, nginx config, and `docker-compose.yml`
  from a description of what each piece needed to do.
- Design discussion before writing infra code: e.g., whether to put an ALB in front of ECS
  Fargate at all (tradeoff: stable URL across redeploys vs. cost) and how to avoid a NAT Gateway
  (not free-tier) while still keeping the RDS instance unreachable from the public internet.

**A concrete decisive prompt:** 

**What I did with what it gave me:** 

**Decisions made explicitly without relying on AI's first suggestion:** the initial stack
proposal was Node.js/Express + React on GCP. I overrode both — chose Go for the backend (smaller
image, no runtime, and it's what I wanted to demonstrate) and a build-free vanilla JS frontend
instead of React, and picked AWS/ECS Fargate over GCP/Cloud Run since it's the stack I am more 
comfortable with.

**Where AI got something wrong or didn't help:** _to be filled in with a real example as the
Terraform/CI-CD work progresses — not fabricating one here._

## Cleanup

Once evaluated, all AWS infrastructure was destroyed with `terraform destroy`. If a live URL was
shared as evidence, it was taken down after the review.
