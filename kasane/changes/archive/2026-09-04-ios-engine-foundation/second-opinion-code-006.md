# セカンドオピニオン: ios-engine-foundation (code-006)
**相方**: codex / **label**: so-code-ios-engine-foundation-006 / **日付**: 2026-09-02 / **対象**: 修正サイクル 6 後の ios/・samples/ios/・change 成果物・関連 handbook / dsl-samples
---
# レビュー結果: ios-engine-foundation（006 回目）

**日付**: 2026-09-02  
**判定**: **CHANGES_REQUESTED**

## サマリー

修正サイクル 6 では、前回の確定指摘 11 件中 9 件が解消され、計測ドライバの分離も完了しています。一方、O(n) 処理対策として追加された早期 return が、配列以外の SwiftUI 槟成変更を反映しない重大な回帰を生んでいます。

また、動的レイアウト変更時のアンカー保証が snapshot 適用前にしか行われず、データ同時変更・アンカー削除の明示要件を満たしていません。Scenario 対応表にも、実在しない統合検証を完了済みとしている箇所があります。

指摘件数: **Critical 0 / Major 3 / Minor 3 / Suggestion 2**

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`（`samples/**`）
- `kasane/handbook/cross/test-execution.md`（テスト結果の報告）
- `kasane/handbook/cross/runtime-behavior-verification.md`（動的レイアウト・操作修正）
- `kasane/handbook/cross/public-identifiers.md`（Package・Xcode project）
- `kasane/handbook/cross/local-development-setup.md`（ビルド・Sample 手順、guide）
- `core/ADR-0003・0004・0006・0007・0009`
- `ios/ADR-0001〜0004`
- `swift-ui-impl-skill` の View 構造、データフロー、アクセシビリティ、性能、Swift Concurrency、コード衛生
- `kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md`（未昇格の追加観点）
- `deviation.md` の記録済み差分はすべて合意済みとして除外

## 前回指摘の追跡

| 前回の確定指摘 | 状態 | 確認結果 |
|---|---|---|
| Major: 既定 feedback が不透明 | 解消 | `.systemFill` 化と描画テストを確認 |
| Major: 位置変更時の全件 reconfigure | 解消 | `positionsChanged` が再構成条件から除外され、既存セルの非再構成テストあり |
| Major: スペーシング DSL 語彙 | 解消 | `.list(rowSpacing:)` / `.grid(columns:rowSpacing:columnSpacing:)` に統一 |
| Major: 長押し認識器の常時有効化 | 解消 | ハンドラ有無に応じた `isEnabled` 更新と実タッチ UI テストあり |
| Minor: header/footer の毎回再生成 | 解消 | `UIContentView.supports` による内容差し替えへ変更 |
| Minor: 不変更新時の O(n) 多重走査 | **回帰あり** | 走査は減ったが、構成変更を落とす Major 指摘 1 が発生 |
| Minor: verification matrix の機種不一致 | 解消 | 合意済み代替条件へ更新 |
| Minor: 重複 ID の release trap | 解消 | 後勝ち縮退、警告、Release テストあり |
| Minor: Sample の冗長な Template 型指定 | 解消 | DSL サンプルと同じ宣言形へ修正 |
| Minor: 未使用 PerformanceHarness | 解消 | ターゲットを撤去し Sample 経路へ統合 |
| Suggestion: 空データ時の `scrollToStart` | **未解消** | 引き続き item 件数で拒否している |
| オーナー昇格: 計測ドライバの通常テストからの分離 | 解消 | 通常・計測スキームが相互に対象クラスを除外 |

集計は **解消 9 / 回帰あり 1 / 未解消 1**。加えてオーナー昇格項目 1 件は解消済みです。

## 指摘事項

### [🟠 Major] 同値配列の早期 return がテンプレートなどの構成変更を捨てる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:48`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:247`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:515`

**問題点**: `self.configuration` を差し替えた後、`items == appliedItems` だけで処理を終了しています。SwiftUI では items が同じでも、テンプレートが捕捉する親状態、テンプレート登録、`id:` / `template:` セレクタ、`touchFeedback` 色などは変更できます。

例えば次の `emphasized` を切り替えても、可視セルは以前の `AnyView` を保持したままです。

```swift
KsCollectionView(items) { item in
    Text(item.title)
        .foregroundStyle(emphasized ? .red : .primary)
}
```

さらに新しいテンプレートキーの事前登録も省略されます。未登録の `CellRegistration` が後からセル要求中に作られると、`deviation.md:3` で修正した実行時例外を再発させる余地があります。

現在の `test同一配列の再適用ではID解決もセル構成も行わない` は、正しくない振る舞いを回帰テストとして固定しています。

**推奨修正**: `items == appliedItems` だけを更新省略条件にしないでください。snapshot 計算と可視セルの描画更新を分離し、items が不変でも新しいテンプレート・feedback 設定を可視セルへ適用してください。ID・テンプレートセレクタ変更を省略する場合は、比較可能な構成識別子が必要です。

親 `@State` の変更、feedback 色変更、同一 items でのテンプレートセレクタ変更を、実際にホストした SwiftUI 統合テストで固定してください。

### [🟠 Major] アンカー復元が新 snapshot より前に行われ、データ同時変更を保証できない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:49`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:66`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:397`、`specs/collection-layout/spec.md:23`

**問題点**: アンカー ID を取得した後、古い snapshot のまま新レイアウトを適用して `restoreAnchor` を呼び、その後に新しい items の snapshot を適用しています。snapshot 完了後の復元処理はありません。

この順序では、layout 切り替えと同時にアンカーより前へ大量挿入した場合、アンカーが画面外へ押し出され得ます。アンカー自体を削除した場合も、仕様が要求する「近傍位置」を選ぶ情報や処理がありません。また、行間だけが変わる変更は `previousLayout.kind` が同一なので、アンカー処理自体を通りません。

`evidence/verification-matrix.md:15` は「layout 切り替え統合テスト」と記載していますが、現行テストは切り替え後のセル幅しか確認しておらず、アンカー ID を検証していません。

**推奨修正**: 変更前のアンカー ID と旧順序を保存し、最新 snapshot の apply と layout 確定後に、同じ IDまたは最も近い生存要素へ復元してください。

少なくとも以下を統合テストに追加してください。

- 深い位置で list → grid を切り替え、先頭可視 ID が表示範囲内に残る
- layout 変更と同時にアンカーより前へ挿入する
- layout 変更と同時にアンカーを削除し、隣接要素が維持される
- 深い位置で `rowSpacing` を大きく変更する

### [🟠 Major] tasks と検証 matrix が、実在しない Scenario 統合検証を完了扱いしている

**該当箇所**: `tasks.md:35`、`tasks.md:36`、`evidence/verification-matrix.md:6`、`evidence/verification-matrix.md:8`、`evidence/verification-matrix.md:12`、`evidence/verification-matrix.md:15`、`evidence/verification-matrix.md:18`

**問題点**: 次の記述に対応する検証がありません。

- 内容変更時のセルインスタンス維持と再描画
- テンプレートキー変更時のセル置換・再利用プール分離
- 非 `Identifiable` 型の実描画と差分更新
- 実スクロールによる `@State` 初期化
- layout 切り替え時のアンカー ID 維持
- 異なる本文量に対する自己サイズと切れ・余白の検査

`KsSnapshotPlannerTests` は計画配列だけを検査しています。`KsPublicAPITests.test非Identifiable型をidキーパスで組み立てられる` も View をホストしておらず、matrix の「Simulator 統合」には該当しません。`prepareForReuse` や「anchor 復元処理」はテスト名ではなく、実装の存在を検証の代わりに記載したものです。

その状態で `tasks.md` の「全 Scenario に対応する単体テスト」と layout Scenario テストを完了扱いしているため、チェックの根拠が成立していません。

**推奨修正**: 上記 Scenario を実 controller または `UIHostingController` 上で観測するテストを追加し、matrix には実在するテスト名と実際の観測内容だけを記載してください。自動化しない項目は、具体的な evidence への参照を付けて手動検証として明記してください。

### [🟡 Minor] 未登録テンプレートキーの debug assertion が可視化時まで遅延する

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:279`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:182`、`ios/Sources/KsCollectionView/KsTemplateRegistry.swift:26`

**問題点**: snapshot 前の準備ではキーごとの `CellRegistration` を作るだけで、registry にキーが存在するか検証していません。未登録キーの assertion はセル内容を構築したときに初めて発生するため、画面外の不正要素はそこまでスクロールしない限り検知されません。`specs/collection-core/spec.md:49` の「debug ビルドでは assertion で即停止」と一致しません。

**推奨修正**: snapshot 準備時に全キーを `registry.contains` で検査し、debug ではその時点で assertion を発生させてください。Release の空セル縮退は現状どおりセル構成時に行えます。

### [🟡 Minor] tasks.md に実装内容・合意スコープと矛盾する完了チェックが残る

**該当箇所**: `tasks.md:16`、`tasks.md:29`、`proposal.md:21`

**問題点**:

- 3.2 は `KsCellViewSupport` / `CustomCellRowPlacement` の翻案を完了扱いしていますが、該当型や同等の自己サイズ補正コードは存在しません。
- 5.3 は「値キー / 型 / 単一クロージャの 3 形」としていますが、型ベース切り替えは proposal で明示的な Non-Goal です。

挙動が `UIHostingConfiguration` と `.estimated` だけで成立する判断だったとしても、現在のチェック文は実装の実態を表していません。

**推奨修正**: 3.2 を実際の自己サイズ実現方式へ書き換え、対応する可変行高テストを示してください。5.3 から型ベース形を削除し、「値キーと単一クロージャの 2 形」に合わせてください。

### [🟡 Minor] ADR が要求するテンプレートキーの有限性に関する注意書きがない

**該当箇所**: `kasane/decisions/core/0004-template-per-type-registration.md:32`、`kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:131`

**問題点**: core/ADR-0004 は、毎要素ユニークなキーを使うとキーごとの `CellRegistration` が無制限に増え、再利用が無効化されるため、仕様ではなく利用者向けドキュメントで注意する、と決定しています。今回更新した DSL 文書にはこの注意がありません。

**推奨修正**: キーはセル表示種別を表す有限集合であり、item ID や毎要素固有値を使ってはいけない旨を、値キーテンプレート例の直後へ追加してください。

### [🔵 Suggestion] 空データでも header を先頭へ戻せるようにする

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:455`

items が空でも header は表示・スクロール可能です。`scrollToStart` は ID を必要としないため、`appliedIdentifiers.isEmpty` の guard を外し、常に先頭 offset を設定することを検討してください。

### [🔵 Suggestion] MainActor の遅延実行を Swift Concurrency へ統一する

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:548`

`swift-ui-impl-skill` は `DispatchQueue.main.async` ではなく Modern Swift Concurrency を使用する規律です。ここは順序保証のための遅延なので、意味を保った `Task { @MainActor ... }` と必要な `Task.yield()` へ置き換え、既存の SwiftUI 統合テストで順序を固定することを推奨します。

## アクションプラン

1. 同一 items でもテンプレート等の構成変更が可視セルへ反映されるよう、早期 return を再設計する。
2. snapshot 適用後のアンカー復元と、削除時の近傍選択を実装する。
3. core/layout Scenario の実統合テストを追加し、tasks と verification matrix を実態へ合わせる。
4. 未登録キーを snapshot 準備時に debug 検知する。
5. tasks の型ベーステンプレート・自己サイズ補正記述と、DSL 文書の有限キー注意書きを整理する。
6. `scrollToStart` と GCD 使用は上記完了後に扱う。

## 確認した観点

- 指定された Debug / Release / generic build / Sample 2 スキームの成功結果と実行件数を前提とした。制約に従い再実行していない。
- proposal / design / specs は HEAD から変更されておらず、足場凍結に違反していない。
- `deviation.md` の 9 件はすべて合意済み差分として扱い、指摘していない。
- `[付随修正]` のセル登録事前準備は同一能力内の局所修正で、同梱条件内。
- Sample は 9 画面、共通トークン、Local Package、公開識別子、通常・計測スキーム分離を満たす。
- 保存済み mock と検証画像を照合し、オーナー承認済みの構造・トークンに対する新規の視覚指摘はない。
- fixed / adaptive / 向き別列数、contentPadding、区切り線、header/footer、prefetch、スクロール receiver の弱参照と detach を確認した。
- コメント規約、公開 doc comment、ローカル絶対パス、識別情報について新規指摘なし。
- ファイルへの書き込みは行っていない。


## 突き合わせ結果 (2026-09-02)

ホスト側 `review-006.md` (APPROVED: Minor 1 / Suggestion 5) と突き合わせ、相方のみの指摘はコード・テスト・spec で根拠を検証した。集計は双方一致 2 件、相方のみで採用 5 件、設計判断へ回す 1 件、降格 1 件。採用に Major 2 件を含むため、`review-006.md` の APPROVED は維持できず CHANGES_REQUESTED 相当とする。

### 確定 — 双方一致

- Suggestion (空データ時 `scrollToStart`): **Suggestion**。双方が挙げ、数行で閉じるため次サイクルに同梱する
- tasks 5.3「3 形」と proposal Non-Goals の不整合 (相方 Minor-2 / ホスト Suggestion-4): **Minor**。足場は凍結のため書き換えず、`deviation.md` に「実装は値キーと単一クロージャの 2 形」を記録する

### 採用 — 相方のみ・根拠強

- Major-2 アンカー復元: **Major**。`KsCollectionViewController.swift:48-80` は layout 種別変更時に旧 snapshot のまま `restoreAnchor` を呼び、その後に新 items を apply する。spec (collection-layout「レイアウトの動的切り替え」) の「アンカー要素が同時に削除された場合は近傍の位置を維持する (SHALL)」に対応する処理が無く、`testグリッドからリストへ切替後に…` はセル幅しか見ておらずアンカー ID を検証するテストが 1 つも無い
- Major-3 tasks / matrix の過大計上: **Major**。「内容変更の再構成」「テンプレートキー変更でのセル置換」の Simulator 統合欄「エンジン更新テストに統合」に該当するテストは存在せず (`KsCollectionEngineTests` の一覧で確認)、`KsSnapshotPlannerTests` は計画配列の検査のみ。「セル再利用時の状態非保持」「動的切り替えの anchor」の unit 欄は実装の説明でテスト名ではない。tasks 6.1 / 6.2 の「全 Scenario に対応するテスト」のチェックは根拠が成立していない。ホスト Minor (matrix の未反映) を包含する
- Minor-1 未登録キーの debug assertion 遅延: **Minor**。snapshot 準備時 (`:279` 付近) は `CellRegistration` を作るだけで registry に照会しない。spec「現れたとき debug では assertion で即停止」に寄せて `registry.contains` で snapshot 準備時に検査する (テスト専用だった `contains` の本番利用にもなる)
- Minor-2 tasks 3.2 の翻案記述: **Minor**。`KsCellViewSupport` / `CustomCellRowPlacement` 相当のコードは無く、自己サイズは `.estimated(44)` + `UIHostingConfiguration` で成立している。足場は書き換えず `deviation.md` に実現方式を記録する。可変行高の Scenario テストは Major-3 に含めて追加する
- Minor-3 テンプレートキー有限性の注意書き: **Minor**。core/ADR-0004 は「仕様では縛らずドキュメントで注意書きする」と決めており、本 change が更新した dsl-samples.md にその注記が無い。値キー例の直後に追記する

### 設計判断へ回す (NEEDS_DISCUSSION)

- Major-1 同値配列の早期脱出が構成変更を捨てる: 相方は Major (回帰)、ホストは Suggestion-5 (spec 忠実・後退なし)。コードを確認した結果、**回帰ではない** — サイクル 6 以前も `hasSnapshotChanges` の guard で同じ結果になっていた。ただし「テンプレートが親の状態を捕捉している (選択中 ID で色を変える等) とき、items が同値のままでは可視セルが更新されない」は SwiftUI 利用者が高頻度で踏む挙動で、spec は「内容変化の判定は `Equatable` 同値比較」としか定めていない。オーナー判断へ提示する

### 降格 — 根拠弱・好み

- Suggestion-2 GCD → Swift Concurrency: **Suggestion (据え置き)**。順序保証 (core/ADR-0007) を担う経路であり、統合テストが通っている現状を書き換えるリスクが利益を上回る。将来の整理項目として残す

### ホストのみ

- Suggestion-1 世代判定のデッドコード / Suggestion-2 既定 feedback テストのピクセル判定: いずれも数行の整理のため次サイクルに同梱する
- Suggestion-5 (外部 state 依存テンプレート): 上記 Major-1 の論点に統合

### オーナー判断 (2026-09-02)

- Major-1 (同値配列の早期脱出): **案 B** — 親の更新が来たら可視セルだけ再構成する。deviation に記録して修正サイクル 7 に含める
- 実装ワーカーのスコープ外の発見: (1) accessibility 設定に依存するテスト 2 件は本 change で作ったテストのため**同梱修正** (起票ではない)。(2) `Template` の完全推論形が書けず明示形で揃えた件は**本意ではない**ため、phase-3 前に対応する申し送りとして記録。(3) `Template` の無接頭辞命名も (2) と合わせて phase-3 前に対応
- 上限超過 2 回目の修正サイクル 7 を承認
