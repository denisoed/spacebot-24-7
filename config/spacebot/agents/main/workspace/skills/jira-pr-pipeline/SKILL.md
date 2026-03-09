---
name: jira-pr-pipeline
description: Deterministic Telegram -> Jira -> worktree -> code -> GitHub PR workflow for this Spacebot deployment.
---

# Jira PR Pipeline

Use this skill when the user asks for code changes tied to a Jira issue or when the task should end with a GitHub pull request.

## Default Path

For normal coding requests, run the pipeline wrapper instead of manually reproducing the steps:

```bash
/opt/spacebot/scripts/pipeline/run-task.sh --message "$TASK"
```

This script:
- extracts the Jira issue key from the original request;
- resolves the target repository from `/opt/spacebot/config/repositories.json`;
- fetches Jira context;
- creates or reuses the worktree for that issue;
- runs OpenCode in the worktree with Atlassian MCP configured;
- stages, commits, pushes, and opens the GitHub PR.

## Diagnostics and Manual Recovery

Use these commands when the wrapper fails and you need to isolate the failing stage:

```bash
/opt/spacebot/scripts/validate-env.sh
/opt/spacebot/scripts/pipeline/prepare-task.sh --message "$TASK"
/opt/spacebot/scripts/jira/get-issue.sh --jira-key PROJ-123
/opt/spacebot/scripts/git/ensure-worktree.sh --jira-key PROJ-123
/opt/spacebot/scripts/github/publish-pr.sh --jira-key PROJ-123 --worktree /workspace/worktrees/PROJ-123
```

## Working Rules

- Do not edit the main repo checkout directly when the task is tied to Jira; use the worktree.
- Keep the branch name aligned with the configured prefix and Jira key.
- Use `TASK_CONTEXT.md` in the worktree as your local brief.
- If Atlassian MCP is not authenticated yet, continue with the bundled Jira context instead of blocking.
- Always report the resulting worktree path, branch name, and PR URL.
