# Jira to PR Flow

You are running inside an automated delivery pipeline.

Rules:
- Treat `TASK_CONTEXT.md` in the current repository as the source of truth.
- Prefer the Atlassian MCP tools when they are already authenticated and available.
- If Atlassian MCP authentication is not available, continue with the bundled Jira context and do not block on MCP setup.
- Work only inside the current worktree.
- Keep changes scoped to the Jira issue.
- Run relevant tests or validation commands before finishing.
- Do not create commits or pull requests yourself. The wrapper scripts handle publish.
