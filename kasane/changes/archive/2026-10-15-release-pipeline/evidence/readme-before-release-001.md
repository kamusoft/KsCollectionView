# README の「まだ公開していない」の 1 文と、配信用 README のひな形 (tasks 10.5)

日付: 2026-10-15 / 承認: オーナーがチャットで tasks 10.5 の実施を指示 (commit はまだしない)

## 外した 1 文

| ファイル | 外した段落 (インストールの節の先頭) |
|---|---|
| `README.md` (38 行目) | `KsCollectionView has not been published yet, so the declarations below cannot be resolved at this time. They show how the dependency will be declared once the first version is released.` |
| `README_ja.md` (38 行目) | `KsCollectionView はまだ公開していないため、以下の宣言は現時点では解決できません。最初の版を公開した後の、依存の書き方を示しています。` |

- 外した後のインストールの節は、`{version}` を置き換えること・置き換えないと依存の解決に失敗すること・最新の版の確かめ先 (本リポジトリの Releases) から始まる
- 同じ趣旨の文がほかに無いことを、`grep -n -i "not yet\|not been published\|まだ公開\|公開していない\|unreleased" README.md README_ja.md skills -r` で確かめた (0 件)
- spec user-readme「まだ公開していないとは書かれていない」には自動の検査を足さなかった。この文は初回のリリースの前の一度きりの状態で、外した後に書き戻す経路が無いため。外したことは、この照合で確かめた

## 配信用 README のひな形との照合

`scripts/distribution/spm-readme.template.md` (写しのルートの README になる) を、ルートの `README.md` と照らした。

| ひな形の記述 | ルートの README・本リポジトリの設定 | 結果 |
|---|---|---|
| 配信用の写し (distribution mirror) で、ソース・文書・Issue は本リポジトリにある (`https://github.com/kamusoft/KsCollectionView`) | 本リポジトリの URL は同じ | 一致 |
| インストールの方法・対応する版・使い方は本リポジトリの README (`#readme`) にある | README にインストール・対応プラットフォーム・最小コード例がある | 一致 |
| ここに Issue と Pull Request を出さない。問題と提案は本リポジトリの Issues へ | README の末尾: 不具合・提案・質問は GitHub Issues で受け、外部の Pull Request は受けない。本リポジトリは Issue が有効 (`has_issues: true`)。配信用リポジトリは Issue 無効・Pull Request は共同作業者だけ (evidence/github-spm-repository-001.md) | 一致 |
| ライセンスは本リポジトリと同じ `LICENSE` | 写しに `LICENSE` が入る (sync-spm-snapshot.py の写しの 5 点) | 一致 |
| (公開の状態について書いていない) | — | 外す文は無い |
| (Release について書いていない) | 最新の版の確かめ先は本リポジトリの Releases (cross/ADR-0024: Release は本リポジトリにだけ作る) | 食い違いは無い |

ひな形は直していない。

## 検査

- `python3 scripts/ci/run-tests.py`: 実行 728 件・失敗 0・スキップ 4
- `python3 scripts/ci/check-readme-examples.py .`: 違反なし (最小コード例 4 つ・依存の宣言の行 12 行が一致)
