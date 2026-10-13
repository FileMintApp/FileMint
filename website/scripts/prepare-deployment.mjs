import { execFileSync } from 'node:child_process'
import { appendFileSync, lstatSync, mkdtempSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { pathToFileURL } from 'node:url'

export const REPOSITORY = 'FileMintApp/FileMint'
const STABLE_TAG = /^v(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$/
const SHA = /^[0-9a-f]{40}$/
const ID = /^[1-9]\d*$/
const allowedFiles = new Set([
  'README.md', 'README.en.md', 'package.json', 'pnpm-lock.yaml',
  'specs/domains/presentation.md', 'specs/domains/distribution.md',
  '.github/workflows/build-pages.yml', '.github/workflows/deploy-website.yml',
])

function requireCondition(condition, message) {
  if (!condition) throw new Error(message)
}

export function validateInputs(env) {
  requireCondition(env.GITHUB_ACTIONS === 'true', 'Deployment preparation requires GitHub Actions')
  requireCondition(SHA.test(env.SITE_COMMIT ?? ''), 'Invalid website commit')
  for (const key of ['SITE_BUILD_RUN_ID', 'SITE_ARTIFACT_ID', 'SITE_RELEASE_ID']) {
    requireCondition(ID.test(env[key] ?? ''), `Invalid ${key}`)
  }
  for (const key of ['GITHUB_OUTPUT', 'RUNNER_TEMP']) {
    requireCondition(typeof env[key] === 'string' && env[key].length > 0, `Missing ${key}`)
  }
  return {
    commit: env.SITE_COMMIT,
    runId: env.SITE_BUILD_RUN_ID,
    artifactId: env.SITE_ARTIFACT_ID,
    releaseId: env.SITE_RELEASE_ID,
  }
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
    && (path.startsWith('website/') || path.startsWith('docs/') || allowedFiles.has(path))),
  'Website-only deployment includes changes outside the permitted website and documentation paths')
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
  const inputs = validateInputs(env)
  const api = endpoint => JSON.parse(run('gh', ['api', `repos/${REPOSITORY}/${endpoint}`]))
  requireCondition(run('git', ['rev-parse', 'HEAD']).trim() === inputs.commit,
    'Workflow checkout differs from the requested website commit')
  validateMain(api('git/ref/heads/main'), inputs.commit)
  const tag = validateRelease(api('releases/latest'), inputs.releaseId)
  // Main must descend from the fully fetched stable tag, with no unpublished app delta.
  run('git', ['merge-base', '--is-ancestor', `refs/tags/${tag}`, 'HEAD'])
  const paths = run('git', ['diff', '--name-only', '--no-renames', '-z', `refs/tags/${tag}`, 'HEAD', '--'])
    .split('\0').filter(Boolean)
  validateWebsitePaths(paths)
  validateBuildRun(api(`actions/runs/${inputs.runId}`), inputs)
  const artifactsEndpoint = `actions/runs/${inputs.runId}/artifacts?per_page=100`
  validateArtifact(api(artifactsEndpoint), inputs)
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
  appendFileSync(env.GITHUB_OUTPUT, `archive=${archive}\n`)
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
