#!/usr/bin/env python3
"""Ensure a notarization timeout resumes the same submitted DMG."""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class NotarizationResumeTests(unittest.TestCase):
    def test_timeout_does_not_submit_again(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            dmg = work / "FileMint-0.6.0.dmg"
            dmg.write_bytes(b"signed test image")
            log = work / "calls.log"
            stub = work / "xcrun"
            stub.write_text("""#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
log = Path(os.environ['FILEMINT_NOTARY_TEST_LOG'])
with log.open('a') as output:
    output.write(' '.join(sys.argv[1:3]) + '\\n')
if sys.argv[1:3] == ['notarytool', 'submit']:
    print(json.dumps({'id': '12345678-1234-1234-1234-123456789abc'}))
elif sys.argv[1:3] == ['notarytool', 'wait']:
    attempts = sum(line == 'notarytool wait' for line in log.read_text().splitlines())
    if attempts == 1:
        sys.exit(1)
    print(json.dumps({'status': 'Accepted'}))
elif sys.argv[1] == 'stapler':
    sys.exit(0)
else:
    sys.exit(2)
""")
            stub.chmod(0o755)
            env = os.environ | {
                "PATH": f"{work}:{os.environ['PATH']}",
                "APPLE_NOTARY_KEYCHAIN_PROFILE": "FileMint",
                "FILEMINT_NOTARY_TEST_LOG": str(log),
            }
            command = ["bash", str(ROOT / "scripts/notarize_dmg.sh"), str(dmg)]
            first = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertNotEqual(first.returncode, 0)
            record = json.loads(Path(str(dmg) + ".notary.json").read_text())
            self.assertEqual(record["id"], "12345678-1234-1234-1234-123456789abc")
            second = subprocess.run(command, env=env, capture_output=True, text=True)
            self.assertEqual(second.returncode, 0, second.stderr)
            calls = log.read_text().splitlines()
            self.assertEqual(calls.count("notarytool submit"), 1)
            self.assertEqual(calls.count("notarytool wait"), 2)
            self.assertEqual(calls.count("stapler staple"), 1)
            self.assertEqual(calls.count("stapler validate"), 1)


if __name__ == "__main__":
    unittest.main()
