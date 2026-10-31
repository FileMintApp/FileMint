#!/usr/bin/env python3
"""Offline regressions for selection and actual subprocess/result semantics; no GUI or keys."""
from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
import native_checks as checks


class SelectionTests(unittest.TestCase):
    def test_launcher_probe_requires_real_system_delivery(self):
        plan = checks.plan_checks(['scripts/launcher_integration/ProbeApp.swift',
                                  'scripts/build_launcher_integration_harness.sh'])
        self.assertEqual(plan['suites'], [])
        self.assertEqual([item['id'] for item in plan['manualChecks']], ['launcher-integration'])
        self.assertEqual(plan['requiresReview'], [])

    def test_product_launcher_fixture_has_its_own_real_entry_boundary(self):
        plan = checks.plan_checks(['scripts/launcher_product/FixtureApp.swift',
                                  'scripts/build_launcher_product_harness.sh'])
        self.assertEqual(plan['suites'], [])
        self.assertEqual([item['id'] for item in plan['manualChecks']], ['launcher-product'])
        self.assertEqual(plan['requiresReview'], [])

    def test_visibility_uses_existing_sandbox_identity_and_keeps_finder_boundary(self):
        plan = checks.plan_checks(['CorePackage/Sources/FileMintCore/FileVisibility.swift'])
        self.assertCountEqual(plan['suites'], ['file-visibility', 'file-tools-settings'])
        self.assertEqual([item['id'] for item in plan['manualChecks']], ['finder'])
        self.assertEqual(checks.SUITES['file-visibility'].kind, 'template-workflow')
    def test_hotkey_prototype_keeps_interactive_keyboard_boundary_explicit(self):
        plan = checks.plan_checks(['scripts/hotkey_sandbox/HotKeyService.swift',
                                  'scripts/build_hotkey_sandbox_harness.sh'])
        self.assertEqual(plan['suites'], ['hotkey-sandbox'])
        self.assertEqual([item['id'] for item in plan['manualChecks']], ['global-hotkey'])
        self.assertEqual(checks.SUITES['hotkey-sandbox'].arguments, ('--verify-automation',))

    def test_docs_and_pure_core_rules_do_not_start_native_checks(self):
        plan = checks.plan_checks(['docs/FINDER_QA.md', 'specs/domains/creation.md',
                                   'CorePackage/Sources/FileMintCore/FilenamePolicy.swift'])
        self.assertEqual(plan['suites'], [])
        self.assertEqual(plan['manualChecks'], [])

    def test_native_surface_selects_only_its_existing_fixture(self):
        self.assertEqual(checks.plan_checks(['App/FileMint/BatchRenameController.swift'])['suites'], ['batch-rename'])
        self.assertEqual(checks.plan_checks(['scripts/resource_tools_smoke.swift'])['suites'], ['resource-tools'])
        plan = checks.plan_checks(['App/FileMint/FileInfoController.swift'])
        self.assertEqual(plan['suites'], ['file-info'])
        self.assertEqual([value['id'] for value in plan['manualChecks']], ['folder-grants'])
        self.assertEqual(checks.plan_checks(['App/FileMint/FileContentCopyController.swift'])['suites'], ['file-info'])

    def test_build_configuration_and_ci_edits_use_other_harness_checks(self):
        plan = checks.plan_checks(['project.yml', 'CorePackage/Package.swift', '.github/workflows/ci.yml'])
        self.assertEqual(plan['suites'], [])
        self.assertEqual(plan['requiresReview'], [])
        self.assertEqual(checks.plan_checks(['Config/FileMint.entitlements'])['requiresReview'], ['Config/FileMint.entitlements'])

    def test_summary_presentation_uses_the_existing_design_fixture_without_installer_checks(self):
        plan = checks.plan_checks(["App/FileMint/AboutPane.swift", "App/FileMint/UserGuideLink.swift"])
        self.assertEqual(plan["suites"], ["update-summary"])
        self.assertEqual(plan["manualChecks"], [])
        self.assertEqual(checks.SUITES["update-summary"].kind, "design-ui")

    def test_shared_model_has_a_conservative_explainable_plan(self):
        path = 'App/FileMint/PreferencesModel.swift'
        plan = checks.plan_checks([path, path])
        self.assertEqual(plan['suites'], ['template-workflow', 'creation-opening', 'update-scheduling', 'design-ui', 'quick-search'])
        self.assertTrue(all(reason == [path] for reason in plan['reasons'].values()))

    def test_manual_boundaries_and_unknown_app_code_are_never_silent_passes(self):
        plan = checks.plan_checks(['App/FileMint/OpenWithFolderAccess.swift', 'App/FileMint/NewFeature.swift'])
        self.assertEqual(plan['suites'], ['open-with'])
        self.assertEqual([value['id'] for value in plan['manualChecks']], ['folder-grants'])
        self.assertEqual(plan['requiresReview'], ['App/FileMint/NewFeature.swift'])

    def test_reviewed_explicit_scope_is_distinct_and_rejects_interactive_modes(self):
        plan = checks.plan_checks(['App/FileMint/PreferencesModel.swift'], explicit=['update-scheduling'])
        self.assertEqual(plan['suites'], ['update-scheduling'])
        self.assertEqual(plan['selection'], 'explicit')
        with self.assertRaises(ValueError):
            checks.plan_checks([], explicit=['sparkle-installation'])
        for path in ['/tmp/file', '../outside']:
            with self.assertRaises(ValueError):
                checks.plan_checks([path])

    def test_runner_only_edits_use_offline_checks_without_replaying_every_gui(self):
        plan = checks.plan_checks(['scripts/native_checks.py', 'scripts/test_native_checks.py', 'Makefile'])
        self.assertEqual(plan['suites'], [])
        self.assertEqual(plan['manualChecks'], [])
        self.assertEqual(checks.plan_checks(['scripts/native_qa.py'])['suites'], list(checks.ALL))
        self.assertEqual(checks.plan_checks([], all_suites=True)['suites'], list(checks.ALL))

    def test_child_environment_removes_external_app_and_interactive_overrides(self):
        with patch.dict(os.environ, {'FILEMINT_TERMINAL_MODE': 'newWindow', 'FILEMINT_OPEN_WITH_APP': 'code',
                                     'FILEMINT_TEMPLATE_QA_MODE': 'opening-apps', 'FILEMINT_BATCH_RENAME_MODE': 'external-export',
                                     'FILEMINT_QA_CODESIGN_IDENTITY': 'Developer ID Application: QA'}):
            environment = checks.child_environment(checks.SUITES['creation-opening'])
        self.assertEqual(environment['FILEMINT_TEMPLATE_QA_MODE'], 'opening')
        self.assertEqual(environment['FILEMINT_QA_CODESIGN_IDENTITY'], 'Developer ID Application: QA')
        self.assertNotIn('FILEMINT_TERMINAL_MODE', environment)
        self.assertNotIn('FILEMINT_OPEN_WITH_APP', environment)
        self.assertNotIn('FILEMINT_BATCH_RENAME_MODE', environment)


class GitSelectionTests(unittest.TestCase):
    def test_staged_unstaged_untracked_and_both_rename_paths_are_included(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            def git(*arguments):
                return subprocess.check_output(['git', *arguments], cwd=root, stderr=subprocess.DEVNULL)
            git('init', '-q')
            git('config', 'user.name', 'Native QA fixture')
            git('config', 'user.email', 'fixture@example.invalid')
            (root / 'old name.swift').write_text('original')
            (root / 'edited.swift').write_text('old')
            git('add', '.')
            git('commit', '-qm', 'fixture baseline')
            base = git('rev-parse', 'HEAD').decode().strip()
            git('mv', 'old name.swift', 'new name.swift')
            (root / 'edited.swift').write_text('new')
            (root / 'untracked.swift').write_text('new source')
            with patch.object(checks, 'ROOT', root):
                self.assertEqual(checks.changed_paths(), ['edited.swift', 'new name.swift', 'old name.swift', 'untracked.swift'])
                before = checks.source_state()
                (root / 'untracked.swift').write_text('changed while running')
                self.assertNotEqual(checks.source_state(), before)
                git('add', '.')
                git('commit', '-qm', 'fixture change')
                self.assertEqual(checks.changed_paths(base), ['edited.swift', 'new name.swift', 'old name.swift', 'untracked.swift'])
                self.assertEqual(checks.changed_paths(), [])


class InputTests(unittest.TestCase):
    def test_docs_and_other_fixtures_leave_inputs_valid_while_real_inputs_invalidate(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(checks, 'ROOT', Path(temporary)):
            root = Path(temporary)
            def write(name, value='fixture'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(value)
            initial = checks.fixture_inputs('design-ui')['sha256']
            for name in ['docs/task.md', 'specs/HARNESS.md', 'scripts/launcher_product/FixtureApp.swift']:
                write(name)
                self.assertEqual(checks.fixture_inputs('design-ui')['sha256'], initial)
            for name in ['App/FileMint/NewUntrackedView.swift', 'CorePackage/Sources/FileMintCore/Policy.swift',
                         'scripts/design_ui_smoke.swift', 'scripts/build_design_ui_harness.sh',
                         'CorePackage/Tests/FileMintCoreTests/Fixtures/update-release-notes.md', 'Resources/icon.png']:
                before = checks.fixture_inputs('design-ui')['sha256']
                write(name)
                self.assertNotEqual(checks.fixture_inputs('design-ui')['sha256'], before, name)

    def test_source_link_target_changes_are_detected_and_escaping_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'target.swift').write_text('before')
            link = root / 'alias.swift'
            link.symlink_to('target.swift')
            with patch.object(checks, 'ROOT', root):
                before = checks.file_manifest([link])
                (root / 'target.swift').write_text('after')
                self.assertNotEqual(checks.file_manifest([link]), before)
                link.unlink()
                link.symlink_to(root.parent)
                with self.assertRaises(checks.qa.QAError):
                    checks.file_manifest([root])


class ProcessTests(unittest.TestCase):
    def run_child(self, source, timeout=5):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        log = Path(temporary.name) / 'run.log'
        log.write_text('PASS fixture completion\n')  # Never accept retained output.
        return checks.execute([sys.executable, '-c', source], log, timeout, ('PASS fixture completion',))

    def test_exit_zero_and_completion_marker_are_both_required(self):
        self.assertEqual(self.run_child("print('PASS fixture completion')")['status'], 'passed')
        self.assertEqual(self.run_child("print('READY only')")['status'], 'failed')
        self.assertEqual(self.run_child("print('PASS fixture completion'); raise SystemExit(17)")['exitCode'], 17)

    def test_explicit_failure_and_signal_exit_cannot_be_hidden_by_success_text(self):
        self.assertEqual(self.run_child("print('FAIL assertion'); print('PASS fixture completion')")['status'], 'failed')
        result = self.run_child('import os, signal; os.kill(os.getpid(), signal.SIGTERM)')
        self.assertEqual(result['status'], 'failed')
        self.assertLess(result['exitCode'], 0)

    def test_timeout_is_failure_even_if_owned_process_exits_zero_on_term(self):
        source = "import signal, sys, time; signal.signal(signal.SIGTERM, lambda *_: sys.exit(0)); print('PASS fixture completion', flush=True); time.sleep(30)"
        result = self.run_child(source, timeout=0.3)
        self.assertTrue(result['timedOut'])
        self.assertEqual(result['status'], 'failed')


class ReportTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.addCleanup(patch.stopall)
        patch.object(checks, 'ROOT', self.root).start()
        patch.object(checks, 'source_state', return_value={'commit': 'fixture', 'workingDiffSHA256': 'fixture'}).start()

    def test_empty_plan_needs_no_signer_and_is_not_applicable(self):
        with patch.object(checks, 'preflight') as preflight:
            report = checks.run_plan(checks.plan_checks(['docs/DEVELOPMENT.md']))
        self.assertEqual(report['status'], 'not-applicable')
        preflight.assert_not_called()
        self.assertEqual(report['checks'], [])

    def test_missing_environment_reports_every_unrun_suite_and_preserves_report(self):
        with patch.object(checks, 'preflight', side_effect=checks.qa.QAError('Signing identity unavailable')):
            report = checks.run_plan(checks.plan_checks([], explicit=['batch-rename', 'open-with']))
        self.assertEqual(report['status'], 'blocked')
        self.assertEqual([check['status'] for check in report['checks']], ['not-run', 'not-run'])
        saved = json.loads(Path(report['report']).read_text())
        self.assertIn('Signing identity unavailable', saved['error'])

    def test_preparation_failure_does_not_run_an_old_fixture_or_become_a_blocked_pass(self):
        with patch.object(checks, 'preflight'), patch.object(checks, 'execute', return_value={'status': 'failed', 'exitCode': 65}) as execute:
            report = checks.run_plan(checks.plan_checks([], explicit=['design-ui']))
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(execute.call_count, 1)
        self.assertEqual(report['checks'][0]['status'], 'not-run')

    def test_manual_or_unmapped_only_plan_returns_blocked_without_launching_any_app(self):
        with patch.object(checks, 'preflight') as preflight:
            report = checks.run_plan(checks.plan_checks(['App/FileMint/SparkleInstaller.swift']))
        self.assertEqual(report['status'], 'blocked')
        preflight.assert_not_called()

    def test_failed_native_builder_never_launches_the_retained_bundle(self):
        with patch.object(checks, 'preflight'), patch.object(checks.qa, 'app_path', return_value=self.root / 'retained.app'), \
             patch.object(checks, 'execute', return_value={'status': 'failed', 'exitCode': 65}) as execute, \
             patch.object(checks, 'verify_fixture') as verify:
            report = checks.run_plan(checks.plan_checks([], explicit=['file-tools-settings']))
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(execute.call_count, 1)
        verify.assert_not_called()

    def test_successful_subprocess_and_documentation_updates_remain_valid(self):
        original = checks.execute
        def child(arguments, log, timeout, markers=(), environment=None):
            (self.root / 'docs').mkdir(exist_ok=True)
            (self.root / 'docs/task.md').write_text('Progress updated during QA')
            return original([sys.executable, '-c', "print('PASS favorite model fixture')"], log, timeout, markers)
        with patch.object(checks, 'preflight'), patch.object(checks, 'execute', side_effect=child), redirect_stdout(io.StringIO()):
            report = checks.run_plan(checks.plan_checks([], explicit=['favorite-model']))
        self.assertEqual(report['status'], 'passed')
        self.assertEqual(report['checks'][0]['exitCode'], 0)
    def test_relevant_source_edit_blocks_observed_success(self):
        original = checks.execute
        def child(arguments, log, timeout, markers=(), environment=None):
            path = self.root / 'scripts/favorite_model_smoke.swift'
            path.parent.mkdir(exist_ok=True)
            path.write_text('Changed during this check')
            return original([sys.executable, '-c', "print('PASS favorite model fixture')"], log, timeout, markers)
        with patch.object(checks, 'preflight'), patch.object(checks, 'execute', side_effect=child), redirect_stdout(io.StringIO()):
            changed = checks.run_plan(checks.plan_checks([], explicit=['favorite-model']))
        self.assertEqual(changed['status'], 'blocked')
        self.assertEqual(changed['checks'][0]['observedStatus'], 'passed')
        self.assertIn('inputs changed', changed['checks'][0]['reason'])

    def test_a_concurrent_runner_cannot_share_the_same_report_or_execute(self):
        base = self.root / 'build/native-checks.noindex'
        base.mkdir(parents=True)
        with checks.lock_file(base / 'runner.lock'), patch.object(checks, 'preflight') as preflight:
            report = checks.run_plan(checks.plan_checks([], explicit=['batch-rename']))
        self.assertEqual(report['status'], 'blocked')
        self.assertIn('Another native QA', report['error'])
        preflight.assert_not_called()

    def test_stale_published_run_is_rejected_before_signing_or_launching(self):
        app = self.root / 'QA.app'
        with patch.object(checks.qa, 'app_path', return_value=app), patch.object(checks.qa, 'read_info', return_value={
                'CFBundleIdentifier': checks.qa.KINDS['batch-rename'][1], 'FixtureRunID': 'run.old'}), patch.object(checks.qa, 'verified_requirement') as verify:
            with self.assertRaisesRegex(checks.qa.QAError, 'stale'):
                checks.verify_fixture('batch-rename', previous_run='run.old')
        verify.assert_not_called()


class BuildReuseTests(unittest.TestCase):
    """Use real child processes and bundle files; only the macOS signer is injected."""
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.addCleanup(patch.stopall)
        self.root = Path(temporary.name)
        self.app = self.root / 'build/native-qa.noindex/file-tools-settings/QA.app'
        self.app.parent.mkdir(parents=True)
        self.executions = self.root / 'executions'
        self.executions.mkdir()
        self.builds = 0
        self.fail_build = self.fail_runtime = False
        self.identity = 'Developer ID Application: Fixture'
        self.requirement = 'designated => fixture'
        self.original_execute = checks.execute
        patch.object(checks, 'ROOT', self.root).start()
        patch.object(checks, 'source_state', return_value={'commit': 'fixture'}).start()
        patch.object(checks, 'preflight', return_value={'xcode': 'fixture compiler', 'swift': 'fixture swift'}).start()
        patch.object(checks.qa, 'app_path', return_value=self.app).start()
        patch.object(checks.qa, 'assert_stopped').start()
        patch.object(checks.qa, 'signing_identity', return_value=self.identity).start()
        self.signer = patch.object(checks.qa, 'verified_requirement', return_value=self.requirement).start()
        patch.object(checks, 'execute', side_effect=self.execute).start()

    def execute(self, arguments, log, timeout, markers=(), environment=None):
        if list(arguments)[:2] == ['bash', checks.BUILDERS['file-tools-settings']]:
            self.builds += 1
            if self.fail_build:
                return self.original_execute([sys.executable, '-c', 'raise SystemExit(65)'], log, timeout)
            resources = self.app / 'Contents/Resources'
            resources.mkdir(parents=True, exist_ok=True)
            (resources / 'fixture.txt').write_text('sealed build resource')
            workspace = self.root / f'build/fixture-run-{self.builds}'
            workspace.mkdir()
            info = {'CFBundleIdentifier': checks.qa.KINDS['file-tools-settings'][1],
                    'CFBundleExecutable': 'fixture', 'FixtureRunID': f'run.{self.builds}', 'FixturePath': str(workspace)}
            (self.app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
            executable = self.app / 'Contents/MacOS/fixture'
            executable.parent.mkdir(exist_ok=True)
            executable.write_text(f'''#!{sys.executable}
from pathlib import Path
import uuid
workspace = Path({str(self.executions)!r}) / uuid.uuid4().hex
workspace.mkdir()
(workspace / 'result.txt').write_text('new execution')
print('PASS native icon styles')
''')
            executable.chmod(0o755)
            checks.qa.write_json(self.app.parent / 'identity.json', dict(workspace=str(self.root), appPath=str(self.app),
                bundleID=info['CFBundleIdentifier'], signingIdentity=self.identity, designatedRequirement=self.requirement))
            return self.original_execute([sys.executable, '-c', "print('Built disposable fixture')"], log, timeout)
        if self.fail_runtime:
            return self.original_execute([sys.executable, '-c', "print('PASS native icon styles'); raise SystemExit(1)"], log, timeout, markers)
        return self.original_execute(arguments, log, timeout, markers, environment)

    def run_checks(self, rebuild=False, suites=('file-tools-settings',)):
        with redirect_stdout(io.StringIO()):
            return checks.run_plan(checks.plan_checks([], explicit=suites), rebuild=rebuild)

    def test_matching_build_is_verified_and_reused_but_checks_and_data_are_new(self):
        first = self.run_checks()
        second = self.run_checks()
        self.assertEqual([first['status'], second['status']], ['passed', 'passed'])
        self.assertEqual(self.builds, 1)
        self.assertEqual(second['builds'][0]['mode'], 'reused')
        self.assertEqual(first['checks'][0]['fixture']['runID'], second['checks'][0]['fixture']['runID'])
        self.assertNotEqual(first['report'], second['report'])
        self.assertEqual(len(list(self.executions.iterdir())), 2)
        self.assertGreaterEqual(self.signer.call_count, 4)

    def test_source_or_signed_resource_changes_rebuild_instead_of_using_stale_code(self):
        self.assertEqual(self.run_checks()['status'], 'passed')
        path = self.root / 'App/FileMint/Changed.swift'
        path.parent.mkdir(parents=True)
        path.write_text('new source')
        self.assertEqual(self.run_checks()['status'], 'passed')
        self.assertEqual(self.builds, 2)
        (self.app / 'Contents/Resources/fixture.txt').write_text('replaced resource')
        self.assertEqual(self.run_checks()['status'], 'passed')
        self.assertEqual(self.builds, 3)

    def test_forced_failed_build_preserves_app_and_invalidates_cache_without_fallback(self):
        self.assertEqual(self.run_checks()['status'], 'passed')
        original = checks.file_manifest([self.app], self.app)
        self.fail_build = True
        self.assertEqual(self.run_checks(rebuild=True)['status'], 'failed')
        self.assertEqual(checks.file_manifest([self.app], self.app), original)
        self.assertFalse((self.app.parent / 'build-cache.json').exists())
        self.assertEqual(self.run_checks()['status'], 'failed')
        self.assertEqual(self.builds, 3)
        self.assertEqual(len(list(self.executions.iterdir())), 1)

    def test_cached_build_does_not_hide_failed_execution(self):
        self.assertEqual(self.run_checks()['status'], 'passed')
        self.fail_runtime = True
        report = self.run_checks()
        self.assertEqual(report['builds'][0]['mode'], 'reused')
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['checks'][0]['exitCode'], 1)

    def test_toolchain_or_build_flags_require_a_new_build(self):
        self.assertEqual(self.run_checks()['status'], 'passed')
        with patch.dict(os.environ, {'CFLAGS': '-DQA_CHANGED'}):
            self.assertEqual(self.run_checks()['status'], 'passed')
        self.assertEqual(self.builds, 2)

    def test_reused_build_still_rejects_bad_identity_and_symlink_cache(self):
        self.assertEqual(self.run_checks()['status'], 'passed')
        with patch.object(checks.qa, 'verified_requirement', side_effect=checks.qa.QAError('Bad signature')):
            self.assertEqual(self.run_checks()['status'], 'blocked')
        cache = self.app.parent / 'build-cache.json'
        cache.unlink()
        target = self.root / 'untouched.json'
        target.write_text('preserve')
        cache.symlink_to(target)
        self.assertEqual(self.run_checks()['status'], 'blocked')
        self.assertEqual(target.read_text(), 'preserve')
        self.assertEqual(self.builds, 1)
        self.assertEqual(len(list(self.executions.iterdir())), 1)

    def test_only_changed_fixture_results_are_invalidated(self):
        original_execute = self.execute
        def changed(arguments, log, timeout, markers=(), environment=None):
            if list(arguments)[:2] == ['bash', 'scripts/verify_favorite_model.sh']:
                path = self.root / 'scripts/file_tools_settings_smoke.swift'
                path.parent.mkdir(exist_ok=True)
                path.write_text('Changed after icons completed')
                return self.original_execute([sys.executable, '-c', "print('PASS favorite model fixture')"], log, timeout, markers)
            return original_execute(arguments, log, timeout, markers, environment)
        with patch.object(checks, 'execute', side_effect=changed):
            report = self.run_checks(suites=('file-tools-settings', 'favorite-model'))
        states = {item['suite']: item['status'] for item in report['checks']}
        self.assertEqual(states, {'file-tools-settings': 'blocked', 'favorite-model': 'passed'})
        self.assertEqual(report['checks'][0]['observedStatus'], 'passed')


if __name__ == '__main__':
    unittest.main()
