# 構造変更の経緯

## 2026-09-01: Sample を各フェーズの完了条件に組み込み、phase-7 を配布専業に純化

前提の改訂 + フェーズスコープの再配分。Sample を「プラットフォーム間パリティの検証装置」と位置づけ (翻案元 `../KsSettingsView/kasane/decisions/cross/0016`、規約は sample-parity)、phase-2/3 の初手に対称 scaffold、phase-4〜6・8 の機能フェーズの完了条件に「デモ画面の両プラットフォーム追加」を組み込んだ (phase-7 は対象外)。理由: phase-2「大量件数の性能検証」・phase-3「再利用効率の検証」が動くホストアプリなしに解消できず、phase-7 一括方式では成立しないため。phase-7 (phase-7-samples-distribution) はサンプル構成の論点を除き「配布 / ドキュメント」に純化 (フェーズ ID は振り直さない)。独立サンプルフェーズ案は「検証装置をフェーズ化すると『後でまとめて』に戻る」ため却下。探索の経緯は `kasane/changes/kasane-initial-assets/exploration.md`。同日、提案のセカンドオピニオン指摘を反映: 前提のうち CI・lockstep・配布を「踏襲候補 (phase-7 で確定)」へ戻し (Non-Goals との矛盾解消)、phase-2/3 の完了条件を「各自 scaffold + 対向への追随タスク、両フェーズ完了時が最初のパリティ収束ゲート」に明文化 (相互ブロック防止)。

## 2026-08-31: phase-8-image-loading を追加 (実行順は phase-4 の前)

フェーズ追加。画像の遅延ロード・キャンセル・キャッシュ・プリフェッチはリスト/グリッドの性能の生命線であり、セル API の形を縛るため機能フェーズ (phase-4 以降) より先に解く必要がある (後付け不可)。番号は末尾採番 (phase-8)、実行順はフェーズ一覧の行順と全体図で phase-3 と phase-4 の間に配置。あわせて phase-1 (DSL 上の外形) と phase-2 (`DataSourcePrefetching` の口) に関連論点を追記した。
