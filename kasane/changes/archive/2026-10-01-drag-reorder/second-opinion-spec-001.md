# セカンドオピニオン: drag-reorder (spec-001)
**相方**: codex / **label**: so-spec-drag-reorder / **日付**: 2026-09-29 / **対象**: 提案一式 (kasane/changes/drag-reorder/ の proposal.md・design.md・specs/・tasks.md・ui/brief.md)

---

## 独立提案レビュー

**判定: NEEDS_DISCUSSION**  
**指摘: Critical 0件 / Major 4件 / Minor 1件 / Suggestion 0件**

受け入れ後の表示を維持する条件と、ドラッグ中に設定が変わる場合の扱いは、実装前に契約として決める必要があります。現仕様の一次情報として `ios/`・`android/`・`samples/` のコードとテストを照合しました。ビルド・テストは依頼どおり実行していません。

### 🟠 Major 1 — 受け入れ後、旧配列を伴う再描画で並びが戻り得る

**該当箇所:** [design.md:77](kasane/changes/drag-reorder/design.md:77)、[collection-reorder/spec.md:49](kasane/changes/drag-reorder/specs/collection-reorder/spec.md:49)  
**問題点:** 「受け入れた後に届いた配列」を通常適用するとしていますが、iOS の `update(configuration:)` は更新ごとに `apply` を呼びます（[KsCollectionViewController.swift:275](ios/Sources/KsCollectionView/KsCollectionViewController.swift:275)）。VM が新しい配列を出す前に、別の状態変更で旧配列のまま再描画された場合、それを「届いた配列」と扱うと、置いた並びの維持という Scenario に反します。Android でも再コンポジションと新配列の区別が必要です。  
**推奨修正:** 受け入れ後にどの更新を確定配列と見なすかを定義し、旧配列を伴う再描画、内容だけの更新、実際の配列差し替えを区別する Scenario を追加してください。

### 🟠 Major 2 — iOS の一時 snapshot とグループ表の整合条件が足りない

**該当箇所:** [design.md:76](kasane/changes/drag-reorder/design.md:76)、[tasks.md:24](kasane/changes/drag-reorder/tasks.md:24)  
**問題点:** 移動後に更新するものとして配列と「各セクションの範囲」を挙げていますが、既存の塊表には範囲以外に塊の件数とグループの項目範囲があります（[KsGroupChunkTable.swift:9](ios/Sources/KsCollectionView/KsGroupChunkTable.swift:9)）。特に最後の１件を持ち出すと、現行の見出し構築は空のグループを消去し（[KsCollectionViewController.swift:691](ios/Sources/KsCollectionView/KsCollectionViewController.swift:691)）、固定見出しの配置計算も先頭・末尾の項目を前提にしています（[KsCompositionalLayout.swift:103](ios/Sources/KsCollectionView/KsCompositionalLayout.swift:103)）。見出しを残すという Scenario を、記載された更新範囲だけでは満たせません。  
**推奨修正:** 仮の並びで保つグループ識別、空になったグループの見出し内容と配置、塊の件数・範囲を含む表全体の整合条件を design と tasks に明記してください。

### 🟠 Major 3 — ドラッグ中の layout・グループ宣言変更が未定義

**該当箇所:** [collection-reorder/spec.md:133](kasane/changes/drag-reorder/specs/collection-reorder/spec.md:133)、[design.md:107](kasane/changes/drag-reorder/design.md:107)  
**問題点:** 保留するのは配列と決まっていますが、Sample はドラッグ中でも list／グリッドとグループの切り替えを操作できます（[samples/spec.md:29](kasane/changes/drag-reorder/specs/samples/spec.md:29)）。既存の iOS 更新経路は layout やグループ宣言の変更でレイアウトを無効化し（[KsCollectionViewController.swift:215](ios/Sources/KsCollectionView/KsCollectionViewController.swift:215)）、Android は表示配列とグループ宣言から計画を再構築します（[KsCollectionView.kt:189](android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:189)）。進行中のドラッグと行き先の対応を保つのか、取り消すのかが決まっていません。  
**推奨修正:** これらの設定変更時にドラッグを継続・保留・取り消すいずれかを決め、配列保留との順序を Scenario にしてください。

### 🟠 Major 4 — iOS の「同じ一覧内」制限が設計されていない

**該当箇所:** [design.md:74](kasane/changes/drag-reorder/design.md:74)、[proposal.md:36](kasane/changes/drag-reorder/proposal.md:36)  
**問題点:** 提案は別の一覧へのドロップを対象外としています。一方、設計の `dragSessionIsRestrictedToDraggingApplication` は持ち出し先をアプリ内に限る指定で、同じアプリの別の `KsCollectionView` を識別する条件はありません。別一覧の drop delegate がセッションを受けた場合の拒否規則と検証が欠けています。  
**推奨修正:** ドラッグ元の一覧を識別し、異なる一覧からのセッションを拒否する条件と Scenario を追加してください。

### 🟡 Minor 1 — 取り消し時の「元の位置」と保留した最新配列の優先順位が曖昧

**該当箇所:** [collection-reorder/spec.md:20](kasane/changes/drag-reorder/specs/collection-reorder/spec.md:20)、[collection-reorder/spec.md:133](kasane/changes/drag-reorder/specs/collection-reorder/spec.md:133)  
**問題点:** スイッチを切ると「元の位置に戻る」一方、取り消し時には保留した最新配列を表示します。最新配列が項目を移動・削除していた場合、最終的な表示と戻りのアニメーションを一意に判定できません。  
**推奨修正:** 「元へ戻す」は保留配列を適用する前の過程なのか、最終結果なのかを明記し、項目の移動・削除を伴う保留配列で確認してください。

照合した規約は、`handbook/cross` の Sample 一致・操作パネル・性能ゲート・コメント規約、および iOS／Android の性能検証規約です。`tasks.md` に `decisions/`・`handbook/`・`concepts/` を実装ワーカーが書き換えるタスクは見当たりませんでした。

## 突き合わせ結果

ホスト側の自己レビュー (design.md「提案の自己レビューの記録」、2 周) との突き合わせ。5 件とも相方のみの指摘で、該当箇所の特定と実害の筋道があるため採用した (2026-09-29)。

| 指摘 | 採否 | 反映 |
|---|---|---|
| Major 1 受け入れ後、旧配列を伴う再描画で並びが戻り得る | 採用 (相方のみ・根拠強: iOS の `update` は毎回 `apply` を呼ぶ) | spec「受け入れと元に戻す」に、置いた時点と同じ配列での描き直しでは待つことと Scenario を追加。design Decision 3・4・5、tasks 3.5・4.4、core/ADR-0033 の Decision |
| Major 2 iOS の一時 snapshot とグループ表の整合条件が足りない | 採用 (相方のみ・根拠強: 塊の表の項目・見出しの組み立て・固定の見出しの計算) | design Decision 3 (表の全体を仮の所属で組み直す・見出しの中身を表から組む・空になったグループを受け入れた時点で取り除く)、spec「グループをまたぐ移動」の Scenario を「受け入れると空のグループが消える」に、tasks 3.4・4.4 |
| Major 3 ドラッグ中の layout・グループ宣言変更が未定義 | 採用 (相方のみ・根拠強: 両プラットフォームの配置の組み直し) | spec「並べ替えのスイッチ」に取りやめと Scenario を追加。design Decision 7 を拡張、Decision 2、tasks 3.5・4.5 |
| Major 4 iOS の「同じ一覧内」制限が設計されていない | 採用 (相方のみ・根拠強: アプリの中だけの指定は別の一覧を区別しない) | spec に Requirement「並べ替えは一覧の中だけ」を追加。design Decision 3・4、tasks 3.2・3.7 |
| Minor 1 取り消し時の「元の位置」と保留した最新配列の優先順位が曖昧 | 採用 (相方のみ・根拠あり: 仕様の一意性) | spec「ドラッグ中に届いた配列」に「元の位置に戻してから最新の配列を当てる」と Scenario を追加。design Decision 5、core/ADR-0033 の Decision |

確定 0 / 採用 5 / 降格 0 / 未解決 0。空になったグループを消す時点を agenda の導出より早めた点は、ホスト側の判断としてオーナーに報告した。

