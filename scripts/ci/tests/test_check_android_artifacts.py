"""Android の発行物の、送る前の確かめ (scripts/release/check-android-artifacts.py) のテスト。

組み立ての段の発行物と、署名して組み立て直した発行物の代わりに、一時のディレクトリに
Maven のリポジトリの形のひな形を作る。
"""

from __future__ import annotations

import os
import shutil
import tempfile
import unittest

import release_fakes
import support

SCRIPT = release_fakes.load("check-android-artifacts.py")

VERSION = "0.1.0-beta.1"
COMMIT = "a" * 40
PREFIX = f"kscollectionview-{VERSION}"
SIGNATURE = "-----BEGIN PGP SIGNATURE-----\n\nabc\n-----END PGP SIGNATURE-----\n"


def publication(version: str = VERSION, commit: str | None = COMMIT) -> dict[str, bytes]:
    prefix = f"kscollectionview-{version}"
    return {
        f"{prefix}.pom": release_fakes.pom_text(version, commit).encode(),
        f"{prefix}.module": b'{"formatVersion": "1.1"}\n',
        f"{prefix}.aar": b"PK\x03\x04aar",
        f"{prefix}-sources.jar": b"PK\x03\x04sources",
        f"{prefix}-javadoc.jar": b"PK\x03\x04javadoc",
    }


class CheckAndroidArtifactsTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.mkdtemp(prefix="android-artifacts-test-")
        self.addCleanup(shutil.rmtree, self.directory)
        self.reference = os.path.join(self.directory, "reference")
        self.signed = os.path.join(self.directory, "signed")

    def place(self, repository: str, files: dict[str, bytes], version: str = VERSION, signed: bool = False) -> str:
        directory = os.path.join(repository, "jp", "kamusoft", "kscollectionview", version)
        os.makedirs(directory, exist_ok=True)
        for name, content in files.items():
            with open(os.path.join(directory, name), "wb") as f:
                f.write(content)
            if signed:
                support.write(os.path.join(directory, name + ".asc"), SIGNATURE)
                support.write(os.path.join(directory, name + ".sha1"), "0" * 40)
        support.write(os.path.join(repository, "jp", "kamusoft", "kscollectionview", "maven-metadata-local.xml"), "<metadata/>")
        return directory

    def check(self, *extra: str, signed: bool = True, commit: str | None = COMMIT):
        arguments = ["--version", VERSION, "--reference", self.reference]
        if signed:
            arguments += ["--signed", self.signed]
        if commit is not None:
            arguments += ["--commit", commit]
        return support.run_main(SCRIPT, [*arguments, *extra])

    def test_matching_signed_publication_passes(self):
        self.place(self.reference, publication())
        self.place(self.signed, publication(), signed=True)
        code, stdout, _ = self.check()
        self.assertEqual(code, 0, stdout)
        self.assertIn("5 ファイル", stdout)

    def test_reference_alone_checks_coordinates_and_commit(self):
        self.place(self.reference, publication())
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 0, stdout)

    def test_missing_signature_stops(self):
        self.place(self.reference, publication())
        directory = self.place(self.signed, publication(), signed=True)
        os.remove(os.path.join(directory, f"{PREFIX}.aar.asc"))
        code, stdout, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn(f"{PREFIX}.aar の署名", stdout)

    def test_signature_of_another_form_stops(self):
        self.place(self.reference, publication())
        directory = self.place(self.signed, publication(), signed=True)
        support.write(os.path.join(directory, f"{PREFIX}.pom.asc"), "not a signature")
        code, stdout, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn("PGP の署名の形でない", stdout)

    def test_different_content_stops(self):
        self.place(self.reference, publication())
        self.place(self.signed, {**publication(), f"{PREFIX}.aar": b"PK\x03\x04other"}, signed=True)
        code, stdout, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn(f"中身が組み立ての段と違う: {PREFIX}.aar", stdout)

    def test_extra_or_missing_files_stop(self):
        self.place(self.reference, publication())
        signed_files = publication()
        del signed_files[f"{PREFIX}-javadoc.jar"]
        signed_files[f"{PREFIX}-extra.jar"] = b"extra"
        self.place(self.signed, signed_files, signed=True)
        code, stdout, _ = self.check()
        self.assertEqual(code, 1)
        self.assertIn(f"組み立ての段にだけある発行物: {PREFIX}-javadoc.jar", stdout)
        self.assertIn(f"署名したほうにだけある発行物: {PREFIX}-extra.jar", stdout)

    def test_missing_required_file_stops(self):
        files = publication()
        del files[f"{PREFIX}.aar"]
        self.place(self.reference, files)
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 1)
        self.assertIn(f"{PREFIX}.aar が無い", stdout)

    def test_snapshot_version_in_the_pom_stops(self):
        files = publication()
        files[f"{PREFIX}.pom"] = release_fakes.pom_text("0.1.0-SNAPSHOT", COMMIT).encode()
        self.place(self.reference, files)
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 1)
        self.assertIn("POM の version が '0.1.0-SNAPSHOT'", stdout)

    def test_commit_mismatch_stops(self):
        self.place(self.reference, publication(commit="b" * 40))
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 1)
        self.assertIn("元になった commit", stdout)

    def test_missing_commit_in_the_pom_stops(self):
        self.place(self.reference, publication(commit=None))
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 1)
        self.assertIn("scm の tag) が None", stdout)

    def test_missing_version_directory_stops(self):
        code, stdout, _ = self.check(signed=False)
        self.assertEqual(code, 1)
        self.assertIn("発行物の置き場が無い", stdout)

    def test_rejects_malformed_inputs(self):
        for arguments in (["--version", "0.1", "--reference", self.reference], ["--version", VERSION, "--reference", self.reference, "--commit", "xyz"]):
            with self.subTest(arguments=arguments):
                code, stdout, _ = support.run_main(SCRIPT, arguments)
                self.assertEqual(code, 1)
                self.assertIn("形が違う", stdout)


if __name__ == "__main__":
    unittest.main()
