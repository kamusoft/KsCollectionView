# セカンドオピニオン: ios-engine-foundation (code-009)
**相方**: codex / **label**: so-code-ios-engine-foundation-009 / **日付**: 2026-09-03 / **対象**: 修正サイクル 9 後の ios/・samples/ios/・change 成果物・関連 handbook / dsl-samples
---
# レビュー結果: ios-engine-foundation（修正サイクル 9 後）

**日付**: 2026-09-03  
**判定**: CHANGES_REQUESTED  
**指摘件数**: Critical 0 / Major 1 / Minor 1 / Suggestion 2

## サマリー

前回の確定修正 8 件中 7 件は解消しています。特にアンカーのクランプ式と数値テストは妥当で、スクロールインジケータ、無効 ID、ヘッダー追従、UI テスト安定化にも後退は見つかりませんでした。

一方、性能画面の「200 件刻み」は非アニメーションの ID ジャンプであり、依然として全項目を通過する走査ではありません。メモリ値も定常化を示していないため、必須性能 Scenario の完了根拠が成立せず、CHANGES_REQUESTED とします。

提示されたビルド・テスト・lint 結果を前提とした静的レビューであり、再実行やファイル書き込みはしていません。

## 照合した規約

- ksn-review の汎用チェックリスト、重要度、判定基準
- ksn-core と references:
  - handbook.md
  - delta-spec.md
  - paths.md
  - domain-axis.md
  - evidence.md
  - config.md
- swift-ui-impl-skill のモダン API、View 構造、状態管理、ナビゲーション、HIG、アクセシビリティ、性能、Concurrency、コード衛生
- kasane/handbook/cross/comment-policy.md（always）
- kasane/handbook/cross/sample-parity.md（samples/）
- kasane/handbook/cross/test-execution.md（テスト結果と条件ベース待機）
- kasane/handbook/cross/runtime-behavior-verification.md（スクロール・再利用・レイアウト変更）
- kasane/handbook/cross/public-identifiers.md（Package.swift、Sample 識別子）
- kasane/handbook/cross/local-development-setup.md（更新対象、guide）
- core/ADR-0003 / 0004 / 0006 / 0007 / 0009
- ios/ADR-0001〜0004
- kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md
- deviation.md の全記録。メモリ再計測を Simulator で行う判断を含め、合意済み差分として扱った

proposal.md、design.md、specs/*/spec.md の凍結領域に HEAD との差分はありません。対象外として指定されていない phase-3 agenda の変更は、実装レビューの判定に含めていません。

## 前回指摘の追跡

| 確定修正 | 状態 | 確認結果 |
|---|---|---|
| Major: メモリ計測を全項目通過の往復にする | **未解消** | samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:67 で 200 件おきの ID へ非アニメーション移動しており、中間項目のセルは生成されない |
| Minor: Swift / Kotlin 基本例の1対1対応 | **解消** | kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:24 と同ファイル:44 で contentPadding、header、footer が対応し、同ファイル:66 の語彙数も更新済み |
| Minor: スクロールインジケータ不動の検証 | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:669 で padding 変更前後の各 inset を検証している |
| Minor: アンカーの要素内オフセット数値テスト | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:479 と同ファイル:511 が、半クリップ位置から単発・連続変更後の数値一致を検証している |
| Minor: 高さ縮小時のアンカークランプ | **解消** | ios/Sources/KsCollectionView/KsCollectionViewController.swift:545 の境界式は最低 4pt の可視長を保証し、ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:587 がクランプ必須条件を作って検証している |
| Minor: 存在しない ID テストの固定待機 | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:273 で processedCommandCount の条件ベース待機へ変更済み |
| Minor: 長押し UI テストの安定化 | **解消** | samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:42 以降で表示・hittable の収束を待ち、提示結果でも通常スキームが3回連続成功している |
| Minor: ヘッダーのスクロール追従検証 | **解消** | ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:691 が、ヘッダーの座標維持と表示範囲からの退出を検証している |

アンカー修正については、通常のオフセット保持、連続変更、高さ縮小、アンカー削除時の近傍復元を通して静的な後退は確認しませんでした。修正による新たな懸念は、下記の本番コードに残った生存セル計測処理です。

## 指摘事項

### [🟠 Major] 200 件刻みのジャンプと単調増加した測定値では、メモリ要件を証明できない

**該当箇所**:  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:57  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:67  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:85  
kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:38  
kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:54  
kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:64  
kasane/changes/ios-engine-foundation/specs/collection-core/spec.md:66  
kasane/changes/ios-engine-foundation/tasks.md:49

**問題点**: `stride(..., by: 200)` で作った約 51 個の ID に対し、`scrollTo(... animated: false)` で直接移動しています。非アニメーション移動は移動先付近のセルだけを生成し、前後のチェックポイント間にある大半の項目を通過しません。30ms の固定待機も、目的位置のレイアウトやセル生成が完了したことを観測していません。

したがって evidence の「全項目を通過」「1 往復あたり 20,000 回の項目通過」という説明は実装と一致しません。また、記録値は両実行とも全往復で増加し、片方は 1 往復後から 5 往復後まで約 18% 増えています。測定限界を明記している点は誠実ですが、この値から「増え続けない」「定常化した」とは判定できません。tasks 8.1 / 8.3 のチェックも現状では完了根拠を欠きます。

**推奨修正**: 可視範囲が前段階と重なる距離で content offset を進めるなど、途中を飛ばさない走査へ変更してください。別の検証実行で全 10,000 ID の表示到達を記録し、同じ走査条件をメモリ計測にも使う方法でも構いません。固定待機ではなく、目的 offset・末尾到達・レイアウト完了などの条件を観測してください。

メモリは事前に許容差を定め、増加傾向が止まるまで往復するか、Allocation/Leaks 等で残存増分の原因を切り分けてください。現在の表を残す場合、判定は「不合格」ではなく「定常化を確認できず未判定」が正確です。

### [🟡 Minor] 生存セル計測が本番のセル供給経路へ常時入っている

**該当箇所**:  
ios/Sources/KsCollectionView/KsCollectionViewController.swift:40  
ios/Sources/KsCollectionView/KsCollectionViewController.swift:168  
ios/Sources/KsCollectionView/KsCollectionViewController.swift:198  
ios/Sources/KsCollectionView/KsCollectionViewController.swift:204  
ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:630

**問題点**: テストでしか利用しない liveCells と cellProviderCallCount が、本番ビルドでも全セル供給時に更新されます。弱参照先が破棄されても辞書エントリは自動削除されず、通常は最大 512 件まで残ります。生存数がしきい値を超えた状態では、セル供給のたびに辞書全体の filter が走ります。

これはメモリ保持を直接引き起こす強参照ではありませんが、性能とメモリを保証するライブラリのホットパスに、製品機能ではない辞書操作・割り当て・走査を加えています。「本番コードへの影響なし」とは評価できません。

**推奨修正**: 計測処理をテスト時だけ注入する observer/counter に移し、通常構成では辞書自体を持たないようにしてください。テスト側が弱参照集合を所有し、controller は有効時だけ通知する構造なら、本番の追加処理を最小化できます。

### [🔵 Suggestion] 計測画面と公開 API のコメントが現行契約に追随していない

**該当箇所**:  
samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:5  
ios/Sources/KsCollectionView/KsCollectionView.swift:148

**問題点**: 計測画面は現在 Simulator でも使用しますが、「実機メモリ計測時だけ」と記載されています。また `listSeparators` の公開 doc コメントは「行間」だけを説明していますが、合意済み deviation により先頭上端・最終行下端にも線を描画します。

**推奨修正**: 前者を環境非依存の「メモリ計測用画面」、後者を「list の行境界に表示する区切り線」など、現行動作に一致する表現へ更新してください。

### [🔵 Suggestion] MainActor 上の遅延処理に GCD が残っている

**該当箇所**:  
ios/Sources/KsCollectionView/KsCollectionViewController.swift:723

**問題点**: `KsCollectionViewController` は MainActor 隔離されていますが、命令フラッシュの次ターン実行に `DispatchQueue.main.async` を使用しています。動作上の不具合は確認していませんが、適用される Swift Concurrency 規律と揃っていません。

**推奨修正**: 現在の「次の MainActor 実行機会まで遅延する」順序を維持したうえで、`Task { @MainActor in await Task.yield(); ... }` などへ置き換え、回帰テストでデータ更新後の実行順序を維持してください。

## アクションプラン

1. 全項目通過を観測できる走査へ直し、メモリが定常化する条件で再計測する。
2. performance evidence と verification matrix を実測結果に合わせて更新し、tasks 8.1 / 8.3 は成立後に完了扱いする。
3. 生存セル計測を本番のホットパスから分離する。
4. 現行契約と食い違うコメントを更新する。
5. 修正後、提示された本体 Debug / Release、Sample 通常3回・計測スキーム、generic build、4 lint を同じ構成で再確認する。

## 確認した観点

- snapshot の挿入・削除・移動・reconfigure・reload と複合更新
- 重複 ID、未登録テンプレート、Release 縮退
- list / fixed / adaptive / 向き別列数、spacing、padding、動的切り替え
- アンカーの要素内オフセット、クランプ、削除時近傍復元、明示スクロール命令との順序
- セル再利用、SwiftUI state、自己サイズ、header / footer
- tap / long tap / 子コントロール競合 / feedback
- scroll controller の attach / detach、no-op、center、データ反映後実行
- prefetch seam、MainActor、弱参照、待機方法
- Sample 9画面、通常／計測スキーム分離、公開識別子、最低対応版
- 承認モックと5枚の視覚照合画像
- handbook、dsl-samples、tasks、verification matrix、deviation
- コメント規約、ローカルパス・識別情報・秘密情報、生成物除外


## 突き合わせ結果 (2026-09-03)

ホスト側 `review-009.md` (CHANGES_REQUESTED: Major 2 / Minor 3 / Suggestion 4) および `verify-002.md` (INVALID: ❌ 2 件) と突き合わせた。サイクル 9 の確定リストのうち 6 件は三者とも解消を確認、後退なし。残る 2 件は三者が同じ根拠で未解消と判定しており、判定は CHANGES_REQUESTED で確定。

### 確定 — 三者一致

- **Major: メモリ計測が全項目を通過していない** (相方 Major / ホスト Major-1 / verify ❌1)。`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:58` の刻み 200 件は、実測の可視範囲 (22〜24 件) の約 9 倍で、チェックポイント間の約 88% の項目はセルが作られない。evidence の「全項目を通過」「1 往復あたり 20,000 回の項目通過」は実装と一致しない。加えて記録値は 5 往復とも単調増加で「定常化」を示していない。同じ change の統合テストが「表示範囲の半分ずつ送る」条件を自ら書いており、Sample 側だけがその条件を外している。**同一テーマの指摘が 2 周連続で残った (収束シグナル) ため、次サイクルの実施はオーナー判断とする**
- **Major: Sample の長押し UI テストが通しで不安定** (ホスト Major-2 / verify ❌2。相方は「提示結果で 3 回連続成功」を前提に解消としたが、ホストは 7 回中 4 回失敗、verify は 3 回中 3 回失敗を実測)。原因の見立て (ホスト): `XCUIApplication().launch()` が残存インスタンスに束縛されて前回の計測画面が出る、`testセル内Buttonの実座標タップを優先する` に待機強化が入っていない、タップ直後の label 同期読み

### 採用 — 相方 / ホストのみ・根拠強

- 生存セル計測フックが Release にも常時載る (相方 Minor / ホスト Minor-1): **Minor**。`KsCollectionViewController.swift:42-48, 199-210` の辞書更新がセル供給経路に常駐し、Release のメモリ計測に自らが混ざる。`#if DEBUG` またはテスト時のみ注入する observer に分離する
- 仮想化の自動検証が 2,000 件で Scenario の 10,000 件を覆っていない / 上限 400 が緩い (ホスト Minor-2, 3): **Minor**。2,000 件への縮小はオーケストレーターの指示 (実行時間 330 秒の是正) によるもの。件数非依存の証明という趣旨は保ちつつ、上限を可視行数に基づく値 (例: 可視セル数 × 3) に締める
- コメントの追随 2 件 (相方 Suggestion): **Suggestion (同梱)**。計測画面の「実機メモリ計測時だけ」、`listSeparators` の doc コメント

### 降格 — 据え置き

- GCD → Swift Concurrency (相方 Suggestion、3 回目): 据え置き (順序保証経路の書き換えリスク)。蒸留時の整理項目

### オーナー判断 (2026-09-03)

- 進行の遅さについてオーナーから指摘。以後、上限超過の伺いは立てず、推奨案 (A: 修正サイクル 10) で完了まで進める
