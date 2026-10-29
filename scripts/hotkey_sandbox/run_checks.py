#!/usr/bin/env python3
"""Coordinate two independently sandboxed, owned QA processes through pipes."""
import json
from pathlib import Path
import select
import subprocess
import sys
import time


def read_line(process, timeout):
    if not select.select([process.stdout], [], [], timeout)[0]:
        raise RuntimeError("QA pipe readiness timed out")
    return process.stdout.readline()


def stop(process):
    if process is None:
        return
    if process.stdin and not process.stdin.closed:
        process.stdin.close()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        # Only this driver's own new process. No force-kill or discovered apps.
        process.terminate()
        process.wait(timeout=5)


def main():
    root = Path(__file__).resolve().parents[2]
    app = Path(sys.argv[1]).absolute()
    expected = root / 'build/native-qa.noindex/hotkey-sandbox/FileMintHotKeyQA.app'
    if app != expected or app.is_symlink():
        raise RuntimeError("Expected the stable hotkey QA bundle")
    host = peer = None
    try:
        host = subprocess.Popen([app / 'Contents/MacOS/FileMintHotKeyQA', '--verify-automation'],
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
        deadline = time.monotonic() + 60
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise RuntimeError("Hotkey QA deadline exceeded")
            line = read_line(host, min(10, remaining))
            if not line:
                break
            sys.stdout.buffer.write(line)
            sys.stdout.buffer.flush()
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if event.get('event') == 'peer-start':
                if peer is not None:
                    raise RuntimeError("Contender already running")
                arguments = [app / 'Contents/Resources/FileMintHotKeyPeer.app/Contents/MacOS/FileMintHotKeyPeer', '--contender']
                if event.get('primary'):
                    arguments.append('--primary')
                peer = subprocess.Popen(arguments, stdin=subprocess.PIPE, stdout=subprocess.PIPE, bufsize=0)
                if read_line(peer, 10) != b'READY exclusive\n':
                    raise RuntimeError("Contender did not register its exclusive key")
                host.stdin.write(b'READY exclusive\n')
                host.stdin.flush()
            elif event.get('event') == 'peer-stop':
                if peer is None:
                    raise RuntimeError("Missing contender")
                stop(peer)
                if peer.returncode != 0:
                    raise RuntimeError("Contender failed during cleanup")
                peer = None
                host.stdin.write(b'STOPPED\n')
                host.stdin.flush()
        if host.wait(timeout=5) != 0:
            raise RuntimeError("Hotkey host failed")
    finally:
        stop(peer)
        stop(host)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'FAIL hotkey driver: {error}', flush=True)
        sys.exit(1)
