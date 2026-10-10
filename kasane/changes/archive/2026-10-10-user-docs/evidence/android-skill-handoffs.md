# 証跡: Android の Skill と申し送りの突き合わせ (tasks グループ 6)

2026-10-10 に、design.md の Decision 2 の表の申し送りを、1 件ずつ Android の Skill と突き合わせた結果。申し送りの出どころは `kasane/roadmaps/v1-foundation/phases/phase-7-3-user-docs/agenda.md`。パスはリポジトリのルートからの相対で書く。

「載せた場所」は、英語版 (`skills/en/kscollectionview-android/`) の見出しで書く。日本語版 (`skills/ja/kscollectionview-android/`) は、同じファイルの同じ順番の見出しに、同じ内容を持つ (見出しの対応は、末尾の表)。

## 6.7 申し送りを載せた場所

### `references/basics.md`

| 申し送り | 載せた場所 (見出し) |
|---|---|
| 不正入力のリリースビルドでの挙動 (core/ADR-0011) | 「What happens with invalid input」。Android に当たる 14 種類を 1 つの表にまとめ、機能の側 (`layout.md`・`paging.md`・`images.md`) からはこの節を指す。デバッグビルドの判定 (アプリがデバッグ可能か)・停止の形 (例外)・警告の出る先 (Logcat のタグ) も、この節に書いた |
| iOS だけ: 親の状態を渡す指定 (ios/ADR-0008) | Android には手順として載せない (Android には対応する指定が無い)。「Read parent state inside a row」に、Android では宣言するものが無いことと、iOS では専用の modifier が要ることを 1 文で書いた。iOS の modifier の名前とコードは書いていない |
| iOS だけ: セルの再利用で内部の状態が残らないこと (ios/ADR-0002) | 出どころの決定は iOS のものだが、Android にも同じ契約がある (源泉の `core/core-model/collection-items.md` の「してはいけないこと」。画面の外へ出た行の `remember` は捨てられる)。「Keep state that must survive scrolling in your model」に、Android の言葉で載せた |
| iOS だけ: 表示中にキーパスやテンプレートの登録を差し替えても反映されないこと (ios/ADR-0006) | 出どころの決定は iOS のものだが、Android でも「表示中に差し替えない」が契約である (源泉の同じ節)。「Update the list by replacing the array」の約束ごとと、「Switch templates by item type」の約束ごと (ブロックは毎回同じ集合を宣言する) に載せた |

### `references/layout.md`

| 申し送り (phase-4) | 載せた場所 (見出し) |
|---|---|
| グループの宣言と、同じグループの項目を続けて並べる責任 | 「Group items under group headers」(利用する側の責任の段) |
| 全画面に広げた一覧の安全領域 (ルートのヘッダーは被ってよく、空きは利用者が作る。ライブラリが合わせるのは固定中の見出しだけ) | 「Place the list full screen under the bars」。祖先が消費した insets を除くことと、実際に重なっている分だけを使うことも、この節に書いた |
| Android のグループの値の型 (Bundle に入る型) | 「Group items under group headers」(利用する側の責任の段の 3 つ目)。違反のときの動きは `basics.md`「What happens with invalid input」の表 |
| グループの値の取り出し方の切り替え | 「Group items under group headers」(保証することの段と、グループ分けを切り替える例) |

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
| Android では `onLoadMore` / `onRefresh` が投げた例外をライブラリは握りつぶさない | 「Add paging to a list」の箇条書き (`onLoadMore` の型と例外の伝わり方)、「Write the model that owns the paging state」の表 (8 行目。捕まえる例外を絞り、取り消しを失敗にしない) |

### `references/reorder.md`

| 申し送り (phase-6) | 載せた場所 (見出し) |
|---|---|
| 受け入れたら配列を並べ替えて渡す。保存の失敗は元の並びの配列を渡し直す | 「Apply the move to your array」の約束ごとと、保存の例 |
| 行き先は項目で届く。行き先の項目が消えていたら受け入れない | 「Apply the move to your array」 |
| グループをまたぐときはグループの値を書き換える。空のグループへは移せない。宣言を付け外しできる画面での書き換え | 「Move items across groups」 |
| 「ここに置けるか」は軽い同期の判定にする | 「Limit what can move and where it can be dropped」 |
| スイッチが有効の間は長押しの知らせが呼ばれない | 「Turn on reordering」 |
| 読み上げの移動操作は文言を渡さないと出ない | 「Offer move actions to TalkBack users」 |
| (同じ申し送りのうち) iOS は行の組み立ての負荷が増える | Android には載せない (iOS だけに当たる) |
| ドラッグ中に届いた配列は指を離すまで表示に出ず、追加読み込みも始まらない | 「Know what is held back during a drag」 |
| ソート中の 2 つの書き方 | 「Reorder a list that is sorted」 |
| 両プラットフォームで動きが違う点 | 「Know how the drag behaves on Android」(Android の動きの表の各行に、iOS の動きを括弧で添えた) |
| Android は、テンプレートの根が背景を塗らないと持ち上げた項目の影が透ける | 「Turn on reordering」の最後の段と、「Know how the drag behaves on Android」の表の最後の行 |

### `references/images.md`

| 申し送り (phase-8) | 載せた場所 (見出し) |
|---|---|
| 先読みに宣言する URL (サムネイル用途の寸法の URL) | 「Prefetch the images of items about to appear」の約束ごと |
| iOS のディスクキャッシュ (起動時に 1 度呼ぶ。delegate を使うアプリは自分でパイプラインを組む) | Android には手順として載せない (iOS だけに当たる)。「Prefetch the images of items about to appear」の保証することに、Android では準備が要らないことと、iOS では起動時に有効にする必要があることを 1 文で書いた |
| iOS の `remove` (消したソースはローダー付属ビューとキャッシュを共有しなくなる) | Android には載せない (iOS だけに当たる) |
| Android のキャッシュ操作 (androidx.startup の初期化が前提) | 「Clear or remove cached images」の約束ごとの 1 つ目。`SKILL.md` の「Setup」にも、provider を取り除かないことを書いた |
| 先読みの幅 | 「Give the prefetch a display width」 |
| 任意キー | 「Use a key for images whose URL changes」 |
| キー付きの画像の削除とローダー付属ビュー | 「Clear or remove cached images」の約束ごと、「Use Coil's own composables next to KsImage」 |

## 6.7 両プラットフォームで動きが違う機能と、差を書いた場所

| 機能 | 差を書いた場所 (ファイル・見出し) |
|---|---|
| 並べ替えの動き | `references/reorder.md`「Know how the drag behaves on Android」 |
| Pull to Refresh が失敗したときの位置 | `references/paging.md`「Add pull to refresh」 |
| 親の状態を渡す指定 (iOS だけ) | `references/basics.md`「Read parent state inside a row」 |
| テンプレートの登録の書き方 (`KsTemplate` の型は iOS だけ) | `references/basics.md`「Switch templates by item type」 |
| タッチ中の色の濃さの決まり方 | `references/basics.md`「Handle taps and long taps」 |
| 末尾へのスクロール命令の行き先 | `references/basics.md`「Scroll from code」の命令の表 |
| グループの値の型の制限 (Android だけ) | `references/layout.md`「Group items under group headers」 |
| 処理が投げる例外の扱い | `references/paging.md`「Add paging to a list」 |
| 色を指定した Pull to Refresh のインジケータ | `references/paging.md`「Color the loading indicators」 |
| 実行中の処理が取り消される時機 | `references/paging.md`「Know when a running load is cancelled」 |
| ディスクキャッシュの有効化 (iOS だけ) | `references/images.md`「Prefetch the images of items about to appear」 |

差をまとめた節は作っていない。iOS の Skill には、名前 (`kscollectionview-ios`) だけで触れた (`SKILL.md` の冒頭の段落の 1 か所。リンクは無い)。Swift のコードブロックは無い。

## iOS の Skill と見出しが違うところ

5 枚の分け方と、`SKILL.md` の 5 つの節は同じである。`references/` の見出しは、次の 3 か所だけが違う。

| ファイル | iOS | Android | 理由 |
|---|---|---|---|
| `references/reorder.md` | Offer move actions to VoiceOver users | Offer move actions to TalkBack users | 読み上げの機能の名前がプラットフォームで違う |
| `references/reorder.md` | Know how the drag behaves on iOS | Know how the drag behaves on Android | 自分のプラットフォームの動きを書く節である |
| `references/images.md` | Enable the disk cache at launch / Use Nuke's own views next to KsImage | (前者は無い) / Use Coil's own composables next to KsImage | ディスクキャッシュの有効化は iOS だけの手順である。ローダーは Android では Coil である |

## 見出しの対応 (英語版と日本語版)

| ファイル | 英語版の見出し | 日本語版の見出し |
|---|---|---|
| `SKILL.md` | KsCollectionView for Android / What you can do / Setup / Minimal working example / References | KsCollectionView for Android / できること / 導入 / 最小の動く例 / リファレンス |
| `references/basics.md` | Showing a list / Show an array of items / Switch templates by item type / Update the list by replacing the array / Read parent state inside a row / Keep state that must survive scrolling in your model / Handle taps and long taps / Scroll from code / What happens with invalid input | 一覧を出す / 配列を表示する / 項目の種類でテンプレートを切り替える / 配列を差し替えて一覧を更新する / 行の中で親の状態を読む / スクロールしても残したい状態はモデルに持たせる / タップと長押しを受ける / コードからスクロールする / 不正な入力を渡したとき |
| `references/layout.md` | Layout and appearance / Choose a list or a grid / Set spacing and content padding / Show, hide, or color the list separators / Add a header and a footer for the whole collection / Group items under group headers / Place the list full screen under the bars / Know how cells are sized and placed / Know what the scroll indicator does | 並べ方と見た目 / リストかグリッドかを選ぶ / 間隔と内側の余白を決める / リストの区切り線を出す・消す・色を変える / 全体のヘッダーとフッターを付ける / 項目をグループに分けて見出しを付ける / バーの裏まで全画面に広げる / セルの大きさと置かれ方を知る / スクロールインジケータの動きを知る |
| `references/paging.md` | Paging and pull to refresh / Add paging to a list / Write the model that owns the paging state / Show the loading, failure, end, and empty displays / Add pull to refresh / Reload from your own code / Color the loading indicators / Place a paged list full screen under the bars / Know when a running load is cancelled | ページングと Pull to Refresh / 一覧にページングを付ける / ページングの状態を持つモデルを書く / 読み込み中・失敗・終端・空の表示を出す / Pull to Refresh を付ける / 自分のコードから読み込み直す / 読み込み中の表示の色を決める / ページングを付けた一覧を、バーの裏まで全画面に広げる / 実行中の読み込みが取り消される時機を知る |
| `references/reorder.md` | Reordering by drag and drop / Turn on reordering / Apply the move to your array / Move items across groups / Limit what can move and where it can be dropped / Offer move actions to TalkBack users / Reorder a list that is sorted / Know what is held back during a drag / Know how the drag behaves on Android | 並べ替え / 並べ替えを有効にする / 移動の内容を配列に当てはめる / グループをまたいで動かす / 動かせる項目と置ける場所を限る / TalkBack に移動の操作を出す / ソートしている一覧を並べ替える / ドラッグ中に保留されるものを知る / Android でのドラッグの動きを知る |
| `references/images.md` | Images / Show an image in a cell / Prefetch the images of items about to appear / Give the prefetch a display width / Use a key for images whose URL changes / Clear or remove cached images / Use Coil's own composables next to KsImage | 画像 / セルに画像を表示する / もうすぐ表示される項目の画像を先読みする / 先読みに表示の幅を伝える / URL が変わる画像にキーを使う / キャッシュした画像を消す / Coil 自身の Composable を KsImage と並べて使う |

どのファイルも、見出しは `#` が 1 つと、その下の `##` だけである (`###` は使っていない)。

## 流した確認

| 確認 | コマンド | 結果 |
|---|---|---|
| Skill 自身の整合 | `python3 scripts/ci/check-skills.py .` | 終了コード 0。「違反なし (Skill 4 つ・Markdown 24 枚)」 |
| インストール例 | `python3 scripts/ci/check-readme-examples.py .` | 終了コード 0。「違反なし (一致した最小コード例 4 つ・確かめた依存の宣言の行 12 行)」 |
| スクリプトのテスト | `python3 scripts/ci/run-tests.py` | 実行 385 件 / 失敗 0 件 / スキップ 0 件 |

## コード例のビルド (spec の求めではない、手元の確認)

リポジトリの外の作業用のディレクトリに、`android/` と `verification/android/` の写しを置いた (ビルドの出力のディレクトリは写していない)。写しの本体を、作業用の Maven のディレクトリへ発行し (`:kscollectionview:publishToMavenLocal`。発行先は Maven のシステムプロパティで作業用のディレクトリに向けた)、写しの利用者の立場のアプリから、利用者と同じ 1 行の依存で取った。写しのアプリには、例が使う Material 3 への依存を 1 行足した。英語版の `references/` の 5 枚から Kotlin のコードブロックを取り出し、1 枚を 1 つのファイルにして (先頭に package の宣言と import を足して) 写しのアプリのソースに置き、コンパイルした。リポジトリのファイルは変えていない。エミュレータと実機は使っていない (コンパイルしただけである)。

| 項目 | 値 |
|---|---|
| ビルドしたコードブロック | 32 個 (`basics.md` 6・`layout.md` 9・`paging.md` 7・`reorder.md` 4・`images.md` 6)。日本語版のコードブロックは、検査が英語版と同じ内容だと確かめている |
| 別の確認でビルドしているコードブロック | 1 個。`SKILL.md` の最小の動く例は、利用者の立場のアプリの画面のファイルと同じ内容で (7.2 の突き合わせ)、そのファイルは写しのアプリの一部として一緒にコンパイルされている |
| ビルドしていないコードブロック | 2 個。`SKILL.md` のインストール例 (ビルドの定義の一部で、単独ではコンパイルできない。値は検査が比べている) と、`paging.md` の発火の条件の式 (Kotlin ではない) |
| コマンドと結果 | 写しのアプリで `:app:compileDebugKotlin` が終了コード 0 |
| 道具 | Gradle 9.7.0・Android Gradle Plugin 9.4.0・Kotlin 2.4.10 (本体のバージョンカタログの値)・JDK 21。`compileSdk` は 36 |
| ビルドが例のソースを読んでいることの確かめ | 存在しないメソッドを呼ぶファイルを 1 つ足すと `Unresolved reference` でビルドが失敗し、消すと成功に戻った |
| 文面の主張の確かめ | Coil を依存に書かずに `coil3.compose.AsyncImage` を呼ぶファイルがコンパイルできた (`images.md` の「Use Coil's own composables next to KsImage」)。`KsReorderMove("a", KsReorderDestination.Before("b"), null)` がコンパイルできた (`reorder.md` の、公開のコンストラクタの記述)。本文の 1 行の断片 `enabled = model.isReordering && !model.isSorted` を `KsReorder` の引数に書いた形もコンパイルできた |

確かめたのはコンパイルが通ることだけで、例を起動して動きを見てはいない。

## 公開の宣言の名前 (手元の数え上げ。網羅の道具はグループ 9)

`android/kscollectionview/src/main/` の `public` の宣言の行と、`public` の enum の値から名前を拾い、宣言の行に `public` を書いていない data class のプロパティ 5 個 (`columns`・`columnSpacing`・`portrait`・`landscape`・`minItemWidth`) を手で足すと、84 個だった。英語版と日本語版のどちらにも、84 個すべてが現れる。載せない名前の候補は無い。

拾い方は手元の簡易なもので、同じ行にコンストラクタのプロパティを持つ宣言 (`KsImageSource.File` の `file`・`KsImageSource.Resource` の `id`・`KsWidth.Fixed` の `width`) は拾えていない。この 3 個は、目で見て、Skill に現れることを確かめた (`width` は拾った名前にも含まれる)。
