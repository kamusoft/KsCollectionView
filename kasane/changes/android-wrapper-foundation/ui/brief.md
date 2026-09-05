# UI Brief: android-wrapper-foundation

## 画面と状態

Sample アプリ (検証装置 — sample-parity 準拠)。**見た目の正は iOS Sample** (ios-engine-foundation の承認モックと実装) であり、Android は同じ宣言内容を Material chrome の中で描く。ライブラリ本体に固有の見た目はない。

- **ルートメニュー**: デモ 9 画面 + 固有検証画面 1 へのリンク一覧 (タイトル「KsCollectionView Samples」)。状態: 通常のみ
- **リスト**: 基本 list。区切り線の 3 択 (なし / 既定 / アクセント — `listSeparators` と `listSeparatorColor` のデモ)、タップ/ロングタップの ripple。状態: 通常のみ。**この 3 択は iOS の「リスト」画面にも同じ文言で追加する** (iOS 追随グループ、sample-parity)
- **グリッド (固定列)**: 3 列グリッド + list⇄grid 切替。状態: 通常のみ
- 他 6 デモ画面と検証画面はモック対象外 — 上記 3 画面の構造 (共通ラッパー + SampleTheme) を踏襲する

### デモ画面の正 (9 画面 + 固有 1)

画面タイトル・検証対象・デモデータは iOS 側 ([ios-engine-foundation の brief](../../archive/2026-09-04-ios-engine-foundation/ui/brief.md) の表と、iOS Sample の実装 `samples/ios/KsCollectionViewSamples/`) を一字一句の正とする。Android 固有に追加するのは「検証: 行の高さ変化 (Android 固有)」のみで、ルートメニューでは検証区分として末尾に置く (iOS の「検証: 行の高さ変化 (iOS 固有)」と同じ扱い)。

### 許容する差異 (sample-parity)

- OS 標準 chrome: `NavigationStack` ⇔ `Scaffold` + `TopAppBar` (戻る矢印)、Toggle ⇔ Switch、segmented control ⇔ Material の segmented、chevron の有無
- フィードバック: iOS のハイライト塗り ⇔ Android の ripple (色は `touchFeedbackColor` 未指定なら標準)
- 既定フォント・描画差

一致させるもの: 文言、画面構成、件数、初期値、DSL パラメータ、SampleTheme の RGBA、区切り線の位置 (先頭上端・行間・最終行下端、全幅) と色、grid セルの content 配置 (上端固定・水平中央)。

## リファレンス注釈

- `references/ios-approved-mock.html` — iOS の承認モック (案 A「システム調」)。採用: 画面構成・文言・トークン値・区切り線とグリッドの見え方。対象外: iOS の nav bar / chevron / Toggle の形状 (Material chrome に置き換える)
- iOS 実装のスクリーンショットは archive 時に削除済み (config `distill.archive-media: delete`)。実装時の視覚照合は iOS Simulator の実物と並べて行う

## デザイントークン参照

concepts/ に UI トークンは未登録。SampleTheme のトークン (accent / 背景 / セル背景 / テキスト主・副 / 区切り線色 / swatches 9 色 / 寸法定数) は iOS の `SampleTheme.swift` を正とし、同じ RGBA を `object SampleTheme` に定義する (sample-parity: platform semantic color 禁止)。

## 承認モック

`mock/variant-android.html` を採用 (`mock/approved.png`、2026-09-04 オーナー承認)。iOS 承認モックを Material chrome へ翻案した 1 案 (config の `ui.mock-variants: 2` に対し 1 案なのは、見た目の正が iOS 側で確定済みで Android 側に選択の余地が chrome しかないため)。

オーナー指示で反映した修正: 「リスト」画面の区切り線の操作を ON/OFF から 3 択 (なし / 既定 / アクセント) に変更。アクセントは SampleTheme の accent (`#2F6FED`)、既定はライブラリ既定 (`#D9D9DE`)。iOS の同画面も同じ 3 択に揃える。

SampleTheme トークン (iOS と同値): accent #2F6FED / bg #F2F2F7 / cell #FFFFFF / text #111214 / text2 #6E7076 / separator #D9D9DE / swatches 9 色 (iOS `SampleTheme.swift` の `swatches`)。

## 照合結果

`ui/verification/` の 4 枚 (root-menu / list-default / list-accent / fixed-grid) を
`mock/approved.png` と照合し、構造・トークン・意図の 3 点で照合した (2026-09-05)。トークンの差が
1 点あり (ルートメニューの検証区分の副文字色)、採らなかった判断として下記に残した。
モック対象外の 6 デモ画面と固有検証画面は iOS Simulator の実画面と並べて照合し、結果を
`evidence/sample-parity-comparison.md` に対応表として記録した。DSL パラメータの不一致が 1 件
(タップのフィードバック色) あり、本体側の統一課題として deviation.md に記録済み。
プラットフォーム制約による差分は下記のとおり。deviation.md に記録したのはタップのフィードバック色 (DSL パラメータの不一致) の 1 件で、残る 3 件は sample-parity の許容差異 (OS 標準 chrome・描画差) に当たるため本ブリーフの記録で確定した。

視覚照合ループは 2 周で収束。1 周目で見つかった乖離は次の 2 点で、いずれも 2 周目で解消した。

- 択一の切り替えが画面幅からはみ出す (残り幅の配分を切り替え側へ渡していなかった)
- 長い画面タイトルが上部バーで折り返し、戻る導線と縦位置がずれる (1 行省略にした)

## プラットフォーム制約による差分

- **タップのフィードバック色**: iOS は accent を 15% の不透明度で渡す。Android の ripple は
  渡した色に自前で不透明度をかけるため、同じ値を渡すと見えなくなる。Android は accent を
  そのまま渡し、承認モックの ripple (`#2F6FED` の淡い塗り) と同じ見え方にしている
- **通知テンプレートの印**: iOS は OS 提供の記号図案。Android は同じ意味の丸い印を Sample 側で
  描画する (図案の提供元が Compose の版で変わるため、依存を増やさない)
- **長い画面タイトル**: 上部バーで 1 行に省略する (Material の標準の振る舞い)
- **ルートメニューの検証区分の副文字色**: 承認モックは検証画面の行だけを副文字色 (`text2`) で
  描いているが、iOS はデモ画面と検証画面を同じ配色で描いている。ここは **iOS に合わせて
  モックの副文字色を採らなかった**。区分の区別は文言 (「検証:」) が担っており、sample-parity の
  「ルートメニュー上でデモ画面と明確に区別する」は文言で満たされている

## トークン候補

`SampleTheme` に無いまま Sample 内で生値を使っている寸法。concepts への昇格候補として記録する。

- グリッドセルの色見本の角丸 8、色見本とタイトルの間隔 6
- 高さ変化検証の行内の行間 4、grid のときの行間 / 列間 8
- 通知テンプレートの印の大きさ 20、印と文言の間隔 8
- 択一の切り替えと見出しの間隔 8
