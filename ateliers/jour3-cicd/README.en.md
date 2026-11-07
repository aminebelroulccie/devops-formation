# Day 3 Lab — CI/CD Pipelines with Gitea Actions

_English version · la version française est dans [`README.md`](README.md)_

**Tuesday 10 November 2026 · Formini DevOps Training**

By the end of this lab, every commit pushed to your `formini-tasks` repository
automatically triggers the lint, the tests, the Docker image build, its security
scan and its publication to the Gitea registry.

---

## Objectives

- Write a Gitea Actions workflow and read it in the web interface.
- Make a pull request fail when the tests break.
- Build, scan and publish an image without typing a single command by hand.
- Protect `main` so that nothing gets merged without a green pipeline.
- Deliver a numbered version with a Git tag.

## Prerequisites

| Item | How to check |
|------|--------------|
| `formini-tasks` repository in your team's organisation on Gitea, with the Day 2 `Dockerfile` | `git clone http://gitea.formini.local:3000/equipe-a/formini-tasks.git` then `docker build -t test .` |
| `act_runner` runner registered on your VM (see `setup/act-runner/`) | `sudo systemctl status act_runner` → *active (running)* |
| Docker allowed to talk to the Gitea registry over HTTP | `cat /etc/docker/daemon.json` contains `"insecure-registries": ["gitea.formini.local:3000"]` |
| trivy installed | `trivy --version` |
| Node.js 20 installed (required by `actions/checkout`) | `node --version` |

Conventions used in this sheet:

- Gitea: `http://gitea.formini.local:3000`
- Organisation: `equipe-a` (replace with yours)
- Image: `gitea.formini.local:3000/equipe-a/formini-tasks`
- User on the VM: `devops`

---

## Part 1 — Guided lab (10:45 – 12:00): test every commit

### 1.1 Enable Actions on the repository

1. Open the repository in Gitea → **Settings** → **Repository**.
2. In the *Repository units* section, tick **Actions**, then **Update settings**.
3. An **Actions** tab appears in the repository bar. It is empty for now.

### 1.2 Check that your runner is online

1. **Settings** → **Actions** → **Runners**.
2. Your VM must appear with a green dot and the `ubuntu-latest` label.
3. If it is missing or grey:

```bash
sudo systemctl restart act_runner
journalctl -u act_runner -n 30 --no-pager
```

> An offline runner does not produce an error: the jobs simply stay
> "waiting" forever. It is the first thing to check.

### 1.3 Write the workflow

On your VM, in the clone of the repository:

```bash
cd ~/formini-tasks
git switch -c ci/pipeline-test
mkdir -p .gitea/workflows
```

Create `.gitea/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependencies
        run: |
          python3 -m venv .venv
          .venv/bin/pip install -q -r requirements-dev.txt

      - name: Lint
        run: .venv/bin/flake8 .

      - name: Tests
        run: .venv/bin/pytest -q
```

Read the file before pushing it, and answer the four questions out loud:
**when** (`on`), **what** (`jobs`), **where** (`runs-on`), **how** (`steps`).

> **YAML indentation:** two spaces, never tabs. An indentation error
> prevents Gitea from reading the file: no run appears, and there is no error message.

### 1.4 Push and watch

```bash
git add .gitea/workflows/ci.yml
git commit -m "ci: add the test pipeline"
git push -u origin ci/pipeline-test
```

1. Open a pull request towards `main` in Gitea.
2. In the PR, a status line appears: **CI / test (pull_request)** with a
   yellow dot (running), then a green tick.
3. **Actions** tab → click the run → click the `test` job → expand
   each step and read its output.

Questions to ask yourself:

- How long did the run take? (target: under two minutes)
- Which step was the longest? Why?

### 1.5 Break a test, on purpose

In `tests/test_api.py`, change an assertion so that it is wrong, for example:

```python
def test_liste_vide(client):
    r = client.get("/api/tasks")
    assert r.status_code == 418   # deliberately wrong
```

```bash
git commit -am "test: deliberately break a test"
git push
```

1. Go back to the PR: the status turns red.
2. Open the run, find the failing step, read **the last line** of the log.
3. Fix the test, commit, push. The status goes back to green.
4. Merge the PR. A new run is triggered on `main` (`push` event).

### Part 1 success criteria

- [ ] A green run on the pull request, then on `main` after the merge.
- [ ] You have seen a red run and were able to say which step and which line caused it.
- [ ] Under two minutes per run.

**Part 1 bonus:** publish the test report as an artifact.

```yaml
      - name: Tests
        run: .venv/bin/pytest -q --junitxml=report.xml

      - name: Test report
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: rapport-tests
          path: report.xml
```

The file becomes downloadable from the run page. `if: always()` publishes it
even when the tests fail, which is precisely when you need it.

---

## Part 2 — Self-paced challenge (14:00 – 15:30): build, scan, publish

In teams. Goal: every push to `main` produces an image that is scanned and published
to the Gitea registry, and a broken pull request cannot be merged.

### 2.1 Create the secrets

1. **Access token**: avatar → **Settings** → **Applications** → *Manage access tokens*.
   Name: `ci-registry`. Permissions: **package → Read and Write**. Copy the token:
   it will never be shown again.
2. **Repository secrets**: repository → **Settings** → **Actions** → **Secrets** → *Add secret*:
   - `REGISTRY_USER`: your Gitea user name
   - `REGISTRY_TOKEN`: the token copied in step 1

> An **organisation** secret (Organisation → Settings → Actions → Secrets) is
> shared by all the team's repositories. Handy when several projects publish
> to the same registry.

Check the token by hand before using it in the pipeline:

```bash
echo "<TOKEN>" | docker login gitea.formini.local:3000 -u <user> --password-stdin
docker logout gitea.formini.local:3000
```

### 2.2 Add the `build` job

Complete `ci.yml` with a second job, which waits for `test` to be green and only runs
on a push to `main` (not on pull requests):

```yaml
env:
  REGISTRY: gitea.formini.local:3000
  IMAGE: gitea.formini.local:3000/equipe-a/formini-tasks

jobs:
  test:
    # ... unchanged ...

  build:
    runs-on: ubuntu-latest
    needs: test
    if: gitea.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Tag = short commit SHA
        run: echo "TAG=$(echo '${{ gitea.sha }}' | cut -c1-7)" >> "$GITHUB_ENV"

      - name: Build the image
        run: docker build -t "$IMAGE:$TAG" .

      - name: Security scan (blocking on CRITICAL)
        run: trivy image --severity CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE:$TAG"

      - name: Log in to the registry
        run: echo "${{ secrets.REGISTRY_TOKEN }}" | docker login "$REGISTRY" -u "${{ secrets.REGISTRY_USER }}" --password-stdin

      - name: Publish
        run: |
          docker push "$IMAGE:$TAG"
          docker tag "$IMAGE:$TAG" "$IMAGE:latest"
          docker push "$IMAGE:latest"

      - name: Log out
        if: always()
        run: docker logout "$REGISTRY"
```

Points to understand:

- `needs: test`: if the tests fail, `build` is not even started.
- `if: gitea.event_name == 'push'`: we do not publish PR drafts.
- `$GITHUB_ENV`: one step writes a variable, the following steps read it.
- `--password-stdin`: the token goes neither through the command line nor through the logs.
- **Why are the scan and the publication steps of the same job, rather than separate jobs?**
  In *host* mode, each job can be picked up by any free runner in the team,
  hence by another VM, which does not have the image locally. Within a single job,
  all the steps run on the same machine and share the same Docker daemon.

Push through a pull request (the pipeline re-reads its own file), merge, then
check:

1. **Actions** tab: the run on `main` has two jobs, `test` then `build`.
2. Organisation → **Packages**: the `formini-tasks` image appears with two tags,
   `<sha>` and `latest`.
3. From a teammate's VM:

```bash
docker pull gitea.formini.local:3000/equipe-a/formini-tasks:latest
docker run --rm -p 8080:5000 gitea.formini.local:3000/equipe-a/formini-tasks:latest
curl http://localhost:8080/health
```

### 2.3 Protect `main`

Repository → **Settings** → **Branches** → *Add new rule*:

| Field | Value |
|-------|-------|
| Protected branch name pattern | `main` |
| Enable push | **unticked** (nobody pushes directly) |
| Enable status check | **ticked**, pattern: `CI / test*` |
| Required approvals | `1` |
| Block merge on requested changes | ticked |

Test it: open a PR with a broken test. The **Merge** button must be greyed out
with the message *required status check missing*, even for the repository owner.

### 2.4 Deliver a version

Create `.gitea/workflows/release.yml` (see `solution/.gitea/workflows/release.yml`):
it is triggered by a `v*` tag, and builds, scans and publishes the image with the
Git tag name as the image tag.

```bash
git switch main && git pull
git tag -a v1.0.0 -m "First released version"
git push origin v1.0.0
```

In **Packages**, the `v1.0.0` tag appears. From any VM:

```bash
docker pull gitea.formini.local:3000/equipe-a/formini-tasks:v1.0.0
```

### Part 2 success criteria

- [ ] A push to `main` produces a `:<sha>` and a `:latest` image in the registry.
- [ ] A PR whose tests fail cannot be merged, even by an admin.
- [ ] `docker pull …:v1.0.0` works from another VM in the team.
- [ ] No secret appears in the repository or in the logs (search for `***`).

### Bonus

1. **Dependency audit**: a `pip-audit` step in the `test` job.
   ```yaml
   - name: Dependency audit
     run: |
       .venv/bin/pip install -q pip-audit
       .venv/bin/pip-audit -r requirements.txt
   ```
2. **pip cache**: reuse `.venv` between two runs with `actions/cache@v4`, with a key
   based on `hashFiles('requirements-dev.txt')`. Measure the time saved.
3. **Version matrix**: test on Python 3.11 and 3.12 with `strategy.matrix`.
   In host mode, both interpreters must be installed on the VM
   (`sudo apt install python3.11-venv`), or a docker label
   `python:docker://python:3.11` must be registered on the runner.
4. **Pull request template**: copy `solution/.gitea/pull_request_template.en.md`
   to `.gitea/pull_request_template.md` so that every PR recalls the checklist.
5. **Notification**: a final step that calls a webhook (Mattermost, Slack,
   Discord…) with `curl` when `build` fails (`if: failure()`).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| No run appears after a push | Actions not enabled on the repository, or invalid YAML | Settings → Repository → Actions; check the indentation with `python3 -c "import yaml,sys; yaml.safe_load(open('.gitea/workflows/ci.yml'))"` |
| The job stays "waiting" | Runner offline, or `runs-on` label with no match | `systemctl status act_runner`; compare `runs-on` with the labels in Settings → Actions → Runners |
| `actions/checkout` fails: `node: not found` | Node.js missing on the VM (host mode) | `node --version`; otherwise reinstall with `setup/act-runner/install-runner.sh` |
| `docker login`: `unauthorized` | Token without the *package write* permission, or wrong user name | Recreate the token with the right permission; `REGISTRY_USER` = Gitea login, not the e-mail |
| `docker push`: `http: server gave HTTP response to HTTPS client` | Registry not declared as insecure | Add `"insecure-registries": ["gitea.formini.local:3000"]` to `/etc/docker/daemon.json`, then `sudo systemctl restart docker` |
| `trivy` fails with a download error | Vulnerability database not updated, no Internet access | `trivy image --download-db-only` once, then run again |
| trivy blocks on a base-system vulnerability | Old base image | Rebuild with `docker build --pull`, or move to a more recent `python:3.12-slim` tag |
| The Merge button stays active despite a red test | Wrong status pattern | The context is called `CI / test (pull_request)`: use the pattern `CI / test*` |
| `permission denied` on `/var/run/docker.sock` | The runner's user is not in the `docker` group | `sudo usermod -aG docker devops`, then `sudo systemctl restart act_runner` |

The complete, commented files are in `solution/`.
