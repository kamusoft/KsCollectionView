# Proposal: android-wrapper-foundation

## Why

phase-1 で対称 DSL の外形 (core/ADR-0002〜0009) が、phase-2 で iOS エンジン基盤 (ios-engine-foundation) が成立し、Sample の 9 デモ画面と文言・トークンの正が iOS 側に固まった。phase-3 の議論で Android 側の実現方式 (android/ADR-0001〜0002、agenda の決定事項 10 件) が固まった。Android ラッパー基盤は Compose 側の全機能フェーズ (画像ロード・セクション・ページング・D&D) の土台であり、両基盤の完了が最初のパリティ収束ゲート (cross/ADR-0004) になる。

あわせて、iOS 実装で判明した対称 DSL の外形 2 点 (値キーテンプレートの推論形・`Template` の接頭辞) と、区切り線の色 API (`listSeparatorColor`) を両プラットフォームで揃える。

## What Changes

- `android/` ビルドルートに単一モジュール `kscollectionview` (`jp.kamusoft:kscollectionview`) を新設 — Compose `LazyVerticalGrid` の薄いラッパー。list は 1 列グリッドとして描く (android/ADR-0001、ビルド構成は android/ADR-0002)
- 公開 DSL (dsl-samples の Kotlin 側): `KsCollectionView(items, key, template, layout, contentPadding, header, footer, onItemTap, onItemLongTap, touchFeedbackColor, listSeparators, listSeparatorColor, scrollController, modifier) { template(key) { } }` — `@DslMarker` 付きスコープ、テンプレートキー → `contentType` 自動導出、未登録キー / 重複 ID の debug assertion と release 継続 (core/ADR-0011)
- レイアウト: list / 固定列 / adaptive / 向き別列数 (コンテナの縦横比で判定) + `rowSpacing` / `columnSpacing` / `contentPadding`。list 区切り線 (既定表示、`listSeparatorColor` で色変更) を項目側で描く
- `KsScrollController` (plain class + `rememberKsScrollController()`): キュー + コンポジション後の解決で「データ反映後に実行」を保証 (core/ADR-0007)
- セル content を上端固定・狭ければ中央に置き、ios/ADR-0007 の配置規則を両プラットフォーム共通にする
- `samples/android/` scaffold (composite build + 明示 substitution、`SampleScreen` / `SampleTheme` / ルートメニュー) + iOS と一字一句同じデモ 9 画面 + Android 固有の検証画面「検証: 行の高さ変化 (Android 固有)」
- 性能検証: Macrobenchmark モジュールによる固定 fixture (10,000 件・2 列・可変行高混在) の計測。合格線は「素の `LazyVerticalGrid` に対する相対劣化 10% 以内」+「Pixel 4a の初回計測で校正した絶対上限」の 2 段。`handbook/android/performance-verification.md` の原料を evidence/ に残す
- **iOS 追随 (最初のタスクグループ)**: `KsTemplateBuilder` に `buildExpression` を足して推論形 `KsTemplate(.message) { item in }` を成立させる、`Template` → `KsTemplate` 改名、`listSeparatorColor` modifier の追加、iOS Sample (「リスト」画面の区切り線を Android と同じ 3 択 なし / 既定 / アクセント に変更) と dsl-samples の追随

影響する能力: collection-core (データ・テンプレート・更新) / collection-layout (レイアウト・スペーシング・区切り線・ヘッダーフッター) / collection-interaction (タップ・スクロール制御) / samples (検証装置)

## Non-Goals

- Pull to Refresh (`onRefresh`) — phase-5。外形は決定済み (phase-5 agenda に申し送り) だが iOS に対応物が無く、両プラットフォーム同時に実装する
- ページング・セクション/グループ化・sticky ヘッダー・D&D・画像ロード (`KsImage` / `prefetchResources`) — 各機能フェーズ (別能力)
- `LazyLayoutCacheWindow` の設定 — v1 は Compose 既定に従う (性能計測で hitch が出たら別途判断)
- maven-publish の設定と CI (verify-android) — phase-7 (配布専業フェーズ)
- テンプレート内でだけ読まれる親 state の変更検知 — 独立 change [template-parent-state-observation](../template-parent-state-observation/exploration.md) (iOS 側の課題。検証画面は対称性を見る場を提供するだけ)
- 型ベースのテンプレート切り替え — v1 対象外 (core/ADR-0004、iOS と同じ)
- 行の高さ変化の検証画面の共通デモへの昇格 — 必要になったら改めて判断 (agenda 論点 8)

## Impact

- 破壊的変更: iOS の公開型 `Template` を `KsTemplate` に改名する (未配布のため利用者影響なし。Sample と dsl-samples を同 change で追随)
- 公開 API 追加 (両プラットフォーム): `listSeparatorColor`
- Compose の版方針: ライブラリを入れると利用者アプリの Compose が最新安定版に引き上がる (android/ADR-0002 の負の帰結、受容済み)
- リスク: 1 列 `LazyVerticalGrid` の性能が `LazyColumn` と乖離する場合は android/ADR-0001 の見直し。性能計測をエンジン中核の直後に置いて早期に検知する (iOS と同じ配置)
- リスク: `key` の Bundle 保存可能制約は利用契約で担保する (ライブラリでは包まない)。違反は debug assertion と Compose の例外

## 級: L

新プラットフォームの基盤導入 (アーキテクチャ) + 公開 DSL の Android 側初実装 + iOS 側の公開 API 変更を含む複数能力横断

domain: cross   # iOS の公開 API 変更 + Android 新設の横断。実装時のスキル解決は ios + android を結合。Android 固有の ADR (material3 依存など) は蒸留時に android へ振る
roadmap: v1-foundation/phase-3-android-wrapper-foundation
