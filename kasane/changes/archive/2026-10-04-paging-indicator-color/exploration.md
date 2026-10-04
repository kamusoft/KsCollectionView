# Exploration: paging-indicator-color

## 課題 / 動機

ページングと Pull to Refresh の読み込み中のインジケータ (次のページの読み込み中・最初の読み込み中の既定のくるくる、Pull to Refresh のインジケータ) の色を、利用者が一覧のプロパティで指定できるようにする (2026-09-27、オーナー指示で起票)。

発見の文脈: `paging-state-machine` の mock との照合 (tasks 7.1) で、ライブラリの既定の読み込み中の表示が、承認 mock のグレーではなく Sample のアクセント色 (青) に見えた。iOS は既定の `ProgressView` が環境の tint (Sample の `.tint(SampleTheme.accent)`) を受け、Android は既定の `CircularProgressIndicator` が Material のテーマの primary (Sample では accent) を受けるため。一方 Pull to Refresh のインジケータは両プラットフォームとも OS / Material の既定 (グレー系) で、同じ一覧の中で読み込み中の色がそろわない (比較画像: `kasane/changes/archive/2026-09-29-paging-state-machine/ui/verification/` の ios-01・android-01 と `evidence/` の ios / android-pull-to-refresh-refreshing。画像は archive 時に削除したため git の履歴から辿る)。オーナーは「インジケータの色はプロパティで持たせる (別タスクで良い)」と判断した。

関連: `library-default-colors-dark-mode` (ライブラリの既定の色の表示モード対応。既定値をどう決めるかはそちらと重なりうる)。

### 現状 (2026-10-04、コードで確認)

ライブラリが自分で出す読み込み中の表示は 3 つある。

| 表示 | iOS | Android | 今の色 |
|---|---|---|---|
| 次のページの読み込み中 (見えている範囲の下端に重ねる) | 標準の `ProgressView` (`ios/Sources/KsCollectionView/KsPagingDefaultIndicator.swift`) | 標準の `CircularProgressIndicator` を 24dp で (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPagingDisplay.kt:81`) | iOS は親の `.tint`、Android はテーマの primary |
| 最初の読み込み中 (0 件のときの真ん中) | 標準の `ProgressView` (`ios/Sources/KsCollectionView/KsPagingDefaultProgress.swift`) | 標準の `CircularProgressIndicator` (同 `KsPagingDisplay.kt:65`) | 同上 |
| Pull to Refresh のインジケータ | 標準の `UIRefreshControl` を継いだ部品 (`ios/Sources/KsCollectionView/KsRefreshControl.swift`)。`tintColor` は未指定 | material3 の `PullToRefreshDefaults.Indicator` (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:905`)。色は未指定 | iOS は OS のグレー、Android は矢印がテーマの onSurfaceVariant・丸い下地が surfaceContainerHigh |

- ページングの 2 つには差し替え口がある (Swift `pagingAppendingIndicator` / `pagingLoadingPlaceholder`、Kotlin `KsPaging` の同名の引数)。Pull to Refresh には差し替え口がない
- Pull to Refresh はページングを付けない一覧でも使える (iOS は SwiftUI 標準の `.refreshable`、Android は `KsCollectionView` の `onRefresh` 引数)
- 色を受け取れることの裏取り: iOS は `UIRefreshControl` の `tintColor` と `ProgressView` の `.tint` (対応 OS の下限は iOS 16)。Android は material3 1.4.0 の `PullToRefreshDefaults.Indicator` が下地の色 (`containerColor`) と矢印の色 (`color`) を引数で受ける (aar のクラスで確認)。`CircularProgressIndicator` は `color` を受ける
- 色を受ける既存の公開 API は、Swift は一覧の modifier (`listSeparatorColor(_:)`・`touchFeedback(color:)`)、Kotlin は `KsCollectionView` の引数 (`listSeparatorColor`・`touchFeedbackColor`) の形でそろっている (core/ADR-0010)
- 概念文書 `kasane/concepts/core/core-model/collection-paging.md` は「色はアプリの色設定に従い、色を指定する設定は持たない」と書いている

## 検討した選択肢 (却下案と理由を含む)

### 論点 1: 色の指定の単位 (2026-10-04 決定)

- **採用: 1 つの色で 3 つの表示をそろえる**。起票の動機が「同じ一覧の中で読み込み中の色がそろわない」で、1 か所の指定で必ずそろう。ページングの 2 つを個別に変えたい利用者には既存の差し替え口があるため、色の設定を分けなくてもすべての組み合わせに手が届く。公開 API は各プラットフォーム 1 つで済む
- 却下: ページングの 2 つと Pull to Refresh で色を分ける — そろえるには 2 か所に同じ色を書くことになる。公開 API が各プラットフォーム 2 つになる
- 却下: 3 つ別々に指定する — 公開 API・ドキュメント・テストが最も増える。そろえるには 3 か所に書く

### 論点 2: 指定しないときの既定の色 (2026-10-04 決定)

| 判断の軸 | 採用: 今のまま標準に任せる | 却下: ライブラリの固定のグレーでそろえる | 却下: テーマの色でそろえる | 却下: 標準のグレー系でそろえる |
|---|---|---|---|---|
| 指定しないとき、同じ一覧で色がそろうか | そろわない (指定すればそろう) | そろう | そろう | そろう |
| 今の見え方が変わるところ | なし | ページングの 2 つ (Android と、`.tint` を付けた iOS) | Pull to Refresh がアクセント色になる | ページングの 2 つ |
| 各プラットフォームの標準の見え方か | 標準どおり | 色がライブラリ独自 | Pull to Refresh が標準 (グレー) から外れる | Android のくるくるが Material 標準 (primary) から外れる |
| ライブラリが色の値を持つか | 持たない | ライト / ダーク 2 組を持ち、表示モードの判定が要る (`library-default-colors-dark-mode` と重なる) | 持たない | 持たない |
| 両プラットフォームで同じ実値か | 違う | 同じ (core/ADR-0010 と同じ方針) | 違う | 違う |

採用の理由: core/ADR-0024 が読み込み中を各プラットフォームの標準のくるくるで出すと決め、core/ADR-0023 が Pull to Refresh をプラットフォームの自然な形にしている。ライブラリが色の値を持たないので、未探索の `library-default-colors-dark-mode` を待たずに進められる。オーナーの元の判断は「色はプロパティで持たせる」で、既定を変える話ではなかった。core/ADR-0010 が OS の色に任せる案を却下したのは区切り線についてで、インジケータには掛からない。

未確認: iOS のくるくるは「`.tint` を明示したときだけ色が付き、付けなければグレー」という理解だが、アセットのアクセント色だけを設定したアプリでの見え方は実物で確かめていない。テーマの色でそろえる案の iOS 側 (アプリの tint をライブラリが読み取れるか) も未検証。

### 論点 3: 公開 API の名前 (2026-10-04 決定)

- **採用: `loadingIndicatorColor`**。3 つとも「読み込み中を示すインジケータ」で、既存の差し替え口の名前 (`appendingIndicator`・`loadingPlaceholder`) や Pull to Refresh の「インジケータ」と同じ言葉で読める。material3 に `LoadingIndicator` という別の部品があり名前が似る点は受け入れる
- 却下: `progressIndicatorColor` — 部品の名前 (`ProgressView`・`CircularProgressIndicator`) には合うが、Pull to Refresh に効くと読み取りにくく、進み具合 (何 %) を出す表示を連想しやすい
- 却下: `refreshIndicatorColor` — Pull to Refresh だけに見え、ページングの 2 つに効くと読めない
- 候補から外した: `indicatorColor`・`loadingColor` — ライブラリが描くスクロールインジケータや、画像 (`KsImage`) の読み込み中の色と紛れる

### 論点 4: Android の Pull to Refresh の丸い下地の色 (2026-10-04 決定)

Android の Pull to Refresh のインジケータは丸い下地 (影つき) と中の矢印でできていて、iOS は下地のないくるくるだけである。同じ色を指定しても見え方は完全には同じにならない。

- **採用: 指定した色は矢印 (動く線) だけに効かせ、下地はテーマの色のままにする**。3 つの表示で線の色がそろい、Material の標準の形と両プラットフォームの語彙の 1 対 1 (core/ADR-0002) を保てる。下地はアプリの Material のテーマに追随するため、テーマと合わない色 (例: ライトのテーマで白) を指定すると矢印が見えにくくなりうる点は受け入れ、ドキュメントに書く
- 却下: 下地の色の設定を Android に足す — アプリが下地も合わせられるが、Android だけの設定が増えて語彙の 1 対 1 が崩れる
- 却下: 下地をなくして iOS と同じ見え方にする — Material の標準の形から外れ、矢印が項目に直接重なって読みにくい

### 論点 5: Sample での見せ方 (2026-10-04 決定)

論点 2 で指定しないときの色を変えないと決めたため、Sample のページングの画面は何もしなければ今の見え方 (くるくるがアクセントの青、Pull to Refresh がグレー) のまま残る。`kasane/changes/archive/2026-09-29-paging-state-machine/ui/brief.md` は「既定の読み込み中は mock のグレーではなくアプリの色設定に従う。色を指定できるようにするのは `paging-indicator-color` で扱う」と記録している。

- **採用: Sample の既存の色「テキスト副」を指定して、3 つをグレーにそろえる**。承認済みの mock のグレーの見え方になる。テキスト副はライト / ダーク 2 組・両プラットフォーム同値の既存の色 (cross/ADR-0007) で、新しい色を足さない。新しい設定の使い方を Sample で見せられる
- 却下: アクセント色を指定して青でそろえる — Pull to Refresh が青になり、承認済みの mock のグレーと違う見え方になる
- 却下: Sample は指定しない — 3 つの色がそろわないまま残り、新しい設定を Sample で見せられない
- 却下: 操作のパネルに色の切り替えを足す — 設定の効き方はいちばん分かるが、パネルの部品・mock・UI テストが増えて変更が大きくなる

## 決定事項

- 読み込み中の表示の色の設定は 1 つで、次のページの読み込み中・最初の読み込み中・Pull to Refresh の 3 つに同時に効く (論点 1)。Pull to Refresh がページングなしでも使えるため、置き場はページングの設定の中ではなく一覧そのものになる
- 設定の名前は両プラットフォームとも `loadingIndicatorColor` (論点 3)。形は既存の区切り線の色 (`listSeparatorColor`) と同じにする: Swift は一覧の modifier `.loadingIndicatorColor(_ color: Color)`、Kotlin は `KsCollectionView` の引数 `loadingIndicatorColor: Color? = null` (省略 = 標準の色)
- 色を指定しないときは、3 つとも今の各プラットフォームの標準の色のまま変えない。ライブラリは既定の色の値を持たない (論点 2)。この change は `library-default-colors-dark-mode` に依存しない
- Android の Pull to Refresh では、指定した色は矢印に効かせ、丸い下地はテーマの色 (material3 の既定) のままにする (論点 4)。利用者向けの説明に「Android では矢印の色に効き、下地はテーマの色」と書く
- Sample のページングの画面 (両プラットフォーム) は、`loadingIndicatorColor` に Sample の「テキスト副」の色を指定して 3 つをグレーにそろえる (論点 5)。新しい色・操作のパネルの部品は足さない。色の実物の見え方は実装時にオーナーが実物で確認する
- 利用者が差し替えた表示 (差し替え口に書いた View / Composable) には、この設定の色を効かせない。効くのはライブラリの既定の 2 つの読み込み中と Pull to Refresh のインジケータだけ (探索で置いた既定を、提案の方向の確認でオーナーが了承。理由は `proposal.md` の What Changes)
- iOS の既定の表示の型 2 つ (`KsPagingDefaultIndicator`・`KsPagingDefaultProgress`) は中身が同じなので、色を足すときに 1 つにまとめる (外から見える挙動は変えない内部の整理。`kasane/changes/archive/2026-09-29-paging-state-machine/review-004.md` の Suggestion)
- 蒸留時に反映: concepts・`kasane/concepts/core/core-model/collection-paging.md` — 「色を指定する設定は持たない」の記述を、色の設定 (`loadingIndicatorColor`)・効く範囲 (既定の 2 つの読み込み中と Pull to Refresh。差し替えた表示には効かない)・指定しないときの色・Android の下地の扱いの説明に改める

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: core/ADR-0035 (proposed) — 読み込み中の表示の色は一覧の 1 つの設定でまとめて指定でき、指定しなければ各プラットフォームの標準の色のままにする (論点 1・論点 2)

## 未決の論点

なし。論点 1〜5 はすべて決定した (2026-10-04)。差し替えた表示に色を効かせない点は、提案の方向の確認でオーナーが了承した (`proposal.md` の What Changes)。

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

**M 級** (2026-10-04、オーナー確定)。proposal の domain は cross (core の契約と iOS・Android 双方の実装・両 Sample に触るため。ADR は core に置く)。

| 判定の材料 | この変更 |
|---|---|
| 触る能力の数 | 1 つ (ページングと Pull to Refresh の表示) |
| 公開 API の変更 | あり (各プラットフォームに設定を 1 つ追加。既存の API の変更・削除はなし) |
| 可逆性 | 高い (追加だけ・配布前。指定しない一覧の見え方は変わらない) |
| UI | 色だけ。新しい画面・配置の変更はなし。Sample は既存の色を指定するだけ |

「公開 API の小変更」に当たるため M。S 級 (提案なし) は、公開 API を足す変更が基準から外れるため採らない。

UI の見た目の基準: 提案で新しい mock を 2 案作り、テキスト副の案を承認した (`ui/brief.md` の承認モック)。

進行中のロードマップ `v1-foundation` との関係: 残るフェーズ (Sample と配布) のゴールとは重ならず、完了済みのページングのフェーズへの追加の変更として単独で進める。
