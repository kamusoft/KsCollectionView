# セカンドオピニオン: android-wrapper-foundation (spec-001)
**相方**: codex / **label**: so-spec-android-wrapper-foundation / **日付**: 2026-09-04 / **対象**: kasane/changes/android-wrapper-foundation/ の proposal.md / design.md / specs/ / tasks.md / ui/brief.md (提案一式)
---
## 1. 総評

静的レビューの結果、現状の提案には実装者だけでは解消できない仕様上の未決事項があります。  
特に再コンポーズ保証、スクロールコマンドの競合、alignment の境界挙動、性能合格基準は、このままでは受け入れ判定が安定しません。  
また、DSL 制約と既存 ADR の一部は、提案された実装方式と直接矛盾しています。  
ビルド・テストは実行していません。

## 2. 指摘一覧

### [Major] 正確な「再コンポーズされない」保証を一般の `Item` に対して実現できない

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/collection-core/spec.md:19-24`
- 関連箇所: `kasane/changes/android-wrapper-foundation/design.md:15-27`
- 問題点: stable key は Composition 上の identity を保つ仕組みであり、未変更セルが必ず再コンポーズされないことまでは保証しません。`Item` の stability、未変更要素のインスタンス維持、親から渡す `List` の変更などによって skip 可否が変わります。[Compose の lifecycle](https://developer.android.com/develop/ui/compose/lifecycle) と [stability の説明](https://developer.android.com/develop/ui/compose/performance/stability) に照らすと、「X だけが再コンポーズされる」は公開ライブラリの一般契約として過剰です。
- 推奨修正: 契約を「key に対応する remember 状態と identity が維持される」「画面外要素を常時 Composition に保持しない」など観測可能な保証に変更してください。厳密な invocation 数を要求するなら、`Item` の stability、同一インスタンス維持、Strong Skipping などの前提も仕様化する必要があります。

### [Major] コマンドキューの順序・中断契約と `LaunchedEffect` 設計が一致していない

- 該当箇所: `kasane/changes/android-wrapper-foundation/design.md:48-51`
- 関連箇所: `kasane/changes/android-wrapper-foundation/specs/collection-interaction/spec.md:28-54`, `kasane/changes/android-wrapper-foundation/tasks.md:32-33`
- 問題点: `LaunchedEffect(items, queue)` は `items` キーの変更時に実行中 coroutine をキャンセルします。[公式仕様](https://developer.android.com/develop/ui/compose/side-effects)上、アニメーション中のデータ更新でコマンドが中断・再実行・消失する可能性があります。また、連続コマンドを FIFO で処理するのか、後着優先で前の animation をキャンセルするのかが未定義です。
- 推奨修正: FIFO／latest-wins、実行中 animation の中断、データ更新との世代境界を Requirement と Scenario で決定してください。そのうえで、Composition 生命周期に対して安定した単一 consumer と現在値参照を使う設計へ変更し、連続2命令・animation 中の追加命令・データ更新との競合を検証対象にしてください。

### [Major] `@DslMarker` だけでは template content 内から外側 DSL を呼べないという契約を満たせない

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/collection-core/spec.md:36-39`
- 関連箇所: `kasane/changes/android-wrapper-foundation/design.md:20-24`
- 問題点: 提案されている content は通常の `(Item) -> Unit` であり、新しい DSL receiver を導入しません。そのため外側の `KsCollectionViewScope` は暗黙 receiver として残ります。`@DslMarker` は同一マーカーを持つ複数の暗黙 receiver 間を制限する仕組みであり、外側 receiver の明示参照まで禁止しません。[Kotlin の DSL scope 規則](https://kotlinlang.org/docs/type-safe-builders.html)とも一致しません。
- 推奨修正: content 側にも同一マーカーを持つ receiver を導入するなど API を再設計するか、「ネストした lambda から呼べない」という保証を削除してください。意図した禁止構文を列挙した compile-negative test も tasks に追加してください。

### [Major] duplicate template registration の既存決定がデルタスペックから欠落している

- 該当箇所: `kasane/decisions/core/0011-invalid-input-release-behavior.md:16-20`
- 関連箇所: `kasane/changes/android-wrapper-foundation/specs/collection-core/spec.md:36-55`, `kasane/changes/android-wrapper-foundation/tasks.md:18-21`
- 問題点: ADR は duplicate template registration を Debug assertion／Release last-wins warning の対象に含めていますが、デルタスペックとテストタスクには duplicate item ID と unknown key しかありません。このままでは既存決定の一部が実装されなくても検証を通過します。
- 推奨修正: duplicate template key の Requirement、Debug／Release Scenario、診断内容、last-wins の確認テストを追加してください。

### [Major] `.center`／`.end` の成立不能な境界条件が未決のまま残っている

- 該当箇所: `kasane/changes/android-wrapper-foundation/design.md:50,97,104-107`
- 関連箇所: `kasane/changes/android-wrapper-foundation/specs/collection-interaction/spec.md:28-44`
- 問題点: viewport 端の item、viewport より大きい item、header/footer や content padding がある場合、要求位置への厳密な center/end 配置は常に可能とは限りません。さらに [LazyGridState](https://developer.android.com/reference/kotlin/androidx/compose/foundation/lazy/grid/LazyGridState) の scroll 操作は相互排他的で、後続 scroll により実行中操作がキャンセルされます。「実装後に目視して deviation」とする設計では受け入れ条件になりません。
- 推奨修正: clamping、測定基準となる viewport、oversized item、content padding、header/footer、animation 中断時の結果を実装前に決定し、数値許容差を持つ Scenario にしてください。

### [Major] 性能基準が循環しており、不合格を判定できない

- 該当箇所: `kasane/changes/android-wrapper-foundation/proposal.md:17`
- 関連箇所: `kasane/changes/android-wrapper-foundation/specs/collection-core/spec.md:57-63`, `kasane/changes/android-wrapper-foundation/design.md:78-80`, `kasane/changes/android-wrapper-foundation/tasks.md:51-52`
- 問題点:
  - 候補実装の初回測定値から閾値を決める方式では、どの性能でもその値を基準に合格できてしまいます。
  - 10,000件固定の測定だけでは「件数に比例して memory が増えない」を検証できません。また入力 `List` 自体は件数比例で増えるため、renderer 保持量との区別が必要です。
  - `MemoryUsageMetric (PSS)` は測定 mode、submetric、測定時点が未定義です。現行 API は `Last`／`Max` と具体的な submetric を選択する形です。[MemoryUsageMetric API](https://developer.android.com/reference/androidx/benchmark/macro/MemoryUsageMetric)
  - Pixel 4a の代替を「evidence に記載」するだけでは、要求端末の保証になりません。
- 推奨修正: 実装前の比較対象（素の LazyColumn/Grid または既知版）、相対劣化率と絶対上限、件数を変えた測定、対象 memory submetric、GC・warmup・反復条件を確定してください。端末代替はオーナー承認を必要とし、Pixel 4a の結果を保証しない旨も明記してください。

### [Major] Android のセル状態について、期待結果のない Scenario が置かれている

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/samples/spec.md:31-42`
- 問題点: 「実際の保持／リセット挙動を観察・記録できる」だけでは、どちらの結果でも成功するため、仕様の Scenario として合否判定できません。これは Bundle-saveable key を要求する理由や、再利用時のセル状態保証にも影響します。
- 推奨修正: reuse、画面外移動、並び替え、プロセス再生成ごとに preserve／reset の期待結果を決定してください。まだ決めないなら Requirement から外し、探索または evidence 収集タスクに移してください。

### [Major] 変更 domain が実際の変更範囲と一致していない

- 該当箇所: `kasane/changes/android-wrapper-foundation/proposal.md:7,18,34-35,44`
- 問題点: `domain: android` ですが、提案は iOS の公開型 rename、builder inference、separator API、Sample 更新も含みます。単一 domain として扱うと、iOS 側の実装規律、レビュー、ADR／concept の蒸留先が漏れる可能性があります。
- 推奨修正: `domain: cross` に変更し、Android と iOS 双方を対象 domain として明示してください。Android だけの変更にするなら、iOS 作業を独立 change に分離してください。

### [Major] 9画面の厳密な Sample parity に対して検証計画が3画面しかない

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/samples/spec.md:13-24`
- 関連箇所: `kasane/changes/android-wrapper-foundation/tasks.md:43-45`, `kasane/concepts/sample-parity.md:26-43`
- 問題点: 実装対象は9画面ですが、視覚比較は root／list／fixed-grid のみです。残る6画面の初期値、表示件数、操作、layout parameter が iOS と異なっても受け入れ可能になっています。
- 推奨修正: 9画面すべてについてタイトル、初期データ、操作、layout parameter、表示結果を対応表にし、各画面の最低1つの静的または実機検証を tasks に追加してください。

### [Major] separator color ADR の Decision と Consequences が自己矛盾している

- 該当箇所: `kasane/decisions/core/0010-list-separator-default-appearance.md:23,39-40`
- 問題点: Decision は `listSeparatorColor` 公開 API の追加を決めていますが、Consequences は公開 API が1つのままで色を変更できないと記述しています。実装者がどちらを正とすべきか判断できません。
- 推奨修正: ADR が Proposed の間に Consequences を Decision と整合させ、デフォルト値、プラットフォーム差、公開 API 数を確定してください。

### [Minor] controller の重要な分岐に Scenario がない

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/collection-interaction/spec.md:28-30`
- 問題点: 複数 View 接続時の last-connection-wins と、queue 待機中に対象 item が削除された場合の契約は Requirement にありますが、個別 Scenario がありません。
- 推奨修正: 旧 View が操作されないこと、削除済み target が no-op となり後続 command が継続することを Scenario として追加してください。

### [Minor] 空配列時の header/footer 表示に明示的な検証がない

- 該当箇所: `kasane/changes/android-wrapper-foundation/specs/collection-layout/spec.md:73-84`
- 関連箇所: `kasane/changes/android-wrapper-foundation/tasks.md:36-38`
- 問題点: Requirement は空配列でも header/footer を表示するとしていますが、その組み合わせの Scenario とテストタスクがありません。
- 推奨修正: `items=[]` かつ header/footer 両方ありの Scenario と UI test を追加してください。

### [Minor] UI brief に生の色値が混在している

- 該当箇所: `kasane/changes/android-wrapper-foundation/ui/brief.md:37,39`
- 問題点: `#2F6FED` などの実値が brief に直接記載され、承認済み mock／token を参照するという UI artifact の役割分担から外れています。
- 推奨修正: brief では意味名または参照元だけを記述し、具体値は approved mock、platform source、または token 定義へ移してください。

## 3. 判定

**NEEDS_DISCUSSION**

コマンド競合、scroll alignment、セル状態、性能合格基準という公開挙動が未決であり、単純な記述修正だけでは閉じられません。これらを決定したうえで、DSL 制約・ADR 整合・検証 Scenario を更新してから再レビューが必要です。


## 突き合わせ結果 (2026-09-04、ホスト側自己レビュー 2 周との照合)

ホスト側の自己レビュー (チェックリスト 2 周) は Requirement ⇔ tasks の対応と ADR / concepts との整合を確認していたが、相方の指摘のうち Compose の実挙動に照らした仕様の過剰・欠落はホスト側の見逃し。採否は根拠で判定した。

| # | 指摘 | 採否 | 反映 |
|---|---|---|---|
| 1 | 「無関係な項目は再コンポーズされない」保証は一般の Item に対して実現できない | 採用 (根拠強: stability 依存) | collection-core「差分更新」を観測可能な保証 (`remember` 状態と identity の維持、画面外は保持しない) に書き換え、再コンポーズ回数を契約から外した |
| 2 | `LaunchedEffect(items, queue)` は配列更新で実行中命令をキャンセルする / FIFO か latest-wins か未定義 | 採用 (根拠強: 公式仕様) | design Decision 4 を単一 consumer (`LaunchedEffect(receiver)` + `snapshotFlow` + `rememberUpdatedState`) に変更。spec に FIFO・後続命令による中断・配列更新で消失しない・削除済み対象は no-op で継続を追加、Scenario 2 件追加 |
| 3 | `@DslMarker` では receiver なしの content ラムダから外側 `template` を呼ぶことを禁止できない | 採用 (根拠強: 言語規則) | spec の SHALL NOT を削除。design Decision 1 に「契約にしない」を明記 |
| 4 | 同じキーへの二重登録 (core/ADR-0011) が spec / tasks から欠落 | 採用 (根拠強: ADR 該当箇所) | Requirement に追加、Scenario 1 件、tasks 3.3 / 6.1 に追加 |
| 5 | `.center` / `.end` の到達不能な境界条件が未決 | 採用 (根拠強) | spec に clamp 規則 (端で止まる / 先頭合わせ)・基準は `contentPadding` 内側・ヘッダーは index に数えないを追加、Scenario 1 件。design Decision 4 に clamp を追記。アニメーション後の残差の許容は Open Question に残す |
| 6 | 性能基準が循環 (候補実装の初回値で校正) / 件数比例の検証不能 / `MemoryUsageMetric` の mode 未定義 / 代替機 | 採用 (根拠強) | 合格線を「素の `LazyVerticalGrid` に対する相対劣化 10% 以内」+「絶対上限の校正」の 2 段に変更。1,000 件 / 10,000 件の定常値比較 Scenario を追加。`Mode.Last` と submetric を design に明記。代替機はオーナー承認 + 保証にならない旨の明記を spec 化。相対 10% は提案側の設定値 (オーナー確認事項) |
| 7 | 検証画面の Scenario に期待結果がない | 採用 (根拠強) | 「テンプレート内の `remember` 状態は可視範囲外で初期化される」を期待結果にした (Compose Lazy 系の Composition 破棄) |
| 8 | `domain: android` が変更範囲 (iOS 追随を含む) と一致しない | 採用 (オーナー判断 2026-09-04) | `domain: cross` に変更。Android 固有 ADR の蒸留先は distill 時に android へ振る旨を proposal に注記 |
| 9 | 9 画面の parity に対し検証計画が 3 画面のみ | 採用 (根拠強: sample-parity 規約) | samples spec に「全画面の対応表による照合」Scenario、tasks 7.6 を追加 |
| 10 | core/ADR-0010 の Consequences が Decision と矛盾 | 採用 (根拠強) | ADR-0010 の Consequences を 2 語彙の形に修正 (proposed のため編集可) |
| 11 | 複数接続の最後勝ち・削除済み対象の Scenario がない | 採用 (Minor、安価) | Scenario 追加 (#2、#5 と合わせて) |
| 12 | 空配列の header / footer Scenario がない | 採用 (Minor、安価) | collection-layout に Scenario 追加、tasks 6.2 に追加 |
| 13 | brief に生の色値がある | 降格 | ksn-propose の規約では視覚パラメータの置き場は brief / mock であり、spec から追い出した値を brief に書くのは意図どおり (iOS の brief も同形)。修正しない |

集計: 採用 12 / 降格 1 / 未解決 0 (domain はオーナー判断で cross に確定)。相方の判定 NEEDS_DISCUSSION のうち「公開挙動の未決」4 点 (命令競合・alignment・セル状態・性能基準) は上記で仕様化した。
