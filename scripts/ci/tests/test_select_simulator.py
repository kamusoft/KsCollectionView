"""使う Simulator を選ぶスクリプトのテスト。"""

from __future__ import annotations

import json
import os
import tempfile
import unittest

import support

SCRIPT = support.load_script("select-simulator.py")

RUNTIME = "com.apple.CoreSimulator.SimRuntime."


def device(name: str, udid: str, available: bool = True) -> dict:
    return {"name": name, "udid": udid, "isAvailable": available, "state": "Shutdown"}


class SelectSimulatorTest(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)

    def run_select(self, catalog) -> tuple[int, str, str]:
        path = os.path.join(self.directory.name, "simulators.json")
        text = catalog if isinstance(catalog, str) else json.dumps(catalog)
        support.write(path, text)
        return support.run_main(SCRIPT, ["--catalog", path])

    def test_OSの版が最も新しいiPhoneを選ぶ(self) -> None:
        code, stdout, stderr = self.run_select(
            {
                "devices": {
                    RUNTIME + "iOS-18-6": [device("iPhone 16", "UDID-OLD")],
                    RUNTIME + "iOS-27-0": [device("iPad Air", "UDID-IPAD"), device("iPhone 17", "UDID-NEW")],
                    RUNTIME + "tvOS-27-0": [device("Apple TV", "UDID-TV")],
                    RUNTIME + "iOS-9-3": [device("iPhone 6s", "UDID-ANCIENT")],
                }
            }
        )
        self.assertEqual(code, 0)
        # 標準出力は UDID だけ (呼ぶ側がそのまま変数に取る)。
        self.assertEqual(stdout, "UDID-NEW\n")
        self.assertIn("iPhone 17 (iOS 27.0)", stderr)

    def test_版は数として比べる(self) -> None:
        code, stdout, _ = self.run_select(
            {
                "devices": {
                    RUNTIME + "iOS-27-10": [device("iPhone 17", "UDID-27-10")],
                    RUNTIME + "iOS-27-2": [device("iPhone 17", "UDID-27-2")],
                }
            }
        )
        self.assertEqual(code, 0)
        self.assertEqual(stdout, "UDID-27-10\n")

    def test_同じ版の中では名前の順で最初のものを選ぶ(self) -> None:
        code, stdout, _ = self.run_select(
            {"devices": {RUNTIME + "iOS-27-0": [device("iPhone 17 Pro", "UDID-PRO"), device("iPhone 17", "UDID-BASE")]}}
        )
        self.assertEqual(code, 0)
        self.assertEqual(stdout, "UDID-BASE\n")

    def test_使えないiPhoneは選ばない(self) -> None:
        code, stdout, _ = self.run_select(
            {
                "devices": {
                    RUNTIME + "iOS-27-0": [device("iPhone 17", "UDID-BROKEN", available=False)],
                    RUNTIME + "iOS-18-6": [device("iPhone 16", "UDID-OK")],
                }
            }
        )
        self.assertEqual(code, 0)
        self.assertEqual(stdout, "UDID-OK\n")

    def test_使えるiPhoneが無ければ失敗する(self) -> None:
        code, stdout, stderr = self.run_select(
            {
                "devices": {
                    RUNTIME + "iOS-27-0": [device("iPad Air", "UDID-IPAD"), device("iPhone 17", "UDID-X", available=False)],
                    RUNTIME + "watchOS-27-0": [device("Apple Watch", "UDID-WATCH")],
                }
            }
        )
        self.assertEqual(code, 1)
        self.assertEqual(stdout, "")
        self.assertIn("使える iPhone の Simulator が見つからない", stderr)

    def test_一覧が空なら失敗する(self) -> None:
        code, stdout, _ = self.run_select({"devices": {}})
        self.assertEqual(code, 1)
        self.assertEqual(stdout, "")

    def test_一覧を読めなければ失敗する(self) -> None:
        code, stdout, stderr = self.run_select("これは JSON ではない")
        self.assertEqual(code, 1)
        self.assertEqual(stdout, "")
        self.assertIn("JSON として読めない", stderr)

    def test_一覧のファイルが無ければ失敗する(self) -> None:
        code, stdout, _ = support.run_main(SCRIPT, ["--catalog", os.path.join(self.directory.name, "none.json")])
        self.assertEqual(code, 1)
        self.assertEqual(stdout, "")


if __name__ == "__main__":
    unittest.main()
