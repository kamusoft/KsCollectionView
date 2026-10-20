# セカンドオピニオン: release-pipeline (code-001)
**相方**: codex / **label**: so-code-release-pipeline-001 / **日付**: 2026-10-15 / **対象**: 作業ツリーの未 commit の変更すべて (HEAD c764358 からの差分と未追跡のファイル。tasks 1〜7)
---
# レビュー結果: release-pipeline (001 回目)

**日付**: 2026-10-15  
**判定**: APPROVED  
**指摘件数**: Critical 0 / Major 0 / Minor 1 / Suggestion 0

## サマリー

レビュー対象の範囲では、公開の順序、再実行時の状態照合、secret の受け渡しについて、Critical／Major に該当する問題は見つからなかった。送信が失敗した際に原因のログが表示されない問題を、Minor として指摘する。

静的レビューのみ実施した。ビルド・テストは再実行せず、提示されたホスト側の結果を前提とした。tasks.md の 8〜10、合意済みの deviation、長命層への反映は判定対象から除外した。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` — 追加・変更されたソースコメント。
- `kasane/handbook/cross/test-execution.md` — 追加テストの検証内容と、実行結果の扱い。
- `kasane/handbook/cross/public-identifiers.md` — Maven 座標と SwiftPM の参照先。
- `kasane/handbook/cross/verification-ci.md` — workflow の権限、道具の固定、失敗の伝播とログの記録。
- `kasane/handbook/cross/package-distribution.md` — 配布物の構成、署名、作業用リポジトリへの発行。
- `kasane/handbook/cross/consumer-build-check.md` — 利用者役の参照元、ビルド条件、既存の切り替えとの互換性。
- 関連 ADR — ブランチ運用、検証 CI、SwiftPM の配布方法、利用者役の確認、版の記述方針、Android のビルド構成。

ロードしたスキル: `ksn-review`、`kotlin-impl-skill`。

## 確認した観点

- デルタスペックと合意済み差分に対する実装の整合。
- 足場アーティファクトの変更と tasks.md のチェック内容。
- 入力検証、dry-run の分岐、公開前の検証への依存。
- 成果物の受け渡し、署名の存在、署名前後の内容比較。
- 公開済み POM の commit 照合と、両リポジトリの tag の照合。
- 送信控えの引き継ぎと、状態別の再実行・取り下げ処理。
- secret の使用範囲、権限、シェルへの入力の渡し方。
- 待機の上限、異常系テスト、workflow 定義テストの検出範囲。
- リリースノートの収集範囲と変更節の検査。
- リリース Skill、リンク、AGENTS.md、手順草稿の整合。

## 指摘事項

### [🟡 Minor] Maven Central への送信が失敗すると Gradle のログが表示されない

**該当箇所**: `.github/workflows/release.yml:432`

**問題点**:  
この step はシェルを指定していないため、Linux の既定である `bash -e {0}` で実行される。`set -uo pipefail` は、起動時から有効な `errexit` を解除しない。[GitHub のシェル仕様](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idstepsshell)

そのため、434 行目の Gradle が非ゼロで終了すると、`status=$?` と `cat "$log"` に到達せずに step が終了する。標準出力・標準エラーは一時ファイルにだけ残り、後続の ID 抽出処理も元のログ全体は表示しないため、認証や送信の失敗原因を Actions のログから確認できなくなる。

既存テストは `status=$?` などの文字列の存在を確認しているが、`-e` が有効なシェルでの失敗経路は検証していない。失敗自体は正しく伝播するため、重要度は Minor とする。

**推奨修正**:  
Gradle の呼び出しを `if …; then …; else status=$?; fi` で囲むなどして、`-e` が有効でも終了コードを保存し、ログを表示してから元の終了コードを返す。

併せて、偽の Gradle がエラーメッセージを出して非ゼロで終了するケースを、Actions と同じシェルオプションで検証し、メッセージの表示と終了コードの保持を確認する。

## アクションプラン

1. 送信 step の終了コード保存とログ表示を、`errexit` の影響を受けない形に修正する。
2. 送信失敗時のログ表示と終了コード保持を確認するテストを追加する。


## 突き合わせ結果

ホスト側: review-001.md (APPROVED、Minor 3・Suggestion 1)。相方: APPROVED (Minor 1)。双方一致の指摘は無い。

| 出典 | 指摘 | 採否 | 理由 |
|---|---|---|---|
| 相方 | 送信の step が `bash -e` で動くため、Gradle が失敗すると終了コードの控えとログの表示に届かない (release.yml:432) | 採用 | 該当箇所と、既定のシェルが `-e` を付ける根拠 (公式の文書) がそろい、失敗の原因が Actions に残らない実害がある。直してテストを足す |
| ホスト | 手順の草稿の「Wait for validation」の行が、後始末の取り下げと合わない (drafts/release-procedure.md:554) | 確定 (ホストのみ) | 初回のリリースはこの草稿に従う |
| ホスト | iOS は確かめた artifact ではなく作り直した写しを push し、照合が無い (release.yml:384-395) | 確定 (ホストのみ) | design Decision 8 の「工程が実際に公開する成果物を確かめる」が iOS で崩れる。確かめた artifact の中身をそのまま push する形に直す |
| ホスト | tasks 1.1・1.2 のチェックが無い | 確定 (ホストのみ) | 記録の漏れ |
| ホスト | 公開のジョブの前半 (署名・別の組み立てとのバイトの一致) は初回の本番まで動かない (Suggestion) | 採用 | 取り消せない公開の前に、使い捨ての鍵と別々の clone で手元で一度通すのは安く、外へ何も送らない |

降格: なし / 未解決: なし
