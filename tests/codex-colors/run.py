"""Exercise streaming ANSI translation and the interactive terminal boundary."""

import importlib.util
import os
from pathlib import Path
import pty
import select
import signal
import subprocess
import sys
import termios
import time
import unittest

sys.dont_write_bytecode = True
SCRIPT = Path(__file__).resolve().parents[2] / "scripts/codex-colors.py"
spec = importlib.util.spec_from_file_location("codex_colors", SCRIPT)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
ARGS = ["--accent", "#8FBF88", "--selection", "#334936", "--selection-text", "#DEE7D5", "--"]


class ColorsTest(unittest.TestCase):
    def test_every_chunk_boundary(self):
        source = b"\x1b[1;38;2;99;168;248m>_\x1b[0m\x1b[38;2;0;0;46;48;2;99;168;248m/theme\x1b[0m"
        expected = b"\x1b[1;38;2;143;191;136m>_\x1b[0m\x1b[38;2;222;231;213;48;2;51;73;54m/theme\x1b[0m"
        for boundary in range(len(source) + 1):
            colors = module.ColorFilter("#8FBF88", "#334936", "#DEE7D5")
            self.assertEqual(colors.feed(source[:boundary]) + colors.feed(source[boundary:]) + colors.finish(), expected)

    def test_other_colors_and_terminal_protocols_pass_through(self):
        data = (
            "你好".encode()
            + b"\x1b[38;2;142;170;184mcode\x1b[0m\x1b[38;5;75mindexed\x1b[0m"
            + b"\x1b]10;rgb:d2/dc/d0\x07"
            + b"\x1b]title\x1b[38;2;99;168;248m\x1b\\"
            + b"\x1b_Gimage\x1b[38;2;99;168;248m\x1b\\"
            + b"\x1b[?2026h\x1b[2J\x1b[?2026l\x1b[38;2;"
        )
        colors = module.ColorFilter("#8FBF88", "#334936", "#DEE7D5")
        self.assertEqual(b"".join(colors.feed(bytes([byte])) for byte in data) + colors.finish(), data)

    def test_nonterminal_keeps_output_args_and_exit_status(self):
        child = "import os,sys; os.write(1, b'\\x1b[38;2;99;168;248m'); print(sys.argv[1]); sys.exit(7)"
        result = subprocess.run([sys.executable, str(SCRIPT), *ARGS, sys.executable, "-c", child, "space 中文"], capture_output=True)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, b"\x1b[38;2;99;168;248mspace " + "中文\n".encode())

    def test_pty_input_resize_colors_and_terminal_restore(self):
        master, slave = pty.openpty()
        termios.tcsetwinsize(slave, (24, 80))
        original = termios.tcgetattr(slave)
        child = """
import os, signal, termios, tty
tty.setraw(0)
def resized(*_):
    os.write(1, ('SIZE:%s\\n' % (termios.tcgetwinsize(0),)).encode())
signal.signal(signal.SIGWINCH, resized)
os.write(1, b'\\x1b[38;2;99;168;248mREADY\\x1b[0m\\n')
resized()
data = os.read(0, 100)
os.write(1, b'INPUT:' + data + b'\\n')
data = os.read(0, 100)
os.write(1, b'\\x1b[38;2;0;0;46;48;2;99;168;248mSELECTED\\x1b[0m\\n')
raise SystemExit(7)
"""
        process = subprocess.Popen([sys.executable, str(SCRIPT), *ARGS, sys.executable, "-c", child], stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        output = bytearray()

        def until(marker):
            deadline = time.monotonic() + 8
            while marker not in output:
                self.assertLess(time.monotonic(), deadline, bytes(output))
                if select.select([master], [], [], 0.1)[0]:
                    output.extend(os.read(master, 65536))

        try:
            until(b"SIZE:(24, 80)")
            os.write(master, "箭头\x1b[B".encode())
            until(b"INPUT:" + "箭头\x1b[B".encode())
            termios.tcsetwinsize(slave, (32, 100))
            process.send_signal(signal.SIGWINCH)
            until(b"SIZE:(32, 100)")
            os.write(master, b"exit")
            until(b"SELECTED")
            self.assertEqual(process.wait(timeout=8), 7)
            self.assertIn(b"\x1b[38;2;143;191;136mREADY", output)
            self.assertIn(b"\x1b[38;2;222;231;213;48;2;51;73;54mSELECTED", output)
            self.assertEqual(termios.tcgetattr(slave), original)
        finally:
            if process.poll() is None:
                process.send_signal(signal.SIGTERM)
                process.wait(timeout=8)
            os.close(master)
            os.close(slave)

    def test_pty_signal_exit_status_and_terminal_restore(self):
        master, slave = pty.openpty()
        original = termios.tcgetattr(slave)
        child = "import os,signal; os.kill(os.getpid(), signal.SIGTERM)"
        process = subprocess.Popen([sys.executable, str(SCRIPT), *ARGS, sys.executable, "-c", child], stdin=slave, stdout=slave, stderr=slave, start_new_session=True)
        try:
            self.assertEqual(process.wait(timeout=8), 143)
            self.assertEqual(termios.tcgetattr(slave), original)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=8)
            os.close(master)
            os.close(slave)


if __name__ == "__main__":
    unittest.main()
