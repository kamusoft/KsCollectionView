# レビュー結果: public-repo-verify-ci (006 回目)

**日付**: 2026-10-08
**判定**: APPROVED

## サマリー

review-005 の 4 件のうち直すとした 3 件と、相方のレビューから採用した 1 件は、どれも解消している。直した文面は、今の workflow・残っているスクリプト・HEAD にある削除前のファイルと合っていて、新しい食い違いは見つからなかった。workflow・スクリプト・テストは review-005 の時点から変わっておらず、スクリプトのテストは 111 件すべて成功した。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テスト結果を報告するとき)
- ksn-core の change-scope (足場の凍結・deviation = 合意済みの差分)

ロードしたスキル: ksn-review (追加のレビュースキルは無し)
lessons: `kasane/lessons/code-review.md` の L-001 (証跡の計測値を自前で再現する) を、deviation の件数 (25 件) に適用した。

## 実行した確認

| 確認 | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 111 件 / 失敗 0 件 / スキップ 0 件 |
| `python3 scripts/ci/check-workflows.py` | workflow 3 本、違反なし |
| `python3 scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | どれも違反なし (コメントの検査は対象 494 ファイル・禁止 0 件) |
| 削除した 3 本のテストの件数 (`git show HEAD:<パス>` でテストのメソッドを数えた) | `test_check_ios_test_count.py` 9 件、`test_run_logged.py` 8 件、`test_select_simulator.py` 8 件。計 25 件で、deviation の記述と一致 |
| 出力を記録に残すスクリプトの呼び出し元 (HEAD) | `verify-ios.yml` の 2 箇所だけ。`verify-android.yml` と `ci.yml` には無い。deviation の「iOS のテストの記録を残すためだけに使っていて、Android は使っていなかった」と一致 |

`xcodebuild`・actionlint・GitHub からの読み取りは、パッケージの制約により流していない。最初の実行の記録にある Xcode の名前 (`Xcode_27.0.0.app` と `Xcode_27.app`) は、今回は読み直しておらず、review-005 で記録から読み取った値と、直した文面が同じであることだけを確かめた。

## 確認した観点

**review-005 と相方の指摘の解消**

| 指摘 | 結果 |
|---|---|
| 出力を記録に残すスクリプトとそのテストの削除が deviation に無い (Minor・優先度高) | 解消。`deviation.md:6` に、取り除いたこと、design の Decision 3 の 6 つのうちの 1 つで tasks 3.6 が作ったものであること、理由 (呼ぶ所が iOS のテストの記録だけで、ビルドの成否は `xcodebuild` の終了コードで決まる)、3 本のテスト計 25 件を取り除いたことが書かれている。design の表 (6 行) と tasks 3.6 の記述に合う |
| 草稿の冒頭の注記が「ランナーの上での実行はまだ 1 度も無い」のまま (Minor・優先度低) | 解消。`drafts/verification-ci.md:6` は、最初の実行 (2026-10-08) の後に iOS の節を直したこと、実測が要る箇所は印を付けて空けてあることを書いている。「1 度も無い」の記述は草稿に残っていない |
| `ios / verify` が落ちる原因をビルドだけに限っている (相方・Minor) | 解消。`drafts/verification-ci.md:152` は、テストの失敗では落ちないこと、落ちるのはビルド・その前の準備 (チェックアウト・Xcode の選択と版の確認)・時間の上限であること、手元の同じコマンドはビルドの誤りの切り分けに使えること、ランナーに固有の失敗は手元で再現しないことがあること、を書いている。直前の表 (Select Xcode / Show toolchain の行) と食い違わない |
| 証跡の Xcode の置き場の名前 (Suggestion) | 解消。`evidence/publication-log.md:96` に、選ばれた名前と実体の場所の両方がある。workflow の探し方 (`Xcode_${KS_XCODE_VERSION}*.app`、版は `27.0`) とも合う |
| 「テストを実行しない」のテストの届かない形 (Suggestion) | 見送り。今の workflow にその形は無く (`xcodebuild` の 2 つの呼び出しは `build-for-testing` と 4 つの引数だけ)、review-005 でも見送ってよいとしていた。妥当 |

**直した文面と実物の一致**
- `drafts/verification-ci.md:152` の「準備」の中身は、workflow の step (Checkout・Select Xcode・Show toolchain) と合う。時間の上限は `timeout-minutes: 40` がある
- 同じ段落が指す節「手元で確かめる」は草稿にある
- `drafts/verification-ci.md:154` の「本体のビルドの step まで進まなかった回では走らない」は、Sample の step の条件 (`!cancelled() && steps.library.outcome != 'skipped'`) と合う
- 残っているスクリプトは 5 本 (Android の件数・Pull Request の出どころ・workflow の定義・報告の共通部品・テストの入口) で、消した 3 本への参照は workflow・スクリプト・草稿に無い

**仕様充足・スコープ**
- 足場の凍結: proposal・design・specs・tasks に差分は無い
- deviation に記録の無い逸脱: 無い (review-005 で残っていた 1 件が埋まった)
- 付随修正 2 件: 変わっていない

**テスト**
- 全テストが成功 (111 件)、スキップ 0。review-005 の時点と同じ件数

**設計品質・記録**
- 直した 3 つのファイルに、ローカル絶対パスは無い (機械の検査も違反なし)
- 直しが持ち込んだ食い違い: 見つからなかった

## 指摘事項

### [🔵 Suggestion] 草稿の冒頭の注記に、ビルドだけにした形はランナーでまだ流していないことを 1 文足すと読み違えにくい

**該当箇所**: `drafts/verification-ci.md:6`

**問題点**: 注記は「最初の実行の後に iOS の節を直した」と書くが、直した後の形 (ビルドだけ) がランナーの上でまだ 1 度も流れていないことは、ここからは読めない。同じ事実は本文の「確かめ方の限界」(`drafts/verification-ci.md:271`) と、証跡の「確かめていないこと」に書いてあるので、食い違いではない。蒸留の担当が冒頭の囲みだけを読んだときに、iOS の節がランナーの実測に基づくと受け取る余地が残る。

**推奨修正**: 余力があれば、注記に「ビルドだけにした後の形は、ランナーの上でまだ流していない」を足す。見送ってよい (この囲みは蒸留のときに消える)。

## アクションプラン

1. 承認を妨げるものは無い。このまま進めてよい
2. (任意) 草稿の冒頭の注記に、上の 1 文を足す
3. (次の push の後) 変えた後の `ios / verify` の結果と所要時間を証跡に足し、草稿の `【公開の実施後に記入】` を埋める (前から決まっている持ち越しで、今回の指摘ではない)
