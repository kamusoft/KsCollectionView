# 読ませる確認の指摘の結末 (タスク 10.2)

- 日付: 2026-10-10
- 入力: `dist-read-en-ios.md`・`dist-read-en-android.md`・`dist-read-ja-ios.md`・`dist-read-ja-android.md` の 4 枚
- 直したもの: `skills/{en,ja}/kscollectionview-{ios,android}/` の 24 枚。パスはリポジトリのルートからの相対で書く
- 直すときの決まり: 事実は、ライブラリのコードの実物を読んで確かめてから書いた。英語版と日本語版は、同じ回に同じ内容で直した。iOS と Android で同じ書き方の箇所は、両方を直した

## 番号の書き方

指摘の番号は、4 枚の記録の番号に、記録を表す前置きを付けて書く。

| 前置き | 記録 | 番号の数 |
|---|---|---|
| EI | `dist-read-en-ios.md` (英語版・iOS) | 49 |
| EA | `dist-read-en-android.md` (英語版・Android) | 51 |
| JI | `dist-read-ja-ios.md` (日本語版・iOS) | 58 |
| JA | `dist-read-ja-android.md` (日本語版・Android) | 53 |

`dist-read-en-ios.md` は、冒頭に「指摘 51 件」と書いているが、表にある番号は 49 個である (U1〜U10・M1〜M24・O1・O3・C1〜C11・N1・N2。O2 が無い)。ここでは、表にある 49 個のすべてに結末を付けた。件数の食い違いは、指揮側が記録を確かめる。

## 結末の数

「一部を直した」は、指摘のうち直せる部分を直し、残りを直さなかったもの。残りと理由は、下の各行に書いた。

| 記録 | 番号の数 | 直した | 一部を直した | 直さない |
|---|---|---|---|---|
| EI | 49 | 42 | 5 (U8・M5・M12・M17・N2) | 2 (M2・O1) |
| EA | 51 | 42 | 4 (M2・M12・N2・N6) | 5 (M1・M14・M20・D1・C4) |
| JI | 58 | 52 | 4 (2-18・3-7・3-8・4-2) | 2 (3-5・4-1) |
| JA | 53 | 46 | 4 (3-4・3-6・3-10・4-2) | 3 (3-20・4-1・5-10) |
| 合計 | 211 | 182 | 17 | 12 |

## 直さないもの

| 番号 | 指摘 | 直さない理由 |
|---|---|---|
| EI-O1・EA-M1・EA-D1・JI-4-1・JA-4-1 | `{version}` の具体の値が Skill に無く、Releases のページを見ないと分からない | 設計のとおり (インストール例に版を書かず `{version}` を置く決まり)。版の値を Skill に書くと、版が上がるたびに Skill が古くなる |
| EI-M2 | Package URL は配信用リポジトリなのに、版は本体のリポジトリの Releases で調べる。版の番号が同じか・タグの形が分からない | ルートの README にも配布の文書にも、2 つのリポジトリの版とタグの対応を決めた記述がまだ無い (公開の工程が決まっていない)。読めないことは書かない。指揮側が、公開の工程を決めるフェーズへ申し送る |
| EA-C4・JA-5-10 | 必要な環境の表の、Android Gradle Plugin の下限 8.6.0 と `compileSdk` 36 の組が疑わしい | この値は、ルートの README から写したもの。Skill の値は変えていない。指揮側が、検収でオーナーに諮る |
| EA-M14 | `content://` の URI の扱いが無い | コードから決められない。`KsImageSource.Remote` の `url` の文字列は、そのまま Coil に渡る。`content://` を渡したときの動きを、ライブラリは決めておらず、テストも無い |
| EA-M20 | 大きな配列の差分の計算がどこで走り、どのくらい掛かるかが無い | 掛かる時間は、コードからは決められない (実測が要る)。コードを書くのに要る事実でもない |
| JI-3-5 | 行の中の `@State` や、後から終わる読み込みで行の高さが変わったとき、セルが測り直されるか | コードから決められない。行の内側だけの変化での測り直しは、UIKit の自己サイズの仕組みに任せていて、ライブラリのコードに、保証として書ける決まりが無い。配列か観測する値を通した変化で高さが変わる場合は、今の本文のとおり |
| JA-3-20 | ページングの無い一覧での `onRefresh` の例が無い | 本文に「ページングの無い一覧でも使える」とあり、書き方は引数を 1 つ渡すだけである。例を足すと、1 枚が膨らむ |

## 直したもの (根ごと)

同じ根の指摘 (英語版と日本語版で同じ箇所・iOS と Android で同じ書き方) は、1 行にまとめた。「場所」のファイルは、英語版と日本語版の両方を指す。iOS は `skills/{en,ja}/kscollectionview-ios/`、Android は `skills/{en,ja}/kscollectionview-android/` の中のファイルである。

### 重大

| 番号 | 場所 | どう直したか |
|---|---|---|
| EI-C1・JI-5-1 | iOS `references/paging.md`「Write the model that owns the paging state」「Know when a running load is cancelled」 | 例の `FeedModel` の、取り消しの見分け方を変えた。`catch is CancellationError` と `error is CancellationError` をやめ、`isCancellation` という 1 つの関数に集めた。この関数は、最初に `Task.isCancelled` を見て (タスクが取り消された後に届いたエラーは、型によらず取り消しとして扱う)、次に `CancellationError` と、コードが `.cancelled` の `URLError` を見る。本文の「取り消された取得は、ふつう `CancellationError` を投げる」を、`URLSession` の `async` の関数が `URLError` を投げることと、ほかのクライアントにも独自のエラーがあることを書いた文に置き換えた。モデルが守る書き方の表に、取り消しを失敗にしない行を足した。作業用の置き場で、コンパイルできることを確かめた |
| (同じ種類の穴の確かめ) | Android `references/paging.md` | Android の例は、`CancellationException` を先に捕まえて投げ直しているので、コルーチンの取り消しは取りこぼさない。クライアントが、取り消された呼び出しを独自の型の例外で知らせる場合だけが残るので、表の該当の行に、その型も同じように扱う 1 文を足した |

### Skill の中の食い違い

| 番号 | 場所 | どう直したか |
|---|---|---|
| EA-C1 | 両プラットフォーム `references/basics.md`「Update the list by replacing the array」 | 「変えない」のは、ID やテンプレートのキーを取り出すキーパス・ラムダそのものと、登録したテンプレートの集合である、と書き直した。項目自身のテンプレートのキーが変わるのは構わない (セルごと置き換わる) ことを、同じ箇条に書いた |
| EA-C2 | 両プラットフォーム `references/reorder.md`「Apply the move to your array」「Reorder a list that is sorted」 | 「違う配列」を、「置いた時点で一覧が持っていた配列と等しくない配列」と書き、比べ方が値 (iOS は `==`、Android は `equals`) であることを書いた。ソートの節の冒頭を、コードの動きに合わせて書き直した (置く前と等しい配列が届く間は、項目は置いた位置のまま配列とずれ、次に違う配列が届くとソートの位置に表示される) |
| EI-C2・EA-C3・JI-5-6・JA-5-5 | 両プラットフォーム `references/basics.md`「What happens with invalid input」 | 冒頭の「項目を消さず」をやめ、「何が表示されるかは表のとおり」にした。ID の重複の行を、「後ろの要素だけを表示し、前の要素は表示しない」に直した (コードは、後勝ちで 1 件に畳む) |
| EI-C3・JI-5-4・JA-5-3 | 両プラットフォーム `references/paging.md` の状態の表と、位置の表 | 取り直し中の行に、「一覧がその状態で一度描かれた (コンポーズされた) 後なら」の条件を書き、「Reload from your own code」を指した |
| JA-5-1・JI-3-9 | 両プラットフォーム `references/paging.md`「Add paging to a list」 | 次を頼むまでの条件を、2 つがそろうこと (処理から戻ったこと・状態か配列が頼んだ時点と違う更新を一覧が受け取ったこと) として書き直した。待機・追加読み込み中・待機と移ったときは、配列が同じでも変わったものと数える (途中で一覧が追加読み込み中を受け取っている) ことと、空のページで待機のままにするモデルが頼まれ続けるのはこのためであることを書いた。判定し直す契機に、処理から戻ったときを足した |
| JI-5-3・JA-5-2 | 両プラットフォーム `references/paging.md` のモデルが守る書き方の表 (2 行目) | 「2 つの状態 (待機と失敗) で動かす」と書き直し、最初のページになる理由 (最後の項目の ID が無い) を例のコードに結び付けた。右の列を、守らなかった結果だけにした |
| EI-C4・EA-C5・JI-5-9・JA-5-4 | 両プラットフォーム `references/paging.md`「Defaults」 | 「少なくとも渡す」の文の直後に、後ろの例のどれが何を省いているかと、写すときは足すことを書いた。取り直しの失敗の知らせが、次の取り直しまで出たままであること (JI-5-9 の後半) も、約束ごとに書いた |
| EI-C5 | 両プラットフォーム `references/reorder.md`「Move items across groups」 | iOS は、グループの値が無いときの扱いが `.before` の場合の式と `.end` の場合の `else` の分岐の 2 か所にあることを、そのとおりに書いた (Android は、元から `?:` の後ろの値と書いてあり、合っている) |
| EI-C6・JI-5-7 | 両プラットフォーム `references/reorder.md`「Reorder a list that is sorted」 | 1 行の断片の `isSorted` が、自分のモデルが持つフラグのことで、このページのモデルには無いことを書いた |
| EI-C8 | 両プラットフォーム `references/basics.md`「Scroll from code」 | 「取りこぼされない」を、「つながっているコントローラに送った命令は、更新やアニメーションの途中だからという理由では失われない」にし、何も起こさない 2 種類の命令 (実行する時点で配列に無い ID・つながっていない間に送った命令) を、別の箇条に分けた。つながっていない間の命令は、後のために取っておかれないことも書いた |
| EI-C9・JI-5-5・JI-2-5 | iOS `references/basics.md`「Read parent state inside a row」 | 理由の段落と、`.observedValue` の無いときの箇条を、食い違わないように書き直した。無いときは、`body` が評価し直されるたびにセルを作り直す代わりの動きになること、それが届くのは、ほかの何かが `body` を評価し直させるときだけであること、同じ更新で配列も変わると届かない穴があること、を順に書いた |
| JA-5-6 | Android `references/layout.md`「Choose a list or a grid」 | 「変わるのは列数だけです」を消した |
| JA-5-7 | 両プラットフォーム `references/layout.md`「Place the list full screen under the bars」 | 「合わせるコンテンツは 1 つだけ」を、「スクロールするコンテンツのうち、合わせるものは 1 つだけ」にして、重ねる表示と区別した |
| EA-C6・JA-5-9 | Android `SKILL.md`「Setup」 | compile classpath に届くものの一覧に、Coil の Compose 向けのアーティファクトを足した (本体のビルドの定義で、`api` の依存であることを確かめた) |
| EI-C7・EA-C11・JI-5-10・JA-5-8 | 両プラットフォーム `references/basics.md`「Switch templates by item type」 | テンプレートの例の画面の名前を、`FeedScreen` から `MixedFeedScreen` に変えた。`references/paging.md` の `FeedScreen` は、そのまま |
| EI-C10 | iOS `references/reorder.md`「Know how the drag behaves on iOS」 | 表が、iOS 18 と iOS 26 で観測した動きの説明で、対応するすべての版での保証ではないことを書いた |

### 例を写したときの落とし穴

| 番号 | 場所 | どう直したか |
|---|---|---|
| EI-C11・EA-C10・JI-5-2・JA-5-11 | 両プラットフォーム `references/reorder.md`「Apply the move to your array」 | `moveAndSave` の例の直後に、配列を丸ごと戻すので、保存の間の変更 (2 回目の移動・編集) も取り消されることと、移動が重なりうるときの作り方を書いた |
| EA-C9・JI-5-8 | 両プラットフォーム `references/reorder.md`「Reorder a list that is sorted」 | `SortableTaskListModel` の例の直後に、ソートへ戻す手段を持たないことと、グループの値を見ないのでグループの無い一覧でだけ使うことを書いた |
| JA-3-21 | Android `references/paging.md`「Write the model that owns the paging state」・`references/reorder.md` | `IOException` は自分のクライアントの失敗の代わりで、クライアントが使う例外の型をすべて並べること、捕まえなかった例外は、状態を追加読み込み中のまま残して外へ出ていくことを書いた |

### 意味の取れない・二通りに読める言い回し

| 番号 | 場所 | どう直したか |
|---|---|---|
| JI-2-1 | iOS `references/basics.md` | 「宣言ごとに 1 度だけ決めます」を、「状態で選ぶ値にせず、`KsCollectionView(...)` の式に固定して書く」に直した (Android の「呼び出しの場所ごとに 1 度だけ」も同じに直した) |
| JI-2-2・JA-2-2 | 両プラットフォーム `references/reorder.md`「Know what is held back during a drag」 | 「比べる相手の配列になります」を書き直した。受け入れたときは、持っていた配列は表示されず、「置いた時点で一覧が持っていた配列」の役をするだけで、一覧は、それと等しくない配列が届くまで置いた並びを保つ |
| JI-2-3 | 両プラットフォーム `SKILL.md` 冒頭 | 「同じ語彙」を、「同じ考え方を、対応する名前で持つ」に直した |
| EI-U4・EA-U3・JI-2-4・JA-2-8 | 両プラットフォーム `references/basics.md`「Switch templates by item type」 | 「reuse pool」「再利用の置き場」をやめ、画面の外へ出たセル (Android は行のコンポジション) がほかの項目に使い回されること、使い回す先は同じテンプレートのキーの項目だけであること、として書いた |
| JI-2-6 | 両プラットフォーム `references/basics.md` | iOS の「戻ってよい状態」を、「初期値に戻っても構わない状態」に直した |
| EI-U2・JI-2-7 | iOS `references/basics.md`「What happens with invalid input」 | 統合ログが Apple の Unified Logging であることと、Xcode のコンソールか「コンソール」アプリで、subsystem に絞って読むことを書いた |
| EI-U3・JI-2-8 | iOS `references/basics.md`「Handle taps and long taps」 | 標準のハイライトが、システムの塗りの色 (`UIColor.systemFill`。半透明の灰色) でセルの全面を覆うものであることを書いた |
| JI-2-9・JA-2-4 | 日本語版の全体 | 「部品」を、指すものごとの言葉に置き換えた (`KsCollectionView` 自身は「一覧」「View」「Composable」、行の中のボタンなどは「コントロール」、機能は「機能」)。日本語版に「部品」は残っていない |
| JI-2-10・JI-2-11 | 両プラットフォーム `references/layout.md`「Know how cells are sized and placed」 | 「押される行の移動」を、「その下にある行が動くところ」に直した。「項目の幅いっぱいの中身は、幅を占めます」を、「幅より狭い中身は中央に置かれ、幅いっぱいに広がる中身は項目の幅を埋める」に直した |
| JI-2-12・JA-2-6 | 両プラットフォーム `references/paging.md`・`references/reorder.md` | 「写して使う型にしてください」を、「写して、自分のアプリ (モデル) に合わせて使ってください」に直した |
| JI-2-13・JA-2-11 | 両プラットフォーム `references/paging.md` 冒頭 | 「取り直し」(最初のページを読み込み直して配列を置き換えること) と「読み込み直し」(自分のコードが始める取り直し) を、冒頭で定義した |
| EI-U9・JI-2-14・JA-2-7 | 両プラットフォーム `references/paging.md` | 「同じ回に書く」「in the same turn」を、「間に `await` (中断点) を挟まずに続けて書く。両方が 1 回の更新で一覧に届くようにするため」に直した。iOS の「付属の値」を「関連値 (associated value)」に、「くるくる」を「スピナー」に直した |
| EI-U6・EI-U7・EI-O3・JI-2-15 | iOS `references/reorder.md`「Know how the drag behaves on iOS」 | 「隙間」「持ち上げた項目の絵」を表の前で定義した。「UIKit 標準の並べ替え」が、システムが自分の一覧で使っている並べ替えのことで、UIKit の知識は要らないことを書いた。「settles」を言い換えた |
| EA-U6・EA-U10 | Android `references/reorder.md`「Know how the drag behaves on Android」 | 呼び方を「置き場所 (open slot)」の 1 つにそろえ、表の前で定義した。iOS の説明から「UIKit」を外し、「システムが自分の一覧で使っている並べ替え」にした |
| JI-2-16・JA-2-10 | 両プラットフォーム `references/reorder.md` | 「置いた先のグループのグループの値」を「置いた先のグループの値」に、「何度も動くので」を「何度も呼ばれるので」に直した |
| JI-2-17・JA-2-13・EA-U7・EA-U8 | 両プラットフォーム `references/images.md` | 「見た目が甘くなります」を「ぼやけて見えます」に直した。iOS の「両方の経路」を、`KsImage` と `LazyImage` の両方の表示と書いた。Android の失敗の印が、線で描いた四角と点の小さな絵であることと、色の値を書いた。「width-aware prefetch」を、幅を宣言した先読みと書いた |
| JA-2-1 | Android の全体 | 「キー」を単独で使うのをやめた。`key` のラムダが返すものは「ID」、`template` のラムダが返すものは「テンプレートのキー」、画像のものは「画像のキー」と書き、`SKILL.md` で 3 つを定義した |
| EA-U1・JA-2-3・JA-2-5・EA-O1 | 両プラットフォーム `SKILL.md` | 「項目」「セル」「行」「一覧」「配列」を、最小の動く例の後ろで定義した。Android は、「配列」が渡す `List` のことで、Kotlin の `Array` ではないことも書いた |
| JA-2-9 | Android `references/basics.md` | 「DSL の印のアノテーション」を、「`@DslMarker` のアノテーション」に直した |
| JA-2-12 | 日本語版の両プラットフォーム `references/paging.md` | `onLoadMore` を呼ぶことを「頼む」と書く、と冒頭で断り、状態の表の「頼みません」を「`onLoadMore` を呼びません」に直した |
| JA-2-14 | Android `references/reorder.md` | 「テンプレートの根」を、ほかの場所と同じ「テンプレートのいちばん外側の要素」にそろえた |
| JA-2-15 | Android `SKILL.md`「Setup」 | 「ネットワークの取得の部品」を、OkHttp を使うネットワークの取得の機能と書いた (本体のビルドの定義の依存で確かめた) |
| JA-2-16 | 両プラットフォーム `references/layout.md` | 「ここに書いたことで」を、「この節の決まりで」に直した |
| EA-U2 | 両プラットフォーム `SKILL.md`「References」 | 一覧の要約に、5 つの状態が `KsPagingState` であること、6 つの表示が読み込み中・失敗・終端・空のものであること、並べ替えのスイッチがどのフラグかを足した |
| EA-U4 | Android `references/paging.md` | 「`threshold` is a `Float` in screens」を、型・単位・既定の 3 つに分けて書いた |
| EA-U11 | Android `references/basics.md`・`references/reorder.md` (iOS の `references/reorder.md` も) | `KsCollectionViewScope<Item>`・`KsReorderMove<Item>` の `Item` が、型引数で、自分の項目の型のことだと書いた |
| EI-U10・EA-U9 | 両プラットフォーム `references/layout.md` | 見出しの無いグループが「区切り線の単位になる」を、「区切り線を引く場所を決める (線はグループごとに引く。上の表を参照)」に直した |

### 事実を実物で確かめて、足したもの

| 番号 | 場所 | 足したこと (確かめた実物) |
|---|---|---|
| EI-M1・JI-3-1 | iOS `references/basics.md`「Show an array of items」 | イニシャライザの引数の順 (配列・`id:`・`template:`・`layout:`・`contentPadding:`・末尾のクロージャ) と、1 行の例。`ios/Sources/KsCollectionView/KsCollectionView.swift` の 4 つのイニシャライザ |
| EA-M3・JA-3-1 | Android `references/basics.md`「Show an array of items」・`references/paging.md`・`references/reorder.md`・`references/images.md` | `KsCollectionView` の 22 個の引数の表 (並び・型・既定)。`KsPaging`・`KsReorder` のコンストラクタの並びと、表示のラムダの型。`KsImage` の引数の並び。`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/` の宣言。並びは、すべての引数を位置で渡す呼び出しをコンパイルして確かめた |
| EI-M19・JI-3-10・JI-3-18 | iOS `references/images.md`「Show an image in a cell」 | `KsImage` の引数の順、URL を短く書く形も同じ引数を受け取ること、URL がオプショナルでないこと (画像の無い項目では自分の View を出す)。失敗の表示の色の値。`KsImage.swift`・`KsDefaultColors.swift` |
| EA-M10・JA-3-13 | Android `references/reorder.md` | `KsReorderMove(item, destination, group)` が 3 つの引数をすべて取ること、`KsReorderDestination.Before(item)`、`End` が object であること。コンパイルして確かめた |
| EI-M15・JI-3-16 | 両プラットフォーム `references/reorder.md` | `KsReorderAccessibilityActions` の `previous`・`next` が `String` であること |
| EA-C8・JA-3-2 | Android `references/layout.md` | `KsGroups<Item, Group>` の 2 つの型引数、見出しのラムダの型、変数に持つときの書き方。コンパイルして確かめた |
| EA-C7・JA-3-9 | Android `references/layout.md` | 括弧の無い `KsLayout.List` が用意済みの値で、括弧を付けるとコンストラクタになること、`KsLayout.List()` が用意済みの値と等しいこと、見分けるには型を調べること。`KsLayout.kt` (companion object が `List` を継ぐ)。コンパイルして確かめた |
| EA-M4・JA-3-3 | 両プラットフォーム `references/basics.md` | 「違う配列」が、値で比べて等しくない配列のことであること (iOS は `==`、Android は `equals`。同じインスタンスは自分自身と等しい)。Android は、ラムダと `KsGroups`・`KsPaging`・`KsReorder` の値を、再コンポーズのたびに作って構わないこと (`remember` は要らない) |
| EI-M16・JI-3-14・EA-M13・JA-3-5・JA-3-19 | 両プラットフォーム `references/basics.md`・`references/reorder.md`・`references/images.md` | タップと長押しのコールバックがメインスレッドで呼ばれること。iOS の `onMove` が `@MainActor` であること。Android の `canMove`・`canDrop` がメインスレッドで呼ばれること。先読みのクロージャがメインスレッドで呼ばれること。Android の `KsImageCache` は、どのスレッドから呼んでもよく、ディスクの削除を呼び出したスレッドで済ませてから戻ること |
| EI-M4・JI-3-4 | iOS `references/basics.md`「Read parent state inside a row」 | ヘッダー・フッター・ページングの表示は `.observedValue` の対象ではなく、`body` が評価し直されるたびに作り直されること。`KsCollectionViewController.swift` の `update(configuration:)` |
| JI-3-3 | iOS `references/basics.md`「Read parent state inside a row」 | ライブラリは、画面の SwiftUI の環境を行・見出し・表示へ引き継がないので、当てにしないこと。行に要るものはイニシャライザで渡すこと。外観は、置かれた場所に従うこと (本体に、環境を引き継ぐコードが無い) |
| EI-M3・JI-3-22 | iOS `SKILL.md` | `@Observable` のモデルも使えること。違いは、`body` 自身が読んだプロパティだけが追跡されること |
| EI-M6・EI-M22・JI-3-2 | iOS `SKILL.md`・`references/basics.md` | 項目の型に要るのは `Equatable` と ID だけで、`Sendable` は要らないこと (例は、`async` の境界を越えるところにだけ付けている)。ID は `Hashable` なら何でもよいこと。class のインスタンスをその場で書き換えると、変化が見つからないこと |
| EI-U5 | 両プラットフォーム `references/basics.md`「Scroll from code」 | 位置の基準。iOS は、項目を一覧自身の端に合わせる (上下の内側の余白はスクロールするコンテンツの一部)。Android は、内側の余白の内側に合わせる。`KsCollectionViewController.swift` の `execute(_:)` と、`KsScrollCommandReceiver.kt` |
| EI-M7・EA-M6・JA-3-14 | 両プラットフォーム `references/basics.md`「Update the list by replacing the array」 | 途中までスクロールした状態で、表示範囲より上に足した・消したときの位置。iOS は、スクロールの量を保つので、画面に出ているものがずれる。Android は、表示範囲の先頭の項目をその場に保つ |
| EA-M5 | Android `references/basics.md` | スクロールの位置が、Compose の状態の保存の仕組みで保存され、回転や、バックスタックの画面に戻ったときに戻ること (`rememberLazyGridState()` を使っている)。iOS は、位置が読み取れず、保存もされないことを書いた |
| EI-M8・EA-M7・JI-3-12・JA-3-12 | 両プラットフォーム `references/basics.md`「Show an array of items」・`references/paging.md`「Defaults」 | ページングを付けない一覧は、空の表示を持たないこと。配列が空の間、自分の View (Composable) を出すこと。ページングの 1 枚から、この箇条を指した |
| EI-M9・JI-3-19 | iOS `references/basics.md` | `adaptive(minItemWidth:)` の幅が 0 以下のとき、リリースビルドでの決まった扱いが無いこと (`KsLayoutMetrics.swift` に、ほかの行のような置き換えが無い) |
| EI-M10 | 両プラットフォーム `references/basics.md` | 末尾へのスクロールの行に、最後の項目の下にあるもの (フッターと、ページングの失敗・終端の表示) を書いた。命令によるスクロールでも、ページングの条件が判定されることを書いた |
| EI-M11・EA-M11・JI-3-13・JA-3-8 | 両プラットフォーム `references/paging.md`「Reload from your own code」 | もう一方の方式の文を、実装できそうに見える書き方から、「ライブラリはその時機を知らせない。この Skill はコードを載せていない。`scrollToStart` の手当てを使う」に直した |
| EI-M12 (一部)・JI-3-8 (一部)・EA-M12 (一部) | 両プラットフォーム `references/paging.md`「Know when a running load is cancelled」 | モデルが持つタスク (スコープ) で読み込む手順を、文で具体にした (`onLoadMore` は中断しないモデルの関数を呼ぶ。その関数は状態を書き換え、モデルのタスクで取得を始めて、すぐに戻る。結果は同じ世代の判定を通す)。直していない部分: 指摘が求めた例 (コードブロック) は足していない。例のモデルの書き換えが要り、1 枚が膨らむため |
| EI-M13 | 両プラットフォーム `references/paging.md` | `retry` の型 (iOS は `@MainActor () -> Void`、Android は `() -> Unit`)。iOS は、`threshold` が `Double` であることも書いた |
| EI-M14 | 両プラットフォーム `references/paging.md`「Add pull to refresh」 | 自分のコードで取り直している間の引っ張りは受け付けること (止めるのは、追加読み込み中と、次ページの処理の実行中だけ)。そのときは、例の世代の判定が古い結果を捨てること |
| EI-M18・JI-3-17 | iOS `references/images.md`「Enable the disk cache at launch」 | 引数が無いこと、足されるのが Nuke 自身のディスクキャッシュで、上限と置き場所は Nuke の既定であること、`KsImageCache.clear(.all)` で空になること |
| EI-M20 | iOS `references/images.md` | `.file` のソースの `remove` は、リモートのソースと同じように扱うこと (ファイル自体には触らない)。`KsImageIdentity.swift`・`KsImageCache.swift` |
| EI-M21・JA-3-16 | 両プラットフォーム `references/layout.md` | 左右の安全領域 (insets) を扱わないと、行が切り欠きの下まで広がること。iOS は、縦の方向にだけ広げる書き方、Android は、同じ insets の左右の値を自分で余白に足すこと |
| EI-M23・JI-3-23 | iOS `SKILL.md`「Setup」 | UIKit の API は無く、UIKit のアプリでは SwiftUI の画面を `UIHostingController` で表示すること |
| EI-M24 | iOS `SKILL.md` の必要な環境の表 | このライブラリに依存する `Package.swift` は、`platforms: [.iOS(.v16)]` 以上を宣言すること |
| JI-3-24 | iOS `SKILL.md`「Setup」 | Xcode の画面から足すときは、Dependency Rule で版を決めること (宣言に合わせるなら Exact Version) |
| JI-3-6 | iOS `references/layout.md` | 一覧とセルは自分の背景を持たず、後ろのものが透けること。背景の付け方 (`KsCollectionViewController.swift` で、背景が透明) |
| JI-3-11 | iOS `references/basics.md` | フィードバックを出したくないときは、`.clear` を渡すこと |
| JI-3-15 | 両プラットフォーム `references/reorder.md` | 項目を自分のグループの中に留める `canDrop` の 1 行。コンパイルして確かめた |
| JI-3-20 | iOS `references/layout.md` | グリッドは、`.listSeparators(true)` を付けても区切り線を描かないこと |
| JI-3-21 | 両プラットフォーム `references/layout.md` | セルの高さをそろえる具体の方法 (固定の高さ・縦横比) |
| JI-3-25 | iOS `references/layout.md` | 間隔が `Double`、列数が `Int`、`minItemWidth` が `Double` であること |
| EA-M8 | Android `references/basics.md` | タップか長押しを渡した一覧は、項目を押せる要素として TalkBack に伝えること。操作のラベルを渡す引数は無いこと |
| EA-M9 | 両プラットフォーム `references/basics.md` | テンプレートのラムダ (クロージャ) は、キーが何であっても、項目を一覧の項目の型で受け取ること。Android は、sealed の型ならラムダの中でキャストすること |
| EA-M15・JA-3-4 (一部) | Android `SKILL.md`「Setup」・`references/images.md` | ライブラリは Coil のアプリ全体のローダーをそのまま使い、差し替えないので、自分で行ったローダーの設定 (要求のヘッダーなど) がライブラリの画像にも効くこと。`KsImage` に、ヘッダーを渡す引数は無いこと。直していない部分: Coil 2 系を使うアプリでの動き (コードから決められない) |
| EA-M16 | 両プラットフォーム `references/images.md` | キャッシュの画像が、必要な大きさの 4 倍より大きいときも、使われずに読み込み直されること (`KsImageMatching` の範囲) |
| EA-M17・JA-3-19 | Android `references/images.md` | 自分で渡した `loading`・`failure` は、自分の大きさのまま、枠の左上 (始端の上) に置かれること (iOS は、枠の中央に置かれる)。`KsImage.kt`・`KsImage.swift` |
| EA-M18 | Android `references/images.md` | `AsyncImage` の import (`coil3.compose.AsyncImage`)。コンパイルして確かめた |
| EA-M19・JA-3-18・EA-U5 | Android `references/layout.md`・両プラットフォーム `references/paging.md`「Where they appear」 | Android の、幅より狭いヘッダー・フッター・グループの見出しは、中央ではなく始端から始まること。ページングの失敗・終端の表示は、左右の余白の内側でコンテンツの幅いっぱいが与えられ、渡したものがその中の水平の中央に置かれること (「フッターと同じ幅」をやめた) |
| JA-3-15 | 両プラットフォーム `references/layout.md` | 上の内側の余白はコンテンツと一緒に流れ、固定中の見出しを下げないこと (見出しは一覧の上端に固定される) |
| JA-3-17 | Android `SKILL.md`「Setup」 | ライブラリのために、R8 や ProGuard の規則を足す必要が無いこと (本体に利用者向けの規則が無く、コード縮小を有効にした利用者の立場のビルドが、規則を足さずに通っている) |
| EA-M2 (一部)・JA-3-10 (一部) | Android `SKILL.md`「Setup」 | 自分のモジュールも Compose BOM を宣言しているときは、Gradle が新しいほうの版を選ぶこと。直していない部分: ライブラリが届ける BOM と Coil の版の値 (版ごとに変わるので、Skill に書かない) |
| EI-U1・EI-M17 (一部)・JI-4-2 (一部)・JA-4-2 (一部) | 両プラットフォーム `SKILL.md`・`references/images.md`・Android `references/paging.md` | Nuke・Coil が、オープンソースの画像読み込みライブラリであること、共有のパイプライン (ローダー) が何か、下の節が断っている場合を除いて知識は要らないことを書いた。Android は、Navigation Compose が何かと、マニフェストから取り除くときの書き方 (`tools:node="remove"`) と、ライブラリの項目の名前を書いた。直していない部分: delegate を使うアプリが自分でパイプラインを組むコード。Nuke 自身の API の使い方で、この Skill の領分ではない。その場合は、自分の依存に Nuke を足して Nuke の文書に従う、と書いた |
| EI-M5 (一部) | iOS `references/basics.md`「Keep state that must survive scrolling in your model」 | 行のクロージャは項目を `Binding` ではなく値で受け取ること、行の中のコントロールからは、配列を差し替えるモデルの関数を呼ぶこと。直していない部分: 入力のたびの作り直しでフォーカスが残るかの保証 (コードから決められない。「画面に出ている間は、行の中の状態は保たれる」は、今の本文のとおり) |
| EI-U8 (一部)・JI-2-18 (一部) | iOS の各 1 枚の、Android の動きの添え書き | Android の言葉を言い換えた (`Bundle` に保存できる型 → Android が画面の状態として保存できる型、波紋 → Android 標準のタッチの効果、コンポジションを離れ → 表示が破棄され、edge-to-edge → システムバーの裏まで広げた、矢印 → インジケータ)。直していない部分: 添え書きそのものは残した。相手のプラットフォームとの差を、その機能の説明の場所に書くのが設計の決まり (design.md の Decision 2) のため |

### 提供していない機能の明記

| 番号 | 場所 | どう直したか |
|---|---|---|
| EI-N2 (一部)・JI-3-7 (一部)・EA-N2 (一部)・EA-N3・EA-N4・EA-N5・EA-N6 (一部)・EA-N7・JA-3-6 (一部)・JA-3-7・JA-3-11 | 両プラットフォーム `SKILL.md`「What you can do」の表の下 | ライブラリに API が無いものを、1 か所に並べた。公開の宣言を読んで、無いことを確かめたもの: スワイプの操作・選択のモード・コンテキストメニュー (iOS)・横スクロール・複数の列にまたがる項目・段違いのグリッド・グループの折りたたみ・グループのフッター・スクロール位置の読み取りとコールバック・スクロール位置の保存と復元 (iOS)・グループの見出しへのスクロール (Android)・先頭へ向かう読み込み・差分のアニメーションの調整・Jetpack Paging 3 (Android)。グループの見出しのタップは、自分の View (Composable) の中で受けることも書いた。直していない部分: `.searchable` (SwiftUI 自身の機能で、ライブラリの決まりが無い)・行の中の `NavigationLink` (コードから決められない)・`nestedScroll` との併用 (コードから決められない)・UI テストの手掛かり (アプリ自身の Composable に付けるもので、ライブラリの決まりが無い) |

### 道案内

| 番号 | 場所 | どう直したか |
|---|---|---|
| EI-N1・JI-6-1・JA-6-1 | 両プラットフォーム `SKILL.md`「What you can do」の表 | 表の行の文言に、行き先の 1 枚の中の、表から見つけられなかった見出しを足した (セルの大きさ・スクロールインジケータ・状態を持つモデル・読み込みの取り消し・動かせる項目と置ける場所・ソート済みの一覧・ドラッグ中に保留されるもの・画像のキー・ディスクキャッシュ・ローダー自身のビュー) |
| JI-6-2 | iOS `SKILL.md`「Setup」 | 起動時に `KsImagePipeline.enableSharedDiskCache()` を 1 度呼ぶと画像がディスクに残ることを書き、`references/images.md` の節を指した |
| EA-N1・JI-6-3 | 両プラットフォーム `SKILL.md` の表 | ページングの行に、「ページングを付けた一覧をバーの裏まで広げる」を足した |
| JA-6-2 | Android `SKILL.md` | ライブラリが自分で描く色 (区切り線・スクロールインジケータ・画像の既定の表示) が、Material の配色ではなく `isSystemInDarkTheme()` に従うことを 1 か所に書き、2 枚を指した |
| JA-6-3 | Android `SKILL.md` の表 | 画像の行に、キャッシュの操作にはライブラリの起動時の初期化が要ること (「導入」を参照) を足した |

## 番号ごとの結末 (照合用)

「直」は直した、「一部」は一部を直した、「否」は直さない。括弧の中は、上のどの表にあるか。

### EI (`dist-read-en-ios.md`)

| 番号 | 結末 | 番号 | 結末 | 番号 | 結末 |
|---|---|---|---|---|---|
| U1 | 直 (事実) | M8 | 直 (事実) | C1 | 直 (重大) |
| U2 | 直 (言い回し) | M9 | 直 (事実) | C2 | 直 (食い違い) |
| U3 | 直 (言い回し) | M10 | 直 (事実) | C3 | 直 (食い違い) |
| U4 | 直 (言い回し) | M11 | 直 (事実) | C4 | 直 (食い違い) |
| U5 | 直 (事実) | M12 | 一部 (事実) | C5 | 直 (食い違い) |
| U6 | 直 (言い回し) | M13 | 直 (事実) | C6 | 直 (食い違い) |
| U7 | 直 (言い回し) | M14 | 直 (事実) | C7 | 直 (食い違い) |
| U8 | 一部 (事実) | M15 | 直 (事実) | C8 | 直 (食い違い) |
| U9 | 直 (言い回し) | M16 | 直 (事実) | C9 | 直 (食い違い) |
| U10 | 直 (言い回し) | M17 | 一部 (事実) | C10 | 直 (食い違い) |
| M1 | 直 (事実) | M18 | 直 (事実) | C11 | 直 (落とし穴) |
| M2 | 否 | M19 | 直 (事実) | N1 | 直 (道案内) |
| M3 | 直 (事実) | M20 | 直 (事実) | N2 | 一部 (提供していない機能) |
| M4 | 直 (事実) | M21 | 直 (事実) | O1 | 否 |
| M5 | 一部 (事実) | M22 | 直 (事実) | O3 | 直 (言い回し) |
| M6 | 直 (事実) | M23 | 直 (事実) | | |
| M7 | 直 (事実) | M24 | 直 (事実) | | |

### EA (`dist-read-en-android.md`)

| 番号 | 結末 | 番号 | 結末 | 番号 | 結末 |
|---|---|---|---|---|---|
| O1 | 直 (言い回し) | M6 | 直 (事実) | C3 | 直 (食い違い) |
| U1 | 直 (言い回し) | M7 | 直 (事実) | C4 | 否 |
| U2 | 直 (言い回し) | M8 | 直 (事実) | C5 | 直 (食い違い) |
| U3 | 直 (言い回し) | M9 | 直 (事実) | C6 | 直 (食い違い) |
| U4 | 直 (言い回し) | M10 | 直 (事実) | C7 | 直 (事実) |
| U5 | 直 (事実) | M11 | 直 (事実) | C8 | 直 (事実) |
| U6 | 直 (言い回し) | M12 | 一部 (事実) | C9 | 直 (落とし穴) |
| U7 | 直 (言い回し) | M13 | 直 (事実) | C10 | 直 (落とし穴) |
| U8 | 直 (言い回し) | M14 | 否 | C11 | 直 (食い違い) |
| U9 | 直 (言い回し) | M15 | 直 (事実) | N1 | 直 (道案内) |
| U10 | 直 (言い回し) | M16 | 直 (事実) | N2 | 一部 (提供していない機能) |
| U11 | 直 (言い回し) | M17 | 直 (事実) | N3 | 直 (提供していない機能) |
| M1 | 否 | M18 | 直 (事実) | N4 | 直 (提供していない機能) |
| M2 | 一部 (事実) | M19 | 直 (事実) | N5 | 直 (提供していない機能) |
| M3 | 直 (事実) | M20 | 否 | N6 | 一部 (提供していない機能) |
| M4 | 直 (事実) | D1 | 否 | N7 | 直 (提供していない機能) |
| M5 | 直 (事実) | C1 | 直 (食い違い) | | |
| | | C2 | 直 (食い違い) | | |

### JI (`dist-read-ja-ios.md`)

| 番号 | 結末 | 番号 | 結末 | 番号 | 結末 |
|---|---|---|---|---|---|
| 2-1 | 直 (言い回し) | 3-3 | 直 (事実) | 3-23 | 直 (事実) |
| 2-2 | 直 (言い回し) | 3-4 | 直 (事実) | 3-24 | 直 (事実) |
| 2-3 | 直 (言い回し) | 3-5 | 否 | 3-25 | 直 (事実) |
| 2-4 | 直 (言い回し) | 3-6 | 直 (事実) | 4-1 | 否 |
| 2-5 | 直 (食い違い) | 3-7 | 一部 (提供していない機能) | 4-2 | 一部 (事実) |
| 2-6 | 直 (言い回し) | 3-8 | 一部 (事実) | 5-1 | 直 (重大) |
| 2-7 | 直 (言い回し) | 3-9 | 直 (食い違い) | 5-2 | 直 (落とし穴) |
| 2-8 | 直 (言い回し) | 3-10 | 直 (事実) | 5-3 | 直 (食い違い) |
| 2-9 | 直 (言い回し) | 3-11 | 直 (事実) | 5-4 | 直 (食い違い) |
| 2-10 | 直 (言い回し) | 3-12 | 直 (事実) | 5-5 | 直 (食い違い) |
| 2-11 | 直 (言い回し) | 3-13 | 直 (事実) | 5-6 | 直 (食い違い) |
| 2-12 | 直 (言い回し) | 3-14 | 直 (事実) | 5-7 | 直 (食い違い) |
| 2-13 | 直 (言い回し) | 3-15 | 直 (事実) | 5-8 | 直 (落とし穴) |
| 2-14 | 直 (言い回し) | 3-16 | 直 (事実) | 5-9 | 直 (食い違い) |
| 2-15 | 直 (言い回し) | 3-17 | 直 (事実) | 5-10 | 直 (食い違い) |
| 2-16 | 直 (言い回し) | 3-18 | 直 (事実) | 6-1 | 直 (道案内) |
| 2-17 | 直 (言い回し) | 3-19 | 直 (事実) | 6-2 | 直 (道案内) |
| 2-18 | 一部 (事実) | 3-20 | 直 (事実) | 6-3 | 直 (道案内) |
| 3-1 | 直 (事実) | 3-21 | 直 (事実) | | |
| 3-2 | 直 (事実) | 3-22 | 直 (事実) | | |

### JA (`dist-read-ja-android.md`)

| 番号 | 結末 | 番号 | 結末 | 番号 | 結末 |
|---|---|---|---|---|---|
| 2-1 | 直 (言い回し) | 3-3 | 直 (事実) | 4-1 | 否 |
| 2-2 | 直 (言い回し) | 3-4 | 一部 (事実) | 4-2 | 一部 (事実) |
| 2-3 | 直 (言い回し) | 3-5 | 直 (事実) | 5-1 | 直 (食い違い) |
| 2-4 | 直 (言い回し) | 3-6 | 一部 (提供していない機能) | 5-2 | 直 (食い違い) |
| 2-5 | 直 (言い回し) | 3-7 | 直 (提供していない機能) | 5-3 | 直 (食い違い) |
| 2-6 | 直 (言い回し) | 3-8 | 直 (事実) | 5-4 | 直 (食い違い) |
| 2-7 | 直 (言い回し) | 3-9 | 直 (事実) | 5-5 | 直 (食い違い) |
| 2-8 | 直 (言い回し) | 3-10 | 一部 (事実) | 5-6 | 直 (食い違い) |
| 2-9 | 直 (言い回し) | 3-11 | 直 (提供していない機能) | 5-7 | 直 (食い違い) |
| 2-10 | 直 (言い回し) | 3-12 | 直 (事実) | 5-8 | 直 (食い違い) |
| 2-11 | 直 (言い回し) | 3-13 | 直 (事実) | 5-9 | 直 (食い違い) |
| 2-12 | 直 (言い回し) | 3-14 | 直 (事実) | 5-10 | 否 |
| 2-13 | 直 (言い回し) | 3-15 | 直 (事実) | 5-11 | 直 (落とし穴) |
| 2-14 | 直 (言い回し) | 3-16 | 直 (事実) | 6-1 | 直 (道案内) |
| 2-15 | 直 (言い回し) | 3-17 | 直 (事実) | 6-2 | 直 (道案内) |
| 2-16 | 直 (言い回し) | 3-18 | 直 (事実) | 6-3 | 直 (道案内) |
| 3-1 | 直 (事実) | 3-19 | 直 (事実) | | |
| 3-2 | 直 (事実) | 3-20 | 否 | | |
| | | 3-21 | 直 (落とし穴) | | |

## コード例の確かめ

コードブロックを変えたのは、次の 2 つだけである。ほかの直しは、本文と、本文の中の 1 行の断片である。

| 変えたコードブロック | 内容 |
|---|---|
| iOS `references/paging.md` の `FeedModel` | 取り消しの見分け方 (上の「重大」) |
| 両プラットフォーム `references/basics.md` のテンプレートの例 | 画面の名前を `FeedScreen` から `MixedFeedScreen` に変えた |

リポジトリの外の作業用の置き場で、英語版のコードブロックをすべて取り出して、コンパイルした (日本語版のコードブロックは、検査が英語版と同じ内容だと確かめている)。リポジトリのファイルは変えていない。Simulator とエミュレータは使っていない。

| プラットフォーム | やり方 | 結果 |
|---|---|---|
| iOS | 本体 (`ios/` のマニフェストとソース) の写しに依存する作業用の Swift パッケージを作り、`SKILL.md` と 5 枚のコードブロックを、1 枚を 1 つのターゲットにして置いた。`xcodebuild -scheme SkillExamples -destination 'generic/platform=iOS Simulator' build` | `** BUILD SUCCEEDED **`。例のソースに由来する警告は無い。本文に足した 1 行の断片 (引数の順の例・`.touchFeedback(color: .clear)`・`.ignoresSafeArea(edges: .vertical)`・項目を自分のグループに留める `canDrop`・`String(localized:)` を渡す移動操作の文言) も、コンパイルできる形にして一緒に通した |
| Android | 本体 (`android/`) の写しに、本体のモジュールに依存する作業用のモジュールを足し、5 枚のコードブロックを、1 枚を 1 つの package にして置いた。`./gradlew :examples:compileDebugKotlin` | `BUILD SUCCESSFUL`。本文に足した断片 (`KsCollectionView` の 22 個の引数を位置で渡す呼び出し・`KsImage` の引数を位置で渡す呼び出し・型を書いた `KsGroups` の変数・`KsLayout.List` の型の判定と値の比較・`KsReorderMove` と `KsReorderDestination` のコンストラクタ・項目を自分のグループに留める `canDrop`・`coil3.compose.AsyncImage`) も一緒に通した |

前の回の Android の確かめは、本体を作業用の Maven のディレクトリへ発行して、利用者と同じ 1 行の依存で取っていた。今回は、発行せずに、写しの本体のモジュールに直接依存させた。コードブロックがコンパイルできることは確かめられるが、発行物を通した依存の届き方は、今回は確かめ直していない。

確かめたのはコンパイルが通ることだけで、例を起動して動きを見てはいない。
