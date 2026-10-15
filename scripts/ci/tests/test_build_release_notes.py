"""リリースノートの組み立て (scripts/release/build-release-notes.py) のテスト。

変更の節の読み方は、本文の文字列を直に渡して確かめる。範囲の決め方は、一時のディレクトリに
作った使い捨ての git リポジトリ (main の first-parent に merge commit が並ぶ) と、GitHub の API の
代わりの偽の HTTP サーバで確かめる。
"""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest
from unittest import mock

import release_fakes
import support
from release_fakes import git

SCRIPT = release_fakes.load("build-release-notes.py")

VERSION = "0.2.0"
TEMPLATE_COMMENT = "<!-- Write one line per change: - breaking|feature|fix|docs: description. Use - none when nothing changed. -->"


def body(*section_lines: str, heading: str = "## Changes", after: str = "") -> str:
    return "\n".join(["## Summary", "", "Internal text.", "", heading, TEMPLATE_COMMENT, *section_lines, after]).rstrip() + "\n"


class ParseChangesTest(unittest.TestCase):
    def test_reads_lines_and_ignores_comments_and_blank_lines(self):
        entries, problems = SCRIPT.parse_changes(body("", "- fix: Fix the crash.", ""))
        self.assertEqual(problems, [])
        self.assertEqual(entries, [("fix", "Fix the crash.")])

    def test_none_section(self):
        self.assertEqual(SCRIPT.parse_changes(body("- none")), ([], []))

    def test_missing_section(self):
        entries, problems = SCRIPT.parse_changes("## Summary\n\nNo changes heading.\n")
        self.assertIsNone(entries)
        self.assertIn("変更の節 (## Changes) が無い", problems[0])

    def test_section_inside_a_comment_is_not_a_section(self):
        _, problems = SCRIPT.parse_changes("<!--\n## Changes\n- fix: hidden\n-->\n")
        self.assertIn("変更の節 (## Changes) が無い", problems[0])

    def test_two_sections(self):
        _, problems = SCRIPT.parse_changes(body("- fix: A.", after="## Changes\n- fix: B."))
        self.assertIn("2 つある", problems[0])

    def test_empty_section(self):
        _, problems = SCRIPT.parse_changes(body("", ""))
        self.assertIn("変更の節が空", problems[0])

    def test_unknown_kind(self):
        _, problems = SCRIPT.parse_changes(body("- improvement: Faster scrolling."))
        self.assertIn("読めない行: '- improvement: Faster scrolling.'", problems[0])

    def test_headings_and_prose_in_the_section(self):
        _, problems = SCRIPT.parse_changes(body("### Fixes", "Some prose.", "- fix: A."))
        self.assertEqual(len(problems), 2)
        self.assertTrue(all("読めない行" in problem for problem in problems))

    def test_empty_description(self):
        for line in ("- fix:", "- fix:   "):
            with self.subTest(line=line):
                _, problems = SCRIPT.parse_changes(body(line))
                self.assertIn("説明の無い行", problems[0])

    def test_section_ends_at_the_next_heading(self):
        entries, problems = SCRIPT.parse_changes(body("- docs: Add a guide.", after="## Testing\n\nRan everything.\n- fix: not read"))
        self.assertEqual(problems, [])
        self.assertEqual(entries, [("docs", "Add a guide.")])

    def test_none_mixed_with_other_lines(self):
        _, problems = SCRIPT.parse_changes(body("- none", "- fix: A."))
        self.assertIn("混ざっている", problems[0])

    def test_reads_crlf_bodies(self):
        entries, problems = SCRIPT.parse_changes(body("- feature: Add paging.").replace("\n", "\r\n"))
        self.assertEqual(problems, [])
        self.assertEqual(entries, [("feature", "Add paging.")])


class BuildNotesTest(unittest.TestCase):
    def pull_request(self, number: int, *lines: str):
        return SCRIPT.PullRequest(number, body(*lines), f"{number:040x}")

    def test_groups_lines_by_kind(self):
        notes = SCRIPT.build_notes(
            [
                self.pull_request(3, "- fix: Fix A.", "- feature: Add B."),
                self.pull_request(4, "- none"),
                self.pull_request(5, "- feature: Add C.", "- breaking: Rename D."),
            ]
        )
        self.assertEqual(
            notes,
            "### Breaking changes\n\n- Rename D. (#5)\n\n"
            "### Features\n\n- Add B. (#3)\n- Add C. (#5)\n\n"
            "### Fixes\n\n- Fix A. (#3)\n",
        )

    def test_all_none_gives_one_line(self):
        notes = SCRIPT.build_notes([self.pull_request(1, "- none"), self.pull_request(2, "- none")])
        self.assertEqual(notes, SCRIPT.NO_CHANGES_LINE + "\n")

    def test_reports_every_problem_with_the_pull_request_number(self):
        with self.assertRaises(SCRIPT.support.ReleaseError) as raised:
            SCRIPT.build_notes(
                [
                    SCRIPT.PullRequest(7, "no section", "7" * 40),
                    self.pull_request(8, "- fix: ok"),
                    self.pull_request(9, "- improvement: bad"),
                ]
            )
        message = str(raised.exception)
        self.assertIn("Pull Request #7: 変更の節", message)
        self.assertIn("Pull Request #9: 読めない行: '- improvement: bad'", message)
        self.assertNotIn("#8", message)


class FakeGitHub:
    """Release の一覧と Pull Request の一覧を返す偽の GitHub の API。ページを分けて返す。"""

    def __init__(self, releases: list[dict], pulls: list[dict], page_size: int):
        self.releases = releases
        self.pulls = pulls
        self.page_size = page_size

    def __call__(self, request: release_fakes.Request):
        page = int(request.query.get("page", "1"))
        if request.path == "/repos/kamusoft/KsCollectionView/releases":
            items = self.releases
        elif request.path == "/repos/kamusoft/KsCollectionView/pulls":
            if request.query.get("state") != "closed" or request.query.get("base") != "main":
                return 400, {"message": "unexpected query"}
            items = self.pulls
        else:
            return 404, {"message": "not found"}
        start = (page - 1) * self.page_size
        return 200, items[start : start + self.page_size]


class RangeTest(unittest.TestCase):
    """main の first-parent に、Pull Request ごとの merge commit が並ぶリポジトリを作る。"""

    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="release-notes-test-")
        self.addCleanup(shutil.rmtree, self.directory)
        self.repository = os.path.join(self.directory, "repository")
        os.makedirs(self.repository)
        git(self.repository, "init", "--quiet")
        support.write(os.path.join(self.repository, "file.txt"), "0\n")
        git(self.repository, "add", "--all")
        git(self.repository, "commit", "--quiet", "-m", "root")
        git(self.repository, "branch", "develop")
        self.merges: dict[int, str] = {}
        self.page_size_patch = mock.patch.object(SCRIPT, "PAGE_SIZE", 2)
        self.page_size_patch.start()
        self.addCleanup(self.page_size_patch.stop)

    def merge_pull_request(self, number: int) -> str:
        """develop に commit を積み、main へ merge commit で取り込む。"""
        git(self.repository, "checkout", "--quiet", "develop")
        support.write(os.path.join(self.repository, "file.txt"), f"{number}\n")
        git(self.repository, "commit", "--quiet", "-am", f"work {number}")
        git(self.repository, "checkout", "--quiet", "main")
        git(self.repository, "merge", "--quiet", "--no-ff", "-m", f"Merge pull request #{number}", "develop")
        self.merges[number] = git(self.repository, "rev-parse", "HEAD")
        return self.merges[number]

    def pull(self, number: int, *lines: str, merged: bool = True, merge_commit: str | None = None) -> dict:
        return {
            "number": number,
            "body": body(*lines),
            "merged_at": "2026-10-01T00:00:00Z" if merged else None,
            "merge_commit_sha": merge_commit or self.merges.get(number, "f" * 40),
        }

    def build(self, releases, pulls, ref="refs/heads/main", commit=None, version=VERSION):
        with release_fakes.FakeServer(FakeGitHub(releases, pulls, page_size=2)) as server:
            output = os.path.join(self.directory, "output")
            notes_file = os.path.join(self.directory, "notes", "notes.md")
            for path in (output, notes_file):
                if os.path.exists(path):
                    os.remove(path)
            code, stdout, _ = support.run_main(
                SCRIPT,
                [
                    "--version", version, "--output", notes_file, "--commit", commit or git(self.repository, "rev-parse", "HEAD"),
                    "--ref", ref, "--repository", "kamusoft/KsCollectionView", "--api-url", server.url,
                    "--repository-root", self.repository,
                ],
                {"GITHUB_OUTPUT": output, "GITHUB_TOKEN": "test-token"},
            )
            requests = list(server.requests)
        outputs = {}
        if os.path.exists(output):
            with open(output, encoding="utf-8") as f:
                outputs = dict(line.split("=", 1) for line in f.read().splitlines())
        notes = None
        if os.path.exists(notes_file):
            with open(notes_file, encoding="utf-8") as f:
                notes = f.read()
        return code, stdout, outputs, notes, requests

    def test_only_pull_requests_after_the_previous_release_are_included(self):
        self.merge_pull_request(1)
        self.merge_pull_request(2)
        git(self.repository, "tag", "0.1.0")
        self.merge_pull_request(3)
        self.merge_pull_request(4)
        releases = [{"tag_name": "0.1.0", "draft": False}, {"tag_name": "0.9.9", "draft": True}]
        pulls = [
            self.pull(4, "- fix: Fix four."),
            self.pull(3, "- feature: Add three."),
            self.pull(2, "- fix: Old two."),
            self.pull(1, "- fix: Old one."),
            self.pull(5, "- fix: Not merged.", merged=False),
            self.pull(6, "- fix: Elsewhere.", merge_commit="e" * 40),
        ]
        code, stdout, outputs, notes, requests = self.build(releases, pulls)
        self.assertEqual(code, 0, stdout)
        self.assertEqual(notes, "### Features\n\n- Add three. (#3)\n\n### Fixes\n\n- Fix four. (#4)\n")
        self.assertEqual(outputs["built"], "true")
        self.assertTrue(outputs["notes-file"].endswith("notes.md"))
        self.assertIn("範囲の起点: 0.1.0", stdout)
        self.assertTrue(all(request.headers.get("Authorization") == "Bearer test-token" for request in requests))
        # 6 件を 2 件ずつのページで読み切っている。
        self.assertEqual(len([request for request in requests if request.path.endswith("/pulls")]), 4)

    def test_first_release_includes_every_pull_request_from_the_start_of_main(self):
        self.merge_pull_request(1)
        self.merge_pull_request(2)
        code, stdout, _, notes, _ = self.build([], [self.pull(1, "- none"), self.pull(2, "- none")])
        self.assertEqual(code, 0, stdout)
        self.assertEqual(notes, SCRIPT.NO_CHANGES_LINE + "\n")
        self.assertIn("範囲の起点: main の最初 / Pull Request: #1, #2", stdout)

    def test_the_release_of_the_same_version_is_not_the_start(self):
        self.merge_pull_request(1)
        git(self.repository, "tag", VERSION)
        code, stdout, _, notes, _ = self.build([{"tag_name": VERSION, "draft": False}], [self.pull(1, "- fix: One.")])
        self.assertEqual(code, 0, stdout)
        self.assertEqual(notes, "### Fixes\n\n- One. (#1)\n")

    def test_stops_with_the_pull_request_number_when_a_section_is_missing(self):
        self.merge_pull_request(1)
        self.merge_pull_request(2)
        pulls = [self.pull(1, "- none"), {**self.pull(2), "body": "No section here."}]
        code, stdout, outputs, notes, _ = self.build([], pulls)
        self.assertEqual(code, 1)
        self.assertIn("Pull Request #2: 変更の節 (## Changes) が無い", stdout)
        self.assertIsNone(notes)
        self.assertEqual(outputs, {})

    def test_dry_run_outside_main_does_not_build(self):
        self.merge_pull_request(1)
        code, stdout, outputs, notes, requests = self.build([], [{**self.pull(1), "body": "broken"}], ref="refs/heads/develop")
        self.assertEqual(code, 0, stdout)
        self.assertEqual(outputs, {"built": "false"})
        self.assertIsNone(notes)
        self.assertEqual(requests, [])

    def test_stops_when_a_release_tag_is_missing_locally(self):
        self.merge_pull_request(1)
        code, stdout, _, _, _ = self.build([{"tag_name": "0.1.0", "draft": False}], [self.pull(1, "- none")])
        self.assertEqual(code, 1)
        self.assertIn("tag 0.1.0 が作業ツリーに無い", stdout)

    def test_stops_when_the_api_fails(self):
        self.merge_pull_request(1)
        with release_fakes.FakeServer(lambda request: (500, "error")) as server:
            code, stdout, _ = support.run_main(
                SCRIPT,
                [
                    "--version", VERSION, "--output", os.path.join(self.directory, "notes.md"),
                    "--commit", git(self.repository, "rev-parse", "HEAD"), "--ref", "refs/heads/main",
                    "--repository", "kamusoft/KsCollectionView", "--api-url", server.url, "--repository-root", self.repository,
                ],
            )
        self.assertEqual(code, 1)
        self.assertIn("500", stdout)


if __name__ == "__main__":
    unittest.main()
