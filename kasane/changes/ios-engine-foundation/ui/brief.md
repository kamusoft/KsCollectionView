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

## 実装者による視覚照合

`ui/verification/root-menu-normal.png`、`ui/verification/list-normal.png`、`ui/verification/list-separators-off.png`、`ui/verification/fixed-grid-normal.png`、`ui/verification/fixed-grid-list-after-scroll.png` を `mock/approved.png` と再照合し、2026-09-02 にオーナーが最終承認した。向き別動作は `evidence/orientation-portrait.png`、`evidence/orientation-landscape-left.png`、`evidence/orientation-landscape-right.png` に保存した。Simulator のデモデータと標準ステータス表示のみを撮影し、保存後に個人情報・端末固有の識別情報が写っていないことを目視確認した。

- 構造: ルートメニューの 9 項目・順序・文言、リストの操作列と 6 行、固定列グリッドの操作列と 3 列 × 3 行が一致
- トークン: SampleTheme の accent / background / cell / text / secondaryText / separator を全対象画面から参照
- 状態: brief で要求された通常状態を 3 画面で確認。リストは 1 pt の Top 区切り線、左右全幅の全行間線、最終行 Bottom を確認し、ON→OFF→ON の切り替えで全線が即時に消失・復帰した。固定列は grid→list 切り替え後に上下操作し、全可視セルが list 幅を維持した
- 動的操作: スペーシングと余白の Slider は step 属性を持たない。物理 drag は Simulator 操作ツールから値変更まで届かなかったため、AX でスペーシング `0.31→0.347`、余白 `0.41→0.463` の小刻みな連続値を投入し、4 刻みに丸められないこと、つまみとグリッド描画の追従、表示安定を確認した。物理 drag の最終確認はオーナー承認時に残す
- 向き: iPhone Sample の対応宣言は portrait / landscape left / landscape right の 3 方向で、portrait は 2 列、左右 landscape は 4 列へ切り替わることを確認した。portrait upside down は対応宣言に含めない
- 意図: OS 標準ナビゲーションの中で、操作列よりデモ内容を主情報とする優先順位を維持
- 照合ラウンド: 3 周。第 1 周でルートメニューの grouped 表現と本体セル登録の実行時例外を修正し、第 2 周で固定列グリッドをモックどおり 9 件へ揃え、第 3 周で区切り線の重なり順・1 pt 視認性・最終行 Bottom、連続 Slider、iPhone の対応 3 方向を再照合して収束
- 合意済み妥協: 見た目の妥協なし。OS 標準 chrome・フォント・segmented control の描画差は sample-parity で許容されたプラットフォーム差として扱う。物理 drag のツール制約は上記へ検証制約として記録し、区切り線の 1 pt 化、Slider の連続値化、iPhone の対応向き変更は `deviation.md` に記録済み

## トークン候補

- レイアウト: `horizontalPadding` / `rowVerticalPadding` / `controlVerticalPadding` / `swatchSize` / `gridMinimumHeight` (`SampleTheme` が定義元)
- グリッド色: `swatches` (mock/variant-a.html の色見本群、`SampleTheme` が定義元)
