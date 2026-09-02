# セカンドオピニオン: ios-engine-foundation (code-008)
**相方**: codex / **label**: so-code-ios-engine-foundation-008 / **日付**: 2026-09-02 / **対象**: 修正サイクル 8 後の ios/・samples/ios/・change 成果物・関連 handbook / dsl-samples
---
# レビュー結果: ios-engine-foundation（修正サイクル 8 後）

**日付**: 2026-09-02  
**判定**: CHANGES_REQUESTED  
**指摘件数**: Critical 0 / Major 1 / Minor 2 / Suggestion 1

## サマリー

修正サイクル 8 の確定リスト（Major 2 / Minor 3 / 契約注記 1）はすべて解消しています。reload 優先とアンカーの要素内オフセット復元にも、静的に確認できる後退はありません。

一方、全体再レビューで、大量件数のメモリ検証がデルタスペックの「リスト全体の往復」を実施していないことを確認しました。必須性能 Scenario の完了根拠が成立しないため、判定は CHANGES_REQUESTED です。

提示されたテスト・ビルド・lint 結果を前提とした静的レビューであり、再実行はしていません。

## 照合した規約

- ksn-review の汎用チェックリスト、重要度、判定基準
- ksn-core と references:
  - handbook.md
  - delta-spec.md
  - paths.md
  - domain-axis.md
  - config.md
- swift-ui-impl-skill の SwiftUI 構造、状態管理、アクセシビリティ、性能、Concurrency、コード衛生
- kasane/handbook/cross/comment-policy.md（always）
- kasane/handbook/cross/sample-parity.md（samples/）
- kasane/handbook/cross/test-execution.md（テスト結果の報告）
- kasane/handbook/cross/runtime-behavior-verification.md（スクロール・再利用・レイアウト変更）
- kasane/handbook/cross/public-identifiers.md（Package.swift・Sample 識別子）
- kasane/handbook/cross/local-development-setup.md（更新対象）
- core/ADR-0003 / 0004 / 0006 / 0007 / 0009
- ios/ADR-0001〜0004
- kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md
- deviation.md の全記録を合意済み差分として扱った

proposal.md / design.md / specs/*/spec.md の凍結領域に HEAD との差分はありません。deviation.md の付随修正2件も、同梱条件内でテストを伴っています。

## 前回指摘の追跡

| 確定項目 | 状態 | 確認結果 |
|---|---|---|
| reconfigure と reload の重複 | **解消** | ios/Sources/KsCollectionView/KsCollectionViewController.swift:347 で reload 集合を作り、同ファイル:357 で reconfigure から除外している。ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:139 の複合更新テストも、セル置換と別 reuse identifier を確認している |
| spacing-only のアンカー保持 | **解消** | ios/Sources/KsCollectionView/KsCollectionViewController.swift:67 で layout 全値と contentPadding の変更を捕捉し、同ファイル:465 で要素内オフセットを保存、同ファイル:495 で復元している。同値配列の高速経路も同ファイル:294 から復元へ進む |
| 自己サイズの完全な受入条件 | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:239 で各セルを対象にし、同ファイル:244 でセル高とホスト内容の fitting height を比較している |
| 存在しない ID / center スクロール | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:253 で offset 不変と後続命令の到達、同ファイル:287 で対象 frame と表示範囲の中心を比較している |
| 固定列 Sample では観測不能だった handbook 記述 | **解消** | kasane/handbook/cross/runtime-behavior-verification.md:53 が、Sample で観測可能な列幅と表示乱れに限定され、アンカーは統合テストへ委ねている |
| id / template / 登録集合の不変契約 | **解消** | kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:394 と deviation.md:17 に明記されている |

アンカー復元は、以前の先頭吸着方式ではなく、変更前の `attributes.frame.minY - bounds.minY` を保存して新しい frame から差し引く方式です。reload 優先も、reload 対象を reconfigure から明示的に除外しており、いずれも修正による後退は確認しませんでした。

## 指摘事項

### [🟠 Major] メモリ計測が「リスト全体の往復」を実施していない

**該当箇所**: samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:60, kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:26, kasane/changes/ios-engine-foundation/specs/collection-core/spec.md:71, kasane/changes/ios-engine-foundation/tasks.md:51

**問題点**: 性能検証画面は `scrollToEnd(animated: false)` と `scrollToStart(animated: false)` で端点間を直接移動しています。これは途中の全項目を順次表示・再利用する「リスト全体のスクロール往復」ではなく、主に移動先付近のセルだけを生成する経路です。

したがって、記録されたメモリ値が定常化していても、10,000 件を通過した際にセル生成が可視範囲＋再利用プールへ留まることや、全体走査後にメモリが増え続けないことの証明にはなりません。基準端末の差し替えは deviation.md にありますが、往復手順の差し替えは記録されていません。tasks 8.3 の完了根拠も不足します。

**推奨修正**: 上端から下端まで中間位置を通過する実スクロールを行い、全体を2往復した直後のメモリを再計測してください。併せて、生成セル数または最大同時生存セル数を計測できるフックを用意すると、仮想化の SHALL を直接固定できます。端点ジャンプを正式な代替手順にするなら、足場を書き換えず deviation.md でオーナー合意を記録する必要があります。

### [🟡 Minor] scroll indicator 不動の Scenario に検証記録がない

**該当箇所**: kasane/changes/ios-engine-foundation/specs/collection-layout/spec.md:42, kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:21, kasane/changes/ios-engine-foundation/ui/brief.md:49

**問題点**: 実装は section の `contentInsets` を使っており、静的にはスクロールインジケータをコンポーネント端に残す構造です。しかし、統合テストはコンテンツ位置とレイアウトオブジェクトの維持だけを確認しています。verification matrix は「インジケータ位置を目視」としていますが、ui/brief.md の操作記録はつまみ・グリッド描画・表示安定までで、インジケータ位置の確認を記録していません。

**推奨修正**: 左右 padding の変更前後でスクロールインジケータが本体右端に留まることを統合テストで観測するか、操作手順と観測結果を evidence に明記してください。

### [🟡 Minor] 対称 DSL の基本例が Swift と Kotlin で1対1になっていない

**該当箇所**: kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:24, kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:44, kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:58

**問題点**: Swift の基本例には `contentPadding`、header、footer が追加されていますが、対になる Kotlin 例にはありません。その直後の「語彙5点が1対1」という自己評価も追加語彙を数えていません。文書冒頭の「宣言の並びが1対1対応」という目的、および tasks 9.1 の header / footer・contentPadding 追随完了と整合しません。

**推奨修正**: Kotlin 例にも対応する `contentPadding`、header、footer を追加し、対称性チェックを更新してください。基本例へ含めない方針なら、Swift 側も別の対称な小節へ分離してください。

### [🔵 Suggestion] アンカーテストが要素内オフセットそのものを固定していない

**該当箇所**: ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:479, ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:497, ios/Sources/KsCollectionView/KsCollectionViewController.swift:465

**問題点**: 現行テストは先頭可視 ID の維持を確認しますが、アンカー要素を `.top` へ揃えてから変更し、変更後も ID だけを比較しています。復元実装を将来 `scrollToItem(.top)` に戻してもテストは通るため、今回導入した「要素内オフセットを保持して跳ねを防ぐ」という方式を回帰テストで固定できていません。提示された手動操作結果から現時点の実害はないため Suggestion とします。

**推奨修正**: アンカー行を半分程度クリップした任意 offset へ移動し、変更前後の `frame.minY - bounds.minY` が許容誤差内で一致することを、単発変更と連続変更の双方で確認してください。

## アクションプラン

1. 全項目を通過する性能計測へ直し、2往復後のメモリと仮想化の証跡を更新する。
2. scroll indicator 不動の自動検証または明示的な操作証跡を追加する。
3. dsl-samples の Swift / Kotlin 基本例を1対1へ戻す。
4. 可能ならアンカーの要素内オフセットを統合テストで固定する。
5. 修正後、提示済みと同じ全件構成でテスト件数・失敗数・lint 結果を再確認する。

## 確認した観点

- snapshot の挿入・削除・移動・reconfigure・reload と複合更新
- 重複 ID、未登録テンプレート、Release 縮退
- list / fixed / adaptive / 向き別列数、spacing、padding、動的切り替え
- アンカー削除時の近傍復元、要素内オフセット、明示 scroll command との優先順位
- セル再利用、SwiftUI state、自己サイズ、header / footer
- tap / long tap / 子 control / feedback
- scroll controller の接続、no-op、center、データ反映後実行
- prefetch seam、MainActor、弱参照、待機処理
- Sample 9画面、通常／計測スキーム分離、公開識別子、最低対応版
- handbook、dsl-samples、tasks、verification matrix、deviation
- コメント規約、ローカルパス・識別情報・秘密情報、生成物除外
- 対象外の phase-3 agenda 差分はレビューから除外した


## 突き合わせ結果 (2026-09-02)

ホスト側 `review-008.md` (APPROVED: Minor 3 / Suggestion 4) および `verify-001.md` (VALID、所見 4 件) と突き合わせた。サイクル 8 の確定リスト 6 件は三者とも解消を確認、後退なし。集計は双方一致 2 件、相方のみで採用 2 件、ホスト / verify のみ 4 件。採用に Major 1 件を含むため、`review-008.md` の APPROVED は維持できず CHANGES_REQUESTED 相当とする。

### 採用 — 相方のみ・根拠強

- Major メモリ計測が「リスト全体の往復」になっていない: **Major**。`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:57-61` は `scrollToEnd` / `scrollToStart` の非アニメーション移動で端点間をジャンプしており、途中の項目を通過しない。spec (collection-core「大量件数での仮想化・再利用」) の「リスト全体の 1 往復スクロール後…さらに 1 往復してもメモリが増え続けない」は全項目を通過する走査を前提としており、現状の evidence は仮想化 (可視範囲 + 再利用プールに留まる) の証明になっていない。基準機の代替は deviation にあるが手順の差し替えは未記録。修正: 中間位置を通過する実スクロール (段階的な `scrollTo(id:)` または連続スクロール) で 2 往復し、iPhone 15 実機で再計測して evidence を更新する
- Minor dsl-samples の基本例が Swift / Kotlin で 1 対 1 でない: **Minor**。Swift 例に `contentPadding` / header / footer を足したが Kotlin 例は未追随、「語彙 5 点が 1 対 1」の自己評価も古い。Kotlin 例を追随させ対称性チェックを更新する

### 確定 — 双方一致

- スクロールインジケータ不動 (相方 Minor / verify 所見 S10.1): **Minor**。実装構造 (`section.contentInsets`) からは成立するが、テストも操作記録も無い。統合テストで観測する
- アンカーテストが復元方式を固定していない (相方 Suggestion / ホスト Minor-2): **Minor**。先頭可視 ID の一致だけでは UIKit 自身の補正と弁別できない。要素内オフセットの数値等式で観測する

### ホスト / verify のみ

- ホスト Minor-1 アンカーの高さが大きく縮む切り替えで表示範囲外に出うる: **Minor**。新レイアウトのアンカー高さでオフセットをクランプする
- ホスト Minor-3「存在しない ID は no-op」テストの固定 200ms 待機: **Minor**。収束待ちの形に直す (後続の有効命令の到達を待ってから offset 不変を確認)
- verify 所見 Sample UI テストの揺れ (3 回中 1 回ランナー中断): **Minor**。長押し UI テストの安定化 (待機条件の見直し) を行い、3 回連続成功を確認する
- verify 所見 S12.1 ヘッダーのスクロール追従に観測記録がない: **Minor**。統合テストで観測する
- verify 所見 8.1 / 8.3 の証跡が 1 本に統合、R14「タップ追跡中のスクロールでキャンセル」が Scenario 化されていない: 蒸留 (ksn-distill) の判断項目へ送る
- ホスト Suggestion 4 件・doc-structure lint の既存ファイル警告: 蒸留へ送る

### オーナー判断 (2026-09-02)

- 修正サイクル 9 (Major 1 + Minor 7) の実施を承認
- メモリの再計測 (全項目を通過する 2 往復) は **Simulator で行う** (iPhone 15 実機は接続しない)。hitch 計測は iPhone 15 実機の既存結果を維持
