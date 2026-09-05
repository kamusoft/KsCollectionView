# Tasks: android-wrapper-foundation

グループ 1 (iOS 追随) はグループ 2 以降の着手前に完了させる (オーナー判断)。

## 1. iOS 追随 — 対称 DSL の外形確定 (design Decision 9)
- [x] 1.1 `KsTemplateBuilder` に `buildExpression` を追加し、推論形 `KsTemplate(.message) { item in … }` をコンパイル可能にする (→ Requirement: 値キーテンプレートの推論形 (iOS 追随))
- [x] 1.2 `Template` → `KsTemplate` 改名 (ファイル名・型名・テスト。旧名は残さない) (→ Requirement: 値キーテンプレートの推論形 (iOS 追随))
- [x] 1.3 `listSeparatorColor(_:)` modifier の追加 (内部固定値を既定として上書き) + 単体テスト (→ Requirement: 区切り線の色 (両プラットフォーム))
- [x] 1.4 iOS Sample を推論形と `KsTemplate` に戻し、「リスト」画面の区切り線の操作を 3 択 (なし / 既定 / アクセント = SampleTheme.accent) に変更する (→ Requirement: iOS Sample と dsl-samples の追随 / 区切り線の色 (両プラットフォーム))
- [x] 1.5 dsl-samples.md の `KsTemplate` 改名・`listSeparatorColor` (両言語)・公開語彙一覧の更新 (→ Requirement: iOS Sample と dsl-samples の追随)
- [x] 1.6 iOS のテスト実行と結果報告 (handbook: test-execution)

## 2. Android ビルド scaffold (android/ADR-0002)
- [x] 2.1 `android/` ビルドルート: `settings.gradle.kts` / `gradle/libs.versions.toml` (AGP・Kotlin・Compose BOM 最新安定・navigation)・`kscollectionview` モジュール (`explicitApi()`、minSdk 29、JDK 17、namespace `jp.kamusoft.kscollectionview`) (handbook: public-identifiers)
- [x] 2.2 material3 依存の追加 (ripple) と最小のビルド確認・空のテストターゲット

## 3. DSL と変換層 (design Decision 1〜3)
- [x] 3.1 `KsCollectionViewScope` (`@DslMarker`) と `template(key) { }` / `template { }` の登録表 (→ Requirement: 値キーによるテンプレート切り替え (Android))
- [x] 3.2 `KsCollectionView` Composable の引数一式 (dsl-samples の Kotlin 側 + `listSeparatorColor`) と `LazyVerticalGrid` への流し込み (`items(key, contentType)`、header / footer の全幅 item) (→ Requirement: プレーンな配列と安定 ID による表示 (Android) / 差分更新 (Android) / ルートヘッダー / フッター (Android))
- [x] 3.3 前処理: 重複 ID の後勝ち除去 + 警告ログ、未登録キーの検出と空項目、同じキーへの二重登録の後勝ち + 警告ログ、debug assertion (→ Requirement: プレーンな配列と安定 ID による表示 (Android) / 未登録キーの挙動 (Android) / 値キーによるテンプレート切り替え (Android))
- [x] 3.4 `key` の利用契約 (Bundle 保存可能な型) の debug assertion と KDoc 明記 (→ Requirement: プレーンな配列と安定 ID による表示 (Android))

## 4. レイアウト (design Decision 2・5・6)
- [x] 4.1 `KsLayout` / `KsColumns` 値型と不正値の assertion (→ Requirement: layout 値による表示形態 (Android))
- [x] 4.2 `BoxWithConstraints` による向き判定 → `GridCells` 解決 (list = 1 列) (→ Requirement: layout 値による表示形態 (Android) / レイアウトの動的切り替え (Android))
- [x] 4.3 `rowSpacing` / `columnSpacing` / `contentPadding` (→ Requirement: スペーシング (Android) / contentPadding (Android))
- [x] 4.4 list 区切り線の `drawBehind` 描画 (既定表示、opt-out、`listSeparatorColor`) (→ Requirement: list の区切り線 (Android) / 区切り線の色 (両プラットフォーム))
- [x] 4.5 項目 content の `Box(TopCenter)` ラップ (→ Requirement: セル自己サイズと content の配置 (Android))

## 5. 操作とスクロール制御 (design Decision 4・6)
- [x] 5.1 `onItemTap` / `onItemLongTap` / `touchFeedbackColor` — `combinedClickable` + ripple (ハンドラ宣言時のみ) (→ Requirement: アイテムタップ / ロングタップ (Android))
- [x] 5.2 `KsScrollController` / `rememberKsScrollController()` / attach・detach (`DisposableEffect`) / 未接続 no-op / 複数接続の最後勝ち (→ Requirement: スクロール制御 (Android))
- [x] 5.3 命令キューと単一 consumer (`LaunchedEffect(receiver)` + `snapshotFlow`) による FIFO 処理・最新配列での解決・先行アニメーションの中断、Start / Center / End の補正と clamp、存在しない ID・削除済み対象の no-op (→ Requirement: スクロール制御 (Android))

## 6. テスト
- [x] 6.1 collection-core の Scenario に対応する Compose UI テスト (表示・`remember` 状態の維持・親 state・未登録キー・重複 ID・二重登録)
- [x] 6.2 collection-layout の Scenario テスト (列数解決・向き判定・スペーシング・区切り線と色・content 配置・空配列のヘッダー/フッター)
- [x] 6.3 collection-interaction の Scenario テスト (タップ排他・項目内ボタン・ハンドラ未宣言・スクロール命令の順序保証・連続命令・削除済み対象・到達不能位置の clamp・複数接続の最後勝ち・未接続/解除後 no-op)
- [x] 6.4 テスト実行と結果報告 (handbook: test-execution)
- [x] 6.5 Requirement ⇔ 検証層 (unit / Compose UI テスト / 実機手動) の対応表を整理 (iOS の 6.5 と同じ形)

## 7. Sample (design Decision 7 / handbook: sample-parity)
- [x] 7.1 `samples/android/` scaffold: composite build + 明示 substitution、catalog 共有、`app` モジュール (application ID `jp.kamusoft.kscollectionview.samples.android`) (→ Requirement: Android Sample の器)
- [x] 7.2 `SampleScreen` / `VerificationScreen` / `SampleTheme` (iOS と同値の RGBA・寸法) / ルートメニュー / Navigation Compose の共通ラッパー (→ Requirement: デモ画面の集合と文言の一致)
- [x] 7.3 デモ 9 画面を iOS の構成・文言・デモデータに一字一句追随して実装 (「リスト」は区切り線 3 択) — `ui/mock/approved.png` との視覚照合 (ルートメニュー / リスト / グリッド (固定列)) (→ Requirement: デモ画面の集合と文言の一致)
- [x] 7.4 「検証: 行の高さ変化 (Android 固有)」画面 (→ Requirement: Android 固有の検証画面)
- [x] 7.5 debug 構成のテンプレート呼び出しカウンタ (再利用確認用。release には含めない)
- [x] 7.6 9 デモ画面の対応表 (タイトル・初期データ・操作・DSL パラメータ・表示結果) を作り、iOS Simulator と Android Emulator で全画面を並べて目視照合、結果と不一致の追跡を evidence/ と deviation.md に記録 (→ Requirement: デモ画面の集合と文言の一致)

## 8. 性能検証 (design Decision 8)
※ 8.1 はグループ 4 完了直後に実施する (Sample 完成を待たず、最小の計測用画面で行う)
- [x] 8.1 `samples/android/benchmark` (Macrobenchmark) と早期計測: 素の `LazyVerticalGrid` の比較対象画面 (debug 限定) とラッパーの 1 列 / 2 列 grid 10,000 件 (iOS と同じ fixture) で `FrameTimingMetric` を比較 — 相対劣化 10% 以内の確認 (→ Requirement: 大量件数での仮想化・再利用 (Android))
- [x] 8.2 最終計測 (Sample「大量件数」画面): フリック 3 秒 × 3 試行 (相対 + 絶対上限の校正) + メモリ往復定常化 (1,000 件 / 10,000 件)。Pixel 4a (代替はオーナー承認 + evidence に「基準機の保証にならない」を明記)。校正値と結果を evidence/ に記録 (`scripts/log-sanitize.py` 経由) (→ Requirement: 性能計測の自動実行)
- [x] 8.3 再利用の確認 (カウンタ + Layout Inspector) の結果を evidence/ に記録

## 9. ドキュメント追随
- [x] 9.1 local-development-setup.md の Android 節 (SDK / JDK の要件、Sample の起動、本体へのステップイン、`SampleScreen` の定義元パス) を実際に確認した手順で埋める
- [x] 9.2 `key` の Bundle 保存可能制約・テンプレート内 state の保持挙動 (検証画面の観察結果) を利用者向け注意書きとして dsl-samples の注記に追加
- [x] 9.3 proposed の ADR (core/ADR-0010 区切り線の実値、core/ADR-0011 不正入力の release 挙動、ios/ADR-0007 content 配置) を Android 実装と突き合わせた結果を evidence/ に記録する (accepted への昇格は ksn-distill)
