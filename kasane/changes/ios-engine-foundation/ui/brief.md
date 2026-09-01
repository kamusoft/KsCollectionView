# UI Brief: ios-engine-foundation

## 画面と状態

Sample アプリ (検証装置 — sample-parity 準拠。ライブラリ本体に固有の見た目はなく、視覚の正は「プラットフォーム標準 + SampleTheme トークン」)。

- **ルートメニュー**: デモ 9 画面へのリンク一覧 (タイトル「KsCollectionView Samples」)。状態: 通常のみ
- **リスト**: 基本 list。区切り線 (既定表示) の ON/OFF トグル、タップ/ロングタップのフィードバック確認。状態: 通常のみ
- **グリッド (固定列)**: 3 列グリッド + list⇄grid 切替トグル。状態: 通常のみ
- 他 7 画面はモック対象外 — 上記 3 画面の構造 (`SampleScreen` ラッパー + SampleTheme) を踏襲する

### デモ画面の正 (9 画面 — この表が Android 追随の一字一句の基準)

| # | 画面タイトル (= メニュー文言) | 検証対象 | モック |
|---|---|---|---|
| 1 | リスト | 基本 list・区切り線の既定表示と非表示切替・タップ/ロングタップのフィードバック | あり |
| 2 | グリッド (固定列) | `.fixed(3)` + list⇄grid 切替トグル (アンカー保持の確認) | あり |
| 3 | グリッド (adaptive) | `.adaptive(minItemWidth:)` | なし |
| 4 | 向きで列数変更 | 向き別列数 | なし |
| 5 | テンプレート切り替え | 値キーによる異種セル + 再利用 | なし |
| 6 | ルートヘッダー/フッター | `header:` / `footer:` | なし |
| 7 | スクロール制御 | `KsScrollController` の ID 指定移動・順序保証 | なし |
| 8 | スペーシングと余白 | `rowSpacing` / `columnSpacing` / `contentPadding` の動的変更 | なし |
| 9 | 大量件数 | 固定高 + 可変行高混在 10,000 件 (固定シード) の仮想化・再利用・性能 | なし |

ルートメニューはデモ画面に数えない (画面 1〜9 へのリンク一覧、モックあり)。デモデータ・文言の確定値は実装時に本 change の成果物として固定し、phase-3 が一字一句追随する (sample-parity)。

## リファレンス注釈

references/ なし (新規 Sample。参照は KsSettingsView の samples 構造のみで、画像リファレンスは持たない)

## デザイントークン参照

concepts/ に UI トークンは未登録 (プロジェクト初期)。SampleTheme のトークン (accent / 背景 / セル背景 / テキスト主・副 / 区切り線色 — 共通 RGBA、sample-parity 規約により platform semantic color 禁止) は承認モックの値を正とし、実装タスク 7.2 でコード化する。

## 承認モック

mock/variant-a.html (案 A「システム調」) を採用 (approved.png、2026-09-01 オーナー承認)。

SampleTheme トークン (確定値): accent #2F6FED / bg #F2F2F7 / cell #FFFFFF / text #111214 / text2 #6E7076 / separator #D9D9DE。variant-b.html は不採用案として保持。
