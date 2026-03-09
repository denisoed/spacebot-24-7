# spacebot-docker

Portable Spacebot stack for a Telegram -> Jira -> worktree -> GitHub PR delivery flow.

The repository now provides:
- a custom `spacebot:full`-based image with `git`, `gh`, `jq`, `opencode`, and supporting CLI tooling;
- a Telegram-bound Spacebot agent with a dedicated `jira-pr-pipeline` skill;
- deterministic helper scripts for Jira lookup, worktree creation, and PR publishing;
- OpenCode configuration with Atlassian remote MCP enabled and a safe Jira REST fallback;
- env-driven configuration so the same repo can be moved to another machine with minimal changes.

## Layout

- [`docker-compose.yml`](/home/denisoed/PROJECTS/spacebot-docker/docker-compose.yml): runtime wiring and mounts
- [`Dockerfile`](/home/denisoed/PROJECTS/spacebot-docker/Dockerfile): extends `ghcr.io/spacedriveapp/spacebot:full`
- [`config/spacebot/config.toml`](/home/denisoed/PROJECTS/spacebot-docker/config/spacebot/config.toml): Spacebot configuration
- [`config/repositories.json`](/home/denisoed/PROJECTS/spacebot-docker/config/repositories.json): Jira-project to local-repo mapping
- [`config/opencode/opencode.json`](/home/denisoed/PROJECTS/spacebot-docker/config/opencode/opencode.json): OpenCode config with Atlassian MCP
- [`scripts/`](/home/denisoed/PROJECTS/spacebot-docker/scripts): reusable pipeline scripts

## Required Secrets and Settings

Copy the template and fill it:

```bash
cp .env.example .env
```

Mandatory variables:

```env
OPENROUTER_API_KEY=
TELEGRAM_BOT_TOKEN=
TELEGRAM_PRIMARY_CHAT_ID=
JIRA_BASE_URL=
JIRA_EMAIL=
JIRA_API_TOKEN=
GH_TOKEN=
PROJECTS_DIR=/home/user/PROJECTS
WORKTREE_ROOT=./state/worktrees
DEFAULT_REPO_ALIAS=main
DEFAULT_BASE_BRANCH=main
WORKTREE_BRANCH_PREFIX=feature
WORKTREE_NAME_TEMPLATE={jira_key}
LOCAL_UID=1000
LOCAL_GID=1000
```

Notes:
- `PROJECTS_DIR` is the host directory that contains your repositories.
- `WORKTREE_ROOT` can stay on the repo-local default if you want worktrees managed by this project.
- `LOCAL_UID` and `LOCAL_GID` should match `id -u` and `id -g` on the host, so files created in worktrees are owned by your user.
- `GH_TOKEN` is the single GitHub credential used by the pipeline and by `gh`.

## Repository Mapping

Edit [`config/repositories.json`](/home/denisoed/PROJECTS/spacebot-docker/config/repositories.json) before the first run.

Example:

```json
{
  "default_alias": "main",
  "project_key_map": {
    "PROJ": "main",
    "OPS": "ops"
  },
  "repositories": {
    "main": {
      "relative_path": "spacebot-app",
      "base_branch": "main",
      "branch_prefix": "feature"
    },
    "ops": {
      "relative_path": "infra-repo",
      "base_branch": "master",
      "branch_prefix": "ops"
    }
  }
}
```

Rules:
- `relative_path` is resolved inside `/workspace/projects`, which is backed by `PROJECTS_DIR`.
- `project_key_map` decides which local repo handles a Jira project key.
- worktrees are created in `${WORKTREE_ROOT}/{jira_key}` by default.

## Jira MCP and Auth

OpenCode is configured with Atlassian remote MCP at `https://mcp.atlassian.com/v1/mcp`.

The pipeline remains operational even without MCP because Jira issue context is also fetched through the bundled REST scripts. The intended setup is:

1. start the stack;
2. authenticate the Atlassian MCP server once;
3. let OpenCode use MCP when it is available, otherwise continue from `TASK_CONTEXT.md`.

Authenticate Atlassian MCP inside the container:

```bash
docker compose exec spacebot opencode mcp auth atlassian
```

If MCP auth is not completed yet, the Telegram flow still works with Jira REST metadata.

## Start

Build and run:

```bash
docker compose up -d --build
```

Inspect:

```bash
docker compose ps
docker compose logs -f spacebot
```

Stop:

```bash
docker compose down
```

## Validation

Validate configuration inside the running container:

```bash
docker compose exec spacebot /opt/spacebot/scripts/validate-env.sh
```

Manual pipeline smoke test without Telegram:

```bash
docker compose exec spacebot /opt/spacebot/scripts/pipeline/prepare-task.sh \
  --message "PROJ-123 implement the requested change"
```

Full wrapper smoke test:

```bash
docker compose exec spacebot /opt/spacebot/scripts/pipeline/run-task.sh \
  --message "PROJ-123 implement the requested change"
```

## Telegram Flow

The configured Telegram chat is the primary ingress. Send a message containing a Jira issue key and the requested work, for example:

```text
PROJ-123 implement the bugfix from the Jira ticket and open a PR
```

Expected flow:
- Spacebot recognizes the Jira key from the message.
- The agent uses the `jira-pr-pipeline` skill.
- Jira context is fetched and written into `TASK_CONTEXT.md` inside the worktree.
- A worktree is created or reused at `WORKTREE_ROOT/PROJ-123`.
- OpenCode performs the implementation in that worktree.
- Changes are committed, pushed, and a GitHub PR is opened automatically.
- Telegram receives the resulting status, including branch and PR URL.

## Included Scripts

- [`scripts/validate-env.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/validate-env.sh): validates secrets, repo mapping, and required binaries
- [`scripts/pipeline/extract-jira-key.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/pipeline/extract-jira-key.sh): extracts the first Jira key from arbitrary text
- [`scripts/jira/get-issue.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/jira/get-issue.sh): fetches Jira issue metadata
- [`scripts/git/ensure-worktree.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/git/ensure-worktree.sh): creates or reuses a worktree and branch for the Jira issue
- [`scripts/pipeline/prepare-task.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/pipeline/prepare-task.sh): prepares `TASK_CONTEXT.md` and returns the resolved task payload
- [`scripts/github/publish-pr.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/github/publish-pr.sh): commits, pushes, and opens or reuses the PR
- [`scripts/pipeline/run-task.sh`](/home/denisoed/PROJECTS/spacebot-docker/scripts/pipeline/run-task.sh): end-to-end wrapper used by the Spacebot skill

## Machine Bootstrap Checklist

On a new machine, only these steps should be necessary:

1. Clone this repository.
2. Copy `.env.example` to `.env` and fill the secrets.
3. Update [`config/repositories.json`](/home/denisoed/PROJECTS/spacebot-docker/config/repositories.json) for local repo paths.
4. Start the stack with `docker compose up -d --build`.
5. Run `docker compose exec spacebot /opt/spacebot/scripts/validate-env.sh`.
6. Run `docker compose exec spacebot opencode mcp auth atlassian` once.
7. Send a Jira-backed task into the configured Telegram chat.
