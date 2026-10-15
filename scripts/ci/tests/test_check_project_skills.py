"""プロジェクト内の Skill の置き場の検査のテスト。

今のリポジトリの置き場に流すテストと、一時のディレクトリに作った置き場 (正しい形と、崩した形)
に流すテストを持つ。
"""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest

import support

SCRIPT = support.load_script("check-project-skills.py")

NAME = "docs-refresh"


def skill_file(name: str, description: str = "追従を行う") -> str:
    return f"""\
---
name: {name}
description: "{description}"
---

# {name}
"""


class RepositoryLayoutTest(unittest.TestCase):
    """今のリポジトリの置き場が、決めた形になっている。"""

    def test_claude_skill_is_relative_link_to_agents_skill(self):
        link = os.path.join(support.REPOSITORY_ROOT, ".claude", "skills", NAME)
        entity = os.path.join(support.REPOSITORY_ROOT, ".agents", "skills", NAME)
        self.assertTrue(os.path.islink(link))
        self.assertFalse(os.path.isabs(os.readlink(link)))
        self.assertEqual(os.path.realpath(link), os.path.realpath(entity))
        self.assertTrue(os.path.isdir(entity))
        self.assertFalse(os.path.islink(entity))

    def test_skill_file_is_readable_through_link_and_name_matches_directory(self):
        path = os.path.join(support.REPOSITORY_ROOT, ".claude", "skills", NAME, "SKILL.md")
        fields = SCRIPT.read_frontmatter(path)
        self.assertIsNotNone(fields)
        self.assertEqual(fields["name"], NAME)
        self.assertTrue(fields["description"])

    def test_check_passes_on_repository(self):
        violations, names = SCRIPT.check_project_skills(support.REPOSITORY_ROOT)
        self.assertEqual(violations, [])
        self.assertIn(NAME, names)

    def test_main_passes_on_repository(self):
        code, out, _ = support.run_main(SCRIPT, [support.REPOSITORY_ROOT])
        self.assertEqual(code, 0, out)
        self.assertIn("違反なし", out)


class LayoutViolationTest(unittest.TestCase):
    """一時の置き場で、崩れた形が違反として出る。"""

    def setUp(self):
        self.root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.root)
        self.entity = os.path.join(self.root, ".agents", "skills", NAME)
        support.write(os.path.join(self.entity, "SKILL.md"), skill_file(NAME))
        self.links = os.path.join(self.root, ".claude", "skills")
        os.makedirs(self.links)
        self.link = os.path.join(self.links, NAME)

    def make_link(self, target: str = os.path.join("..", "..", ".agents", "skills", NAME)) -> None:
        os.symlink(target, self.link)

    def violations(self) -> list[str]:
        return SCRIPT.check_project_skills(self.root)[0]

    def test_valid_layout_passes(self):
        self.make_link()
        violations, names = SCRIPT.check_project_skills(self.root)
        self.assertEqual(violations, [])
        self.assertEqual(names, [NAME])

    def test_missing_link_is_violation(self):
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn(".claude/skills/docs-refresh: リンクが無い", violations[0])

    def test_directory_instead_of_link_is_violation(self):
        support.write(os.path.join(self.link, "SKILL.md"), skill_file(NAME))
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("シンボリックリンクでない", violations[0])

    def test_link_to_other_place_is_violation(self):
        other = os.path.join(self.root, "other", NAME)
        support.write(os.path.join(other, "SKILL.md"), skill_file(NAME))
        self.make_link(os.path.join("..", "..", "other", NAME))
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("リンクの先 (../../other/docs-refresh) が、実体 .agents/skills/docs-refresh でない", violations[0])

    def test_dangling_link_is_violation(self):
        self.make_link(os.path.join("..", "..", ".agents", "skills", "missing"))
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("実体 .agents/skills/docs-refresh でない", violations[0])

    def test_absolute_link_is_violation(self):
        self.make_link(self.entity)
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("絶対のパス", violations[0])

    def test_name_different_from_directory_is_violation(self):
        support.write(os.path.join(self.entity, "SKILL.md"), skill_file("skills-refresh"))
        self.make_link()
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("name (skills-refresh) が、ディレクトリの名前 (docs-refresh) と違う", violations[0])

    def test_missing_description_is_violation(self):
        support.write(os.path.join(self.entity, "SKILL.md"), "---\nname: docs-refresh\n---\n")
        self.make_link()
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("description が無い", violations[0])

    def test_missing_frontmatter_is_violation(self):
        support.write(os.path.join(self.entity, "SKILL.md"), "# docs-refresh\n")
        self.make_link()
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("frontmatter が無い", violations[0])

    def test_missing_skill_file_is_violation(self):
        os.remove(os.path.join(self.entity, "SKILL.md"))
        self.make_link()
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn("SKILL.md が無い", violations[0])

    def test_link_without_entity_is_violation(self):
        self.make_link()
        os.symlink(os.path.join("..", "..", ".agents", "skills", NAME), os.path.join(self.links, "release"))
        violations = self.violations()
        self.assertEqual(len(violations), 1)
        self.assertIn(".claude/skills/release: リンクの先 (../../.agents/skills/docs-refresh) が、実体 .agents/skills/release でない", violations[0])

    def test_no_agents_skills_is_violation(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root)
        violations, names = SCRIPT.check_project_skills(root)
        self.assertEqual(names, [])
        self.assertIn(".agents/skills: ディレクトリが無い", violations[0])

    def test_empty_agents_skills_is_violation(self):
        root = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root)
        os.makedirs(os.path.join(root, ".agents", "skills"))
        violations, _ = SCRIPT.check_project_skills(root)
        self.assertIn("Skill が 1 つも無い", violations[0])

    def test_main_reports_violation(self):
        code, out, _ = support.run_main(SCRIPT, [self.root])
        self.assertEqual(code, 1)
        self.assertIn("::error::.claude/skills/docs-refresh: リンクが無い", out)
        self.assertIn("違反 1 件", out)

    def test_main_rejects_missing_root(self):
        code, out, _ = support.run_main(SCRIPT, [os.path.join(self.root, "missing")])
        self.assertEqual(code, 2)
        self.assertIn("実在するディレクトリではない", out)


if __name__ == "__main__":
    unittest.main()
