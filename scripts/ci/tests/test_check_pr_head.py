"""main 宛ての Pull Request の出どころの確認のテスト。"""

from __future__ import annotations

import unittest

import support

SCRIPT = support.load_script("check-pr-head.py")

REPOSITORY = "kamusoft/KsCollectionView"


def pull_request_env(head_ref: str, head_repository: str, base_ref: str = "main") -> dict[str, str]:
    return {
        "GITHUB_EVENT_NAME": "pull_request",
        "GITHUB_BASE_REF": base_ref,
        "GITHUB_HEAD_REF": head_ref,
        "GITHUB_REPOSITORY": REPOSITORY,
        "KS_PR_HEAD_REPOSITORY": head_repository,
    }


class CheckPrHeadTest(unittest.TestCase):
    def test_同じリポジトリのdevelopからなら通る(self) -> None:
        code, stdout, _ = support.run_main(SCRIPT, [], env=pull_request_env("develop", REPOSITORY))
        self.assertEqual(code, 0)
        # 確認が実際に走ったことを、記録から読み取れる。
        self.assertIn(f"出どころは {REPOSITORY} の develop", stdout)

    def test_develop以外のブランチからなら落ちる(self) -> None:
        code, stdout, _ = support.run_main(SCRIPT, [], env=pull_request_env("feature/x", REPOSITORY))
        self.assertEqual(code, 1)
        self.assertIn("::error::", stdout)
        self.assertIn("出どころが develop でない", stdout)
        self.assertIn("feature/x", stdout)

    def test_別のリポジトリの同じ名前のブランチからなら落ちる(self) -> None:
        code, stdout, _ = support.run_main(SCRIPT, [], env=pull_request_env("develop", "someone/KsCollectionView"))
        self.assertEqual(code, 1)
        self.assertIn("出どころが別のリポジトリである", stdout)
        self.assertIn("someone/KsCollectionView", stdout)

    def test_pushで起動したときは確かめない(self) -> None:
        env = {"GITHUB_EVENT_NAME": "push", "GITHUB_REPOSITORY": REPOSITORY, "GITHUB_REF_NAME": "develop"}
        code, stdout, _ = support.run_main(SCRIPT, [], env=env)
        self.assertEqual(code, 0)
        self.assertNotIn("::error::", stdout)
        self.assertIn("出どころは確かめない", stdout)

    def test_main以外に宛てたPullRequestは確かめない(self) -> None:
        env = pull_request_env("feature/x", "someone/KsCollectionView", base_ref="develop")
        code, stdout, _ = support.run_main(SCRIPT, [], env=env)
        self.assertEqual(code, 0)
        self.assertIn("出どころは確かめない", stdout)

    def test_出どころを読み取れなければ落ちる(self) -> None:
        # 出どころのリポジトリを workflow が渡し忘れたときに、黙って通さない。
        env = pull_request_env("develop", "")
        code, stdout, _ = support.run_main(SCRIPT, [], env=env)
        self.assertEqual(code, 1)
        self.assertIn("出どころを読み取れない", stdout)

    def test_ブランチの名前の大文字と小文字や前後の違いは別のブランチとして扱う(self) -> None:
        for head_ref in ("Develop", "develop-2", "refs/heads/develop"):
            with self.subTest(head_ref=head_ref):
                code, _, _ = support.run_main(SCRIPT, [], env=pull_request_env(head_ref, REPOSITORY))
                self.assertEqual(code, 1)

    def test_引数で渡した値が環境変数より優先される(self) -> None:
        code, stdout, _ = support.run_main(
            SCRIPT, ["--head-ref", "hotfix"], env=pull_request_env("develop", REPOSITORY)
        )
        self.assertEqual(code, 1)
        self.assertIn("hotfix", stdout)


if __name__ == "__main__":
    unittest.main()
