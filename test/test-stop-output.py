#!/usr/bin/env python3
"""Exercise Stop output without invoking Claude or using personal transcripts."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parent.parent


class StopOutputTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="latte-stop-test-")
        self.addCleanup(self.scratch.cleanup)
        self.home = Path(self.scratch.name)
        bin_dir = self.home / "bin"
        bin_dir.mkdir()
        scripts = {
            "timeout": '#!/bin/bash\nif [ -n "$TEST_TIMEOUT_EXIT" ]; then exit "$TEST_TIMEOUT_EXIT"; fi\nshift\nexec "$@"\n',
            "claude": '#!/bin/bash\nprintf "%s\\n" "$TEST_JUDGE_OUTPUT"\nexit "${TEST_JUDGE_EXIT:-0}"\n',
        }
        for name, body in scripts.items():
            path = bin_dir / name
            path.write_text(body)
            path.chmod(0o700)
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(bin_dir) + os.pathsep + os.environ["PATH"],
                        CLAUDE_HOOK_JUDGE_MODE="false", TEST_TIMEOUT_EXIT="", TEST_JUDGE_EXIT="0",
                        TEST_JUDGE_OUTPUT=json.dumps({"structured_output": {"should_continue": False, "reasoning": "Done"}}))
        self.session = "latte-stop-test-" + uuid.uuid4().hex
        self.throttle = Path("/tmp/.claude-continue-throttle-" + self.session)
        self.addCleanup(lambda: self.throttle.unlink(missing_ok=True))
        transcript = self.home / "transcript.jsonl"
        transcript.write_text('{"role":"assistant","content":"Done"}\n')
        self.event = {"session_id": self.session, "transcript_path": str(transcript), "stop_hook_active": False}

    def run_hook(self):
        result = subprocess.run(["bash", str(ROOT / "hooks/run-hook.cmd"), "claude-judge-continuation"],
                                input=json.dumps(self.event), text=True, capture_output=True, env=self.env, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertIsInstance(output, dict)
        # Codex's stop.command.output schema permits only "block" or an omitted decision.
        self.assertIn(output.get("decision"), (None, "block"), result.stdout)
        return output

    def test_recursion_allows_stop(self):
        self.env["CLAUDE_HOOK_JUDGE_MODE"] = "true"
        self.assertEqual(self.run_hook(), {})

    def test_missing_transcript_allows_stop(self):
        self.event.pop("transcript_path")
        self.assertEqual(self.run_hook(), {})

    def test_throttle_allows_stop_and_clears_counter(self):
        self.event["stop_hook_active"] = True
        self.throttle.write_text("3:" + str(int(time.time())))
        self.assertEqual(self.run_hook(), {})
        self.assertFalse(self.throttle.exists())

    def test_timeout_allows_stop(self):
        self.env["TEST_TIMEOUT_EXIT"] = "124"
        self.assertEqual(self.run_hook(), {})

    def test_judge_failure_allows_stop(self):
        self.env["TEST_JUDGE_EXIT"] = "1"
        self.assertEqual(self.run_hook(), {})

    def test_invalid_judge_json_allows_stop(self):
        self.env["TEST_JUDGE_OUTPUT"] = "not JSON"
        self.assertEqual(self.run_hook(), {})

    def test_missing_structured_output_allows_stop(self):
        self.env["TEST_JUDGE_OUTPUT"] = "{}"
        self.assertEqual(self.run_hook(), {})

    def test_completed_work_allows_stop_and_clears_counter(self):
        self.throttle.write_text("1:" + str(int(time.time())))
        self.assertEqual(self.run_hook(), {})
        self.assertFalse(self.throttle.exists())

    def test_unfinished_work_still_blocks_stop(self):
        self.env["TEST_JUDGE_OUTPUT"] = json.dumps({"structured_output": {"should_continue": True, "reasoning": "Run the tests"}})
        output = self.run_hook()
        self.assertEqual(output["decision"], "block")
        self.assertIn("Run the tests", output["reason"])
        self.assertEqual(self.throttle.read_text().split(":")[0], "1")


if __name__ == "__main__":
    unittest.main(verbosity=2)
