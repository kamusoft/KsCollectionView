# UI Brief: image-loading

## 画面と状態

UI に触れるのは 2 点。ライブラリ本体の `KsImage` の既定表示 (読み込み中 / 失敗) と、Sample のデモ画面「画像グリッド」(sample-parity 準拠)。

### `KsImage` の既定表示 (ライブラリ本体)

- **読み込み中**: 枠全体を無地で塗る (スロット未指定時の既定)。文字・アイコンは出さない
- **成功**: 画像を当てはめ方 (`fit` / `fill`) に従って表示
- **失敗**: 枠全体を無地で塗り、中央に小さな印 (画像が無いことを示す) を置く。文字は出さない
- リソース (アセット / DrawableRes) は読み込み中を経由しない

既定表示の色は各プラットフォームの標準的な無彩色に寄せ、`SampleTheme` には依存しない (本体はテーマを持たない)。生値は mock が持つ。

### Sample「画像グリッド」

- **ルートメニュー**: 既存のデモ 9 画面の末尾 (「大量件数」の次) に「画像グリッド」を追加。両プラットフォームで同じ位置
- **画像グリッド**: 3 列の固定列グリッド、10,000 件。各セルは正方形の `KsImage` (fill) とその下に ID の文言 (「#1234」)。状態: 通常 (オンライン) / 各セルの読み込み中 / 失敗 (オフライン時)
  - 操作 1: プリフェッチの切り替え (3 択: なし / ディスクまで / メモリまで)。初期値「ディスクまで」
  - 操作 2: 「キャッシュを消去」(全消去)。押すと `KsImageCache.clear(all)` を呼び、表示中の画像が読み込み中を経由して再取得される
  - 操作の置き場は mock で選ぶ (案 A: 上部に固定 / 案 B: 下部に固定)
- デモ画像: 公開のプレースホルダー画像サービス (アイテム ID から決定的に生成した URL)。サービスの選定は tasks.md (identity lint の許可設定を含む)

### 許容する差異 (sample-parity)

- OS 標準 chrome: `NavigationStack` ⇔ `Scaffold` + `TopAppBar`、segmented control ⇔ Material の segmented、ボタンの形状
- `KsImage` の既定の無彩色の実値 (プラットフォーム標準に寄せるため、RGBA 一致を要求しない。Sample のセル文言・件数・列数・初期値は一致させる)

## リファレンス注釈

references/ なし (画像の持ち込みなし)。見た目の正は既存の Sample (iOS の承認モック `kasane/changes/archive/2026-09-04-ios-engine-foundation/ui/` と Android の翻案 `kasane/changes/archive/2026-09-05-android-wrapper-foundation/ui/brief.md`) の構造を踏襲する。

## デザイントークン参照

concepts/ に UI トークンは未登録。Sample は `SampleTheme` (iOS `SampleTheme.swift` を正、Android `object SampleTheme` が同値) の既存トークン (accent / 背景 / セル背景 / テキスト主・副 / 区切り線色) を使う。新しいトークンは足さない。`KsImage` の既定表示の無彩色はライブラリ本体の定数で、トークン化しない。

## 承認モック

`mock/variant-b-bottom-bar.html` を採用 (`mock/approved.png`、2026-09-05 オーナー承認)。案 A (操作を上部に固定) との違いは操作の置き場のみで、下部バー (プリフェッチの 3 択を全幅、その下に説明文言 + 「キャッシュを消去」) を採った。提示時にセルの ID 文言と読み込み中・失敗の既定表示が画面外に切れていたのを、承認前に撮り直して修正した (文言・構成の変更なし)。

セルの構成: 正方形の `KsImage` (fill) の下に「#ID」。読み込み中は無地、失敗は無地 + 中央の印 (文字なし)。トークンは SampleTheme と同値 (accent #2F6FED / bg #F2F2F7 / cell #FFFFFF / text #111214 / text2 #6E7076 / separator #D9D9DE)。既定表示の無彩色 (mock の値: 読み込み中 #E5E5EA / 失敗 #D1D1D6 / 印 #8E8E93) は本体の定数で、各プラットフォーム標準の無彩色に寄せてよい (RGBA 一致を要求しない)。

## 照合結果

`ui/verification/image-grid-normal-ios.png` (iPhone 17 Pro Simulator / iOS 26.5 / 402pt 幅) と
`ui/verification/image-grid-normal-android.png` (エミュレータ API 35 / 392dp 幅) を `mock/approved.png` と
照合した (2026-09-07、視覚照合 2 周)。構造・トークン・意図は一致。
**2026-09-07 にオーナーが最終承認した** (下の「合意済み差分」3 件を含む)。

- 1 周目: 両プラットフォームとも構造・配色は一致。Android だけ「キャッシュを消去」の文言が
  Material の TextButton の内側余白のぶんバーの右端から離れていた
- 2 周目: Android の TextButton の左右の内側余白を外し、文言をバーの余白 (16dp) にそろえた。残差なし
- 画素で確認した点: 下部バーの背景が `#FFFFFF`、バー上端の区切り線が `#D9D9DE` であること (両プラットフォーム)

## 合意済み差分 (プラットフォーム制約)

- 戻る導線: mock は「‹ 戻る」、iOS の実装は iOS 26 の円形の戻るボタン、Android は `TopAppBar` の「←」。
  いずれも OS 標準 chrome で、本ブリーフの「許容する差異」に当たる
- 下部バーと画面下端の間: iOS はバーの背景が下端の安全領域まで伸び、Android はジェスチャー
  ナビゲーションの領域 (約 24dp) が背景色のまま残る。mock はどちらの領域も持たない
- 下部バーの 2 行目の高さ: Android は Material の最小タップ寸法 (48dp) を保つため iOS より高い

## 未撮影の状態

読み込み中と失敗の既定表示は Sample の画面上では撮影できていない。読み込み中は取得が速く
静止画に収まらず、失敗は取得を落とす手段が手元になかったため。いずれも `KsImage` 側の表示であり、
ライブラリのテストで担保している。

## トークン候補

`ImageGridMetrics` (iOS / Android 同名・同値) が持つ生値 — グリッドの間隔と内側余白 8、セルの角丸 8、
ID の文言の余白 (左右 8 / 上下 6)。`SampleTheme` にはこれらに当たるトークンが無く、この画面だけが
使う値のため画面固有の定義に置いた。他の画面でも要るようになったら `SampleTheme` への昇格を検討する。
