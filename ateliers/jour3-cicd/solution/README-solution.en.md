# Solution — Day 3: CI/CD pipeline

_English version · la version française est dans [`README-solution.md`](README-solution.md)_

Files to copy to the root of the `formini-tasks` repository:

```
.gitea/
├── workflows/
│   ├── ci.yml          # test → build (scan + publication) on every push / PR
│   └── release.yml     # publication of a version on a v* tag
└── pull_request_template.md
```

In both workflows, adapt the `IMAGE` variable to the name of your organisation.

## Secrets to create

The workflows read two secrets. Without them, the "Connexion au registre" (registry
login) step fails with `unauthorized`.

### 1. Gitea access token

Avatar → **Settings** → **Applications** → *Manage access tokens* → *Generate token*:

| Field | Value |
|-------|-------|
| Token name | `ci-registry` |
| Permissions | **package**: *Read and Write* (everything else: *No access*) |

Copy the token immediately: Gitea only displays it once.

> The token has the rights of the user who creates it. To publish to the packages
> of the `equipe-a` organisation, that user must be a member of the organisation
> with write access to packages (*Owners* team, or a team with the
> *Packages* unit in write mode).

### 2. Repository (or organisation) secrets

Repository → **Settings** → **Actions** → **Secrets**:

| Name | Value |
|------|-------|
| `REGISTRY_USER` | the Gitea user name (the login, not the e-mail) |
| `REGISTRY_TOKEN` | the token created above |

Declared at organisation level (Organisation → Settings → Actions → Secrets),
they are available in all the team's repositories.

## Checks on the VM that hosts the runner

```bash
sudo systemctl status act_runner          # active?
node --version                            # required by actions/checkout
docker info | grep -A1 'Insecure Registries'   # must list gitea.formini.local:3000
trivy --version
echo "<TOKEN>" | docker login gitea.formini.local:3000 -u <login> --password-stdin && docker logout gitea.formini.local:3000
```

## Branch protection

Repository → **Settings** → **Branches** → `main` rule:

- *Enable push*: unticked
- *Enable status check*: ticked, pattern `CI / test*`
  (the context published by Gitea Actions is `CI / test (pull_request)`)
- *Required approvals*: 1

## Why a single `build` job?

In host mode, each job is handed to **one free runner among the team's runners**.
If `scan` and `publish` were separate jobs, they could be executed by
a different VM from the one that built the image, and `trivy image` or `docker push`
would fail with *image not found*. A single job guarantees that all the steps
share the same Docker daemon. With a single runner, or an intermediate registry
(pushing the image before the scan), splitting into three jobs becomes possible again.
