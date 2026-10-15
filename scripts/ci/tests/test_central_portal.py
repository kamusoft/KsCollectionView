"""Central Portal の Publisher API の操作 (scripts/release/central-portal.py) のテスト。

本物の Central Portal の代わりに、偽の API (127.0.0.1 の HTTP サーバ) を相手にする。偽の API は、
送信ごとに、問い合わせのたびに返す状態の並びを持つ (並びの最後の状態は、その後も返し続ける)。
"""

from __future__ import annotations

import base64
import json
import os
import shutil
import tempfile
import unittest

import release_fakes
import support

SCRIPT = release_fakes.load("central-portal.py")

VERSION = "0.1.0-beta.1"
DEPLOYMENT = "28570f16-da32-4c14-bd2e-c1acc0782365"
CREDENTIALS = {"KS_CENTRAL_USERNAME": "token-user", "KS_CENTRAL_PASSWORD": "token-pass"}
EXPECTED_AUTHORIZATION = "Bearer " + base64.b64encode(b"token-user:token-pass").decode()
# 待つテストの上限 (分) と問い合わせの間隔 (秒)。上限は 0.1 秒ほど。
SHORT_TIMEOUT_MINUTES = "0.002"
SHORT_INTERVAL = "0.01"


class FakePortal:
    def __init__(self, states: dict[str, list[object]] | None = None, published: object = False, drop_status: int = 204, publish_status: int = 204):
        # 状態の並びの要素は、状態の文字列か、(HTTP の状態, 本文) の組。
        self.states = {key: list(value) for key, value in (states or {}).items()}
        self.published = published
        self.drop_status = drop_status
        self.publish_status = publish_status

    def next_state(self, deployment_id: str):
        sequence = self.states.get(deployment_id)
        if not sequence:
            return 404, {"error": "not found"}
        item = sequence.pop(0) if len(sequence) > 1 else sequence[0]
        if isinstance(item, tuple):
            return item
        return 200, {"deploymentId": deployment_id, "deploymentName": "x", "deploymentState": item, "purls": [], "errors": {"bundle": ["bad"]} if item == "FAILED" else {}}

    def __call__(self, request: release_fakes.Request):
        if request.path == "/api/v1/publisher/status" and request.method == "POST":
            return self.next_state(request.query.get("id", ""))
        if request.path == "/api/v1/publisher/published" and request.method == "GET":
            if isinstance(self.published, tuple):
                return self.published
            return 200, {"published": self.published}
        if request.path.startswith("/api/v1/publisher/deployment/"):
            deployment_id = request.path.rsplit("/", 1)[1]
            if request.method == "POST":
                if self.publish_status in (200, 204) and deployment_id in self.states:
                    self.states[deployment_id] = ["PUBLISHING", "PUBLISHED"]
                return self.publish_status, b""
            if request.method == "DELETE":
                if self.drop_status in (200, 204):
                    self.states.pop(deployment_id, None)
                return self.drop_status, b""
        return 400, {"error": "unexpected"}


class PortalTestCase(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="central-portal-test-")
        self.addCleanup(shutil.rmtree, self.directory)

    def run_portal(self, portal: FakePortal, *arguments: str, env: dict[str, str] | None = None):
        output = os.path.join(self.directory, "output")
        if os.path.exists(output):
            os.remove(output)
        with release_fakes.FakeServer(portal) as server:
            code, stdout, stderr = support.run_main(
                SCRIPT,
                ["--base-url", server.url, "--interval-seconds", SHORT_INTERVAL, *arguments],
                {"GITHUB_OUTPUT": output, **(CREDENTIALS if env is None else env)},
            )
            self.requests = list(server.requests)
        outputs = {}
        if os.path.exists(output):
            with open(output, encoding="utf-8") as f:
                outputs = dict(line.split("=", 1) for line in f.read().splitlines())
        return code, stdout + stderr, outputs

    def count(self, method: str, prefix: str) -> int:
        return len([request for request in self.requests if request.method == method and request.path.startswith(prefix)])


class PublishedTest(PortalTestCase):
    def test_reports_published_and_sends_the_user_token(self):
        for value in (True, False):
            with self.subTest(published=value):
                code, _, outputs = self.run_portal(FakePortal(published=value), "published", "--version", VERSION)
                self.assertEqual(code, 0)
                self.assertEqual(outputs, {"published": "true" if value else "false"})
                request = self.requests[0]
                self.assertEqual(request.query, {"namespace": "jp.kamusoft", "name": "kscollectionview", "version": VERSION})
                self.assertEqual(request.headers.get("Authorization"), EXPECTED_AUTHORIZATION)

    def test_authentication_failure_stops(self):
        code, output, _ = self.run_portal(FakePortal(published=(401, "unauthorized")), "published", "--version", VERSION)
        self.assertEqual(code, 1)
        self.assertIn("認証が通らない", output)
        self.assertNotIn("token-pass", output)

    def test_missing_credentials_stop_without_calling(self):
        code, output, _ = self.run_portal(FakePortal(), "published", "--version", VERSION, env={})
        self.assertEqual(code, 1)
        self.assertIn("KS_CENTRAL_USERNAME", output)
        self.assertEqual(self.requests, [])


class ExtractIdTest(PortalTestCase):
    def write_log(self, text: str) -> str:
        return support.write(os.path.join(self.directory, "gradle.log"), text)

    def extract(self, log_text: str, attempt: str = "2"):
        receipts = os.path.join(self.directory, "receipts")
        code, output, outputs = self.run_portal(
            FakePortal(), "extract-id", "--log", self.write_log(log_text), "--version", VERSION, "--receipts", receipts, "--attempt", attempt, env={}
        )
        return code, output, outputs, receipts

    def test_reads_the_id_and_writes_the_receipt(self):
        log = f"> Task :kscollectionview:publishToMavenCentral\nUploaded bundle to Central Portal as USER_MANAGED, deployment id: {DEPLOYMENT}\nSkipping deployment validation!\n"
        code, _, outputs, receipts = self.extract(log)
        self.assertEqual(code, 0)
        self.assertEqual(outputs["deployment-id"], DEPLOYMENT)
        with open(os.path.join(receipts, "deployment-2.json"), encoding="utf-8") as f:
            self.assertEqual(json.load(f), {"deploymentId": DEPLOYMENT, "version": VERSION, "attempt": 2})
        self.assertEqual(self.requests, [])

    def test_missing_line_stops_and_points_to_leftover_deployments(self):
        code, output, outputs, receipts = self.extract("BUILD SUCCESSFUL\n")
        self.assertEqual(code, 1)
        self.assertIn("送信の ID の行が無い", output)
        self.assertIn("取り下げる", output)
        self.assertFalse(os.path.exists(receipts))
        self.assertEqual(outputs, {})

    def test_two_ids_stop(self):
        log = "".join(f"Uploaded bundle to Central Portal as USER_MANAGED, deployment id: {value}\n" for value in ("a-1", "b-2"))
        code, output, _, _ = self.extract(log)
        self.assertEqual(code, 1)
        self.assertIn("複数", output)

    def test_automatic_publishing_stops(self):
        code, output, _, _ = self.extract(f"Uploaded bundle to Central Portal as AUTOMATIC, deployment id: {DEPLOYMENT}\n")
        self.assertEqual(code, 1)
        self.assertIn("保留 (USER_MANAGED) でない", output)


class InspectTest(PortalTestCase):
    def write_receipt(self, attempt: int, deployment_id: str, version: str = VERSION) -> str:
        receipts = os.path.join(self.directory, "receipts")
        support.write(
            os.path.join(receipts, f"attempt-{attempt}", f"deployment-{attempt}.json"),
            json.dumps({"deploymentId": deployment_id, "version": version, "attempt": attempt}),
        )
        return receipts

    def test_no_receipt_means_a_new_upload(self):
        code, _, outputs = self.run_portal(FakePortal(), "inspect", "--version", VERSION, "--receipts", os.path.join(self.directory, "none"))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"action": "upload", "deployment-id": ""})
        self.assertEqual(self.requests, [])

    def test_actions_by_state(self):
        expected = {
            "PENDING": "reuse",
            "VALIDATING": "reuse",
            "VALIDATED": "reuse",
            "PUBLISHING": "wait-published",
            "PUBLISHED": "published",
            "FAILED": "upload",
        }
        receipts = self.write_receipt(1, DEPLOYMENT)
        for state, action in expected.items():
            with self.subTest(state=state):
                code, _, outputs = self.run_portal(FakePortal({DEPLOYMENT: [state]}), "inspect", "--version", VERSION, "--receipts", receipts)
                self.assertEqual(code, 0)
                self.assertEqual(outputs["action"], action)
                self.assertEqual(outputs["deployment-id"], "" if action == "upload" else DEPLOYMENT)

    def test_dropped_deployment_is_not_reused(self):
        receipts = self.write_receipt(1, DEPLOYMENT)
        code, _, outputs = self.run_portal(FakePortal({}), "inspect", "--version", VERSION, "--receipts", receipts)
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"action": "upload", "deployment-id": ""})

    def test_uses_the_latest_attempt(self):
        self.write_receipt(1, "old-id")
        receipts = self.write_receipt(3, "new-id")
        code, _, outputs = self.run_portal(FakePortal({"new-id": ["VALIDATED"], "old-id": ["FAILED"]}), "inspect", "--version", VERSION, "--receipts", receipts)
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"action": "reuse", "deployment-id": "new-id"})

    def test_receipt_of_another_version_stops(self):
        receipts = self.write_receipt(1, DEPLOYMENT, version="0.0.9")
        code, output, _ = self.run_portal(FakePortal({DEPLOYMENT: ["VALIDATED"]}), "inspect", "--version", VERSION, "--receipts", receipts)
        self.assertEqual(code, 1)
        self.assertIn("今回の版", output)


class SettleTest(PortalTestCase):
    def settle(self, portal: FakePortal, timeout: str = "1"):
        return self.run_portal(portal, "settle", "--deployment-id", DEPLOYMENT, "--timeout-minutes", timeout)

    def test_waits_until_validated(self):
        code, _, outputs = self.settle(FakePortal({DEPLOYMENT: ["PENDING", "VALIDATING", "VALIDATED"]}))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"state": "VALIDATED"})
        self.assertEqual(self.count("POST", "/api/v1/publisher/status"), 3)
        self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)

    def test_failed_validation_drops_the_deployment_and_fails(self):
        code, output, outputs = self.settle(FakePortal({DEPLOYMENT: ["VALIDATING", "FAILED"]}))
        self.assertEqual(code, 1)
        self.assertIn("検証が失敗した", output)
        self.assertIn("取り下げた", output)
        self.assertEqual(self.count("DELETE", f"/api/v1/publisher/deployment/{DEPLOYMENT}"), 1)
        self.assertEqual(self.count("POST", "/api/v1/publisher/deployment/"), 0)
        self.assertEqual(outputs, {})

    def test_reaching_the_limit_fails(self):
        code, output, outputs = self.settle(FakePortal({DEPLOYMENT: ["VALIDATING"]}), timeout=SHORT_TIMEOUT_MINUTES)
        self.assertEqual(code, 1)
        self.assertIn("上限", output)
        self.assertEqual(outputs, {})
        self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)

    def test_transient_errors_keep_waiting(self):
        code, _, outputs = self.settle(FakePortal({DEPLOYMENT: [(503, "busy"), (429, "slow down"), "VALIDATED"]}))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"state": "VALIDATED"})

    def test_authentication_failure_stops_immediately(self):
        code, output, _ = self.settle(FakePortal({DEPLOYMENT: [(401, "no"), "VALIDATED"]}))
        self.assertEqual(code, 1)
        self.assertIn("認証が通らない", output)
        self.assertEqual(self.count("POST", "/api/v1/publisher/status"), 1)

    def test_already_publishing_is_settled(self):
        code, _, outputs = self.settle(FakePortal({DEPLOYMENT: ["PUBLISHING"]}))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"state": "PUBLISHING"})

    def test_missing_deployment_fails(self):
        code, output, _ = self.settle(FakePortal({}))
        self.assertEqual(code, 1)
        self.assertIn("見つからない", output)


class PublishTest(PortalTestCase):
    def test_instructs_a_validated_deployment(self):
        code, _, outputs = self.run_portal(FakePortal({DEPLOYMENT: ["VALIDATED"]}), "publish", "--deployment-id", DEPLOYMENT)
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"state": "PUBLISHING"})
        self.assertEqual(self.count("POST", f"/api/v1/publisher/deployment/{DEPLOYMENT}"), 1)

    def test_does_not_instruct_again_once_publishing(self):
        for state in ("PUBLISHING", "PUBLISHED"):
            with self.subTest(state=state):
                code, _, outputs = self.run_portal(FakePortal({DEPLOYMENT: [state]}), "publish", "--deployment-id", DEPLOYMENT)
                self.assertEqual(code, 0)
                self.assertEqual(outputs, {"state": state})
                self.assertEqual(self.count("POST", "/api/v1/publisher/deployment/"), 0)

    def test_refuses_a_deployment_that_is_not_validated(self):
        code, output, _ = self.run_portal(FakePortal({DEPLOYMENT: ["VALIDATING"]}), "publish", "--deployment-id", DEPLOYMENT)
        self.assertEqual(code, 1)
        self.assertIn("検証済みでない", output)
        self.assertEqual(self.count("POST", "/api/v1/publisher/deployment/"), 0)

    def test_rejected_instruction_fails(self):
        code, output, _ = self.run_portal(FakePortal({DEPLOYMENT: ["VALIDATED"]}, publish_status=400), "publish", "--deployment-id", DEPLOYMENT)
        self.assertEqual(code, 1)
        self.assertIn("公開を指示できない", output)


class WaitPublishedTest(PortalTestCase):
    def wait(self, portal: FakePortal, timeout: str = "1"):
        return self.run_portal(portal, "wait-published", "--deployment-id", DEPLOYMENT, "--timeout-minutes", timeout)

    def test_waits_until_published(self):
        code, _, outputs = self.wait(FakePortal({DEPLOYMENT: ["PUBLISHING", "PUBLISHING", "PUBLISHED"]}))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"state": "PUBLISHED"})

    def test_failure_after_the_instruction_is_not_dropped(self):
        code, output, _ = self.wait(FakePortal({DEPLOYMENT: ["PUBLISHING", "FAILED"]}))
        self.assertEqual(code, 1)
        self.assertIn("公開が失敗した", output)
        self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)

    def test_reaching_the_limit_fails(self):
        code, output, outputs = self.wait(FakePortal({DEPLOYMENT: ["PUBLISHING"]}), timeout=SHORT_TIMEOUT_MINUTES)
        self.assertEqual(code, 1)
        self.assertIn("上限", output)
        self.assertEqual(outputs, {})


class DropTest(PortalTestCase):
    def drop(self, portal: FakePortal, timeout: str = "1"):
        return self.run_portal(portal, "drop", "--deployment-id", DEPLOYMENT, "--timeout-minutes", timeout)

    def test_drops_a_settled_deployment(self):
        for states in (["VALIDATED"], ["VALIDATING", "FAILED"]):
            with self.subTest(states=states):
                code, _, outputs = self.drop(FakePortal({DEPLOYMENT: states}))
                self.assertEqual(code, 0)
                self.assertEqual(outputs, {"dropped": "true"})
                self.assertEqual(self.count("DELETE", f"/api/v1/publisher/deployment/{DEPLOYMENT}"), 1)

    def test_nothing_to_drop(self):
        code, _, outputs = self.drop(FakePortal({}))
        self.assertEqual(code, 0)
        self.assertEqual(outputs, {"dropped": "false"})
        self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)

    def test_refuses_to_drop_after_publishing_started(self):
        for state in ("PUBLISHING", "PUBLISHED"):
            with self.subTest(state=state):
                code, output, _ = self.drop(FakePortal({DEPLOYMENT: [state]}))
                self.assertEqual(code, 1)
                self.assertIn("取り下げない", output)
                self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)

    def test_reaching_the_limit_fails(self):
        code, output, _ = self.drop(FakePortal({DEPLOYMENT: ["VALIDATING"]}), timeout=SHORT_TIMEOUT_MINUTES)
        self.assertEqual(code, 1)
        self.assertIn("上限", output)
        self.assertEqual(self.count("DELETE", "/api/v1/publisher/deployment/"), 0)


class RerunScenarioTest(PortalTestCase):
    """前の試行が残した送信を、再実行の試行が送り直さずに使う流れを、コマンドの並びで確かめる。"""

    def test_leftover_validated_deployment_is_published_without_uploading_again(self):
        receipts = os.path.join(self.directory, "receipts")
        support.write(os.path.join(receipts, "deployment-1.json"), json.dumps({"deploymentId": DEPLOYMENT, "version": VERSION, "attempt": 1}))
        portal = FakePortal({DEPLOYMENT: ["VALIDATED"]})
        code, _, outputs = self.run_portal(portal, "inspect", "--version", VERSION, "--receipts", receipts)
        self.assertEqual((code, outputs["action"]), (0, "reuse"))
        code, _, _ = self.run_portal(portal, "settle", "--deployment-id", DEPLOYMENT)
        self.assertEqual(code, 0)
        code, _, _ = self.run_portal(portal, "publish", "--deployment-id", DEPLOYMENT)
        self.assertEqual(code, 0)
        self.assertEqual(self.count("POST", f"/api/v1/publisher/deployment/{DEPLOYMENT}"), 1)
        code, _, outputs = self.run_portal(portal, "wait-published", "--deployment-id", DEPLOYMENT)
        self.assertEqual((code, outputs), (0, {"state": "PUBLISHED"}))


if __name__ == "__main__":
    unittest.main()
