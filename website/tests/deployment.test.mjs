import test from 'node:test'
import assert from 'node:assert/strict'
import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import {
  REPOSITORY, prepareDeployment, validateArchive, validateArtifact, validateBuildRun,
  automaticBuildInputs, validateInputs, validateMain, validateRelease,
} from '../scripts/prepare-deployment.mjs'

const commit = 'a'.repeat(40)
const inputs = { commit, runId: '12', artifactId: '34', releaseId: '56' }
const published = {
  id: 56, tag_name: 'v1.2.3', draft: false, prerelease: false,
  published_at: '2026-10-13T00:00:00Z',
  html_url: `https://github.com/${REPOSITORY}/releases/tag/v1.2.3`,
}
const buildRun = {
  id: 12, repository: { full_name: REPOSITORY }, head_repository: { full_name: REPOSITORY },
  head_sha: commit, head_branch: 'main', event: 'push', path: '.github/workflows/build-pages.yml',
  status: 'completed', conclusion: 'success',
}
const artifact = {
  id: 34, name: 'github-pages', expired: false,
  workflow_run: { id: 12, head_sha: commit, head_branch: 'main' },
}
const main = { object: { type: 'commit', sha: commit } }
const environment = {
  GITHUB_ACTIONS: 'true', GITHUB_EVENT_NAME: 'workflow_dispatch', SITE_COMMIT: commit, SITE_BUILD_RUN_ID: '12', SITE_ARTIFACT_ID: '34',
  SITE_RELEASE_ID: '56', GITHUB_OUTPUT: '/tmp/output', RUNNER_TEMP: '/tmp',
}

test('requires Actions and explicit valid commit and resource IDs', () => {
  assert.deepEqual(validateInputs(environment), inputs)
  for (const [key, value] of [
    ['GITHUB_ACTIONS', 'false'], ['GITHUB_EVENT_NAME', 'pull_request'],
    ['SITE_COMMIT', 'main'], ['SITE_COMMIT', 'A'.repeat(40)],
    ['SITE_BUILD_RUN_ID', '0'], ['SITE_ARTIFACT_ID', '-1'], ['SITE_RELEASE_ID', '1;echo'],
    ['GITHUB_OUTPUT', ''], ['RUNNER_TEMP', ''],
  ]) assert.throws(() => validateInputs({ ...environment, [key]: value }), key)
})

test('requires the requested commit to remain main', () => {
  validateMain(main, commit)
  for (const value of [null, {}, { object: { type: 'tag', sha: commit } },
    { object: { type: 'commit', sha: 'b'.repeat(40) } }]) {
    assert.throws(() => validateMain(value, commit))
  }
})

test('requires the pinned current public stable release', () => {
  assert.equal(validateRelease(published, '56'), 'v1.2.3')
  for (const change of [
    { id: 57 }, { draft: true }, { draft: undefined }, { prerelease: true }, { prerelease: 'false' },
    { tag_name: 'v1.2.3-beta' }, { tag_name: '../main' }, { tag_name: 'v01.2.3' },
    { published_at: null }, { published_at: 'invalid' }, { html_url: 'https://other.example' },
  ]) assert.throws(() => validateRelease({ ...published, ...change }, '56'), JSON.stringify(change))
})

test('binds successful build to repository, SHA, workflow, event and branch', () => {
  validateBuildRun(buildRun, inputs)
  for (const change of [
    { id: 13 }, { repository: { full_name: 'other/FileMint' } },
    { head_repository: { full_name: 'fork/FileMint' } }, { head_sha: 'b'.repeat(40) },
    { head_branch: 'v1.2.3' }, { event: 'workflow_dispatch' }, { event: 'pull_request' },
    { path: '.github/workflows/ci.yml' }, { status: 'in_progress' }, { conclusion: 'failure' },
    { conclusion: 'cancelled' },
  ]) assert.throws(() => validateBuildRun({ ...buildRun, ...change }, inputs), JSON.stringify(change))
})

test('requires one retained artifact from the exact run and source', () => {
  validateArtifact({ artifacts: [artifact] }, inputs)
  for (const artifacts of [
    [], [artifact, artifact], [{ ...artifact, expired: true }], [{ ...artifact, id: 35 }],
    [{ ...artifact, name: 'another-artifact' }], [{ ...artifact, workflow_run: { id: 13 } }],
    [{ ...artifact, workflow_run: { ...artifact.workflow_run, head_sha: 'b'.repeat(40) } }],
    [{ ...artifact, workflow_run: { ...artifact.workflow_run, head_branch: 'feature' } }],
  ]) assert.throws(() => validateArtifact({ artifacts }, inputs), JSON.stringify(artifacts))
})

test('download must contain only a nonempty regular artifact.tar', t => {
  const directory = mkdtempSync(join(tmpdir(), 'filemint-deploy-test-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  assert.throws(() => validateArchive(directory))
  const archive = join(directory, 'artifact.tar')
  writeFileSync(archive, '')
  assert.throws(() => validateArchive(directory))
  writeFileSync(archive, 'verified archive')
  assert.equal(validateArchive(directory), archive)
  writeFileSync(join(directory, 'extra'), 'extra')
  assert.throws(() => validateArchive(directory))
  rmSync(join(directory, 'extra'))
  rmSync(archive)
  symlinkSync('/etc/hosts', archive)
  assert.throws(() => validateArchive(directory))
})

function fixture(t, { afterDownload = () => {}, checkout = commit,
  ancestor = true, automatic = false, gitRun } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'filemint-deploy-test-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const sourceCommit = gitRun ? gitRun(['rev-parse', 'HEAD']).trim() : commit
  const env = { ...environment, SITE_COMMIT: sourceCommit,
    RUNNER_TEMP: directory, GITHUB_OUTPUT: join(directory, 'outputs') }
  const state = {
    build: { ...structuredClone(buildRun), head_sha: sourceCommit },
    artifacts: [{ ...structuredClone(artifact), workflow_run: { ...artifact.workflow_run, head_sha: sourceCommit } }],
    main: { object: { type: 'commit', sha: sourceCommit } }, release: structuredClone(published),
  }
  if (automatic) {
    env.GITHUB_EVENT_NAME = 'workflow_run'
    env.GITHUB_REPOSITORY = REPOSITORY
    env.GITHUB_EVENT_PATH = join(directory, 'event.json')
    env.GITHUB_STEP_SUMMARY = join(directory, 'summary.md')
    writeFileSync(env.GITHUB_EVENT_PATH, JSON.stringify({ action: 'completed',
      repository: { full_name: REPOSITORY }, workflow_run: state.build }))
    for (const key of ['SITE_COMMIT', 'SITE_BUILD_RUN_ID', 'SITE_ARTIFACT_ID', 'SITE_RELEASE_ID']) delete env[key]
  }
  const calls = []
  const run = (command, args) => {
    calls.push([command, ...args])
    if (command === 'git') {
      if (gitRun) return gitRun(args)
      if (args[0] === 'rev-parse') return checkout
      if (args[0] === 'merge-base') {
        if (!ancestor) throw Error('not an ancestor')
        assert.deepEqual(args, ['merge-base', '--is-ancestor', 'refs/tags/v1.2.3', 'HEAD'])
        return ''
      }
    }
    if (command === 'gh' && args[0] === 'api') {
      const endpoint = args[1].replace(`repos/${REPOSITORY}/`, '')
      if (endpoint === 'git/ref/heads/main') return JSON.stringify(state.main)
      if (endpoint === 'releases/latest') return JSON.stringify(state.release)
      if (endpoint === 'actions/runs/12') return JSON.stringify(state.build)
      if (endpoint === 'actions/runs/12/artifacts?per_page=100') return JSON.stringify({ artifacts: state.artifacts })
    }
    if (command === 'gh' && args[0] === 'run' && args[1] === 'download') {
      assert.deepEqual(args.slice(0, -1), ['run', 'download', '12', '--repo', REPOSITORY,
        '--name', 'github-pages', '--dir'])
      writeFileSync(join(args.at(-1), 'artifact.tar'), 'verified website bytes')
      afterDownload(state)
      return ''
    }
    assert.fail(`Unexpected command: ${command} ${args.join(' ')}`)
  }
  return { env, run, calls, state }
}

test('reuses the successful archive with read-only commands and no rebuild or app release', t => {
  const options = fixture(t)
  const archive = prepareDeployment(options)
  assert.equal(readFileSync(archive, 'utf8'), 'verified website bytes')
  assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), `archive=${archive}\nready=true\n`)
  assert.equal(options.calls.filter(call => call[0] === 'gh' && call[1] === 'run').length, 1)
})

test('changed checkout or unrelated release history prevents downloading', t => {
  for (const changes of [{ checkout: 'b'.repeat(40) }, { ancestor: false }]) {
    const options = fixture(t, changes)
    assert.throws(() => prepareDeployment(options))
    assert.ok(options.calls.every(call => !(call[0] === 'gh' && call[1] === 'run')))
  }
})

test('website deployment stays independent of unpublished native changes in a real Git history', t => {
  const directory = mkdtempSync(join(tmpdir(), 'filemint-deploy-history-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const gitRun = args => execFileSync('git', [
    '-c', 'core.hooksPath=/dev/null', '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false', ...args,
  ], {
    cwd: directory, encoding: 'utf8', timeout: 10_000, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, GIT_CONFIG_GLOBAL: '/dev/null', GIT_CONFIG_NOSYSTEM: '1',
      GIT_AUTHOR_NAME: 'FileMint Test', GIT_AUTHOR_EMAIL: 'filemint-test@example.invalid',
      GIT_COMMITTER_NAME: 'FileMint Test', GIT_COMMITTER_EMAIL: 'filemint-test@example.invalid' },
  })
  gitRun(['init', '--initial-branch=main'])
  for (const name of ['App', 'website', 'Resources']) mkdirSync(join(directory, name))
  writeFileSync(join(directory, 'App/FileMint.swift'), '// Published application\n')
  writeFileSync(join(directory, 'website/index.md'), 'Published feature guide\n')
  gitRun(['add', '.'])
  gitRun(['commit', '-m', 'Published stable application'])
  gitRun(['tag', 'v1.2.3'])
  const stableCommit = gitRun(['rev-parse', 'refs/tags/v1.2.3']).trim()
  writeFileSync(join(directory, 'App/FileMint.swift'), '// Unreleased native development\n')
  writeFileSync(join(directory, 'Resources/native.txt'), 'Unreleased native resource\n')
  writeFileSync(join(directory, 'project.yml'), 'name: NativeDevelopment\n')
  gitRun(['add', '.'])
  gitRun(['commit', '-m', 'Continue native development'])
  writeFileSync(join(directory, 'website/index.md'), 'Reviewed guide for a published feature\n')
  gitRun(['add', '.'])
  gitRun(['commit', '-m', 'Update the website independently'])
  assert.deepEqual(gitRun(['diff', '--name-only', 'v1.2.3', 'HEAD']).trim().split('\n'), [
    'App/FileMint.swift', 'Resources/native.txt', 'project.yml', 'website/index.md',
  ])
  const websiteCommit = gitRun(['rev-parse', 'HEAD']).trim()
  for (const automatic of [false, true]) {
    const options = fixture(t, { automatic, gitRun })
    const archive = prepareDeployment(options)
    assert.equal(readFileSync(archive, 'utf8'), 'verified website bytes')
    assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), `archive=${archive}\nready=true\n`)
    assert.deepEqual(options.state.release, published)
    assert.equal(gitRun(['rev-parse', 'refs/tags/v1.2.3']).trim(), stableCommit)
    assert.equal(gitRun(['rev-parse', 'HEAD']).trim(), websiteCommit)
    assert.equal(options.calls.filter(call => call[0] === 'gh' && call[1] === 'run').length, 1)
  }
})

test('reruns, artifact replacement, newer main or newer latest release block deployment output', t => {
  for (const change of [
    state => { state.artifacts[0].id = 35 },
    state => { state.build.status = 'in_progress' },
    state => { state.main.object.sha = 'b'.repeat(40) },
    state => { state.release.id = 57 },
    state => { state.release.draft = true },
  ]) {
    const options = fixture(t, { afterDownload: change })
    assert.throws(() => prepareDeployment(options))
    assert.throws(() => readFileSync(options.env.GITHUB_OUTPUT), { code: 'ENOENT' })
  }
})

test('automatic trigger accepts only successful original-repository main push builds', () => {
  const event = { action: 'completed', repository: { full_name: REPOSITORY }, workflow_run: buildRun }
  assert.deepEqual(automaticBuildInputs(event), { commit, runId: '12' })
  for (const change of [
    { event: 'pull_request' }, { event: 'workflow_dispatch' }, { conclusion: 'failure' },
    { conclusion: 'cancelled' }, { status: 'in_progress' }, { head_branch: 'feature' },
    { head_repository: { full_name: 'fork/FileMint' } }, { path: '.github/workflows/ci.yml' },
    { id: '../12' }, { head_sha: 'main' },
  ]) assert.throws(() => automaticBuildInputs({ ...event, workflow_run: { ...buildRun, ...change } }))
  assert.throws(() => automaticBuildInputs({ ...event, action: 'requested' }))
  assert.throws(() => automaticBuildInputs({ ...event, repository: { full_name: 'fork/FileMint' } }))
})

test('automatic deployment discovers and pins the exact build, artifact and stable release', t => {
  const options = fixture(t, { automatic: true })
  const archive = prepareDeployment(options)
  assert.equal(readFileSync(archive, 'utf8'), 'verified website bytes')
  assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), `archive=${archive}\nready=true\n`)
  assert.equal(options.calls.filter(call => call[0] === 'gh' && call[1] === 'run').length, 1)
})

test('automatic deployment skips superseded builds before downloading', t => {
  for (const changes of [{ checkout: 'b'.repeat(40) }]) {
    const options = fixture(t, { automatic: true, ...changes })
    assert.equal(prepareDeployment(options), null)
    assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), 'ready=false\n')
    assert.match(readFileSync(options.env.GITHUB_STEP_SUMMARY, 'utf8'), /Website deployment skipped:/)
    assert.ok(options.calls.every(call => !(call[0] === 'gh' && call[1] === 'run')))
  }
  const options = fixture(t, { automatic: true })
  options.state.main.object.sha = 'b'.repeat(40)
  assert.equal(prepareDeployment(options), null)
  assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), 'ready=false\n')
})

test('automatic deployment revalidates API metadata before trusting a trigger or downloading bytes', t => {
  for (const mutate of [
    state => { state.build.event = 'pull_request' },
    state => { state.build.repository.full_name = 'fork/FileMint' },
    state => { state.build.head_sha = 'b'.repeat(40) },
    state => { state.build.conclusion = 'failure' },
    state => { state.artifacts = [] },
    state => { state.artifacts.push(structuredClone(artifact)) },
    state => { state.artifacts[0].expired = true },
    state => { state.artifacts[0].workflow_run.head_sha = 'b'.repeat(40) },
    state => { state.release.draft = true },
  ]) {
    const options = fixture(t, { automatic: true })
    mutate(options.state)
    assert.throws(() => prepareDeployment(options))
    assert.ok(options.calls.every(call => !(call[0] === 'gh' && call[1] === 'run')))
    assert.throws(() => readFileSync(options.env.GITHUB_OUTPUT), { code: 'ENOENT' })
  }
  const options = fixture(t, { automatic: true })
  options.env.GITHUB_REPOSITORY = 'fork/FileMint'
  assert.throws(() => prepareDeployment(options))
  assert.equal(options.calls.length, 0)
})

test('automatic deployment refuses identities that change while the retained archive downloads', t => {
  for (const afterDownload of [
    state => { state.artifacts[0].id = 35 },
    state => { state.build.status = 'in_progress' },
    state => { state.main.object.sha = 'b'.repeat(40) },
    state => { state.release.id = 57 },
  ]) {
    const options = fixture(t, { automatic: true, afterDownload })
    assert.throws(() => prepareDeployment(options))
    assert.throws(() => readFileSync(options.env.GITHUB_OUTPUT), { code: 'ENOENT' })
  }
})
