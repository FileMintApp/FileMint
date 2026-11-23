#!/usr/bin/env python3
"""Exercise Debug bundle replacement with real directories on the same volume."""
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import install_debug as installer


class DebugInstallTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        self.staged = root / "Staged.app"
        self.destination = root / "FileMint.app"
        self.staged.mkdir()
        (self.staged / "new").touch()

    def previous_app(self):
        self.destination.mkdir()
        (self.destination / "old").touch()
        return installer.bundle_key(self.destination)

    def test_replacement_keeps_previous_bundle_until_verification(self):
        previous = self.previous_app()

        def verify(app, signatures):
            self.assertEqual(app, self.destination)
            self.assertTrue((app / "new").is_file())
            self.assertTrue((self.staged / "old").is_file())

        with patch.object(installer, "verify_copy", side_effect=verify):
            installer.replace_bundle(self.staged, self.destination, previous, ())
        self.assertTrue((self.destination / "new").is_file())

    def test_failed_verification_restores_previous_bundle(self):
        previous = self.previous_app()
        with patch.object(installer, "verify_copy", side_effect=installer.InstallError("signature failed")):
            with self.assertRaisesRegex(installer.InstallError, "signature failed"):
                installer.replace_bundle(self.staged, self.destination, previous, ())
        self.assertEqual(installer.bundle_key(self.destination), previous)
        self.assertTrue((self.destination / "old").is_file())
        self.assertTrue((self.staged / "new").is_file())

    def test_failed_first_install_removes_candidate_from_destination(self):
        with patch.object(installer, "verify_copy", side_effect=installer.InstallError("signature failed")):
            with self.assertRaisesRegex(installer.InstallError, "signature failed"):
                installer.replace_bundle(self.staged, self.destination, None, ())
        self.assertFalse(self.destination.exists())
        self.assertTrue((self.staged / "new").is_file())

    def test_concurrent_first_install_is_preserved(self):
        self.previous_app()
        with self.assertRaises(FileExistsError):
            installer.move_bundle(self.staged, self.destination, exchange=False)
        self.assertTrue((self.destination / "old").is_file())
        self.assertTrue((self.staged / "new").is_file())


if __name__ == "__main__":
    unittest.main()
