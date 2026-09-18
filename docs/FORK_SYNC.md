# Downstream fork synchronization

This repository includes [`.github/workflows/sync-fork.yml`](../.github/workflows/sync-fork.yml)
for downstream forks that want to follow `FileMintApp/FileMint` automatically.

## One-time setup

1. Put the workflow file on the fork's default branch. A fork created after this
   change already contains it; an existing fork may need one manual sync or a
   one-time copy of the file.
2. In the fork, open **Settings → Actions → General**, enable Actions, and allow
   workflows to have **Read and write permissions**. The workflow requests write
   access to repository contents and Actions so it can push the merge and dispatch
   the fork's CI.
3. Open **Actions → Sync fork from upstream** and run it once with **Run workflow**.

The scheduled run executes daily at 02:17 UTC. It syncs `FileMintApp/FileMint`'s
`main` branch into the fork's default branch, then pushes the result to the fork.
Because a `GITHUB_TOKEN` push does not start ordinary `push` workflows, the sync
job explicitly dispatches the fork's `ci.yml` after a successful update.

## Safety behavior

- The workflow runs only when `github.event.repository.fork` is true, so the
  upstream repository does not write to itself.
- It uses the fork's built-in `GITHUB_TOKEN`; no personal access token is needed.
- It performs a regular merge and never uses a force push. Existing downstream
  commits are retained.
- Scheduled runs do not dispatch CI when the fork is already up to date. A
  manual run still dispatches CI, which also provides a recovery path after a
  transient dispatch failure.
- A merge conflict or protected-branch rejection stops before a remote update.
  If the post-push CI dispatch fails, the sync commit remains in the fork; fix
  the Actions permission or workflow name and run this workflow manually again.

If the upstream repository or branch changes, update `UPSTREAM_REPOSITORY` and
`UPSTREAM_BRANCH` in the copied workflow before enabling the schedule. If the
fork renames its CI workflow, update `CI_WORKFLOW` as well.

## 下游 fork 自动同步

工作流也适用于中文维护者：它每天从上游 `main` 拉取变更，合并到 fork 的
默认分支，并显式触发 fork 自己的 CI。不会强制覆盖下游提交；发生冲突时需要
手动处理后重新运行。
