"""Android の発行物の POM に、元になった commit を書く設定 (android/kscollectionview/build.gradle.kts) のテスト。

2 つの層で確かめる。

- 設定の書き方: ビルドの定義が、Gradle のプロパティ ksCollectionViewSourceCommit を POM の scm の
  tag に渡し、commit の無い発行物を Maven Central へ送るビルドを止めていること。いつでも流れる
- 実物: Gradle で発行物を手元の一時の Maven リポジトリに作り、POM に commit が入ること・形の違う
  値と commit の無い送信が止まることを確かめる。Android の SDK と JDK が要り、時間がかかるので、
  環境変数 KS_GRADLE_TESTS=1 のときだけ流す (それ以外はスキップとして数える)
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest

import release_fakes
import support

ANDROID_DIR = os.path.join(support.REPOSITORY_ROOT, "android")
BUILD_FILE = os.path.join(ANDROID_DIR, "kscollectionview", "build.gradle.kts")
PROPERTY = "ksCollectionViewSourceCommit"
VERSION = "0.1.0-beta.1"
CHECK_ARTIFACTS = release_fakes.load("check-android-artifacts.py")


def read_build_file() -> str:
    with open(BUILD_FILE, encoding="utf-8") as f:
        return f.read()


def strip_comments(text: str) -> str:
    return re.sub(r"//[^\n]*", "", text)


class BuildDefinitionTest(unittest.TestCase):
    def setUp(self):
        self.code = strip_comments(read_build_file())

    def test_scm_tag_takes_the_source_commit_property(self):
        self.assertIn(f'providers.gradleProperty(sourceCommitProperty)', self.code)
        self.assertIn(f'val sourceCommitProperty = "{PROPERTY}"', self.code)
        scm = re.search(r"scm \{(?P<body>.*?)\n        \}", self.code, re.DOTALL)
        self.assertIsNotNone(scm)
        self.assertIn("tag.set(sourceCommit)", scm.group("body"))

    def test_sending_without_the_commit_is_refused(self):
        self.assertRegex(self.code, r"if \(!providers\.gradleProperty\(sourceCommitProperty\)\.isPresent\)")
        self.assertNotIn("mavenCentralAutomaticPublishing", self.code)


def gradle(*arguments: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [os.path.join(ANDROID_DIR, "gradlew"), "--console=plain", *arguments],
        cwd=ANDROID_DIR,
        capture_output=True,
        text=True,
    )


@unittest.skipUnless(os.environ.get("KS_GRADLE_TESTS") == "1", "KS_GRADLE_TESTS=1 のときだけ Gradle を流す")
class GradlePublicationTest(unittest.TestCase):
    def setUp(self):
        self.commit = subprocess.run(
            ["git", "-C", support.REPOSITORY_ROOT, "rev-parse", "HEAD"], capture_output=True, text=True, check=True
        ).stdout.strip()

    def test_pom_carries_the_source_commit(self):
        with tempfile.TemporaryDirectory(prefix="android-publication-") as repository:
            result = gradle(
                f"-Dmaven.repo.local={repository}", f"-Pversion={VERSION}", f"-P{PROPERTY}={self.commit}",
                ":kscollectionview:publishToMavenLocal",
            )
            self.assertEqual(result.returncode, 0, result.stdout[-3000:] + result.stderr[-3000:])
            code, stdout, _ = support.run_main(
                CHECK_ARTIFACTS, ["--version", VERSION, "--reference", repository, "--commit", self.commit]
            )
            self.assertEqual(code, 0, stdout)

    def test_pom_without_the_property_has_no_tag(self):
        with tempfile.TemporaryDirectory(prefix="android-publication-") as repository:
            result = gradle(f"-Dmaven.repo.local={repository}", f"-Pversion={VERSION}", ":kscollectionview:publishToMavenLocal")
            self.assertEqual(result.returncode, 0, result.stdout[-3000:] + result.stderr[-3000:])
            pom = os.path.join(repository, "jp", "kamusoft", "kscollectionview", VERSION, f"kscollectionview-{VERSION}.pom")
            with open(pom, encoding="utf-8") as f:
                self.assertIsNone(CHECK_ARTIFACTS.support.read_pom(f.read())["scmTag"])

    def test_malformed_commit_is_refused(self):
        with tempfile.TemporaryDirectory(prefix="android-publication-") as repository:
            result = gradle(
                f"-Dmaven.repo.local={repository}", f"-Pversion={VERSION}", f"-P{PROPERTY}=ABC",
                ":kscollectionview:publishToMavenLocal",
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("40 桁の小文字の 16 進", result.stdout + result.stderr)

    def test_sending_without_the_commit_is_refused(self):
        # -m (dry run) はタスクを実行しない。止める判定はタスクの集合が決まった時点で走る。
        refused = gradle("-m", f"-Pversion={VERSION}", ":kscollectionview:publishToMavenCentral")
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("元になった commit が無い発行物は Maven Central へ送れない", refused.stdout + refused.stderr)
        accepted = gradle("-m", f"-Pversion={VERSION}", f"-P{PROPERTY}={self.commit}", ":kscollectionview:publishToMavenCentral")
        self.assertEqual(accepted.returncode, 0, accepted.stdout[-3000:] + accepted.stderr[-3000:])


if __name__ == "__main__":
    unittest.main()
