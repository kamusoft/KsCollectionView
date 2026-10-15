"""Maven Central の取得先に版が現れるまでの待ち (scripts/release/wait-for-maven-central.py) のテスト。

本物の取得先の代わりに、偽の HTTP サーバを相手にする。待ちが上限に達したら失敗で終わることを、
短い上限の実際の待ちと、進み方を決めた時計の両方で確かめる。
"""

from __future__ import annotations

import unittest
from unittest import mock

import release_fakes
import support

SCRIPT = release_fakes.load("wait-for-maven-central.py")

VERSION = "0.1.0-beta.1"
COMMIT = "a" * 40
SHORT_TIMEOUT_MINUTES = "0.002"


class Registry:
    """appear_after 回目の問い合わせ (POM の取得の回数で数える) から、発行物を返す偽の取得先。"""

    def __init__(self, appear_after: int | None, commit: str | None = COMMIT, missing_status: int = 404):
        self.appear_after = appear_after
        self.commit = commit
        self.missing_status = missing_status
        self.rounds = 0

    def __call__(self, request: release_fakes.Request):
        if request.path.endswith(".pom"):
            self.rounds += 1
        if self.appear_after is None or self.rounds < self.appear_after:
            return self.missing_status, "missing"
        if request.path.endswith(".pom"):
            return 200, release_fakes.pom_text(VERSION, self.commit)
        return 200, b"content"


class WaitForMavenCentralTest(unittest.TestCase):
    def wait(self, registry: Registry, *extra: str, timeout: str = "1"):
        with release_fakes.FakeServer(registry) as server:
            code, stdout, _ = support.run_main(
                SCRIPT,
                ["--version", VERSION, "--maven-url", server.url + "/maven2", "--timeout-minutes", timeout, "--interval-seconds", "0.01", *extra],
            )
            paths = [request.path for request in server.requests]
        return code, stdout, paths

    def test_waits_until_the_files_appear(self):
        code, stdout, paths = self.wait(Registry(appear_after=3))
        self.assertEqual(code, 0, stdout)
        self.assertIn("現れた", stdout)
        base = f"/maven2/jp/kamusoft/kscollectionview/{VERSION}/kscollectionview-{VERSION}"
        self.assertEqual(paths[-3:], [base + ".pom", base + ".module", base + ".aar"])

    def test_reaching_the_limit_fails(self):
        code, stdout, paths = self.wait(Registry(appear_after=None), timeout=SHORT_TIMEOUT_MINUTES)
        self.assertEqual(code, 1)
        self.assertIn("上限", stdout)
        self.assertGreaterEqual(len(paths), 3)

    def test_server_errors_keep_waiting(self):
        code, stdout, _ = self.wait(Registry(appear_after=2, missing_status=503))
        self.assertEqual(code, 0, stdout)

    def test_checks_the_commit_in_the_pom(self):
        code, stdout, _ = self.wait(Registry(appear_after=1), "--commit", COMMIT)
        self.assertEqual(code, 0, stdout)
        self.assertIn(COMMIT, stdout)

    def test_commit_mismatch_fails(self):
        code, stdout, _ = self.wait(Registry(appear_after=1, commit="b" * 40), "--commit", COMMIT)
        self.assertEqual(code, 1)
        self.assertIn("起動した commit", stdout)

    def test_missing_commit_fails(self):
        code, stdout, _ = self.wait(Registry(appear_after=1, commit=None), "--commit", COMMIT)
        self.assertEqual(code, 1)
        self.assertIn("scm の tag", stdout)

    def test_rejects_a_non_positive_limit(self):
        code, stdout, paths = self.wait(Registry(appear_after=1), timeout="0")
        self.assertEqual(code, 1)
        self.assertIn("0 より大きく", stdout)
        self.assertEqual(paths, [])


class DeadlineWithFakeClockTest(unittest.TestCase):
    """時計を差し替え、120 分の上限で止まり、上限より後に問い合わせないことを確かめる。"""

    def test_stops_at_the_default_limit(self):
        now = [0.0]
        probes = []

        def clock():
            return now[0]

        def sleep(seconds):
            now[0] += seconds

        def probe(maven_url, version):
            probes.append(now[0])
            return False, "まだ"

        with mock.patch.object(SCRIPT, "probe_files", probe):
            with self.assertRaises(SCRIPT.support.WaitTimeout):
                SCRIPT.wait_for_release("http://unused", VERSION, None, 120 * 60, 60, clock=clock, sleep=sleep)
        self.assertEqual(len(probes), 121)
        self.assertLessEqual(max(probes), 120 * 60)


if __name__ == "__main__":
    unittest.main()
