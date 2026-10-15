# セカンドオピニオン: release-pipeline (code-002)
**相方**: codex / **label**: so-code-release-pipeline-002 / **日付**: 2026-10-15 / **対象**: 作業ツリーの未 commit の変更すべて (HEAD c764358 からの差分と未追跡のファイル。修正サイクル 1 の後)
---
# レビュー結果: release-pipeline (002 回目)

**日付**: 2026-10-15  
**判定**: APPROVED

## サマリー

対象の未コミット差分と未追跡ファイルを静的にレビューし、修正を要求する問題は見つかりませんでした。前回の指摘は、実装修正・手順の修正・署名リハーサルの証跡で対応されています。

この判定は今回のレビュー対象に限ります。GitHub 上でのリリース実行、tasks 1.3・9・10、蒸留時の長命層への反映は含みません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` — 常時適用。追加・変更されたソースコメントを確認。
- `kasane/handbook/cross/test-execution.md` — テストの追加と実行結果の報告を確認。
- `kasane/handbook/cross/public-identifiers.md` — Maven 座標と SwiftPM の参照名を確認。
- `kasane/handbook/cross/package-distribution.md` — Android の公開設定、POM、署名、SwiftPM の写しを確認。
- `kasane/handbook/cross/consumer-build-check.md` — 利用者役の参照先と成功条件を確認。
- `kasane/handbook/cross/verification-ci.md` — 再利用 workflow、権限、道具の固定、失敗の伝播を確認。
- `kasane/handbook/cross/branch-and-github-settings.md` — 手順草稿のブランチ運用とマージ条件を確認。
- 関連する accepted ADR — 配布座標、ブランチの役割、検証 CI、SwiftPM 配信用リポジトリ、利用者役の確認に関する決定を照合。

ロードしたスキル: `ksn-review`、`kotlin-impl-skill`。

`deviation.md` の記録は合意済み差分として扱い、長命層への未反映を指摘対象から除外しました。

## 確認した観点

- 入力の版、起動元、dry-run、同時実行の制御。
- 検証・利用者役の確認が失敗した場合に公開へ進まないこと。
- iOS の検証済み artifact の配置と、配置前後の tree 照合。
- Android の版と元 commit の注入、署名の存在、署名を除いた発行物の一致。
- 公開済みの POM と起動 commit の照合。
- 保留・検証失敗・公開処理中・公開済み・取り下げ済みの再実行分岐。
- 公開指示前の後始末と、公開指示後の取り下げ抑止。
- tag と Release の作成順、既存成果物の扱い、リリースノートの引き継ぎ。
- secret の配置、step ごとの受け渡し、シェルへの入力の渡し方。
- 待機の上限、異常系テスト、既存の `local`・`published` の挙動。
- tasks のチェックと証跡の対応、足場アーティファクトの凍結。
- Kotlin DSL の Provider の扱い、入力検証、公開タスクの拒否条件。

ビルド・テストは依頼どおり再実行していません。ホスト提示のスクリプトテスト実行 728 件・失敗 0・スキップ 4、各 lint の違反なし、および `evidence/local-tests-001.md` の4系統の結果を確認材料としました。

### 前回の指摘の確認

| 指摘 | 確認結果 |
|---|---|
| Gradle 失敗時に終了コードの保持とログ表示へ届かない | 解消。`.github/workflows/release.yml:447` の `|| status=$?` で失敗を受け、ログ表示後に元の終了コードを返す。シェルでの回帰テストも追加されている。 |
| 検証待ちの上限時の手順が後始末と合わない | 解消。`drafts/release-procedure.md:573` で、後始末の待機と、取り下げ済み・検証中で残る場合の再実行を区別している。 |
| iOS が検証済み artifact を push していない | 解消。`.github/workflows/release.yml:397` が artifact を配置し、`scripts/release/place-spm-snapshot.py:96` が元 commit の写しと配置後の index を照合する。 |
| tasks 1.1・1.2 のチェック漏れ | 解消。`tasks.md:7`・`tasks.md:8` にチェックがあり、対応する調査証跡がある。 |
| 公開ジョブ前半の事前確認 | 対応済み。`evidence/publish-rehearsal-001.md:24` に署名付きの組み立て直しと発行物の一致、署名検証の結果がある。別ランナー間の一致と実送信は未確認として明記されている。 |

## 指摘事項

なし。

**件数**: Critical 0 / Major 0 / Minor 0 / Suggestion 0。

## アクションプラン

レビュー起因の修正はありません。対象外として残されているオーナー確認・GitHub の準備・通しの確認は、既存の tasks に従って扱ってください。


## 突き合わせ結果

ホスト側: review-002.md (APPROVED、Minor 1・Suggestion 1)。相方: APPROVED (指摘なし)。前回確定した 5 件は、双方とも解消を確認。

| 出典 | 指摘 | 採否 | 理由 |
|---|---|---|---|
| ホスト | push の直後に検証 CI の run がまだ一覧に現れないと、事前の確認が「代えられない」で止まる (drafts/release-procedure.md:311-344・SKILL.md:58-60) | 確定 (ホストのみ) | 止まる側で害は無いが、spec の止まる条件に当たらない停止。草稿の文面で直せる |
| ホスト | upload-artifact は隠しファイルと権限を保たないので、将来そういうファイルが写しに入ると照合が毎回外れる (Suggestion。drafts/release-procedure.md:567) | 採用 (草稿に原因の候補として書く) | 今は該当なし。検査を足すのは過剰なので、失敗したときの手掛かりとして 1 文足すだけにする |

降格: なし / 未解決: なし
