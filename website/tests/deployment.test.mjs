import test from 'node:test'
import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import {
  REPOSITORY, prepareDeployment, validateArchive, validateArtifact, validateBuildRun,
  validateInputs, validateMain, validateRelease, validateWebsitePaths,
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
  GITHUB_ACTIONS: 'true', SITE_COMMIT: commit, SITE_BUILD_RUN_ID: '12', SITE_ARTIFACT_ID: '34',
  SITE_RELEASE_ID: '56', GITHUB_OUTPUT: '/tmp/output', RUNNER_TEMP: '/tmp',
}

test('requires Actions and explicit valid commit and resource IDs', () => {
  assert.deepEqual(validateInputs(environment), inputs)
  for (const [key, value] of [
    ['GITHUB_ACTIONS', 'false'], ['SITE_COMMIT', 'main'], ['SITE_COMMIT', 'A'.repeat(40)],
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

test('website-only deployment refuses app or existing release-pipeline changes', () => {
  validateWebsitePaths([
    'website/index.md', 'website/scripts/prepare-deployment.mjs', 'README.en.md',
    'package.json', 'pnpm-lock.yaml', 'docs/tasks/deployment.md',
    'specs/domains/presentation.md', 'specs/domains/distribution.md',
    '.github/workflows/build-pages.yml', '.github/workflows/deploy-website.yml',
  ])
  for (const path of [
    'project.yml', 'CorePackage/Sources/Foo.swift', 'App/FileMint/App.swift',
    'scripts/release_publication.py', '.github/workflows/deploy-pages.yml',
    '.github/workflows/release.yml', 'specs/domains/updates.md',
    'website/../App/main.swift', '/website/index.md', '',
  ]) assert.throws(() => validateWebsitePaths([path]), path)
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

function fixture(t, { afterDownload = () => {}, paths = ['website/index.md'], checkout = commit,
  ancestor = true } = {}) {
  const directory = mkdtempSync(join(tmpdir(), 'filemint-deploy-test-'))
  t.after(() => rmSync(directory, { recursive: true, force: true }))
  const env = { ...environment, RUNNER_TEMP: directory, GITHUB_OUTPUT: join(directory, 'outputs') }
  const state = { build: structuredClone(buildRun), artifacts: [structuredClone(artifact)],
    main: structuredClone(main), release: structuredClone(published) }
  const calls = []
  const run = (command, args) => {
    calls.push([command, ...args])
    if (command === 'git') {
      if (args[0] === 'rev-parse') return checkout
      if (args[0] === 'merge-base') {
        if (!ancestor) throw Error('not an ancestor')
        assert.deepEqual(args, ['merge-base', '--is-ancestor', 'refs/tags/v1.2.3', 'HEAD'])
        return ''
      }
      if (args[0] === 'diff') return paths.join('\0') + '\0'
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
  return { env, run, calls }
}

test('reuses the successful archive with read-only commands and no rebuild or app release', t => {
  const options = fixture(t)
  const archive = prepareDeployment(options)
  assert.equal(readFileSync(archive, 'utf8'), 'verified website bytes')
  assert.equal(readFileSync(options.env.GITHUB_OUTPUT, 'utf8'), `archive=${archive}\n`)
  assert.equal(options.calls.filter(call => call[0] === 'gh' && call[1] === 'run').length, 1)
})

test('changed checkout, unrelated history or unpublished app code prevents downloading', t => {
  for (const changes of [{ checkout: 'b'.repeat(40) }, { ancestor: false }, { paths: ['project.yml'] }]) {
    const options = fixture(t, changes)
    assert.throws(() => prepareDeployment(options))
    assert.ok(options.calls.every(call => !(call[0] === 'gh' && call[1] === 'run')))
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
