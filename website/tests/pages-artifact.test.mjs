import test from 'node:test'
import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

function runWait(script, { first = '', later = '', status = '0' } = {}) {
  return spawnSync('bash', ['--noprofile', '--norc', '-eo', 'pipefail', '-c', `
    polls=0
    sleep() {
      polls=$((polls + 1))
      printf '%s\n' "$1"
    }
    gh() {
      [[ $# == 8 && $1 == api && $2 == --method && $3 == GET &&
         $4 == repos/FileMintApp/FileMint/actions/runs/42/artifacts &&
         $5 == -f && $6 == name=github-pages-2 && $7 == --jq ]] || return 91
      if [[ $polls == 1 ]]; then
        printf '%s' "$FIXTURE_FIRST"
        return "$FIXTURE_STATUS"
      fi
      printf '%s' "$FIXTURE_LATER"
    }
    ${script}
  `], {
    encoding: 'utf8',
    timeout: 5000,
    env: {
      ...process.env,
      GITHUB_REPOSITORY: 'FileMintApp/FileMint', GITHUB_RUN_ID: '42',
      PAGES_ARTIFACT_NAME: 'github-pages-2', PAGES_ARTIFACT_ID: '72',
      FIXTURE_FIRST: first, FIXTURE_LATER: later, FIXTURE_STATUS: status,
    },
  })
}

for (const file of ['deploy-website.yml', 'deploy-pages.yml']) {
  test(`${file} waits for the exact upload and keeps attempts separate`, () => {
    const workflow = readFileSync(new URL(`../../.github/workflows/${file}`, import.meta.url), 'utf8')
    const upload = workflow.indexOf('      - uses: actions/upload-artifact@')
    const wait = workflow.indexOf('      - name: Wait for the uploaded Pages artifact')
    const deploy = workflow.indexOf('        uses: actions/deploy-pages@')
    assert.ok(0 <= upload && upload < wait && wait < deploy)
    assert.match(workflow, /PAGES_ARTIFACT_NAME: github-pages-\$\{\{ github\.run_attempt \}\}/)
    assert.match(workflow.slice(upload, wait), /name: \$\{\{ env\.PAGES_ARTIFACT_NAME \}\}/)
    assert.match(workflow.slice(wait, deploy), /PAGES_ARTIFACT_ID: \$\{\{ steps\.pages_upload\.outputs\.artifact-id \}\}/)
    assert.match(workflow.slice(deploy), /artifact_name: \$\{\{ env\.PAGES_ARTIFACT_NAME \}\}/)

    const script = workflow.slice(wait, deploy).match(/^        run: \|\n((?: {10}[^\n]*\n)+)/m)?.[1]
    assert.ok(script)

    const delayed = runWait(script, { later: '72' })
    assert.equal(delayed.status, 0, delayed.stderr)
    assert.equal(delayed.stdout, '2\n4\n')

    const missing = runWait(script)
    assert.equal(missing.status, 1, missing.stderr)
    assert.match(missing.stdout, /^2\n4\n8\n16\n30\n::error::GitHub did not list Pages artifact 72/)

    for (const first of ['73', '72\n73', 'expired']) {
      const unexpected = runWait(script, { first, later: '72' })
      assert.equal(unexpected.status, 1, unexpected.stderr)
      assert.match(unexpected.stdout, /^2\n::error::Unexpected or ambiguous Pages artifact/)
    }

    const unavailable = runWait(script, { status: '22', later: '72' })
    assert.equal(unavailable.status, 22, unavailable.stderr)
    assert.equal(unavailable.stdout, '2\n')
  })
}
