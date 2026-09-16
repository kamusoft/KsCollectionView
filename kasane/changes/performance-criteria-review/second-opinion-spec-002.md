# セカンドオピニオン: performance-criteria-review (spec-002)
**相方**: codex / **label**: so-spec2-performance-criteria-review / **日付**: 2026-09-16 / **対象**: 提案一式の改訂版 (proposal / design / specs / tasks、ios/ADR-0009 ドラフト)
---
# レビュー結果: performance-criteria-review 改訂版

**判定: NEEDS_DISCUSSION**

## サマリー

内部セクション分割を試作で先に検証する方向自体は妥当です。しかし、性能判定の比較条件、adaptive の分割契約、位置維持の成立方法について仕様判断が未確定です。また、現行コードと組み合わせるとメモリ計測が必ず未判定になる問題があります。

指摘は **Critical 0 / Major 5 / Minor 3 / Suggestion 1** です。`deviation.md` に記録済みの合意済み差分は違反として扱っていません。指定どおり静的レビューのみで、ビルド・テスト・書き込みは行っていません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/cross/scroll-performance-gate.md`
- `kasane/handbook/ios/performance-verification.md`
- lessons: `trace-numeric-acceptance-values-to-same-fixture`、`confirm-launch-arguments-on-screen-before-measuring`、`report-device-and-os-with-layout-numeric-tests`、`check-tests-exercise-production-path-before-accepting-green`
- accepted ADR: core/ADR-0006、ios/ADR-0003
- proposed ADR: cross/ADR-0006、ios/ADR-0009（決定根拠ではなく整合確認対象として扱った）

## 指摘事項

### [🟠 Major] 2,000件と10,000件の比例判定が同じ仕事量を比較していない

**該当箇所**: `specs/collection-layout/spec.md:74`、`design.md:162`、`tasks.md:40`、`evidence/manual-largeData-ios-2026-09-15.md:64`

**問題点**: 受け入れ基準は solver 占有率の比を `10,000 ≤ 2,000 × 1.5` としていますが、既存証跡では10,000件側の入力区間が36.40秒、2,000件側が17.27秒で、2,000件側は末尾へ近づくため推定対象範囲も狭くなったと明記されています。2,000件では固定操作列の「未訪問域へ下向き10秒」を同条件で完遂できず、占有率差に配列件数だけでなく初見セル数・末尾到達・操作量の差が混ざります。このままでは試作を誤って合格または不合格にできます。

**基準値の出典**: `evidence/manual-largeData-ios-2026-09-15.md:53-76`（fixture: 同じ。2列・同じ混在規則の2,000/10,000件。ただし実効操作量は異なる）。500件という塊基準も同証跡の2,000件側から導出されています。

**推奨修正**: 両件数で「同数の新規セルを可視化した区間」「末尾到達前の同じ長さの初見区間」など、比較対象となる仕事量を定義してください。到達件数・入力時間・初見セル数の成立条件もScenarioへ入れ、成立しない記録は未判定にしてください。

### [🟠 Major] adaptive の塊契約が仕様・design・ADRで矛盾している

**該当箇所**: `specs/collection-layout/spec.md:31`、`design.md:129`、`design.md:152`、`kasane/decisions/ios/0009-internal-section-chunking.md:20`

**問題点**: spec は塊件数を「layout値から決まりうる列数すべての倍数」とし、adaptive の列数が変わるたびに組み直すことを要求しています。一方、design/ADR はadaptiveでは直近の列数だけを使い、塊件数が変わるときだけ組み直します。

adaptive の候補列数は表示幅によって増減するため、「決まりうるすべて」の最小公倍数を固定することはできません。また、2列から4列へ変わっても500は両方の倍数なので、designでは組み直さず、specでは組み直すことになります。

現行実装も同値配列ならsnapshot処理前に早期returnします（`ios/Sources/KsCollectionView/KsCollectionViewController.swift:430`）。`hasSnapshotChanges` に条件を足すだけではadaptive再分割へ到達できません。

**推奨修正**: 例えば次のように契約を一本化してください。

- 固定・向き別: 宣言された候補列数すべての倍数
- adaptive: 現在解決済みの列数の倍数
- adaptive の列数変更時: 現在の塊件数が新しい列数で割り切れない場合だけ再分割

併せて、同値配列の早期returnより前に塊構造変更を判定することをdesign/tasksへ明記してください。

### [🟠 Major] 内部分割後、メモリ計測ドライバは全件通過を判定できない

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:224`、`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:151`、`tasks.md:54`、`tasks.md:60`

**問題点**: 現行ドライバは可視項目を `indexPath.item` で記録しています。内部分割後、この値は各セクションで0から再開します。500件×20セクションの10,000件を走査しても集合の件数は最大約500となり、`visited.count == fixture.itemCount` が必ず失敗します。

`tasks.md:6.2` はテスト内の `section: 0` 直書きだけを対象としており、Sampleの計測経路が漏れています。

**推奨修正**: ドライバも項目IDまたは全セクションを通したglobal ordinalで通過を記録するタスクを追加してください。2つ以上の内部セクションをまたいで全件数が一意に数えられる回帰テストも必要です。

### [🟠 Major] データ挿入時の位置維持を「既存アンカー」に任せられない

**該当箇所**: `specs/collection-layout/spec.md:64`、`design.md:152`、`tasks.md:46`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:114`

**問題点**: designは先頭挿入時の位置維持を既存アンカー経路に任せていますが、現行コードが`captureAnchor()`を呼ぶのはlayoutまたはpadding変更時だけです。項目だけを挿入・削除・並べ替えたsnapshot適用ではアンカーを捕捉しません。既存テストも「レイアウト切替と同時の挿入」であり、項目変更単独の経路を証明していません（`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:670`）。

またRequirementは追加・削除・並べ替えを含みますが、Scenarioは先頭挿入だけです。「X自身が内部セクションをまたぐ場合にも同じcell instanceを維持するのか」も決まっていません。

**推奨修正**: snapshot適用前に位置変更を検出してアンカーを捕捉する条件をdesignに追加してください。挿入・削除・並べ替えを個別Scenarioにし、Xが塊境界をまたぐ場合の「セルを作り直さない」保証範囲も明示してください。

### [🟠 Major] 改訂後の計測ドライバ構成がnormative handbookと矛盾する

**該当箇所**: `specs/samples/spec.md:46`、`design.md:172`、`tasks.md:54`、`kasane/handbook/ios/performance-verification.md:69`

**問題点**: 改訂spec/designは「メモリ自動往復と画像読み込みの観測駆動を残す」としていますが、現行handbookは「計測ドライバはこのメモリの自動往復だけを持つ」と規定しています。`tasks.md:8.4` は同handbookへ起動引数手順を追記するだけで、この矛盾を解消しません。

これは記録済みdeviationの再指摘ではありません。改訂specへ合意差分を畳み込んだ結果、最終状態としてhandbookのruleが古く残る問題です。

**推奨修正**: `tasks.md:8.4` にドライバ構成節の更新を追加し、「自動フリックは持たないが、メモリ往復と画像観測駆動は持つ」と揃えてください。

### [🟡 Minor] 合計高さ基準の出典表記が異なるfixtureのまま

**該当箇所**: `design.md:37`、`specs/collection-layout/spec.md:26`

**問題点**: designの「平均での実測は0% / 1回」は旧証跡を指していますが、その計測は一様1列ながら100件相当で、現Scenarioの2,000件とは件数が異なります。

**基準値の出典**: `kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/estimated-height-ab-measurement.md:7-16`（fixture: 異なる — 一様1列だが100件相当）。

一方、現在は `deviation.md:5-15` に一様1列・2,000件・複数機種の再校正値があります（fixture: 同じ）。

**推奨修正**: designの根拠を同じfixtureの再校正値へ差し替え、旧0% / 1回は歴史的参考値として分離してください。

### [🟡 Minor] proposed ADRをソースコメントから参照する計画になっている

**該当箇所**: `tasks.md:49`、`tasks.md:63`、`kasane/handbook/cross/comment-policy.md:19`

**問題点**: task 7.7はコードへ`ios/ADR-0009`参照を追加しますが、task 5.1はADRをproposedのまま維持します。comment-policyが許容するのは確定した設計判断へのADR参照であり、proposed ADRはレビュー規律上まだ決定ではありません。

**推奨修正**: 実装時点では塊の規則と理由を自己完結したコメントで書き、ADR参照はaccepted後に追加するか、参照追加タスクを蒸留後へ移してください。

### [🟡 Minor] 最小公倍数計算のオーバーフロー方針がない

**該当箇所**: `design.md:131`、`tasks.md:45`、`ios/Sources/KsCollectionView/KsCollectionLayout.swift:45`

**問題点**: 列数は公開APIの`Int`で、正の値に上限がありません。互いに素な大きなportrait/landscape値ではLCM計算がオーバーフローしてReleaseでもtrapし得ます。またLCMが配列件数を大幅に超えると、性能対策としての分割が事実上消えます。

**推奨修正**: overflow-safeなLCM計算、上限超過時の縮退方針、巨大値・互いに素な値のテストを決めてください。

### [🔵 Suggestion] Risksのタスク参照がずれている

**該当箇所**: `design.md:194`

**問題点**: 合計高さ・同時生存の再実行先をtasks 7.7としていますが、実際は7.6です。7.7はコメント更新です。

**推奨修正**: `tasks 7.6`へ訂正してください。

## アクションプラン

1. 比例計測の「同じ仕事量」とadaptiveの再分割条件を仕様判断として確定する。
2. 項目更新時のアンカー捕捉と、境界をまたぐセルidentityの保証範囲を決める。
3. Sampleメモリドライバを複数section対応にし、handbookとの矛盾を解消する。
4. 数値出典・ADRコメント・LCM境界条件を修正して再レビューする。


## 突き合わせ結果 (2026-09-16、ホスト側の自己レビュー 2 周との突き合わせ)

| # | 指摘 | 採否 | 反映先 |
|---|---|---|---|
| Major 1 | 2,000 / 10,000 の比例判定が同じ仕事量を比較していない | **採用** (ホスト見逃し) | `specs/collection-layout/spec.md` Scenario「件数に比例しない」を初回区間だけの比較に改め、成立条件 (末尾未到達・区間長の差 3 秒以内) と未判定を追加。`design.md` Decision 13、`tasks.md` 6.3 |
| Major 2 | adaptive の塊契約が spec / design / ADR で矛盾、同値配列の早期 return | **採用** (ホスト見逃し) | Requirement「配列の内部分割 (iOS)」を「固定・向き別は宣言された列数すべての倍数、adaptive は現在の列数の倍数、割り切れなくなったときだけ組み直す」に一本化。design Decision 10・12、ios/ADR-0009、tasks 7.3 |
| Major 3 | 内部分割後、メモリ計測ドライバの通過記録 (`indexPath.item`) が全件通過を判定できない | **採用** (ホスト見逃し) | tasks 6.2・8.3、design Decision 14 |
| Major 4 | 項目だけの挿入では既存アンカーが捕捉されず、位置維持を任せられない | **採用** (ホスト見逃し) | 契約を「塊が無い場合と同じ位置の動き、境界で飛ばない、所属が変わらない可視セルは作り直さない」に改め、位置を項目に固定する契約は足さないと明記。挿入・削除・並べ替えを別 Scenario に。design Decision 12、ios/ADR-0009、tasks 7.4 |
| Major 5 | handbook/ios の「ドライバはメモリの自動往復だけ」が改訂 spec と矛盾したまま残る | **採用** (ホスト見逃し) | tasks 8.4 にドライバ構成節の更新を追加 |
| Minor 1 | 合計高さ基準の出典が異なる fixture (100 件相当) のまま | **採用** | design Decision 2 の基準 3 に校正後の出典 (`deviation.md`、一様 1 列 2,000 件・5 機種) を追記し、旧値を起票時の出典として分離 |
| Minor 2 | proposed ADR をソースコメントから参照する計画 | **降格** (根拠が規約と食い違う) | ksn-core の ADR 規約 (references/decisions.md「ADR の性格」) では、変更由来の ADR は実装コードの `ADR-NNNN` コメントが「埋め込みの証拠」で、その merge を根拠に蒸留時 accepted へ昇格する。コメントを accepted 後に足す順序では証拠が先に無い。既存の ios/ADR-0006 / 0008 も同じ経路。tasks 7.7 は維持 |
| Minor 3 | 最小公倍数のオーバーフロー方針が無い | **採用** | design Decision 10 (オーバーフロー検査、lcm > 2,000 は現在の列数の倍数に縮退)、ios/ADR-0009、tasks 7.3 |
| Suggestion | Risks のタスク参照が 7.7 → 7.6 | **採用** | design.md Risks |

採用 8 / 降格 1 / 未解決 0。相方の判定 NEEDS_DISCUSSION の論点 (比較条件・adaptive の契約・位置維持の成立方法) は、いずれも上の反映で仕様判断として確定した。位置維持については「項目に固定する契約を足さない」側に倒した (現行の 1 セクションの挙動と同じ範囲に留め、Android との対称性の判断は別に扱う)。
