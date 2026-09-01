# セカンドオピニオン: kasane-initial-assets (code-001)
**相方**: codex / **label**: so-code-kasane-initial-assets / **日付**: 2026-09-01 / **対象**: 実装成果物一式 (decisions/ ADR 4 本と index 再構成、handbook/cross 5 本と index、roadmap 改訂、config・各 index の maui 除去)
---
# レビュー結果: kasane-initial-assets

**日付**: 2026-09-01
**判定**: CHANGES_REQUESTED

## サマリー

翻案元との照合では、MAUI 固有部分の除去、未検証知見の明示、公開識別子の先取り、ADR 間の参照は概ね妥当です。Markdown リンクの実在確認と `git diff --check` も通過しました。

一方、代替仕様である tasks.md に未充足の完了条件があり、ロードマップには phase-7 のスコープと矛盾する完了条件があります。

指摘件数: Critical 0 / Major 2 / Minor 2 / Suggestion 0

## 照合した規約

- `ksn-review` および `ksn-core` の handbook・domain-axis・delta-spec・paths 規約
- ソースコメント規約（always。今回ソース変更なし）
- Sample のプラットフォーム間一致
- テスト実行規約
- 実行時挙動の検証規約
- 公開識別子と配布座標
- ローカル開発環境と Sample の実行

ビルド・テストは依頼条件に従い未実施です。ホスト実施済み lint 結果を前提としました。対象外の `.claude/`、`.codex/`、`scripts/comment-policy-lint.py` はレビュー範囲に含めていません。

## 指摘事項

### [🟠 Major] 完了済みとされた決定対応表が存在しない

**該当箇所**: `tasks.md:35`

**問題点**: 4.4 は「exploration.md の決定事項と成果物の対応を1件ずつ照合して記録」と明記されていますが、対応表または個別の照合記録が成果物内にありません。tasks.md が代替仕様であるため、記録のない状態での `[x]` は完了条件を満たしていません。

**推奨修正**: tasks.md に少なくとも次の4行の対応表を追加してください。

- handbook 5本移植 → 対応する5ファイル
- ADR 4本翻案 → cross/0002〜0005
- artifactId の先取り → cross/0003・public-identifiers
- 二本立て実施 → 本 change とロードマップ改訂箇所

### [🟠 Major] phase-7 を除外した決定とロードマップの完了条件が矛盾している

**該当箇所**: `kasane/roadmaps/v1-foundation/roadmap.md:32`
**関連箇所**: `kasane/roadmaps/v1-foundation/history.md:5`、`kasane/roadmaps/v1-foundation/phases/phase-7-samples-distribution/agenda.md:3`

**問題点**: roadmap.md は「phase-4 以降の change フェーズ」すべてに Sample デモ追加を要求しています。この表現では phase-7 も対象になりますが、phase-7 agenda は Sample を明確に対象外としています。また、実行順では phase-8 が phase-4 より前なので、「phase-4 以降」では承認済みの対象範囲「phase-4〜6、8」を正確に表せません。history.md の「以降の全 change フェーズ」も同じ矛盾を持ちます。

**推奨修正**: 対象を「phase-8 および phase-4〜6」のように明示し、history.md も同じ表現へ揃えてください。

### [🟡 Minor] accepted な長命成果物ではなく使い捨て change を参照している

**該当箇所**: `kasane/roadmaps/v1-foundation/roadmap.md:30`
**関連箇所**: `kasane/roadmaps/v1-foundation/phases/phase-7-samples-distribution/agenda.md:9`

**問題点**: Sample 規約の参照先が exploration.md であり、phase-7 も方針 ADR を「change で起草済み」と記述しています。実際には cross/ADR-0004・0005 と handbook が accepted 済みです。change の Markdown リンクは archive 後に切れ、状態表現も既に古くなっています。

**推奨修正**: roadmap.md は `kasane/handbook/cross/sample-parity.md` と cross/ADR-0004、phase-7 agenda は cross/ADR-0005 を直接参照し、「accepted 済み」に合わせて記述してください。

### [🟡 Minor] Sample の作成フェーズに関する config コメントが旧計画のまま

**該当箇所**: `kasane/config.yaml:62`

**問題点**: 「skills / samples は phase-7 で作られる予定」とありますが、改訂後は Sample scaffold を phase-2 / phase-3 で作成し、phase-7 は Sample 対象外です。成果物間で計画が食い違っています。

**推奨修正**: 「samples は phase-2/3、skills は phase-7 で作成予定」のように分けて記述してください。

## アクションプラン

1. tasks.md に決定対応表を記録する。
2. Sample 追加対象を phase-8・phase-4〜6へ限定し、roadmap/history を同期する。
3. roadmap の参照を accepted ADR・handbook へ張り替える。
4. config.yaml のフェーズ記述を現行ロードマップへ合わせる。

---

## 突き合わせ結果 (ホスト側判定: 2026-09-01)

ホスト側独立レビュー (review-001.md、判定 CHANGES_REQUESTED: Major 1 / Minor 5 / Suggestion 3) との突き合わせ。

| 指摘 | 出典 | 採否 | 対応 |
|---|---|---|---|
| tasks 4.4 決定対応表の記録欠落 | 双方一致 (両者 Major) | 確定 | tasks.md に対応表を記録 |
| roadmap「phase-4 以降」が phase-7 を巻き込み・phase-8 の実行順も表せない | 相方のみ・根拠強 | 採用 | 「phase-4〜6 および phase-8」へ明示、history.md も同期 |
| roadmap / phase-7 agenda が change (exploration.md) を参照 | 双方一致 (両者 Minor) | 確定 | accepted 済みの cross/ADR-0004・0005 と handbook へ張り替え |
| config.yaml の「skills / samples は phase-7 で」コメントが旧計画 | 相方のみ・根拠強 | 採用 | samples = 基盤フェーズ / skills = 配布フェーズに分けて修正 |
| tasks 4.2 の「3 箇所」宣言と 4 件列挙の不一致 | ホストのみ | 採用 | 個数宣言を削除 |
| tasks 4.2 が roadmap の先行実装参照 (KsSettingsViewUI 等) を取りこぼし | ホストのみ | 採用 | 許容 (先行実装参照) を明記 |
| tasks 4.1 comment-policy lint「PASS」が実行 0 件の空振り | ホストのみ | 採用 | 「検査対象 0 ファイル」と実行件数を明記する記録へ修正 |
| proposal 未申告の同梱物 (comment-policy lint 一式・hook 登録) | ホストのみ | 採用 | proposal Impact にコミット単位の申し送りを追記 |
| concepts/rules.md の timestamp 未更新 | ホストのみ | 採用 | 2026-09-01 へ更新 |
| Suggestion 3 件 (applies-when.paths の bundle ID 宣言箇所 / agenda への完了条件の落とし込み / 既存 agenda のパス規約) | ホストのみ | 見送り | 任意対処。agenda への落とし込みは各フェーズの ksn-agenda 議論で反映、既存 agenda のパス規約は本 change のスコープ外 |

降格: なし / 未解決: なし。確定・採用分はすべて記録・文言の修正で、成果物 (ADR・handbook) の内容修正は不要 — 両レビューとも内容面 (翻案の忠実性・混入なし・リンク解決) は合格評価。
