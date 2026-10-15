# Batch rename P1 implementation verification

Date: 2026-10-14. Parent: [batch rename task](../2026-10-14-batch-rename.md).

## Scope and result

**P1 complete; `make verify` passed. P2–P5 remain not started.**

Primary checkout, baseline `ea9259bb978b555051e31e7d708d2d3f5d0b6ec1` plus the
uncommitted P1 change. Runtime macOS 27.2 (`26B5101f`), arm64; Xcode 27.0
(`27A266a`), Swift 6.4. Verification used the repository's
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` and command-scoped
approved SwiftPM/Xcode access. No product installation, signing or release ran.

| Component | Implementation | Pure test coverage |
| --- | --- | --- |
| Name policy | [RenameNamePolicy.swift](../../../CorePackage/Sources/FileMintCore/RenameNamePolicy.swift) | [19 tests](../../../CorePackage/Tests/FileMintCoreTests/RenameNamePolicyTests.swift): exact UTF-8 parts, hidden marker, compound suffixes, strict changed output, 255/1024-byte limits, unchanged/restoration exemptions, namespace keys and ordering |
| Ordered rules | [BatchRenameRule.swift](../../../CorePackage/Sources/FileMintCore/BatchRenameRule.swift) | [12 tests](../../../CorePackage/Tests/FileMintCoreTests/BatchRenameRuleTests.swift): literal scalar-exact replacement/deletion, rule order, numbering, overflow and byte budgets, full Unicode case mappings |
| Planner | [BatchRenamePlanner.swift](../../../CorePackage/Sources/FileMintCore/BatchRenamePlanner.swift) | [21 tests](../../../CorePackage/Tests/FileMintCoreTests/BatchRenamePlannerTests.swift): sorted ordinal mapping, name-list binding/reassignment, conflicts including unchanged rows, swaps/cycles, injected failures/pending results, stale inputs and frozen value isolation |

The 52 new tests use synthetic descriptors and explicit target observations.
The planner does not access paths, read the clipboard, query metadata or mutate
files. A frozen plan is a naming proposal; native identity, parent, authorization,
availability and target revalidation remain P2 responsibilities.

## Observed verification

Final command:

```sh
make verify > .local/verification/batch-rename-p1-20261014-final.log 2>&1
```

Exit code: **0**.

| Check | Result |
| --- | --- |
| Core Swift tests | 287 tests / 30 suites passed, including all 52 new P1 tests |
| Image Swift tests | 22 tests / 2 suites passed |
| Public JSON creation Harness | 5/5 cases passed; format and cases unchanged |
| Real Harness CLI regressions | 10 tests passed |
| Remaining `make verify` checks | Context, fork sync, compression artifact, appcast, release tooling, Homebrew, entitlements and native-QA tooling checks passed |
| Product App / Finder build, installed native QA | Not run: P1 changes only Core pure logic; no P2–P5 integration exists |

Concise final log excerpts:

```text
Test run with 22 tests in 2 suites passed
Suite "Batch rename pure planning" passed
Suite "Batch rename ordered body rules" passed
Suite "Batch rename name policy" passed
Test run with 287 tests in 30 suites passed
PASSED suite: 5/5 cases executed, 5 passed, 0 failed, 0 case errors, 0 suite errors
Ran 10 tests ... OK
```

Release/signing/native-QA entries above are the repository's offline tooling
regressions. They do not mean FileMint was packaged, notarized, installed or
tested through Finder. This run also does not establish macOS 13 runtime behavior.

## Failures resolved during implementation

- The first run compiled successfully but found three new-test failures: Swift's
  context-insensitive lowercase mapping lost final-sigma behavior, and one mixed
  filename fixture assumed a different ordering from the SPEC's POSIX Foundation
  comparison. The fixture now asserts the actual specified order with independent
  constants; the sorting contract was unchanged.
- The second run fixed sigma and the planner fixture but exposed Greek accent
  changes from locale-tailored Foundation uppercasing. The rule engine now uses
  `CFStringUppercase` / `CFStringLowercase` with no language tailoring for both
  scalar length budgeting and whole-string output. Original sigma/accent/expansion
  expectations were retained. See [Apple's CF implementation](https://github.com/apple-oss-distributions/CF/blob/main/CFString.c)
  and [Unicode SpecialCasing](https://www.unicode.org/Public/UCD/latest/ucd/SpecialCasing.txt).
- The final version counts name-list lines before allocating row strings and
  covers a 1 MiB all-newline input. Target observations also explicitly reject a
  replacement batch even when the visible names and revision are unchanged.

Local full logs are retained in ignored `.local/verification/`:
`batch-rename-p1-20261014.log`, `batch-rename-p1-20261014-rerun.log`, and
`batch-rename-p1-20261014-final.log`. The final log SHA-256 is
`cf76d3650ae3d40482f2b931d43f1afd36bf4e1af15373eac42dfe911d5b6d48`.

## Tested source integrity

| File | SHA-256 |
| --- | --- |
| `BatchRenamePlanner.swift` | `2ed2f45b79a1952f7f79a7fabfc4a919857929745a08c46c7e95365c3afc1ca1` |
| `BatchRenameRule.swift` | `4935040935d6f0962e88c8a39fdad4f870dccb5e61d2c8eecbaca3786f51a6f2` |
| `RenameNamePolicy.swift` | `665917335e2e8fa889ea4ed19f012d311128c908e1961894e6a113486c206a9e` |
| `BatchRenamePlannerTests.swift` | `c4423bf81936e89ae1ee9e99277332508b2de09b559e4c860d260bed23deba5c` |
| `BatchRenameRuleTests.swift` | `d6a711e7c36b039bc8f5b672eef9847d2d1030459ebcb1d5f32eb40caed08784` |
| `RenameNamePolicyTests.swift` | `0a01861bd68e8e0aa96f29e59a2df26ef385a922fb7f624622ad85a8db6cf98f` |
