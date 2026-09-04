# セカンドオピニオン: ios-engine-foundation (code-005)
**相方**: claude / **label**: so-code-ios-engine-foundation-final / **日付**: 2026-09-02 / **対象**: 最終差分 (ios/・samples/ios/・change成果物・関連handbook)
---
レビューを完了しました。`ksn-review` の規律に従い、変更アーティファクト・実装・handbook のみを見て判定しています (review-NNN.md / second-opinion は未読、`deviation.md` 記録済みの乖離は指摘対象外)。

---

# レビュー結果: ios-engine-foundation (独立レビュー)

**日付**: 2026-09-02
**判定**: **CHANGES_REQUESTED**

## サマリー

デルタスペックの Requirement / Scenario はほぼ全て実装と検証層に写像されており、tasks.md のチェックに虚偽は見当たらず、足場 (proposal / design / specs) の書き換えもありません。テストは実レイアウト属性・実描画画像・実 SwiftUI Button の AX 起動まで踏み込んでおり、質は高いです。

一方で、**「既定値のまま使う経路」と「毎更新で走る経路」に検証の空白**があり、そこに実害のある欠陥が残っています。具体的には (a) `touchFeedback` 未指定時の既定色が不透明でセル内容を覆う、(b) 長押し認識器が `onItemLongTap` 未宣言でも常時タッチをキャンセルする、(c) 位置変更のたびに全既存要素を reconfigure している (spec の「無関係な要素は再描画されない」に反する)、(d) 項目が不変でも `update` のたびに O(n) の再構築が走る、の 4 点です。いずれも既存テスト・実機計測 (純スクロールのみ) の射程外にあります。

## 照合した規約

- `handbook/cross/comment-policy.md` (always) — 公開 doc コメントに内部用語なし、禁止参照なし。適合
- `handbook/cross/sample-parity.md` (`samples/**` を触るため) — 9 画面・`SampleScreen`/`SampleTheme` 集約・semantic color 不使用。適合 (検証専用画面はメニュー非掲載でデモ集合に数えていない)
- `handbook/cross/public-identifiers.md` (`ios/Package.swift` を触るため) — package/product `KsCollectionView`、bundle ID `jp.kamusoft.kscollectionview.samples.ios`。適合
- `handbook/cross/test-execution.md` / `runtime-behavior-verification.md` / `local-development-setup.md` — 実測手順への書き換えは妥当。適合
- `lessons/inbox/verify-interactive-collection-layout-transitions.md` (未昇格 pain) — 「操作後にだけ現れる不具合」の観点として参照。本レビューは静的のため、下記 Major-1/2 は実操作での再確認を推奨
- `decisions/core|ios|cross/*`, `concepts/` — 概念は未作成。ADR は core/0003・0004・0006・0007・0009 と ios/0001〜0004 を参照

---

## 指摘事項

### 🟠 Major-1: `touchFeedback` 未指定時の既定色が不透明で、タッチ中にセル内容が完全に隠れる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:194` / `ios/Sources/KsCollectionView/KsHostingCell.swift:74,88`

**問題点**: 既定値が `.systemGray4` (alpha = 1 の不透明色) で、`touchFeedbackView` は `frame = bounds` かつ `bringSubviewToFront` で `contentView` の前面にあります。したがって `touchFeedback(color:)` を宣言しない利用者は、タップ中にセルの中身が単色の灰色矩形で完全に覆われます。デルタスペック (collection-interaction)「既定はプラットフォーム標準のハイライト」および dsl-samples.md の「省略時はプラットフォーム標準のハイライト」と乖離します。

既存の検証はこの経路を通っていません — engine テストは alpha 0.3 の色、Sample は `accent.opacity(0.15)`、検証画面は意図的な `.red` を渡しており、**既定値を使う画面が 1 つもありません**。

**失敗シナリオ**: `KsCollectionView(items) { ... }.onItemTap { ... }` だけを書いた画面で行を押し下げると、押している間そのセルの文字・画像がすべて消えて灰色の板になる。

**推奨修正**: 既定値を半透明のシステム色 (`UIColor.systemFill` 等) にするか、`UICollectionViewCell` の標準ハイライト (`backgroundConfiguration` の `.highlighted` 状態) を既定経路に使う。併せて既定値のまま highlight したときの描画比較テスト (既存の `renderedImageData` 方式) を追加する。

---

### 🟠 Major-2: 長押し認識器が `onItemLongTap` 未宣言でも常時アタッチされ、タッチをキャンセルする

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:103-106`, `381-397`

**問題点**: `UILongPressGestureRecognizer` が `cancelsTouchesInView = true` で無条件にアタッチされ、`handleLongPress` の側でだけ `configuration.onItemLongTap != nil` を見ています。認識自体は常に成立するため、`onItemTap` だけを宣言した利用者でも、長押し閾値 (既定 0.5 秒) を超えたゆっくりしたタップはタッチがキャンセルされ、`onItemTap` が発火しません。

さらに spec の SHALL NOT「長押しが成立したタッチでは `onItemTap` を発火しない」に対応するテストが存在しません。存在するのは `test長押し成立後の別タッチによる通常タップを抑止しない` (:243) で、これは `performLongPress` と `didSelectItemAt` を直接呼び、**両方が発火することを期待する**テストです。つまり排他性は `cancelsTouchesInView` の副作用に委ねられたまま未検証です。ここは二者択一で、どちらに転んでも欠陥になります:

- キャンセルが効いている → 上記のとおり「遅いタップ」で `onItemTap` が落ちる (実害)
- キャンセルが効いていない → 長押し成立時に `onItemLongTap` と `onItemTap` が二重発火し spec の SHALL NOT 違反

**失敗シナリオ**: `onItemTap` のみ宣言したリストで、行を 1 秒押してから離す → コールバックが呼ばれず、利用者からは「タップが反応しないことがある」と見える。

**推奨修正**: `onItemLongTap` が宣言されているときだけ認識器を有効化する (`longPress.isEnabled = configuration.onItemLongTap != nil` を `update(configuration:)` でも更新)。その上で「長押し成立と同一タッチでは onItemTap が発火しない」「long tap ハンドラ未宣言なら長押し後の指離しで onItemTap が発火する」の 2 本を、実タッチ経路 (XCUITest の press) で検証する。

---

### 🟠 Major-3: 位置が変わると既存要素を全件 reconfigure している (spec「無関係な要素は再描画されない」に反する)

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:270-272`

```swift
let reconfigureIdentifiers = reconfiguringAllItems || positionsChanged
    ? identifiers.filter(existingIdentifiers.contains)   // ← 既存要素すべて
    : plan.reconfigure.map(...)
```

**問題点**: 挿入・削除・並べ替えのいずれか (= `positionsChanged`) が起きると、内容が一切変わっていない要素も含めて全既存 identifier が `reconfigureItems` に載ります。reconfigure はセルプロバイダを再実行し、`UIHostingConfiguration` を作り直して SwiftUI の本文を再評価するため、collection-core の Scenario「挿入・削除・移動のアニメーション適用 → 無関係な要素は再描画されない」に正面から反します。

区切り線の位置追随が目的であれば、apply の completion にある `updateVisibleCellSeparators()` (:286) が既に同じ仕事をしており、冗長です (`reconfiguringAllItems` = layout 種別変更時の全再構成は、テンプレート本文が layout に依存する `FixedGridDemoView` のような使い方に必要なので妥当)。

**失敗シナリオ**: 10,000 件のリストに 1 件を先頭挿入すると、10,000 個の identifier が reconfigure 対象になり、可視セル全ての SwiftUI 本文が再評価される。件数に比例したスナップショット処理も毎回走る。

**推奨修正**: `positionsChanged` を reconfigure の条件から外し、位置依存の表示 (先頭行の Top 区切り線) は completion の `updateVisibleCellSeparators()` に一本化する。併せて「無関係な要素が reconfigure されない」ことを、セルプロバイダ呼び出し回数を数えるテストで固定する。

---

### 🟠 Major-4: 項目が変わっていなくても、更新のたびに O(n) の再構築が走る

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:231-258` (`apply`)、呼び出し元 `:77-81`

**問題点**: `updateUIViewController` は親の状態が変わるたびに呼ばれ、`update(configuration:)` は無条件に `apply(items:)` を呼びます。`apply` は「変化なし」を判定する前に、
`makePlan` の `newItems.map(id)` / 全件の Equatable 比較 → `itemsByID` 再構築 → `keysByID` 再構築 → `Set(keysByID.values)` → `identifiers.map(KsItemIdentifier.init)` → `dataSource.snapshot()` のコピー → 配列比較、と **8 パス近い O(n) 処理と `AnyHashable` のボックス化**を毎回実行します。`hasSnapshotChanges` のガード (:259) はこれらすべてが終わった後にしか効きません。

実機計測 (`evidence/performance-early-measurement.md`) は「純粋なスクロールのみ」の土俵なのでこの経路を通っておらず、hitch 0.0 ms/s はこの問題を否定しません。

**失敗シナリオ**: 10,000 件のリストと検索用 `TextField` (または Slider) を同じ画面に置くと、1 文字入力・1 ドラッグフレームごとに 10,000 件分のクロージャ呼び出し・ハッシュ計算・ボックス化が走り、入力が引っかかる。`SpacingPaddingDemoView` と同じ構造を大量件数データに適用すると再現する。

**推奨修正**: `apply` の冒頭で「前回の items と新 items が同一 (`==`) かつ layout 種別も不変」なら即 return する早期脱出を入れる。加えて `execute` 内の `dataSource.snapshot()` (:425, :432) はスナップショット全体のコピーなので、末尾 identifier は保持済みの配列から取る形に置き換える。

---

### 🟡 Minor-1: header / footer が更新のたびにホスティングビューごと作り直され、内部状態が失われる

**該当箇所**: `ios/Sources/KsCollectionView/KsHostingSupplementaryView.swift:25-37`、`KsCollectionViewController.swift:213-220, 75, 287`

**問題点**: `configure(using:)` は毎回 `hostedView?.removeFromSuperview()` → `configuration.makeContentView()` で新しいビューを作り直します。これが `update(configuration:)` と apply completion の両方から**無条件に**呼ばれるため、header の内容が変わっていなくても毎更新で作り直されます。`UIContentView.supports(_:)` による差分更新経路を使っていません。

**失敗シナリオ**: `header { TextField(...) }` を宣言した画面で 1 文字入力すると、その入力によって親が更新 → header が作り直され、フォーカスとキーボードが落ちる。アニメーション中の header も毎フレーム再生成される。

**推奨修正**: 既存の `hostedView` が `UIContentView` で `supports(configuration)` を満たすなら `configuration` の代入で更新し、満たさないときだけ作り直す。

---

### 🟡 Minor-2: 重複 ID が release ビルドでプロセスを落とす

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:246-249` (併せて `KsTemplateRegistry.swift:10-12`)

**問題点**: spec は「重複 ID は不正入力であり、debug ビルドでは assertion で検知する」と定めており、`KsSnapshotPlanner.swift:12` の `assert` はこれを満たします。しかし `Dictionary(uniqueKeysWithValues:)` は **release でもトラップする**ため、debug と release で「assertion による検知」と「無条件クラッシュ」の区別がありません。未登録テンプレートキーでは「release はクラッシュせず空セル + 警告ログ」という方針を採っているのに、重複 ID だけ方針が逆になっています (テンプレートキーの重複登録も同様)。

**失敗シナリオ**: サーバ由来のデータで同一 ID が 2 件混入した瞬間、製品アプリが `Fatal error: Duplicate values for key` で落ちる。

**推奨修正**: `Dictionary(items.map { ... }, uniquingKeysWith: { first, _ in first })` 等で release を非致命にし、release では警告ログを出す (debug は現行の assertion を維持)。

---

### 🟡 Minor-3: スナップショット世代の判定が実質デッドコード

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:280-292`

**問題点**: 外側の `if generation == snapshotGeneration || applyingSnapshotCount == 0` は、直後の `guard applyingSnapshotCount == 0 else { return }` に完全に吸収され、条件全体が `applyingSnapshotCount == 0` と等価です。結果として `snapshotGeneration` は加算されるだけで一切効いておらず、「最後の差分反映の完了後に実行」という core/ADR-0007 の意図が状態変数の見かけ上だけ表現されています。

**推奨修正**: 世代判定で意図を表現するなら二重条件を解消して `generation == snapshotGeneration` を実際の判定に使う。カウンタだけで足りるなら `snapshotGeneration` を削除して意図をコメントで補う。

---

### 🟡 Minor-4: `ios/PerformanceHarness/` が誰からも参照されない死んだターゲット

**該当箇所**: `ios/Package.swift:14-20`、`ios/PerformanceHarness/KsPerformanceHarnessView.swift`、`ios/PerformanceHarness/README.md:5`

**問題点**: `KsPerformanceHarnessView` はテスト・Sample・製品のどこからも参照されておらず (grep で 0 件)、テストターゲットの `dependencies` に載っているだけです。実際の計測は `samples/ios/.../PerformanceVerificationView.swift` と Sample「大量件数」で行われており、10,000 件の fixture が LCG 生成 (harness) と `index % 7` (Sample) の 2 系統に分裂しています。README は iPhone 11 前提の手順を現行手順のように記述しており、`evidence/performance-early-measurement.md` の実施内容と一致しません。

**推奨修正**: harness を削除して Sample の計測経路に一本化するか、逆に harness を実際の計測装置として使い README を実施内容に合わせる。どちらでも fixture は 1 箇所に統合する。

---

### 🟡 Minor-5: `evidence/verification-matrix.md` の実機行が実施内容と食い違う

**該当箇所**: `kasane/changes/ios-engine-foundation/evidence/verification-matrix.md` (「10,000 件の仮想化・再利用」行)

**問題点**: 実機手動欄が「iPhone 11 + Instruments」のままです。基準機の差し替え自体は `deviation.md` にオーナー合意済みとして記録されているため乖離としては指摘しませんが、**証跡の表が実施していない機種を実施したかのように読める**点は証跡の正確性の問題です (同じ表の他行が実施内容を書いているため、この行だけ計画値になっている)。

**推奨修正**: 「iPhone 15 (代替機、deviation 記録済み) + Instruments」のように実施内容へ揃え、参照先は現状どおり `performance-early-measurement.md` を残す。

---

### 🔵 Suggestion-1: `scrollToStart` が空データで no-op になる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:425`

items が空でも header は表示されうるため、`guard !itemIdentifiers.isEmpty` は「先頭へ戻る」命令を必要以上に落とします。spec は `.start` に件数条件を課していません。オフセット設定は件数に依存しないので、ガードを外すことを検討してください。

### 🔵 Suggestion-2: `KsItemIdentifier` の `@unchecked Sendable`

**該当箇所**: `ios/Sources/KsCollectionView/KsItemIdentifier.swift:3`

利用者の ID 型が非 Sendable でも Sendable を主張します。`NSDiffableDataSourceSnapshot` の差分計算はバックグラウンドで走りうるため、無条件の `@unchecked` は将来の落とし穴になります。少なくとも「MainActor 上でのみ生成・消費する」根拠をコメントで自己完結させてください。

### 🔵 Suggestion-3: `columnSpacing` だけ後付け modifier がない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionLayout.swift:33`

`rowSpacing(_:)` はあるのに `columnSpacing(_:)` がなく、対称 DSL の語彙表 (dsl-samples.md) 上も片側だけ非対称です。公開 API は覆すコストが高いので、この change のうちに揃えるか、意図的な非対称なら理由を残すことを勧めます。

### 🔵 Suggestion-4: 無接頭辞の公開型 `Template`

**該当箇所**: `ios/Sources/KsCollectionView/Template.swift:4`

他の公開型がすべて `Ks*` の中でここだけ接頭辞がなく、利用者側の同名型・他ライブラリと衝突しやすい名前です。名前は phase-1 の dsl-samples.md 由来なので**本 change の違反として直せとは言いません**が、公開後は変更不能になるため、配布フェーズ (phase-7) を待たずに命名の是非をオーナー判断に載せる価値があります。

### 🔵 Suggestion-5: UI テストに固定 `Thread.sleep` が混ざる

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:29,38`

`test大量件数を3秒間連続フリックスクロールする` は Instruments 接続待ちの固定 sleep (最大 20 秒) を含み、アサーションを持たない計測ドライバです。通常の UI テストスイートに常駐すると `handbook/cross/test-execution.md` の「収束を待つアサーション」の精神から外れ、実行時間も食います。計測専用スキーム / テストプランへ分離することを勧めます。

## 突き合わせ結果 (2026-09-02)

ホスト側最終レビュー `review-005.md` の観点と現在のコード・仕様を再照合した。集計は双方一致 0 件、相方のみで採用 7 件、降格 7 件、未解決 0 件。採用した指摘に Major 2 件があるため、`review-005.md` の APPROVED は維持できず CHANGES_REQUESTED 相当とする。

### 採用 — 相方のみ・根拠強

- Major-1 既定 touch feedback: **Major**。不透明な `.systemGray4` の全セル overlay が content 前面に出て内容を隠し、標準ハイライト契約に反する
- Major-2 長押し認識器の常時有効化: **Minor**。ハンドラなしでも recognizer が成立し touch をキャンセルする。ただし 1 秒保持を tap と扱う契約は明記されず、二重発火も未実証のため重要度を降格
- Major-3 位置変更時の全件 reconfigure: **Major**。`positionsChanged` で全既存 ID を再構成し、spec の「無関係な要素は再描画されない」に直接反する
- Major-4 不変更新時の O(n) 再構築: **Minor**。複数回の全件走査は事実だが、早期配列比較も O(n) で実測上の支障は未提示
- Minor-1 header / footer 再生成: **Minor**。更新ごとに破棄・再生成するため内部状態と focus を失うシナリオが成立する
- Minor-5 verification matrix の機種不一致: **Minor**。計画値 iPhone 11 の記述が残り、実施した iPhone 15 代替と一致しない
- Suggestion-1 空データ時 scrollToStart: **Suggestion**。items が空でも大きな header はスクロール可能だが guard で命令が落ちる

### 降格 — 根拠弱・仕様外・既判断と重複

- Minor-2 重複 ID release trap: 対応不要〜Suggestion。不正入力の release 縮退契約はなく、初回突き合わせの降格判断を維持
- Minor-3 snapshot 世代判定: Suggestion。カウンタが全 apply 完了後の flush を保証しており、挙動不良は成立しない
- Minor-4 PerformanceHarness: Suggestion。test target dependency によりコンパイル保証はあり、「誰からも参照されない」は誤認
- Suggestion-2 `@unchecked Sendable`: Suggestion 以下。MainActor 内の生成・利用で、越境の実害は推測
- Suggestion-3 columnSpacing modifier: 対応不要。initializer で spec を満たし、初回降格判断を維持
- Suggestion-4 `Template` 命名: 対応不要。phase-1 の確定語彙で、本 change の欠陥ではない
- Suggestion-5 UI test の固定 sleep: Suggestion。Instruments 接続用の意図的な計測窓で correctness 違反ではない

### 未解決

なし。

---

## アクションプラン (優先度順)

1. **Major-1** 既定 touchFeedback を半透明化 (または標準ハイライト経路へ) + 既定値の描画テスト追加 — 既定利用者に直撃する視覚不具合
2. **Major-2** 長押し認識器を `onItemLongTap` 宣言時のみ有効化 + 排他性 2 ケースを実タッチ経路で検証 — spec の SHALL NOT が現状無検証
3. **Major-3** `positionsChanged` による全件 reconfigure の撤去 + セルプロバイダ呼び出し回数のテスト固定
4. **Major-4** `apply` の早期脱出 (items 不変時) + `execute` の `snapshot()` コピー除去
5. **Minor-1 / Minor-2** header/footer の差分更新化、重複 ID の release 非致命化
6. **Minor-3〜5** 世代判定の整理、PerformanceHarness の統合または削除、verification-matrix の実施内容への修正
7. **Suggestion** は次フェーズ判断でも可 (Suggestion-4 は公開前に一度オーナー判断へ)

## 確認した観点 (指摘に至らなかったもの)

- 足場 (proposal / design / specs) の書き換えなし。tasks.md のチェックはすべて実体を伴う (`tasks.md` の 2.4 欠番は HEAD 時点からの採番ギャップで、本実装による削除ではない)
- `deviation.md` の `[付随修正]` は「iOS 26 のセル登録準備」1 件のみで、同一能力内の局所修正 + Sample 起動に必要という同梱条件に収まり、`test初回表示前にセル登録を準備して再利用セルを生成する` で担保されている
- contentPadding は `section.contentInsets` で実装され、スクロールインジケータがコンポーネント端に残る構造になっている (spec 適合)
- adaptive の列数式・列間・余白は実レイアウト属性でアサートされており、`KsLayoutMetrics` の式も spec の「利用可能幅」定義と一致
- 向き別列数は `environment.container.effectiveContentSize` の縦横比参照で、物理向きに依存しない (core/ADR-0006 適合)。回転通知の購読なし
- レイアウト差し替えではなく `invalidateLayout()` のみ (ios/ADR-0001 適合)、`test連続するスペーシングと余白変更でレイアウトを作り直さない` で固定されている
- `KsScrollController` の receiver は weak、`dismantleUIViewController` で detach しており、参照循環・解放後命令は問題なし
- Sample は 9 画面・文言/トークン集約・semantic color 不使用で sample-parity 適合。検証専用画面は launch 引数ゲートでメニュー非掲載
- ビルド・テストは本レビューの依頼条件により未実行。ホスト報告 (Debug 33/33、Release 34/34、Sample UI 3/3、iOS 16 build、各 lint) を前提としています。Major-1/2 は静的解析による判断のため、実機・Simulator での操作確認での裏取りを推奨します

## 再突き合わせ (オーケストレーター引き継ぎ後、2026-09-02)

オーナーから「突き合わせの降格判断が怪しい (columnSpacing の modifier 対応など)」と指摘を受け、`second-opinion-code-001.md` と本ファイルの降格・重要度変更を、ADR / dsl-samples / デルタスペック / 現行コードと再照合した。

### 降格を覆す (再昇格)

| 出典 | 元の判定 | 再判定 | 根拠 |
|---|---|---|---|
| code-001 #21 / code-005 Suggestion-3 スペーシングの DSL 語彙 | 対応不要 | **Major** | core/ADR-0006 の語彙は `.list(rowSpacing:)` / `.grid(columns:, rowSpacing:, columnSpacing:)` (引数形)。実装 (`ios/Sources/KsCollectionView/KsCollectionLayout.swift:16-35`) は `.list` に引数が無く `rowSpacing(_:)` modifier だけがあり、`columnSpacing(_:)` modifier は無い。本 change が更新した dsl-samples.md の Swift 例は `.list.rowSpacing(4)` (ADR に無い形) で、対になる Kotlin 例は `KsLayout.List` (スペーシング無し) — 対称性が文書内で崩れている。proposal は「dsl-samples.md と ADR 群への整合を必須とする」と明記しており、「初期化子で契約を満たす」は list には当てはまらない |
| code-005 Major-2 長押し認識器の常時有効化 | Minor へ降格 | **Major** | `KsCollectionViewController.swift:103-106` で認識器は無条件に付き `cancelsTouchesInView = true`、ハンドラ有無は `handleLongPress` (:381-397) でしか見ていない。`onItemTap` だけを宣言した利用者が 0.5 秒以上押してから離すと、タッチがキャンセルされコールバックが発火しない (実害が具体的)。spec の「長押しが成立したタッチでは onItemTap を発火しない」も同一タッチのテストが無い |
| code-001 #22 Sample のテンプレート宣言 | 対応不要 | **Minor** | Sample は「DSL の書き味の実証装置」(proposal / brief)。`TemplateSwitchDemoView.swift:7,14` の `Template<TemplateDemoItem, TemplateDemoKind>(.message)` は dsl-samples の `Template(FeedItem.Kind.message) { (item: FeedItem) in ... }` と乖離。推論が通らないなら DSL 側の書き味の問題として報告対象 |
| code-001 #2 / code-005 Minor-2 重複 ID の release trap | 対応不要 | **Minor** | spec は release の挙動に沈黙しているが、同じ spec の未登録キーは「release ではクラッシュせず警告ログ」を採る。原因の読めない `Duplicate values for key` で製品が落ちるのは堅牢性の指摘として妥当。修正は非 trap 構築 + 警告ログの数行で、契約の明確化として deviation に残す |
| code-005 Minor-4 PerformanceHarness | Suggestion | **Minor** | 「コンパイル保証あり」は正しい (`ios/Package.swift:14-20`) が、`ios/PerformanceHarness/README.md` は iPhone 11 前提の手順を現行手順として記述し、実施内容 (Sample の計測経路 + iPhone 15 代替) と食い違う。fixture も 2 系統。削除か整合のどちらかが要る |

### 降格を維持する (判断妥当)

- code-001 #13 (Template キー重複診断) / #18 (prefetcher 強参照) / #20 (fractionalWidth) / #23 (test seam) — Suggestion の域。#24 (apply 再入) はカウンタ + 世代番号の導入で解消済み
- code-001 #14 (safe area) — Sample に `ignoresSafeArea` は無く、`UIViewControllerRepresentable` は safe area 内に配置されるため実害が成立しない
- code-001 #17 (セグメント文言 list / grid) — 承認モック `ui/mock/variant-a.html:68` がそのまま `list` / `grid` を掲げている
- code-005 Minor-3 (世代判定のデッドコード) / Suggestion-2 (`@unchecked Sendable`) / Suggestion-5 (固定 sleep) — Suggestion の域
- code-005 Suggestion-4 (`Template` の無接頭辞) — phase-1 の確定語彙 (core/ADR-0004、dsl-samples) であり本 change の欠陥ではない。公開前の命名判断としてオーナーに一言だけ提示する

### 現状の判定

- `review-005.md` の APPROVED は維持できない。本ファイルで採用済みの Major-1 (既定 touch feedback が不透明) と Major-3 (位置変更時の全件 reconfigure) は現行コード (`KsCollectionViewController.swift:194`, `:270`) に未修正のまま残っている
- 再昇格分を加えた残指摘: Major 4 件 (既定 feedback / 全件 reconfigure / スペーシング語彙 / 長押し認識器)、Minor 6 件 (header・footer 再生成 / 不変更新の O(n) / matrix 機種行 / 重複 ID / Sample テンプレート宣言 / harness README)、Suggestion 1 件 (空データ時 scrollToStart)
- L 級で必須の verify (ksn-verifier) は未実施 (verify-NNN.md 無し)
- レビューサイクルは上限 3 を超過済み (review-001〜005)。次サイクルの実施はオーナー判断とする

### オーナー判断 (2026-09-02)

- スペーシングの DSL 語彙: **案 A** — core/ADR-0006 通りの引数形 (`.list(rowSpacing:)` / `.grid(columns:rowSpacing:columnSpacing:)`) に統一し、`rowSpacing(_:)` modifier を撤去する。ADR と一致するため deviation は不要
- Suggestion-5 (UI テストの固定 `Thread.sleep`): オーナー判断で本 change の修正対象に**昇格** (計測ドライバを通常のテストスイートから分離する)
- 上限超過の修正サイクル 6 を実施することを承認
