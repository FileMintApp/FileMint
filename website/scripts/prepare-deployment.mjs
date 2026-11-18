import { execFileSync } from 'node:child_process'
import { appendFileSync, lstatSync, mkdtempSync, readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

export const REPOSITORY = 'FileMintApp/FileMint'
const STABLE_TAG = /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/
const SHA = /^[0-9a-f]{40}$/
const ID = /^[1-9]\d*$/

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

function validateBuildIdentity(run, { commit, runId }) {
  requireCondition(String(run?.id) === runId && run?.repository?.full_name === REPOSITORY
    && run?.head_repository?.full_name === REPOSITORY && run?.head_sha === commit
    && run?.head_branch === 'main' && run?.event === 'push'
    && run?.path === '.github/workflows/build-pages.yml',
  'Website build must be a main push build for the exact requested commit and repository')
}

export function validateBuildRun(run, inputs) {
  validateBuildIdentity(run, inputs)
  requireCondition(run.status === 'completed' && run.conclusion === 'success',
    'Website build has not succeeded; rerun the exact main-push build before retrying deployment')
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
  const catchup = !automatic && Boolean(env.SITE_RELEASE_COMMIT || env.SITE_REQUEST_ID)
  const discoverArtifact = automatic || catchup
  if (discoverArtifact) requireCondition(env.GITHUB_REPOSITORY === REPOSITORY,
    'Automatic deployment must run in the original repository')
  const api = endpoint => JSON.parse(run('gh', ['api', `repos/${REPOSITORY}/${endpoint}`]))
  const skip = reason => {
    const message = `Website deployment skipped: ${reason}`
    appendFileSync(env.GITHUB_OUTPUT, 'ready=false\n')
    if (env.GITHUB_STEP_SUMMARY) appendFileSync(env.GITHUB_STEP_SUMMARY, `${message}\n`)
    console.log(message)
    return null
  }
  const checkout = run('git', ['rev-parse', 'HEAD']).trim()
  let inputs
  if (automatic) {
    inputs = automaticBuildInputs(JSON.parse(readFileSync(env.GITHUB_EVENT_PATH, 'utf8')))
  } else if (catchup) {
    requireCondition(env.GITHUB_REF === 'refs/heads/main' && SHA.test(checkout)
      && SHA.test(env.SITE_RELEASE_COMMIT ?? '') && ID.test(env.SITE_RELEASE_ID ?? '')
      && /^[0-9a-f]{32}$/.test(env.SITE_REQUEST_ID ?? '')
      && !env.SITE_COMMIT && !env.SITE_BUILD_RUN_ID && !env.SITE_ARTIFACT_ID,
    'Invalid post-release website catch-up request')
    inputs = { commit: checkout, releaseId: env.SITE_RELEASE_ID }
  } else {
    inputs = validateInputs(env)
  }
  const main = api('git/ref/heads/main')
  requireCondition(main?.object?.type === 'commit' && SHA.test(main.object.sha ?? ''), 'Invalid main branch identity')
  if (discoverArtifact && (checkout !== inputs.commit || main?.object?.sha !== inputs.commit)) {
    return skip('a newer main commit superseded this build')
  }
  requireCondition(checkout === inputs.commit, 'Workflow checkout differs from the requested website commit')
  validateMain(main, inputs.commit)
  if (!catchup) validateBuildRun(api(`actions/runs/${inputs.runId}`), inputs)
  const release = api('releases/latest')
  const releaseId = automatic ? String(release?.id) : inputs.releaseId
  const tag = validateRelease(release, releaseId)
  if (catchup) {
    const tagCommit = run('git', ['rev-parse', '--verify', `refs/tags/${tag}^{commit}`]).trim()
    requireCondition(tagCommit === env.SITE_RELEASE_COMMIT, 'Release commit differs from the current public tag')
    if (checkout === tagCommit) return skip('main is already the published release commit')
  }
  const notes = run('git', ['show', 'HEAD:docs/RELEASE_NOTES.md'])
  const heading = notes.match(/^# FileMint ([^\r\n]+)$/m)
  requireCondition(heading && STABLE_TAG.test(`v${heading[1]}`), 'Missing stable release-notes heading')
  const required = heading[1].split('.').map(BigInt)
  const published = tag.slice(1).split('.').map(BigInt)
  const changed = required.findIndex((value, index) => value !== published[index])
  if (changed !== -1 && required[changed] > published[changed]) {
    return skip(`website copy awaits public release v${heading[1]}`)
  }
  // Keep release ancestry, but publish only the verified static artifact.
  // Unrelated App development must not block a reviewed website update.
  run('git', ['merge-base', '--is-ancestor', `refs/tags/${tag}`, 'HEAD'])
  if (catchup) {
    const query = new URLSearchParams({ branch: 'main', event: 'push', head_sha: checkout, per_page: '1' })
    const runs = api(`actions/workflows/build-pages.yml/runs?${query}`).workflow_runs
    requireCondition(Array.isArray(runs) && runs.length === 1 && ID.test(String(runs[0]?.id ?? '')),
      'No main-push website build found for the current commit; retry after its build is available')
    inputs.runId = String(runs[0].id)
    validateBuildIdentity(runs[0], inputs)
    const build = api(`actions/runs/${inputs.runId}`)
    validateBuildIdentity(build, inputs)
    if (['queued', 'in_progress', 'waiting', 'pending', 'requested'].includes(build.status)) {
      return skip('the current main build is pending and will deploy on successful completion')
    }
    validateBuildRun(build, inputs)
  }
  const artifactsEndpoint = `actions/runs/${inputs.runId}/artifacts?per_page=100`
  const artifacts = api(artifactsEndpoint)
  if (discoverArtifact) {
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
  const finalMain = api('git/ref/heads/main')
  if (catchup && finalMain?.object?.type === 'commit' && SHA.test(finalMain.object.sha)
    && finalMain.object.sha !== inputs.commit) return skip('a newer main commit superseded this build')
  validateMain(finalMain, inputs.commit)
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
