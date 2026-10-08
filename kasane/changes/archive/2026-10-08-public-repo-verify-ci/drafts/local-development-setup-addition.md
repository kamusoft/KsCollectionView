> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/local-development-setup.md`
> - 追記 1 は、節「必要環境」の前に、新しい節として足す (clone の直後に行うことなので、先頭に置く)
> - 追記 2 は、節「関連」に 2 行足す
> - 追記 3 は、frontmatter と冒頭の段落の直し
> - hook の中身は `.githooks/pre-commit`・`.githooks/pre-push` の実物から書いた。GitHub のリポジトリは 2026-10-08 に公開され、既定のブランチが `main` であること・開発に使っている手元の remote が SSH の形であることは、公開の実施の記録 (`evidence/publication-log.md`) にある。新しく clone して直後の状態を見た記録は無い。`【公開の実施後に記入】` の印は残っていない
> - `timestamp` は、手順が再現することを確かめた場合だけ動かす

---

## 追記 1: 節を足す

## clone した後の準備と作業の基点

clone した後に、次の 2 つを行う。どちらも clone ごとに 1 回でよい。

| 行うこと | コマンド | 確かめ方 |
|---|---|---|
| commit と push の前の検査を有効にする | `git config core.hooksPath .githooks` | `git config core.hooksPath` が `.githooks` を返す |
| 作業の基点のブランチに移る | `git switch develop` | `git branch --show-current` が `develop` を返す |

remote は clone した時点で `origin` として入っている。`git remote -v` で、`kamusoft/KsCollectionView` を指していることを確かめる。

clone した直後の状態: チェックアウトされるブランチは、既定のブランチの `main` である。作業は `develop` に切り替えてから始める。開発に使っている手元の remote は、GitHub の SSH の URL (ホストは `github.com`、パスは `kamusoft/KsCollectionView.git`) である。

既定のブランチが `main` であることは、2026-10-08 に GitHub の設定を読み直して確かめた。新しく clone して、直後の状態を見ることはしていない。

### 作業の基点は develop

日々の開発は `develop` で行う。作業用のブランチと worktree は、`main` ではなく `develop` から切る。GitHub の既定のブランチは `main` なので、clone した直後は `develop` に移ってから始める。

`main` に直接 commit しない。`main` に入るのは、`develop` からの Pull Request だけである ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))。

### commit と push の前の検査

`.githooks/` の hook は、有効にしないと動かない。有効にすると、次の検査が走る。

| 時点 | 検査 | 止まるもの |
|---|---|---|
| commit の前 | `scripts/git-gate-lint.py --staged` | ステージした内容にある、個人・端末・秘密を特定する値とローカル絶対パス |
| commit の前 | gitleaks (入っているときだけ) | ステージした内容にある secret |
| push の前 | `scripts/git-gate-lint.py --push` | push する commit が触ったファイルの、各 commit の時点の内容にある同じ違反 |

- gitleaks が入っていないと、commit の前の secret の検査は警告を出して省かれる。`brew install gitleaks` で入れる
- 検査で止まったら、該当の行を直して commit し直す。`--no-verify` で迂回しない
- 公開リポジトリでは、push した時点で内容が公開される。`kasane/` 配下だけを変えた push では検証 CI が起動しないので、その内容を止められるのは手元のこの検査だけである

## 追記 2: 節「関連」に足す行

- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — `develop` と `main` の役割、push と Pull Request の進め方
- [検証 CI](verification-ci.md) — push の後に走る検証と、workflow を手元で確かめる方法

## 追記 3: frontmatter と冒頭の段落

`applies-when.tasks` に「clone した後の準備」「作業用のブランチ・worktree の作成」を足し、index の「適用のきっかけ」にも同じ言葉を足す。

`description` の先頭に「clone した後の準備 (検査の有効化・作業の基点)、」を足す。

冒頭の段落「リポジトリを clone した開発者が iOS・Android の Sample を開いて実行し…」は、「リポジトリを clone した開発者が、検査を有効にして `develop` から作業を始め、iOS・Android の Sample を開いて実行し…」に直す。
