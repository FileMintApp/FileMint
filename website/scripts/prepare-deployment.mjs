import { execFileSync } from 'node:child_process'
import { appendFileSync, lstatSync, mkdtempSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

export const REPOSITORY = 'FileMintApp/FileMint'
const STABLE_TAG = /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/
const SHA = /^[0-9a-f]{40}$/
const ID = /^[1-9]\d*$/
const allowedFiles = new Set([
  'README.md', 'README.zh-CN.md', 'package.json', 'pnpm-lock.yaml',
  // Stable tags may still include this former English README in rename/deletion diffs.
  'README.en.md',
  'Makefile', 'AGENTS.md', '.gitignore',
])
// These maintain the repository and its publication process, not the application
// shipped in the stable release. Native source, resources, config and dependencies
// are deliberately absent, as are unknown root paths and the bundled LICENSE.
const maintenanceRoots = ['website/', 'docs/', 'specs/', 'scripts/', '.github/']

function requireCondition(condition, message) {
  if (!condition) throw new Error(message)
}

function validateContext(env) {
  requireCondition(env.GITHUB_ACTIONS === 'true', 'Deployment preparation requires GitHub Actions')
  requireCondition(['workflow_dispatch', 'workflow_run'].includes(env.GITHUB_EVENT_NAME),
    'Unsupported website deployment event')
  for (const key of ['GITHUB_OUTPUT', 'RUNNER_TEMP']) {
    requireCondition(typeof env[key] === 'string' && env[key].length > 0, `Missing ${key}`)
  }
}

export function validateInputs(env) {
  validateContext(env)
  requireCondition(SHA.test(env.SITE_COMMIT ?? ''), 'Invalid website commit')
  for (const key of ['SITE_BUILD_RUN_ID', 'SITE_ARTIFACT_ID', 'SITE_RELEASE_ID']) {
    requireCondition(ID.test(env[key] ?? ''), `Invalid ${key}`)
  }
  return {
    commit: env.SITE_COMMIT,
    runId: env.SITE_BUILD_RUN_ID,
    artifactId: env.SITE_ARTIFACT_ID,
    releaseId: env.SITE_RELEASE_ID,
  }
}

export function automaticBuildInputs(event) {
  const run = event?.workflow_run
  requireCondition(event?.action === 'completed' && event?.repository?.full_name === REPOSITORY
    && run?.head_repository?.full_name === REPOSITORY && run?.head_branch === 'main'
    && run?.event === 'push' && run?.status === 'completed' && run?.conclusion === 'success'
    && run?.path === '.github/workflows/build-pages.yml'
    && SHA.test(run?.head_sha ?? '') && ID.test(String(run?.id ?? '')),
  'Automatic deployment requires the original repository successful main-push website build')
  return { commit: run.head_sha, runId: String(run.id) }
}

export function validateMain(main, commit) {
  requireCondition(main?.object?.type === 'commit' && main.object.sha === commit,
    'Website commit is no longer the current main commit')
}

export function validateRelease(release, releaseId) {
  requireCondition(String(release?.id) === releaseId && release?.draft === false
    && release?.prerelease === false && STABLE_TAG.test(release?.tag_name ?? '')
    && typeof release?.published_at === 'string' && Number.isFinite(Date.parse(release.published_at)),
  'Latest release is not the requested published stable release')
  requireCondition(release.html_url === `https://github.com/${REPOSITORY}/releases/tag/${release.tag_name}`,
    'Unexpected public release URL')
  return release.tag_name
}

export function validateBuildRun(run, { commit, runId }) {
  requireCondition(String(run?.id) === runId && run?.repository?.full_name === REPOSITORY
    && run?.head_repository?.full_name === REPOSITORY && run?.head_sha === commit
    && run?.head_branch === 'main' && run?.event === 'push'
    && run?.path === '.github/workflows/build-pages.yml'
    && run?.status === 'completed' && run?.conclusion === 'success',
  'Website build must be a successful main push build for the exact requested commit and repository')
}

export function validateArtifact(data, { artifactId, runId, commit }) {
  const candidates = Array.isArray(data?.artifacts)
    ? data.artifacts.filter(artifact => artifact.name === 'github-pages' && artifact.expired === false)
    : []
  requireCondition(candidates.length === 1 && String(candidates[0].id) === artifactId
    && String(candidates[0].workflow_run?.id) === runId
    && candidates[0].workflow_run?.head_sha === commit
    && candidates[0].workflow_run?.head_branch === 'main',
  'Website artifact is missing, expired, ambiguous or differs from the requested build artifact')
}

export function validateWebsitePaths(paths) {
  requireCondition(Array.isArray(paths) && paths.every(path => typeof path === 'string'
    && path.length > 0 && !path.split('/').includes('..') && !path.startsWith('/')
    && (maintenanceRoots.some(root => path.startsWith(root)) || allowedFiles.has(path))),
  'Application source, resources or project configuration differs from the published release, or an unknown root path changed')
}

export function validateArchive(directory) {
  const entries = readdirSync(directory)
  requireCondition(entries.length === 1 && entries[0] === 'artifact.tar', 'Unexpected website artifact contents')
  const archive = join(directory, 'artifact.tar')
  const metadata = lstatSync(archive)
  requireCondition(metadata.isFile() && !metadata.isSymbolicLink() && metadata.size > 0,
    'Website artifact.tar must be a nonempty regular file')
  return archive
}

export function prepareDeployment({ env = process.env, run = (command, args) => execFileSync(command, args, {
  encoding: 'utf8', timeout: 120_000, maxBuffer: 8 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
}) } = {}) {
  validateContext(env)
  const automatic = env.GITHUB_EVENT_NAME === 'workflow_run'
  if (automatic) requireCondition(env.GITHUB_REPOSITORY === REPOSITORY,
    'Automatic deployment must run in the original repository')
  let inputs = automatic
    ? automaticBuildInputs(JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')))
    : validateInputs(env)
  const api = endpoint => JSON.parse(run('gh', ['api', `repos/${REPOSITORY}/${endpoint}`]))
  const skip = reason => {
    const message = `Website deployment skipped: ${reason}`
    appendFileSync(env.GITHUB_OUTPUT, 'ready=false\n')
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `${message}\n`)
    console.log(message)
    return null
  }
  const checkout = run('git', ['rev-parse', 'HEAD']).trim()
  const main = api('git/ref/heads/main')
  if (automatic && (checkout !== inputs.commit || main?.object?.sha !== inputs.commit)) {
    return skip('a newer main commit superseded this build')
  }
  requireCondition(checkout === inputs.commit, 'Workflow checkout differs from the requested website commit')
  validateMain(main, inputs.commit)
  validateBuildRun(api(`actions/runs/${inputs.runId}`), inputs)
  const release = api('releases/latest')
  const releaseId = automatic ? String(release?.id) : inputs.releaseId
  const tag = validateRelease(release, releaseId)
  // Main must descend from the stable tag. Repository maintenance may advance,
  // but application code, resources, dependencies and project settings may not.
  run('git', ['merge-base', '--is-ancestor', `refs/tags/${tag}`, 'HEAD'])
  const paths = run('git', ['diff', '--name-only', '--no-renames', '-z', `refs/tags/${tag}`, 'HEAD', '--'])
    .split('\0').filter(Boolean)
  if (automatic) {
    try { validateWebsitePaths(paths) } catch {
      return skip('application or unsupported source changes await a published release')
    }
  } else validateWebsitePaths(paths)
  const artifactsEndpoint = `actions/runs/${inputs.runId}/artifacts?per_page=100`
  const artifacts = api(artifactsEndpoint)
  if (automatic) {
    const candidates = artifacts?.artifacts?.filter(item => item.name === 'github-pages' && item.expired === false) ?? []
    requireCondition(candidates.length === 1, 'Automatic deployment needs one unexpired github-pages artifact')
    inputs = validateInputs({ ...env, SITE_COMMIT: inputs.commit, SITE_BUILD_RUN_ID: inputs.runId,
      SITE_ARTIFACT_ID: String(candidates[0].id), SITE_RELEASE_ID: releaseId })
  }
  validateArtifact(artifacts, inputs)
  const directory = mkdtempSync(join(env.RUNNER_TEMP, 'filemint-website-'))
  run('gh', ['run', 'download', inputs.runId, '--repo', REPOSITORY,
    '--name', 'github-pages', '--dir', directory])
  const archive = validateArchive(directory)
  // A run can be rerun while downloading by name. Refuse if its artifact or state changed.
  validateBuildRun(api(`actions/runs/${inputs.runId}`), inputs)
  validateArtifact(api(artifactsEndpoint), inputs)
  validateMain(api('git/ref/heads/main'), inputs.commit)
  requireCondition(validateRelease(api('releases/latest'), inputs.releaseId) === tag,
    'Latest release tag changed during deployment preparation')
  appendFileSync(env.GITHUB_OUTPUT, `archive=${archive}\nready=true\n`)
  return archive
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    prepareDeployment()
  } catch (error) {
    console.error(`Website deployment refused: ${error.message}`)
    process.exitCode = 1
  }
}
