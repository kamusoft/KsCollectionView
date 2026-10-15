"""検証 CI の成功で代えてよいかの確かめ (scripts/release/check-ci-skipped-changes.py) のテスト。

本リポジトリの代わりに、一時のディレクトリに作った使い捨ての git リポジトリを使う。そこに置く
ci.yml は、このリポジトリの ci.yml の本文をそのまま写したもの (paths-ignore を手で写さない)。
"""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest

import release_fakes
import support
from release_fakes import git

SCRIPT = release_fakes.load("check-ci-skipped-changes.py")
CI_WORKFLOW = os.path.join(".github", "workflows", "ci.yml")


def read_ci() -> str:
    with open(os.path.join(support.REPOSITORY_ROOT, CI_WORKFLOW), encoding="utf-8") as f:
        return f.read()


class CheckTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="release-ci-skipped-test-")
        self.addCleanup(shutil.rmtree, self.directory)
        git(self.directory, "init", "--quiet")
        self.write({CI_WORKFLOW: read_ci(), "ios/Sources/A.swift": "let a = 1\n", "kasane/a.md": "a\n"})
        self.base = self.commit("base")

    def write(self, files: dict[str, str]) -> None:
        for relative, text in files.items():
            support.write(os.path.join(self.directory, relative), text)

    def commit(self, message: str) -> str:
        git(self.directory, "add", "--all")
        git(self.directory, "commit", "--quiet", "--allow-empty", "-m", message)
        return git(self.directory, "rev-parse", "HEAD")

    def run_check(self, base: str | None = None, target: str | None = None):
        return support.run_main(
            SCRIPT,
            ["--base", base or self.base, "--target", target or git(self.directory, "rev-parse", "HEAD"),
             "--repository-root", self.directory],
        )

    def test_accepts_changes_only_in_paths_that_do_not_start_ci(self):
        self.write({"kasane/changes/x/evidence/a.md": "x\n", ".github/ISSUE_TEMPLATE/bug.yml": "name: bug\n"})
        self.commit("records")
        self.write({".github/CONTRIBUTING.md": "c\n", ".github/CONTRIBUTING_ja.md": "c\n"})
        self.commit("guides")
        code, stdout, _ = self.run_check()
        self.assertEqual(code, 0, stdout)
        self.assertIn("起動しないパス: kasane/changes/x/evidence/a.md (kasane/**)", stdout)
        self.assertIn("起動しないパス: .github/CONTRIBUTING_ja.md (.github/CONTRIBUTING_ja.md)", stdout)
        self.assertIn("代えてよい", stdout)

    def test_stops_when_a_path_that_starts_ci_changed(self):
        self.write({"kasane/b.md": "b\n", "ios/Sources/A.swift": "let a = 2\n"})
        self.commit("code")
        code, stdout, _ = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("起動するパス: ios/Sources/A.swift", stdout)
        self.assertIn("代えられない", stdout)

    def test_counts_both_names_of_a_rename(self):
        git(self.directory, "mv", "kasane/a.md", "docs-a.md")
        self.commit("rename")
        code, stdout, _ = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("起動するパス: docs-a.md", stdout)
        self.assertIn("起動しないパス: kasane/a.md (kasane/**)", stdout)

    def test_a_change_to_ci_yml_starts_ci(self):
        self.write({CI_WORKFLOW: read_ci() + "# changed\n"})
        self.commit("ci")
        code, stdout, _ = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn(f"起動するパス: {CI_WORKFLOW}", stdout)

    def test_star_does_not_cross_directories(self):
        # .github/CONTRIBUTING.md は 1 つのファイルだけを指す。下の階層や似た名前は当たらない。
        self.write({".github/CONTRIBUTING.md.bak": "x\n"})
        self.commit("similar name")
        code, stdout, _ = self.run_check()
        self.assertEqual(code, 1)
        self.assertIn("起動するパス: .github/CONTRIBUTING.md.bak", stdout)

    def test_reads_paths_ignore_from_the_target_commit(self):
        workflow = read_ci().replace('      - "kasane/**"\n', '      - "kasane/**"\n      - "notes/**"\n')
        self.assertNotEqual(workflow, read_ci())
        self.write({CI_WORKFLOW: workflow})
        middle = self.commit("ignore notes")
        self.write({"notes/a.md": "a\n"})
        target = self.commit("notes")
        code, stdout, _ = self.run_check(base=middle, target=target)
        self.assertEqual(code, 0, stdout)
        self.assertIn("起動しないパス: notes/a.md (notes/**)", stdout)

    def test_accepts_no_difference(self):
        code, stdout, _ = self.run_check(target=self.base)
        self.assertEqual(code, 0, stdout)
        self.assertIn("差は無い", stdout)

    def test_stops_when_base_is_not_an_ancestor(self):
        self.write({"kasane/b.md": "b\n"})
        target = self.commit("records")
        git(self.directory, "checkout", "--quiet", "-b", "other", self.base)
        self.write({"kasane/c.md": "c\n"})
        other = self.commit("other")
        code, stdout, _ = self.run_check(base=other, target=target)
        self.assertEqual(code, 1)
        self.assertIn("祖先でない", stdout)

    def test_stops_on_unknown_or_malformed_commits(self):
        code, stdout, _ = self.run_check(base="abc")
        self.assertEqual(code, 1)
        self.assertIn("commit の ID の形が違う", stdout)
        code, stdout, _ = self.run_check(base="f" * 40)
        self.assertEqual(code, 1)
        self.assertIn("手元に無い", stdout)

    def test_stops_when_paths_ignore_cannot_be_read(self):
        cases = {
            "無い": read_ci().replace("    paths-ignore:\n", "    paths-ignore-x:\n"),
            "paths で絞り込んでいる": read_ci().replace("    paths-ignore:\n", "    paths:\n"),
            "読めない形": read_ci().replace('      - "kasane/**"\n', '      - "!kasane/keep.md"\n      - "kasane/**"\n'),
        }
        for expected, workflow in cases.items():
            with self.subTest(expected=expected):
                self.assertNotEqual(workflow, read_ci())
                self.write({CI_WORKFLOW: workflow})
                target = self.commit(expected)
                code, stdout, _ = self.run_check(base=target, target=target)
                self.assertEqual(code, 1)
                self.assertIn(expected, stdout)


class RepositoryCiTest(unittest.TestCase):
    def test_reads_the_paths_ignore_of_this_repository(self):
        patterns = SCRIPT.ignored_patterns(read_ci())
        self.assertIn("kasane/**", patterns)
        self.assertEqual(SCRIPT.matching_pattern("kasane/changes/a/tasks.md", patterns), "kasane/**")
        self.assertIsNone(SCRIPT.matching_pattern("scripts/release/central-portal.py", patterns))
        self.assertIsNone(SCRIPT.matching_pattern(".github/workflows/ci.yml", patterns))


if __name__ == "__main__":
    unittest.main()
