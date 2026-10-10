# 証跡: iOS の Skill と申し送りの突き合わせ (tasks グループ 5)

2026-10-10 に、design.md の Decision 2 の表の申し送りを、1 件ずつ iOS の Skill と突き合わせた結果。申し送りの出どころは `kasane/roadmaps/v1-foundation/phases/phase-7-3-user-docs/agenda.md`。パスはリポジトリのルートからの相対で書く。

「載せた場所」は、英語版 (`skills/en/kscollectionview-ios/`) の見出しで書く。日本語版 (`skills/ja/kscollectionview-ios/`) は、同じファイルの同じ順番の見出しに、同じ内容を持つ (見出しの対応は、末尾の表)。

## 5.7 申し送りを載せた場所

### `references/basics.md`

| 申し送り | 載せた場所 (見出し) |
|---|---|
| 不正入力のリリースビルドでの挙動 (core/ADR-0011) | 「What happens with invalid input」。iOS に当たる 9 種類を 1 つの表にまとめ、機能の側 (`layout.md`・`paging.md`・`images.md`) からはこの節を指す |
| iOS だけ: 親の状態を渡す指定 (ios/ADR-0008) | 「Read parent state inside a row」。Android には対応する指定が無いことも、この節に書いた |
| iOS だけ: セルの再利用で内部の状態が残らないこと (ios/ADR-0002) | 「Keep state that must survive scrolling in your model」 |
| iOS だけ: 表示中にキーパスやテンプレートの登録を差し替えても反映されないこと (ios/ADR-0006) | 「Update the list by replacing the array」の約束ごと |

### `references/layout.md`

| 申し送り (phase-4) | 載せた場所 (見出し) |
|---|---|
| グループの宣言と、同じグループの項目を続けて並べる責任 | 「Group items under group headers」(利用する側の責任の段) |
| 全画面に広げた一覧の安全領域 (ルートのヘッダーは被ってよく、空きは利用者が作る。ライブラリが合わせるのは固定中の見出しだけ) | 「Place the list full screen under the bars」 |
| Android のグループの値の型 (Bundle に入る型) | iOS には手順として載せない (Android だけに当たる)。「Group items under group headers」の約束ごとに、Android にはこの制限があり iOS には無いことを 1 文で書いた |
| グループの値の取り出し方の切り替え | 「Group items under group headers」(保証することの段と、キーを切り替える例) |

### `references/paging.md`

| 申し送り (phase-5) | 載せた場所 (見出し) |
|---|---|
| 項目があるときの取り直しの失敗は失敗の状態にせず元に戻し、知らせはアプリが出す | 「Write the model that owns the paging state」の表、「Add pull to refresh」の約束ごと |
| 最初の読み込みはライブラリが頼む。続きありのまま空のページで待機に戻すと頼み続ける | 「Write the model that owns the paging state」の表 (1 行目・5 行目)、「Add paging to a list」の状態の表 |
| 失敗・終端・空は既定で出ない | 「Show the loading, failure, end, and empty displays」の既定の動き |
| 続きのページが同じグループの値で始まればそのグループが伸びる。並び順は利用者の責任 | 「Write the model that owns the paging state」の表 (最後の行) |
| 状態と配列は同じ回に書く。戻る前に追加読み込み中にする。自分で取り直すときは古い読み込みの結果を捨てる | 「Write the model that owns the paging state」の表 (3・4・7 行目) と、モデルの例 |
| VM が自分で始める取り直しを先頭から見せる書き方 | 「Reload from your own code」 |
| 差し替えた「次のページの読み込み中」の表示のタッチ | 「Show the loading, failure, end, and empty displays」のタッチの段 |
| Pull to Refresh の取り直しの間にスクロールして失敗したときの位置 (iOS は先頭へ戻り、Android は残る) | 「Add pull to refresh」の約束ごと |
| Android では `onLoadMore` / `onRefresh` が投げた例外をライブラリは握りつぶさない | iOS には手順として載せない (Android だけに当たる)。「Add paging to a list」に、iOS の `onLoadMore` は投げられない型であることと、Android との差を 1 文で書いた |

### `references/reorder.md`

| 申し送り (phase-6) | 載せた場所 (見出し) |
|---|---|
| 受け入れたら配列を並べ替えて渡す。保存の失敗は元の並びの配列を渡し直す | 「Apply the move to your array」の約束ごとと、保存の例 |
| 行き先は項目で届く。行き先の項目が消えていたら受け入れない | 「Apply the move to your array」 |
| グループをまたぐときはグループの値を書き換える。空のグループへは移せない。宣言を付け外しできる画面での書き換え | 「Move items across groups」 |
| 「ここに置けるか」は軽い同期の判定にする | 「Limit what can move and where it can be dropped」 |
| スイッチが有効の間は長押しの知らせが呼ばれない | 「Turn on reordering」 |
| 読み上げの移動操作は文言を渡さないと出ない。iOS は行の組み立ての負荷が増える | 「Offer move actions to VoiceOver users」 |
| ドラッグ中に届いた配列は指を離すまで表示に出ず、追加読み込みも始まらない | 「Know what is held back during a drag」 |
| ソート中の 2 つの書き方 | 「Reorder a list that is sorted」 |
| 両プラットフォームで動きが違う点 | 「Know how the drag behaves on iOS」(iOS の動きの表の各行に、Android の動きを括弧で添えた) |
| Android は、テンプレートの根が背景を塗らないと持ち上げた項目の影が透ける | iOS には載せない (Android だけに当たる) |

### `references/images.md`

| 申し送り (phase-8) | 載せた場所 (見出し) |
|---|---|
| 先読みに宣言する URL (サムネイル用途の寸法の URL) | 「Prefetch the images of items about to appear」の約束ごと |
| iOS のディスクキャッシュ (起動時に 1 度呼ぶ。delegate を使うアプリは自分でパイプラインを組む) | 「Enable the disk cache at launch」。Android には要らないことも、この節に書いた |
| iOS の `remove` (消したソースはローダー付属ビューとキャッシュを共有しなくなる) | 「Use Nuke's own views next to KsImage」 |
| Android のキャッシュ操作 (androidx.startup の初期化が前提) | iOS には載せない (Android だけに当たる) |
| 先読みの幅 | 「Give the prefetch a display width」 |
| 任意キー | 「Use a key for images whose URL changes」 |
| キー付きの画像の削除とローダー付属ビュー | 「Clear or remove cached images」の約束ごと、「Use Nuke's own views next to KsImage」 |

## 5.7 両プラットフォームで動きが違う機能と、差を書いた場所

| 機能 | 差を書いた場所 (ファイル・見出し) |
|---|---|
| 並べ替えの動き | `references/reorder.md`「Know how the drag behaves on iOS」 |
| Pull to Refresh が失敗したときの位置 | `references/paging.md`「Add pull to refresh」 |
| 親の状態を渡す指定 (iOS だけ) | `references/basics.md`「Read parent state inside a row」 |
| テンプレートの登録の書き方 (`KsTemplate` の型は iOS だけ) | `references/basics.md`「Switch templates by item type」 |
| タッチ中の色の濃さの決まり方 | `references/basics.md`「Handle taps and long taps」 |
| 末尾へのスクロール命令の行き先 | `references/basics.md`「Scroll from code」の命令の表 |
| グループの値の型の制限 (Android だけ) | `references/layout.md`「Group items under group headers」 |
| 処理が投げる例外の扱い | `references/paging.md`「Add paging to a list」 |
| 色を指定した Pull to Refresh のインジケータ | `references/paging.md`「Color the loading indicators」 |
| 実行中の処理が取り消される時機 | `references/paging.md`「Know when a running load is cancelled」 |
| ディスクキャッシュの有効化 (iOS だけ) | `references/images.md`「Enable the disk cache at launch」 |

差をまとめた節は作っていない。Android の Skill には、名前 (`kscollectionview-android`) だけで触れた (`SKILL.md` の冒頭の段落の 1 か所。リンクは無い)。Kotlin のコードブロックは無い。

## 見出しの対応 (英語版と日本語版)

| ファイル | 英語版の見出し | 日本語版の見出し |
|---|---|---|
| `SKILL.md` | KsCollectionView for iOS / What you can do / Setup / Minimal working example / References | KsCollectionView for iOS / できること / 導入 / 最小の動く例 / リファレンス |
| `references/basics.md` | Showing a list / Show an array of items / Switch templates by item type / Update the list by replacing the array / Read parent state inside a row / Keep state that must survive scrolling in your model / Handle taps and long taps / Scroll from code / What happens with invalid input | 一覧を出す / 配列を表示する / 項目の種類でテンプレートを切り替える / 配列を差し替えて一覧を更新する / 行の中で親の状態を読む / スクロールしても残したい状態はモデルに持たせる / タップと長押しを受ける / コードからスクロールする / 不正な入力を渡したとき |
| `references/layout.md` | Layout and appearance / Choose a list or a grid / Set spacing and content padding / Show, hide, or color the list separators / Add a header and a footer for the whole collection / Group items under group headers / Place the list full screen under the bars / Know how cells are sized and placed / Know what the scroll indicator does | 並べ方と見た目 / リストかグリッドかを選ぶ / 間隔と内側の余白を決める / リストの区切り線を出す・消す・色を変える / 全体のヘッダーとフッターを付ける / 項目をグループに分けて見出しを付ける / バーの裏まで全画面に広げる / セルの大きさと置かれ方を知る / スクロールインジケータの動きを知る |
| `references/paging.md` | Paging and pull to refresh / Add paging to a list / Write the model that owns the paging state / Show the loading, failure, end, and empty displays / Add pull to refresh / Reload from your own code / Color the loading indicators / Place a paged list full screen under the bars / Know when a running load is cancelled | ページングと Pull to Refresh / 一覧にページングを付ける / ページングの状態を持つモデルを書く / 読み込み中・失敗・終端・空の表示を出す / Pull to Refresh を付ける / 自分のコードから読み込み直す / 読み込み中の表示の色を決める / ページングを付けた一覧を、バーの裏まで全画面に広げる / 実行中の読み込みが取り消される時機を知る |
| `references/reorder.md` | Reordering by drag and drop / Turn on reordering / Apply the move to your array / Move items across groups / Limit what can move and where it can be dropped / Offer move actions to VoiceOver users / Reorder a list that is sorted / Know what is held back during a drag / Know how the drag behaves on iOS | 並べ替え / 並べ替えを有効にする / 移動の内容を配列に当てはめる / グループをまたいで動かす / 動かせる項目と置ける場所を限る / VoiceOver に移動の操作を出す / ソートしている一覧を並べ替える / ドラッグ中に保留されるものを知る / iOS でのドラッグの動きを知る |
| `references/images.md` | Images / Show an image in a cell / Prefetch the images of items about to appear / Give the prefetch a display width / Use a key for images whose URL changes / Enable the disk cache at launch / Clear or remove cached images / Use Nuke's own views next to KsImage | 画像 / セルに画像を表示する / もうすぐ表示される項目の画像を先読みする / 先読みに表示の幅を伝える / URL が変わる画像にキーを使う / 起動時にディスクキャッシュを有効にする / キャッシュした画像を消す / Nuke 自身の View を KsImage と並べて使う |

どのファイルも、見出しは `#` が 1 つと、その下の `##` だけである (`###` は使っていない)。

## 流した確認

| 確認 | コマンド | 結果 |
|---|---|---|
| Skill 自身の整合 | `python3 scripts/ci/check-skills.py .` | 終了コード 0。「違反なし (Skill 2 つ・Markdown 12 枚)」。Skill 2 つは、iOS の英語版と日本語版である |
| インストール例 | `python3 scripts/ci/check-readme-examples.py .` | 終了コード 1。違反は 2 件で、どちらも Android の `SKILL.md` (英語版・日本語版) が無いことである。iOS の `SKILL.md` に由来する違反は無い |
| スクリプトのテスト | `python3 scripts/ci/run-tests.py` | 実行 385 件 / 失敗 0 件 / スキップ 0 件 |

## コード例のビルド (spec の求めではない、手元の確認)

リポジトリの外の作業用のディレクトリに、`ios/` の `Package.swift` と `Sources/` の写しを `KsCollectionView-SPM` という名前で置き、それに依存する作業用の Swift パッケージを作った。英語版の 6 枚から Swift のコードブロックを取り出し、1 枚を 1 つの target にして (先頭に `import SwiftUI` と `import KsCollectionView` を足して) ビルドした。リポジトリのファイルは変えていない。Simulator は起動していない (行き先を機種を決めない形にしてビルドしただけである)。

| 項目 | 値 |
|---|---|
| ビルドしたコードブロック | 35 個 (`SKILL.md` 1・`basics.md` 7・`layout.md` 9・`paging.md` 7・`reorder.md` 4・`images.md` 7)。日本語版のコードブロックは、検査が英語版と同じ内容だと確かめている |
| ビルドしていないコードブロック | 2 個。`SKILL.md` のインストール例 (マニフェストの一部で、単独ではコンパイルできない。値は検査が利用者役と比べている) と、`paging.md` の発火の条件の式 (Swift ではない) |
| Swift 6 の言語モード | `xcodebuild -scheme SkillExamples -destination 'generic/platform=iOS Simulator' build` が `** BUILD SUCCEEDED **`。例のソースに由来する警告は無い |
| Swift 5 の言語モード | 行き先を `generic/platform=iOS` にした同じビルドが `** BUILD SUCCEEDED **`。例のソースに由来する警告は無い |
| 道具 | Xcode 27.0 (Build version 27A266a)。deployment target は iOS 16 |
| ビルドが例のソースを読んでいることの確かめ | 存在しない modifier を呼ぶファイルを 1 つ足すと `** BUILD FAILED **` になり、消すと成功に戻った |
| 文面の主張の確かめ | ラベルの無い末尾クロージャ 1 つの `KsImage(source) { ... }` は、`ambiguous use of 'init'` でコンパイルできない (`images.md` の約束ごとのとおり) |

確かめたのはコンパイルが通ることだけで、例を起動して動きを見てはいない。本文の中に書いた 1 行の断片 (`KsCollectionView(entries, id: \.entryId, template: \.kind) { ... }` と `.reorder(isEnabled: model.isReordering && !model.isSorted) { ... }`) は、ビルドしていない。

## 公開の宣言の名前 (手元の数え上げ。網羅の道具はグループ 9)

`ios/Sources/` の `public` の宣言の行と、`public` の enum の case から、計測用の印の付いたものを除いて名前を拾うと 83 個だった。英語版と日本語版のどちらにも現れない名前は、次の 2 個である。どちらも result builder (`KsTemplateBuilder`) が持つ組み立て用の関数で、利用者が呼ぶことは無い。載せない名前の候補として、指揮側に渡す。

- `buildExpression`
- `buildBlock`
