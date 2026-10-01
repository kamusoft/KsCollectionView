# セカンドオピニオン: drag-reorder (code-001)
**相方**: codex / **label**: so-code-drag-reorder / **日付**: 2026-09-30 / **対象**: 作業ツリーの未コミットの変更 (`git diff HEAD` と未追跡のファイル。ios/ android/ samples/)
---
**判定: CHANGES_REQUESTED** — Major 2 件。対象 diff と未追跡ファイルを静的に確認しました。テスト結果は依頼文に記載されたホスト側の結果として扱い、こちらでは実行していません。

### 🟠 Major: 可視範囲の下端から一覧全体の末尾へ飛ぶ

**該当箇所**: [android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:722](android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:722)

**問題点**: list の移動先計算は可視項目だけを走査します。その全項目の中心より持ち上げた項目の上端が下に来ると、一覧の途中を表示中でも「最後のグループの末尾」を返します。10,000 件の先頭付近から画面下端へ運ぶだけで、仮の置き先とドロップ先が全件の末尾へ飛び得ます。

**推奨修正**: 可視項目を走査し終えた場合は最後の可視項目の直後を候補にし、全件の末尾は実際に一覧末尾を表示している場合だけ返してください。長い list の途中で下端へ運ぶケースをテストに加えてください。

### 🟠 Major: ドロップ時に最新の `canDrop` を確認しない

**該当箇所**: [android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:193](android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:193)

**問題点**: `canDrop` は移動先が変わったときに評価されますが、`drop()` は控えた `isOverForbidden` を見るだけです。ドラッグ中に業務条件が変わり、それまで許可されていた移動先が禁止されても、指を離すと `onMove` が呼ばれ得ます。`retarget()` も候補が現在の位置と同じなら判定を省きます。

**推奨修正**: 確定直前に最新の `canDrop` で移動先を再評価し、偽なら元へ戻してください。同じ位置に留まったまま判定条件が変わるケースをテストしてください。

合意済みの `deviation.md` と UI の妥協 2 件は指摘に含めていません。体感・動作の確認タスク 6.2〜6.4 は未完了であり、この静的レビューでは判定していません。

## 突き合わせ結果

ホスト側レビュー: review-001.md (CHANGES_REQUESTED、Critical 1 / Minor 3 / Suggestion 1)。

- **確定**: Major「可視範囲の下端から一覧全体の末尾へ飛ぶ」(KsReorderController.kt:722) — ホスト側の Critical 1 と同じ箇所・同じ原因。重要度はホスト側の Critical (エミュレータで 8 回中 3 回再現)
- **採用**: Major「ドロップ時に最新の canDrop を確認しない」(KsReorderController.kt:193) — ホスト側は指摘なし。該当箇所の特定と実害シナリオ (ドラッグ中に業務条件が変わり、禁止になった行き先に置ける) があり、iOS 側は置いたときに判定し直しているので両プラットフォームの契約もそろわない。ホスト側の見逃しとして扱う
- **降格**: なし
- **未解決**: なし
