"""リリースの道具が共有する部品 (scripts/release/release_support.py) のテスト。"""

from __future__ import annotations

import contextlib
import io
import os
import tempfile
import unittest
from unittest import mock

import release_fakes

SUPPORT = release_fakes.load("release_support.py")


class FakeClock:
    """呼ばれるたびに進む時計。sleep は時計を進めるだけで、本当には待たない。"""

    def __init__(self, step_per_read: float = 0.0):
        self.now = 1000.0
        self.step_per_read = step_per_read
        self.sleeps: list[float] = []

    def clock(self) -> float:
        value = self.now
        self.now += self.step_per_read
        return value

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.now += seconds


class VersionTest(unittest.TestCase):
    def test_accepts_release_and_prerelease_forms(self):
        for version in ("0.1.0", "1.2.3", "10.20.30", "0.1.0-alpha.1", "0.1.0-beta.1", "1.0.0-rc.12"):
            with self.subTest(version=version):
                self.assertIsNone(SUPPORT.check_version(version))

    def test_rejects_other_forms(self):
        for version in ("v0.1.0", "0.1", "0.1.0-pre.1", "0.1.0-beta.0", "0.1.0-beta", "01.0.0", "0.1.0-SNAPSHOT", "", "0.1.0 "):
            with self.subTest(version=version):
                self.assertIn("版の形が違う", SUPPORT.check_version(version))


class WaitUntilTest(unittest.TestCase):
    def test_returns_value_when_probe_finishes(self):
        fake = FakeClock()
        answers = iter([(False, "まだ"), (False, "まだ"), (True, "できた")])
        value = SUPPORT.wait_until(lambda: next(answers), 60, 10, "テスト", clock=fake.clock, sleep=fake.sleep)
        self.assertEqual(value, "できた")
        self.assertEqual(fake.sleeps, [10, 10])

    def test_fails_when_the_deadline_is_reached(self):
        fake = FakeClock()
        calls = []

        def probe():
            calls.append(1)
            return False, "VALIDATING"

        with self.assertRaises(SUPPORT.WaitTimeout) as raised:
            SUPPORT.wait_until(probe, 120, 30, "決着", clock=fake.clock, sleep=fake.sleep)
        self.assertIn("上限 (2 分) までに終わらなかった", str(raised.exception))
        self.assertIn("VALIDATING", str(raised.exception))
        # 0・30・60・90・120 秒の 5 回で止まり、それより後は問い合わせない。
        self.assertEqual(len(calls), 5)
        self.assertLessEqual(sum(fake.sleeps), 120)

    def test_slow_probes_still_stop_at_the_deadline(self):
        # 問い合わせ 1 回ごとに時計が 50 秒進む (応答が遅い相手)。上限を過ぎた後に待ち直さない。
        fake = FakeClock(step_per_read=50)
        with self.assertRaises(SUPPORT.WaitTimeout):
            SUPPORT.wait_until(lambda: (False, "遅い"), 100, 30, "遅い相手", clock=fake.clock, sleep=fake.sleep)
        self.assertLessEqual(len(fake.sleeps), 2)

    def test_rejects_non_positive_limits(self):
        for timeout, interval in ((0, 10), (-1, 10), (10, 0)):
            with self.subTest(timeout=timeout, interval=interval):
                with self.assertRaises(SUPPORT.ReleaseError):
                    SUPPORT.wait_until(lambda: (True, None), timeout, interval, "テスト")

    def test_minutes_to_seconds(self):
        self.assertEqual(SUPPORT.minutes_to_seconds("60", "--timeout-minutes"), 3600)
        for value in ("0", "-1", "abc"):
            with self.subTest(value=value):
                with self.assertRaises(SUPPORT.ReleaseError):
                    SUPPORT.minutes_to_seconds(value, "--timeout-minutes")


class PomTest(unittest.TestCase):
    def test_reads_coordinates_and_commit(self):
        pom = SUPPORT.read_pom(release_fakes.pom_text("0.1.0-beta.1", "a" * 40))
        self.assertEqual(pom, {"groupId": "jp.kamusoft", "artifactId": "kscollectionview", "version": "0.1.0-beta.1", "scmTag": "a" * 40})

    def test_reads_pom_without_namespace_and_without_tag(self):
        text = "<project><groupId>g</groupId><artifactId>a</artifactId><version>1.0.0</version></project>"
        self.assertEqual(SUPPORT.read_pom(text)["scmTag"], None)
        self.assertEqual(SUPPORT.read_pom(text)["version"], "1.0.0")

    def test_rejects_broken_xml(self):
        with self.assertRaises(SUPPORT.ReleaseError):
            SUPPORT.read_pom("<project>")


class OutputTest(unittest.TestCase):
    def test_appends_outputs_to_the_github_output_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "output")
            with mock.patch.dict(os.environ, {"GITHUB_OUTPUT": path}), contextlib.redirect_stdout(io.StringIO()):
                SUPPORT.write_outputs({"a": "1"})
                SUPPORT.write_outputs({"b": "two"})
            with open(path, encoding="utf-8") as f:
                self.assertEqual(f.read(), "a=1\nb=two\n")

    def test_rejects_values_with_newlines(self):
        with self.assertRaises(SUPPORT.ReleaseError):
            SUPPORT.write_outputs({"a": "1\n2"})


if __name__ == "__main__":
    unittest.main()
