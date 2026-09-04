# セカンドオピニオン: ios-engine-foundation (code-007)
**相方**: codex / **label**: so-code-ios-engine-foundation-007 / **日付**: 2026-09-02 / **対象**: 修正サイクル 7 後の ios/・samples/ios/・change 成果物・関連 handbook / dsl-samples
---
# 判定

**CHANGES_REQUESTED**

指摘件数: **Critical 0 / Major 3 / Minor 2 / Suggestion 0**

修正サイクル 7 で前回の主要指摘は大幅に改善されていますが、複合更新と spacing-only のレイアウト変更に未処理経路があります。提示された全テスト成功を考慮しても、必須 Scenario を満たさない静的経路が残るため APPROVED にはできません。

## サマリー

主な残存問題は次の3点です。

- レイアウト変更とテンプレートキー変更が同時に起きると、同じ ID を `reconfigureItems` と `reloadItems` の両方へ登録する。
- `rowSpacing` / `columnSpacing` だけの変更では、仕様で要求される可視アンカーを保存・復元しない。
- 同値配列の高速経路が、親状態の再描画には対応した一方、`id:` / `template:` / registry の構成変更を反映しない。

追加された Scenario テストは、前回不足していた内容変更、テンプレート置換、非 `Identifiable`、セル state、代表的なアンカー変更を実 controller 上で観測しており、有効です。ただし自己サイズの完全な受入条件と、スクロール制御の一部 Scenario はまだ検証が閉じていません。

レビューは静的に実施し、ビルド・テストは再実行していません。提示された Debug 51件、Release 53件、Sample 3件、計測 2件の成功結果を前提としています。ファイル変更も行っていません。

## 照合した規約

- `ksn-review` の汎用チェックリスト、重要度、判定基準
- `ksn-core` と references:
  - `handbook.md`
  - `delta-spec.md`
  - `paths.md`
  - `domain-axis.md`
  - `config.md`
- `swift-ui-impl-skill` の状態・データフロー、UIKit/SwiftUI 統合、アクセシビリティ、性能、Concurrency、コード衛生
- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/cross/public-identifiers.md`
- `kasane/handbook/cross/local-development-setup.md`
- core ADR-0003 / 0004 / 0006 / 0007 / 0009
- iOS ADR-0001〜0004
- 未昇格観点 `kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md`
- `deviation.md` の合意済み差分

proposal / design / delta spec の凍結領域に差分は確認されませんでした。

## 前回指摘の追跡

| 前回項目 | 状態 | 確認結果 |
|---|---|---|
| 同値配列でも親状態を可視セルへ反映する案 B | **部分解消** | 可視セル再構成と SwiftUI 統合テストは追加済み。ただし selector / registry の変更を同じ高速経路が落とす |
| レイアウト変更後のアンカー復元 | **部分解消** | list→grid、先頭挿入、アンカー削除は修正・テスト済み。spacing-only が未対応 |
| tasks / matrix の過大計上 | **部分解消** | 前回列挙された統合テストの大半は追加済み。自己サイズとスクロール Scenario に残存あり |
| 未登録キーの即時検知 | **部分解消** | 通常 snapshot 準備時は解消。同値配列の registry 変更経路では再計算されない |
| tasks 3.2 の翻案方式不一致 | **解消** | `deviation.md:14` に記録済み |
| tasks 5.3 の「3形」不一致 | **解消** | `deviation.md:15` に記録済み |
| テンプレートキー有限性の注意書き | **解消** | DSL 文書へ追記済み |
| 空データ時の `scrollToStart` | **解消** | header を含む先頭への offset 設定とテストを確認 |
| snapshot 世代判定のデッドコード | **解消** | 不要な世代状態は撤去済み |
| feedback のピクセル検証 | **解消** | 実描画差と解決済み色の alpha を分けて検証 |
| accessibility 設定依存の2テスト | **解消** | UIKit の実操作要素へ変更され、提示された accessibility 無効環境の全件成功を確認 |
| GCD から Swift Concurrency への置換 | 対応不要 | 採用修正ではなく Suggestion 据え置き。新しい不具合根拠なし |

## 指摘事項

### [Major] 同じ ID を reconfigure と reload の両方へ登録する複合更新がある

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:344`、`ios/Sources/KsCollectionView/KsSnapshotPlanner.swift:22`、`ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:110`

**問題点**: レイアウト種別またはグリッド列指定が変わると、既存の全 ID が `reconfigureIdentifiers` に入ります。同じ更新で項目のテンプレートキーも変わると、その ID は planner の `reload` にも入ります。

したがって同じ snapshot 内で、同じ ID に対して `reconfigureItems` と `reloadItems` の両方が呼ばれます。Apple の `reconfigure` は既存セルを維持する更新であり、セル登録を変える場合は reload が必要です。[API documentation](https://developer.apple.com/documentation/uikit/nsdiffabledatasourcesnapshotreference/reconfigureitems(withidentifiers:))、[Apple Frameworks Engineer の説明](https://developer.apple.com/forums/thread/756295)。

現行テストは「レイアウト変更」と「テンプレートキー変更」を別々に検証しているため、この組み合わせを通りません。

**推奨修正**: `plan.reload` の ID を `reconfigureIdentifiers` から除外し、reload を優先してください。list→grid またはグリッド列数変更と、同一 ID のテンプレートキー変更を同時に行う統合テストを追加し、例外が起きず、新しい登録のセルへ置き換わることを確認してください。

### [Major] spacing-only の layout 差し替えで可視アンカーを維持しない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:60`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:75`、`ios/Sources/KsCollectionView/KsCollectionLayout.swift:8`、`kasane/changes/ios-engine-foundation/specs/collection-layout/spec.md:23`

**問題点**: レイアウト無効化は `previousLayout != configuration.layout` で行っていますが、アンカー保存は `previousLayout.kind != configuration.layout.kind` のときだけです。

`rowSpacing` / `columnSpacing` は `kind` の外側にあるため、深くスクロールした状態で spacing だけを大きく変更するとレイアウトは変わってもアンカー復元を通りません。delta spec は「`layout` 値を差し替えたとき」に先頭可視要素を維持することを SHALL としています。

また、同値配列の場合は高速経路から即 return するため、spacing-only 更新向けにアンカーを保存するだけでは足りず、`layoutIfNeeded()` と復元を行う完了経路も必要です。

既存の spacing テストはレイアウトオブジェクトの同一性と件数だけを確認しており、スクロール位置を観測していません。

**推奨修正**: アンカー保存条件を `previousLayout != configuration.layout` に広げ、snapshot を適用しない高速経路でもレイアウト確定後に復元してください。深い位置で `rowSpacing` を大きく変更し、変更前の先頭可視 ID が変更後も可視範囲に残るテストを追加してください。

### [Major] 同値配列の高速経路が ID・テンプレート構成の変更を無視する

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:265`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:289`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:297`、`kasane/changes/ios-engine-foundation/deviation.md:13`

**問題点**: 案 B の「同値配列では差分計算せず可視セルだけ再構成する」こと自体は合意済みであり、問題ではありません。しかし、高速経路は items の同値性しか見ておらず、新しい configuration の次の構造を評価しません。

- `id:` のキーパス
- `template:` のキーパス
- registry に登録されたキー集合

このため、同じ項目配列で別の ID キーパスへ切り替えても snapshot と `itemsByID` は旧 ID のままです。テンプレート選択が変わった場合も、可視セルは既存セルのまま別内容を載せるため、キー変更時に reuse pool を分ける契約を満たしません。

画面外のキーについては `prepareRegistrations` と未登録キー検査も実行されず、セル要求時に初めて登録を生成する経路が復活します。これは `deviation.md:3` の iOS 26 互換修正と、画面外キーを snapshot 準備時に検知する修正を迂回します。

**推奨修正**: 親状態を捕捉したテンプレートクロージャの変更と、ID・template projection・登録キー集合の構造変更を区別できる signature を configuration に保持してください。

- signature 不変: 現行どおり O(visible) の再構成
- signature 変更: ID/key map の再計算、登録準備、通常の reload/reconfigure 計画

動的な selector 変更をサポートしない方針なら、公開契約として不変条件を明示する設計判断が必要です。少なくとも、同値配列で別 ID キーパスへ切り替えるケースと、画面外項目が使う template key / registry を変更するケースをテストしてください。

### [Minor] 自己サイズテストが「切れ・余分な空白なし」を観測していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:186`、`kasane/changes/ios-engine-foundation/specs/collection-layout/spec.md:68`、`kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:24`

**問題点**: 追加テストは、長文行が短文行より高いことと、同じ短文の高さが等しいことを確認しています。これは内容に応じて高さが変わる証拠にはなりますが、「コンテンツに必要な高さ」「切れなし」「余分な空白なし」は検証していません。

matrix の記述は実際の assertion には概ね正確ですが、tasks 6.2 を全 Scenario 完了とする根拠としては不足します。

**推奨修正**: ホストされた内容の実測 bounds または intrinsic fitting size とセルの content bounds を比較し、クリッピングがなく、許容値を超える余白もないことを固定してください。自動化しない場合は、具体的な画像・操作記録を evidence に残してください。

### [Minor] スクロール制御の2つの明示 Scenario に自動検証または証跡がない

**該当箇所**: `kasane/changes/ios-engine-foundation/specs/collection-interaction/spec.md:23`、`kasane/changes/ios-engine-foundation/tasks.md:34`、`kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:28`

**問題点**: 実在するテストを照合すると、次の明示 Scenario を直接検証するテストがありません。

- 接続済み controller に存在しない ID を渡しても offset が変わらず、クラッシュしない。
- 画面外 ID への `.center` 指定で対象が中央へ来る。

matrix はこれらを手動操作扱いにしていますが、参照可能な evidence は示されていません。一方、tasks 6.3 は collection-interaction の Scenario テストを完了扱いにしています。

**推奨修正**: 実 controller を使い、存在しない ID で content offset が変わらないテストと、画面外 ID が中央付近へ来るテストを追加してください。手動確認に留める場合は証跡を保存し、tasks 6.3 の完了根拠を明確にしてください。

## アクションプラン

1. `reload` 対象を全件 `reconfigure` から除外し、レイアウト＋テンプレート変更の複合テストを追加する。
2. アンカー判定を layout 全値へ広げ、snapshot なしの高速経路でも復元する。spacing-only の深位置テストを追加する。
3. configuration の構造 signature を導入し、親状態だけの変更と ID/template/registry の変更を分離する。
4. 自己サイズと scroll ID / center の不足検証を追加し、verification matrix と tasks の完了根拠を更新する。
5. 同じ全件構成で再実行し、件数、失敗数、lint、Sample の動的操作証跡を更新する。

## `[付随修正]` の確認

`deviation.md` の次の2件はいずれも同梱条件内です。

- snapshot 前のセル登録準備
- 空配列でも初回 snapshot を適用し、header / footer と `scrollToStart` を成立させる修正

どちらも同一 change・同一 capability 内の局所修正で、独立した公開 API、ADR、設計選択を増やしておらず、対応テストもあります。したがって `[付随修正]` という分類自体への指摘はありません。ただし前者は、上記 Major 3 の同値配列経路にも適用されるよう補完が必要です。

## 確認した観点

- snapshot の挿入・削除・移動・内容変更・テンプレート置換
- 重複 ID、未登録キー、Release 縮退
- list / fixed / adaptive / 向き別列数、spacing、padding、動的切り替え
- セル再利用、SwiftUI state、自己サイズ、header / footer
- tap / long tap / 子 control / feedback / accessibility
- scroll controller の接続、順序保証、空データ
- prefetch seam、弱参照、MainActor、非同期待機
- Sample 9画面、通常・計測スキーム分離、公開識別子
- コメント、絶対パス、秘密情報、コード衛生
- deviation、tasks、verification matrix、前回レビューとの整合
- 関係のない phase-3 agenda 差分はレビュー対象外として除外


## 突き合わせ結果 (2026-09-02)

ホスト側 `review-007.md` (APPROVED: Minor 1 / Suggestion 6) と突き合わせ、相方のみの指摘はコード・テスト・spec で根拠を検証した。集計は双方一致 1 件 (重要度は割れ)、相方のみで採用 4 件、降格 (重要度引き下げ) 1 件。採用に Major 2 件を含むため、`review-007.md` の APPROVED は維持できず CHANGES_REQUESTED 相当とする。サイクル 7 の確定リスト 12 件は双方とも解消を確認しており後退はない。

### 確定 — 双方一致 (重要度はホスト側基準に相方の主張を加味)

- spacing だけの layout 差し替えでアンカーを維持しない (相方 Major-2 / ホスト Suggestion「アンカー保持の要求射程の確定」): **Major**。spec (collection-layout「レイアウトの動的切り替え」) は「表示中に `layout` 値を差し替えたとき」を条件にしており、core/ADR-0006 で `rowSpacing` / `columnSpacing` は layout 値のパラメータ。`KsCollectionViewController.swift:60` はアンカー保存を `kind` 変更に限っており、Sample「スペーシングと余白」の Slider 操作がまさにこの経路を通る。修正は `scrollToItem(.top)` で吸着させず、アンカー要素の表示範囲内オフセットを保つ形にする (連続変更で跳ねないため)。同値配列の高速経路でもレイアウト確定後に復元する

### 採用 — 相方のみ・根拠強

- Major-1 同じ ID を reconfigure と reload の両方へ登録: **Major**。`KsCollectionViewController.swift:342-349` で layout 種別変更時は既存全 ID を reconfigure に載せ、同じ更新でテンプレートキーが変わった ID は `plan.reload` にも載る。diffable は同一 snapshot 内で同じ項目の reconfigure と reload を許さないため実行時例外の可能性がある。`plan.reload` を reconfigure から除外し、複合更新の統合テストを追加する
- Minor-1 自己サイズテストが「切れ・余分な空白なし」を観測していない: **Minor**。ホストされた内容の fitting size とセル高の一致を固定する
- Minor-2 スクロール制御の Scenario「存在しない ID への命令」「ID 指定スクロール (center)」に自動検証が無い: **Minor**。テスト一覧で確認 (未接続 no-op と末尾命令の順序保証しか無い)。実 controller でのテストを追加する

### 降格 — 根拠弱 (契約の明文化で閉じる)

- Major-3 同値配列の高速経路が `id:` / `template:` / 登録キー集合の変更を無視: **Minor (コード変更なし、契約の注記)**。`KsTemplateBuilder` は `buildBlock` しか持たず登録集合は呼び出し箇所ごとに静的、`id:` / `template:` はキーパスの定数指定が通常で、表示中に差し替える利用は想定外。ただし差し替えた場合は画面外キーの遅延登録がセル要求中に走り `deviation.md` の iOS 26 例外経路に戻るため、dsl-samples に「`id:` / `template:` の指定と `Template` の登録集合は表示中に変えない」を利用者契約として注記し、deviation.md に記録する

### ホストのみ

- Minor: `handbook/cross/runtime-behavior-verification.md` の観測点表「グリッド (固定列)」行が、9 件でスクロールしない `FixedGridDemoView` では観測できない: **Minor**。承認モックは 3×3 の 9 件のため Sample は変えず、観測点の記述を実際に観測できる形 (300 件の統合テスト 3 件で担保、Sample では list⇄grid 切替後の列幅を確認) に直す
- Suggestion 6 件 (利用者向け注記・性能証跡・コメント整理): 蒸留 (ksn-distill) と phase-7 のドキュメント整備へ送る

### オーナー判断 (2026-09-02)

- 上限超過 3 回目の修正サイクル 8 (Major 2 + Minor 3 + 契約注記 1) の実施を承認
