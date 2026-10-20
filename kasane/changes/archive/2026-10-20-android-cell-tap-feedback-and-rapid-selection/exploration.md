# Exploration: android-cell-tap-feedback-and-rapid-selection

## 課題 / 動機
起票元: ../ColorAnalyzer/kasane/roadmaps/kmp-migration/autopilot-log.md

ColorAnalyzer の KMP 移植 (ksn-autopilot の kmp-migration、phase-10-library-traditional、2026-10-20) で、Android 版 0.1.0-beta.1 の一覧のセルのタップまわりに 2 つの事象が見つかった。どちらもアプリ側に回避のコードは無い。

### 1. 押した直後に灰色の押下の帯が一瞬残る

- ColorAnalyzer は、押したときの反応を消すつもりで `touchFeedbackColor = Color.Transparent` を渡している (`../ColorAnalyzer/kmp/androidApp/src/main/kotlin/jp/kamusoft/coloranalyzer/ui/library/TraditionalListScreen.kt:129`・`PatternListScreen.kt:104` など)
- それでも、押した直後に灰色の帯が一瞬見える

調査 (2026-10-20): 原因は確定した。ライブラリの不具合ではなく、決めたとおりの動き。

- Android 版は、渡された色をそのまま標準の波紋に渡す (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:452`)
- 標準の波紋は、渡した色の不透明度を捨てて標準の濃さで塗る (core/ADR-0037 の前提。実測で確認済み)。`Color.Transparent` は不透明度 0 の黒なので、黒が標準の濃さで塗られて灰色になる
- iOS 版は渡した色を不透明度ごとそのまま塗る (`ios/Sources/KsCollectionView/KsHostingCell.swift` の `configureTouchFeedback`)。透明を渡すと何も見えない
- つまり同じ値で iOS は反応が消え、Android は消えない。Android には反応を消す手段が無い

### 2. 連続で速く押すと 2 回目の選択が効かないことがある

- 一覧のセルを続けて速くタップすると、2 回目のタップの選択が届かないことがある
- ColorAnalyzer の押したときの処理 (`../ColorAnalyzer/kmp/shared/src/commonMain/kotlin/jp/kamusoft/coloranalyzer/presentation/presenters/library/TraditionalListPresenter.kt:187`) は、選択モードなら選択を切り替え、選択モードでなければ詳細の画面へ進む。連打を間引く処理は無い
- ライブラリ側の押したときの処理は、標準の部品 (`combinedClickable`) 1 つだけで、ダブルタップを待つ設定 (`onDoubleClick`) は無い (`KsCollectionView.kt:815`)
- コードを読むだけでは、落ちる場所の見当がつかなかった

再現 (2026-10-20、作業用の Android 16 エミュレータ・Sample に仮の計測の画面を足して。仮のコードとエミュレータは後で消した):

- 指が動かないきれいなタップでは再現しなかった。約 1,100 回で、一覧に届いた 2 回目の down はすべて onItemTap に届いた。間隔は約 60〜750ms。次の条件のどれでも同じだった
  - items が変わる / 変わらない
  - 同じセル / 違うセル
  - リスト / グリッド
  - 長押しの処理のあり / なし
  - アプリと同じ形 (グリッド 3 列・paging・footer・`Color.Transparent`)
  - 実際の入力の経路 (`adb shell input tap`)
- 再現したのは、1 回目のタップで指がタッチスロップ (8dp) より動いた場合だけ。その後 0.3〜0.5 秒ほどは、2 回目のきれいなタップも落ちた (40px 動かしたとき、間隔 100〜300ms で 10 回中 7〜10 回)。スロップ未満 (15px) なら落ちなかった
- ライブラリを使わない LazyVerticalGrid + combinedClickable でも同じように落ちた (間隔 100〜500ms で 10 回中 3〜8 回)。ライブラリの不具合ではない
- 落ちる仕組み: 1 回目に指が動くと、一覧の先頭なら端が伸び、途中なら少しスクロールして慣性で流れる。その動きの間に来た down は、Compose の標準のスクロールの処理が「動きを止める操作」として先に消費する (foundation 1.11.4 の `DragGestureNode`。スクロール中か端の伸びの最中なら down を消費する)。消費済みの down はセルのタップの処理 (`combinedClickable`) が受け付けないので、onItemTap は呼ばれない。動いている一覧へのタップを「止める」として扱うのは、Android の一覧の標準の動き
- ライブラリが自分でスクロールを動かして 2 回目を落とす経路 (位置を保つ処理など) は見つからなかった
- 推測 (確かめていない): ColorAnalyzer の症状は、速く連打したときの指のぶれか、直前のスクロールの慣性や端の伸びが残っていることによる可能性が高い。実機の ColorAnalyzer では観測していない。開発者向けオプションの「ポインタの位置」でタップ中の指の動きを見れば確かめられる

## 検討した選択肢 (却下案と理由を含む)

### 論点 1: 押したときの反応を消す方法

- **A: 完全に透明な色を渡したら、Android でも反応を出さない** (採用): 公開 API を変えずに済み、iOS と同じ値で同じ結果になる。ColorAnalyzer の今のコードのままで直る。core/ADR-0037 の「不透明度は使わない」に例外が 1 つできる
- **B: 反応を消す専用の設定を両プラットフォームに足す** (却下): 色と反応を出すかどうかを別々に指定できるが、両プラットフォームの公開 API が増える (M 級)。iOS ではすでに透明で消せるので、A でも意味は通る

### 論点 3: この change で何を直すか

- **事象 1 だけを直し、事象 2 は対象外として記録する** (採用): 事象 2 はライブラリの不具合ではなく、動いている一覧へのタップを「止める」として扱う Android の一覧の標準の動き。標準のまま、ほかの一覧と同じ動きを保てる
- **事象 2 もライブラリで直す** (却下): 動いている最中でもタップが選択として届くようになるが、慣性を止めるつもりのタップで選択が切り替わる。Compose の標準のスクロールの処理を迂回することになり、重く壊れやすい

## 決定事項

- 論点 1: A を採る。Android は、完全に透明な色 (不透明度 0) を受け取ったときだけ標準の波紋に渡さず、押したときの反応を出さない。押したときの処理 (タップ・長押しの知らせ) はそのまま届く。iOS のコードは変えない
- 論点 3: この change で直すのは事象 1 だけ。事象 2 (速く続けて押すと 2 回目が効かない) はライブラリを変えず、調べた結果をこのメモに残すだけにする
- 「完全に透明」は不透明度がちょうど 0 の色に限る。ほとんど透明な色は今までどおり標準の濃さの波紋になる
- 実装時に追記 (2026-10-20): Compose の `Color.Unspecified` は不透明度が 0 だが「色を指定しない」ことを表す値なので、完全に透明な色として扱わず、今までどおり標準の波紋を出す
- 蒸留時に反映: concepts の操作契約 (`kasane/concepts/core/core-model/collection-interaction.md`) — 完全に透明な色を渡すと両プラットフォームで反応が出ないこと
- 蒸留時に反映: core/ADR-0037 の frontmatter に `amended-by: 0038` を足し、core の index の 0037 の行に「一部改訂: 0038」を書く。android/ADR-0003 の footer の関連に core/ADR-0038 を足す

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: core/ADR-0038 (タップしたときの色に完全に透明な色を渡したら、両プラットフォームとも反応を出さない。amends core/ADR-0037。proposed)

## 未決の論点

- なし

## UI 素材 (ui/references/ の一覧と注釈)

なし

## 変更級の推奨: S (Android の 1 能力 (タップの反応) の中の局所的な挙動の修正。公開 API は変えず、KDoc に完全に透明な色の扱いを足すだけ。iOS のコードは変えない。可逆。見た目の基準は「反応が出ない」で、モックは要らない)
