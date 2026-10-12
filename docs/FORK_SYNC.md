# Downstream fork synchronization

This repository includes [`.github/workflows/sync-fork.yml`](../.github/workflows/sync-fork.yml)
for downstream forks that want to follow `FileMintApp/FileMint` automatically.

## One-time setup

1. Put the workflow file on the fork's default branch. A fork created after this
   change already contains it; an existing fork may need one manual sync or a
   one-time copy of the file.
2. In the fork, open **Settings → Actions → General** and enable Actions. The
   workflow requests Contents write access for source-only sync and Actions write
   access for explicitly dispatching the fork's CI; repository policies must allow
   these permissions.
3. To sync changes to `.github/workflows/`, create a fine-grained personal access
   token scoped only to your fork with **Contents: Read and write** and
   **Workflows: Read and write**. Store it in the fork under **Settings → Secrets
   and variables → Actions → New repository secret**, named `FORK_SYNC_TOKEN`.
   The dedicated token is used by checkout and Git push; explicit CI dispatch
   continues to use the built-in token, so the dedicated token needs no Actions
   write permission.
4. Existing forks must manually sync the updated workflow once, for example with
   **Sync fork → Update branch** on GitHub. Adding the secret alone cannot change
   an old workflow that still ignores it. Resolve any conflicts through a normal
   merge; do not discard downstream changes.
5. Open **Actions → Sync fork from upstream** and run it once with **Run workflow**.

The scheduled run executes daily at 02:17 UTC. It syncs `FileMintApp/FileMint`'s
`main` branch into the fork's default branch, then pushes the result to the fork.
Because a `GITHUB_TOKEN` push does not start ordinary `push` workflows, the sync
job explicitly dispatches the fork's `ci.yml` after a successful built-in-token
update. A dedicated-token push to `main` starts the existing push CI directly,
so that case does not also dispatch a duplicate run. Updates to another default
branch are explicitly dispatched because `ci.yml` only listens for pushes to
`main`.

## Safety behavior

- The workflow runs only when `github.event.repository.fork` is true, so the
  upstream repository does not write to itself.
- Checkout uses `FORK_SYNC_TOKEN` when configured, otherwise the fork's built-in
  `GITHUB_TOKEN`. The built-in token can sync ordinary source changes. If new
  upstream history changes workflow files, the workflow stops before push and
  explains how to configure the dedicated token, including when those files were
  changed and later reverted in the incoming history.
- `contents: write` and `actions: write` do not grant workflow-file write access.
  Adding `workflows: write` to YAML is not supported. See GitHub's
  [workflow permission reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)
  and [additional token permissions](https://docs.github.com/en/actions/tutorials/authenticate-with-github_token#granting-additional-permissions).
- It performs a regular merge and never uses a force push. Existing downstream
  commits are retained.
- Scheduled runs do not dispatch CI when the fork is already up to date. A
  manual run still dispatches CI, which also provides a recovery path after a
  transient dispatch failure.
- Fetch, merge, workflow-permission checking and push are separate steps, so a
  failed run identifies which operation needs attention. A merge conflict, missing
  token or protected-branch rejection stops before a remote update and CI dispatch.
- If the post-push CI dispatch fails, the sync commit remains in the fork; fix
  the Actions permission or workflow name and run this workflow manually again.
- Node runtime and runner-image notices are separate from the failed command.
  Inspect the red step's output to distinguish a merge conflict from a push
  permission or branch-protection rejection.

If the upstream repository or branch changes, update `UPSTREAM_REPOSITORY` and
`UPSTREAM_BRANCH` in the copied workflow before enabling the schedule. If the
fork renames its CI workflow, update `CI_WORKFLOW` as well.

## 下游 fork 自动同步

工作流也适用于中文维护者：它每天从上游 `main` 拉取变更，合并到 fork 的
默认分支，再触发 fork 自己的 CI。不会强制覆盖下游提交；发生冲突时需要
手动处理后重新运行。

完整同步工作流文件需要在**下游 fork** 配置 `FORK_SYNC_TOKEN` Secret：创建
仅授权该 fork 的 fine-grained Token，授予 `Contents` 和 `Workflows` 的
读写权限。普通 `GITHUB_TOKEN` 即使已配置 `contents: write` 和
`actions: write`，也无法推送工作流更新。

旧 fork 需要先通过 GitHub 的 **Sync fork → Update branch** 手动同步一次新版
工作流，再运行自动同步。配置专用 Token 后，推送到 `main` 会自动触发 CI；
默认 Token 的同步、其他默认分支的同步，以及已同步后的手动重试会显式触发
CI。缺少权限时会在推送前给出配置提示。
