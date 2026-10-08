"""テストが共有する道具。"""

from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import sys
from unittest import mock

SCRIPTS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPOSITORY_ROOT = os.path.dirname(os.path.dirname(SCRIPTS_DIR))


def script_path(name: str) -> str:
    return os.path.join(SCRIPTS_DIR, name)


def load_script(name: str):
    """名前にハイフンを含むスクリプトを、モジュールとして読み込む。"""
    module_name = name.replace("-", "_").removesuffix(".py")
    spec = importlib.util.spec_from_file_location(module_name, script_path(name))
    module = importlib.util.module_from_spec(spec)
    # dataclass は、定義したモジュールを sys.modules から引く。
    sys.modules[module_name] = module
    spec.loader.exec_module(module)
    return module


def run_main(module, argv: list[str], env: dict[str, str] | None = None) -> tuple[int, str, str]:
    """スクリプトの main を呼び、(終了コード, 標準出力, 標準エラー出力) を返す。

    GitHub Actions の環境変数は、渡したものだけが見える状態にする
    (CI の上で流したときに、ランナーの値がテストに混ざらないようにするため)。
    """
    cleaned = {key: value for key, value in os.environ.items() if not key.startswith(("GITHUB_", "KS_"))}
    cleaned.update(env or {})
    stdout, stderr = io.StringIO(), io.StringIO()
    with mock.patch.dict(os.environ, cleaned, clear=True):
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                code = module.main(argv)
            except SystemExit as exit_:
                code = exit_.code if isinstance(exit_.code, int) else 1
    return code, stdout.getvalue(), stderr.getvalue()


def write(path: str, text: str) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path
