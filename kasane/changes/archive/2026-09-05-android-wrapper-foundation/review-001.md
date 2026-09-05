# レビュー結果: android-wrapper-foundation (001 回目)

**日付**: 2026-09-05
**判定**: APPROVED

**レビュー範囲**: tasks.md グループ 1 (iOS 追随、1.1〜1.6) のみ。グループ 2 以降 (Android 側) は未着手のため対象外。

## サマリー

グループ 1 の 3 つの Requirement (値キーテンプレートの推論形 (iOS 追随) / 区切り線の色 (両プラットフォーム) / iOS Sample と dsl-samples の追随) はいずれも実装・テスト・文書のすべてで満たされている。`Template` → `KsTemplate` の改名はコード・テスト・Sample・dsl-samples から旧名を完全に排し、`buildExpression` の追加で推論形が型注釈なしに成立することを実結合テストで担保している。`listSeparatorColor` は表示の有無と独立した語彙として実装され、非表示時に何も描かないことも別テストで押さえている。Simulator で「リスト」画面の 3 択を全状態確認し、文言・色・戻り動作が brief どおりであることを確認した。

指摘は Minor 2 件・Suggestion 3 件で、いずれも本グループの完了を妨げない。長命層 (concepts) の追随は ksn-distill の担当領域として申し送る。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [handbook/cross/comment-policy.md](../../handbook/cross/comment-policy.md) | always |
| [handbook/cross/sample-parity.md](../../handbook/cross/sample-parity.md) | `samples/` を触る (「リスト」画面の操作と文言を変更) |
| [handbook/cross/test-execution.md](../../handbook/cross/test-execution.md) | テストを実行し件数を報告する |

参照した決定・概念: core/ADR-0002 (対称性の粒度)・core/ADR-0004 (テンプレート宣言)・core/ADR-0010 (区切り線の既定外観、proposed)・ios/ADR-0005 (単一 product と公開型)・ios/ADR-0006 (同値配列更新時の可視セル再構成)、concepts/core/styling/collection-layout.md、concepts/core/core-model/collection-items.md、concepts/ios/architecture/collection-engine.md。
lessons: `kasane/lessons/code-review.md` は未作成 (昇格済みルールなし)。inbox の観測のうち「この change で追加・変更したファイルはスコープ内」「Simulator を他ワーカーと共有しない」を運用に反映した。

## 実行した検証

- `ios/` SwiftPM 全件 (Simulator iPhone 17 Pro / iOS 26.0、Debug): **Executed 81 tests, with 0 failures**
- `samples/ios` 通常スキーム `KsCollectionViewSamples` (計測ドライバ除外、同 Simulator): **Executed 3 tests, with 0 failures**
- `xcodebuild build -scheme KsCollectionView`: 警告 0 件・エラー 0 件 (swift-tools-version 6.2 = Swift 6 言語モード)
- lint: comment-policy 0 件 (検査対象 75 ファイル) / local-path 0 件 / identity 0 件
- Simulator 目視 (iPhone 17 Pro): ルートメニュー → 「リスト」で 3 択 (なし / 既定 / アクセント) が截断なく表示され、既定選択が「既定」であること、アクセント選択で全区切り線が青 (`#2F6FED` 相当) に変わること、「既定」へ戻すと灰色に復帰すること、「なし」で線が消えることを確認。「テンプレート切り替え」画面が推論形のまま Message / Notice の 2 テンプレートで描画されることを確認

## 指摘事項

### [🟡 Minor] 区切り線の色のテストが下端の線を検証していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:164` (`test区切り線の色を指定すると位置と本数を変えずにその色で描く`)、`ios/Sources/KsCollectionView/KsHostingCell.swift:57`

**問題点**: テストは 3 セルすべてについて `separatorColor` を検証しているが、この計算プロパティは `topSeparatorView.backgroundColor` だけを返す。中間行・最終行で実際に可視なのは下端の線であり、その色は 1 件もアサートされていない。実装上は `configureSeparators` が上下を同じ値で更新するため現状は破綻しないが、上下を別扱いにする改修 (インセット・行間だけ色を変える等) が入ったときテストが空振りする。Scenario「色の指定」の「区切り線が指定した色で描かれ」を厳密には担保していない。

**推奨修正**: `KsHostingCell` に下端側の色を読む窓 (`bottomSeparatorColor` 等) を足し、中間行の下端の色をアサートに加える。あるいは既存テストが `showsSeparators` の検証で使っている `renderedImageData` による描画比較を色にも当てる。

補足: Simulator 目視では全行の線がアクセント色に変わることを確認済みのため、現時点の実挙動に問題はない。

### [🟡 Minor] 本 change が長命層に持ち込む乖離 (蒸留への申し送り)

**該当箇所**:
- `kasane/concepts/core/styling/collection-layout.md:46` — 「色はライブラリ内部の固定値 (`#D9D9DE` 相当)」。`listSeparatorColor` の追加で「固定値」ではなくなった
- `kasane/concepts/core/core-model/collection-items.md:23,40,47` — 旧名 `Template` と旧・明示形 `Template(Kind.message) { (item: Item) in … }`
- `kasane/concepts/ios/architecture/collection-engine.md:33` — 構成要素表の `KsTemplateRegistry` / `Template`

**問題点**: 公開型名の改名と公開 API の追加により、L2 概念の記述がコードと食い違う状態になった。concepts はコードに合わせて直す側の層 (記述) であり、放置すると次に読む人が存在しない型名と誤った契約 (「色は変更できない」) を信じる。

**推奨修正**: 本グループでの修正は求めない — concepts の追随は ksn-distill の責務であり、足場側で先に書くと二重管理になる。蒸留時に上記 3 ファイルを `KsTemplate` と `listSeparatorColor` へ追随させること。あわせて accepted の ios/ADR-0005 が公開型の列挙に `Template` を含んでいる点 (`kasane/decisions/ios/0005-single-swiftpm-product.md:16`)、ios/ADR-0006 の本文 (`:12,17`) も、ADR は append-only のため書き換えではなく改訂・追記の要否を蒸留時に判断すること。

### [🔵 Suggestion] Android 実装への申し送り: 「リスト」画面の初期選択は「既定」

**該当箇所**: `samples/ios/KsCollectionViewSamples/ListDemoView.swift:5`、`kasane/changes/android-wrapper-foundation/ui/mock/variant-android.html:55`

**問題点**: 承認モックは 3 択のうち「アクセント」が選択された状態で描かれているが、iOS 実装の初期値は `.standard` (既定) である。sample-parity は初期値の一致を要求するため、モックの見た目をそのまま初期状態と解釈すると Android 側が「アクセント」始まりになり不一致になる。

**推奨修正**: グループ 7 (Sample) の実装時、Android 側の初期選択も「既定」に揃える。モックのハイライトは選択状態の表現例であって初期値ではない。

### [🔵 Suggestion] dsl-samples の公開語彙一覧で `listSeparatorColor` の出典 ADR が 0006 のまま

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:403`

**問題点**: 「余白・区切り線」の行に `listSeparatorColor` を足したが、出典 ADR 列は `0006` (レイアウト指定 — 単一コンポーネント + layout 値) のままになっている。区切り線の色を変更可能にした決定は core/ADR-0010 (2026-09-04 改訂) にあり、読者が根拠へ到達できない。

**推奨修正**: 出典列を `0006, 0010` にする。core/ADR-0010 は現時点で proposed のため、Android 実装完了後の昇格に合わせて蒸留時に整えてもよい。

### [🔵 Suggestion] `UIColor` の同値比較に依存した色変更検知

**該当箇所**: `ios/Sources/KsCollectionView/KsHostingCell.swift:153`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:115-117`

**問題点**: 色が変わったかの判定を `UIColor` の `isEqual` に委ねている。SwiftUI の `Color` から毎回生成する `UIColor` は、trait 依存の動的色を渡された場合に同値と判定されない可能性があり、そのときは更新のたびに `updateVisibleCellSeparators()` と可視セル全件の `setNeedsLayout()` が空振りで走る。可視セル数は十数件なので実害は小さく、今回のレビューでは動的色での不一致を再現していない (未検証の懸念)。

**推奨修正**: 必要になったら、比較対象を `UIColor` ではなく利用者が渡した `Color` (Swift の `Equatable`) 側に置く、または `configureSeparators` の early return 条件から色を外して単純に代入する (代入は冪等なのでガードの価値が薄い)。今回の修正は不要と考える。

## アクションプラン

1. (本 change 内・任意) 下端区切り線の色をアサートに加える (Minor 1 件目)。実挙動は目視で確認済みのため、グループ 2 以降と合わせて対応してもよい
2. (Android 実装時) 「リスト」画面の初期選択を「既定」に揃える
3. (蒸留時) concepts 3 ファイルの追随と、ios/ADR-0005 / ios/ADR-0006 の扱いの判断、dsl-samples の出典 ADR 列の整理

## 確認して問題がなかった観点

- 足場アーティファクト (proposal / design / specs / brief) は未変更。tasks.md の差分はチェックボックスの反映のみで、本文の書き換えはない
- 実装済みチェックに虚偽なし (1.1〜1.6 すべて対応する成果物を確認)
- 公開 API・テスト・Sample・dsl-samples に旧名 `Template` の残存なし (`ios/` `samples/` の Swift 全走査、`kasane/` の md 全走査で確認。残存はアーカイブ済み文書・roadmap 履歴・ADR 本文のみで、いずれも過去の記録として正しい)
- `KsTemplate(.message) { item in … }` が型注釈なしで成立し、`KsSwiftUIIntegrationTests` の実結合テストでキーごとの描画まで検証されている
- `listSeparators` 非表示時に `listSeparatorColor` が何も描かないこと (専用テスト + Simulator 目視)
- 「リスト」画面の 3 択が brief の文言 (なし / 既定 / アクセント) と一致し、アクセント = `SampleTheme.accent` (47,111,237 = #2F6FED)、既定 = `KsHostingCell.defaultSeparatorColor` (217,217,222 = #D9D9DE) と一致する
- segmented Picker への置き換えは brief の「許容する差異」(segmented control ⇔ Material の segmented) の範囲内で、既存の `FixedGridDemoView` と同じ実装パターン・同じ `SampleTheme` の余白定数を使っている
- `ListSeparatorChoice` は 1 ファイル 1 型で、既存の `FixedGridLayoutChoice` と同じ形 (`String` raw value + `CaseIterable` + `Identifiable`)
- `ListDemoView.collection` は両分岐とも `KsCollectionView<DemoItem>` を返し、`AnyView` や分岐による型変化を持ち込んでいない (構造的同一性が保たれる)
- コメント規約: 新規コメントに作業文書パス・ローカル通番・仮称・履歴記述・デルタスペック構文キーワードの混入なし。公開 doc コメント (`listSeparatorColor` / `KsTemplate` / `KsTemplateBuilder`) は内部用語なしで機能と契約だけを述べている
- Swift 6 言語モードでのビルド警告なし。`KsHostingCell.defaultSeparatorColor` の `static let` を含め並行性の診断は出ていない
- deviation.md は不在。無断の仕様逸脱・条件を超える付随修正の同梱は見当たらない
