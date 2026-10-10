# 読ませる確認: 英語版・Android (タスク 10.1)

- 日付: 2026-10-10
- 渡したもの: `skills/en/kscollectionview-android/` の写し 1 ディレクトリ (空の作業用の置き場。リポジトリの外)。リポジトリのパス・ほかの文書は渡していない
- 読ませた相手: リポジトリを知らない新しいエージェント。置き場の外を読まない・Web を使わない・事前の知識を使わない、と指示した
- 返ってきたもの: 6 枚をすべて読んだうえでの指摘 51 件 (重大 0・欠け 19・軽微 32)。コンパイルはしていない (読んだだけの判断)

## 冒頭

何のライブラリか・プラットフォーム・いつ使うかは、SKILL.md の最初の画面で分かった。

## 指摘 (返ってきた番号のまま)

重さ: 欠け = 推測が要る / 軽微

| 番号 | 重さ | 場所 | 指摘 |
|---|---|---|---|
| O1 | 軽微 | SKILL.md「What you can do」 | 「array」が Kotlin の `Array` に読める。`List` を配列と呼ぶ断りは basics.md にしか無い |
| U1 | 軽微 | 全体 | cell・row・item・cell template が定義なしに混ざって使われている |
| U2 | 軽微 | SKILL.md「References」 | 「the six displays」「the reorder switch」「the five paging states」が、定義する 1 枚より前に出る |
| U3 | 軽微 | basics.md「Switch templates by item type」 | 「reuse pool」の説明が無い |
| U4 | 軽微 | paging.md「Add paging to a list」 | 「`threshold` is a `Float` in screens」の言い回しが分かりにくい |
| U5 | 欠け | paging.md「Where they appear」 | 失敗と終端の表示が「フッターと同じ幅」とあるが、フッターの幅がどこにも無い |
| U6 | 軽微 | reorder.md「Know how the drag behaves on Android」 | 「the open slot」と「the gap」が同じものに 2 つの呼び方 |
| U7 | 軽微 | images.md「Show an image in a cell」 | 既定の失敗の表示「a fill with a mark」の印と色が分からない |
| U8 | 軽微 | images.md 最後の節 | 「a width-aware prefetch」が新しい呼び方 |
| U9 | 軽微 | layout.md「Group items under group headers」 | 見出しの無いグループが「区切り線の単位になる」は、区切り線の節を読むまで分からない |
| U10 | 軽微 | reorder.md「Know how the drag behaves on Android」 | 「the standard UIKit reordering behavior」。SKILL.md は iOS を SwiftUI と書いていて、食い違って見える |
| U11 | 軽微 | basics.md・reorder.md | `KsCollectionViewScope<Item>`・`KsReorderMove<Item>` の `Item` が、型引数の名前なのか例の `Item` なのか紛らわしい |
| M1 | 欠け | SKILL.md「Setup」 | `{version}` の具体の値が無く、Web のページでしか分からない |
| M2 | 欠け | SKILL.md「Setup」 | ライブラリが持ち込む Compose BOM・Coil の版と、自分の BOM と重なったときの動きが無い |
| M3 | 軽微 | 全体 | `KsCollectionView` の引数の一覧 (並び・型・既定値・null を渡せるか) が 1 か所に無い |
| M4 | 欠け | basics.md「Update the list by replacing the array」 | 「違う配列を受け取ったときだけ見る」の「違う」が、参照か `equals` か分からない |
| M5 | 欠け | basics.md | スクロール位置が回転・戻る・プロセスの終了をまたいで残るかが無い |
| M6 | 欠け | basics.md「Update the list by replacing the array」 | 途中までスクロールした状態で、見えている範囲より上に項目を足した・消したときの位置が無い |
| M7 | 欠け | basics.md / paging.md | ページングを使わない一覧の、空のときの表示の作り方が無い |
| M8 | 軽微 | basics.md「Handle taps and long taps」 | タップ・長押しの読み上げでの扱いが無い |
| M9 | 軽微 | basics.md「Switch templates by item type」 | sealed の型のとき、テンプレートの引数が基底の型でキャストが要ることが無い |
| M10 | 欠け | reorder.md「Apply the move to your array」 | `KsReorderMove`・`KsReorderDestination.Before` の公開のコンストラクタの引数の名前と並びが無い |
| M11 | 軽微 | paging.md「Reload from your own code」 | もう一方の方式 (`SideEffect` で報告) のコードが無い |
| M12 | 軽微 | paging.md「Know when a running load is cancelled」 | 「先に `Appending` にしてから launch」の例と、`ViewModel` の形の例が無い |
| M13 | 欠け | images.md「Clear or remove cached images」 | `clear`・`remove` をメインスレッドで呼んでよいかが無い |
| M14 | 欠け | images.md | `content://` の URI の扱い (使えないのか、`AsyncImage` を使うのか) が無い |
| M15 | 欠け | images.md | リクエストのヘッダー・認証、Coil の共有の loader を自分で差し替えるときの扱いが無い |
| M16 | 軽微 | images.md「Give the prefetch a display width」 | キャッシュの画像が要る大きさの 4 倍を超えるときの動きが無い |
| M17 | 軽微 | images.md「Show an image in a cell」 | `loading`・`failure` の中身の位置と大きさ、切り替えの効果の有無が無い |
| M18 | 軽微 | images.md 最後の節 | `AsyncImage` の import の package が無い |
| M19 | 軽微 | layout.md「Add a header and a footer」 | ヘッダー・フッターが幅より狭いときの位置の決まりが無い |
| M20 | 軽微 | SKILL.md 冒頭 | 大きな配列の差分の計算がどこで走り、どのくらい掛かるかが無い |
| D1 | 欠け | SKILL.md「Setup」 | 最新の版を知るには releases のページを見るしかない (M1 と同じ根) |
| C1 | 欠け | basics.md | 「テンプレートのキーが変わるとセルが作り直される」と「表示中に `key`・`template` が返す値を変えない」が食い違って読める |
| C2 | 欠け | reorder.md | 「落とす前と違う配列が届いたら従う」と「ソート済みの配列を渡し続けると、落とした項目がソートの位置へ跳ぶ」が、「違う」の意味しだいで食い違う |
| C3 | 軽微 | basics.md「What happens with invalid input」 | 「項目を落とさない」と、ID の重複の行の「後の要素が勝つ」が合わない |
| C4 | 欠け | SKILL.md「Setup」 | `compileSdk` 36 に対して AGP の下限 8.6.0 は低すぎるように見える |
| C5 | 軽微 | paging.md「Defaults」 | 「3 つの表示は最低限渡す」と書きながら、同じ 1 枚の例 3 つが渡していない |
| C6 | 軽微 | SKILL.md「Setup」と images.md | compile classpath に届くものの一覧に、Coil の Compose の成果物が無い |
| C7 | 軽微 | layout.md「Choose a list or a grid」 | `KsLayout.List` が値としてもコンストラクタとしても使われている。`KsLayout.List()` の扱いが分からない |
| C8 | 軽微 | layout.md「Group items under group headers」 | `KsGroups` の総称の形が示されておらず、型推論が失敗したときの書き方が分からない |
| C9 | 軽微 | reorder.md「Reorder a list that is sorted」 | 例のモデルに、ソートを戻す手段が無い |
| C10 | 軽微 | reorder.md「Apply the move to your array」 | `moveAndSave` の `restore(original)` が、落としてから保存が失敗するまでの間の変更を上書きする |
| C11 | 軽微 | paging.md「Add paging to a list」 | 例の名前 `FeedScreen` が、basics.md の別の例と同じ |
| N1 | 軽微 | SKILL.md の表 | 全画面の案内が layout.md だけで、ページングの場合の節 (paging.md) へは 2 回たどる |
| N2 | 欠け | — | スクロールの状態を読む方法 (先頭の見えている項目・`nestedScroll` との併用) の行き先が無い |
| N3 | 欠け | — | 横方向の一覧が「提供されない」と書かれていない |
| N4 | 欠け | — | 項目ごとの列のまたぎ・段違いのグリッドの行き先が無い |
| N5 | 欠け | — | 上へ向かって前のページを読み込む使い方の行き先が無い |
| N6 | 軽微 | — | スワイプの操作・選択のモード・グループの見出しへのスクロール・差分のアニメーションの調整・UI テストの手掛かりが無い |
| N7 | 軽微 | — | Jetpack Paging 3 との併用ができないことが書かれていない |

外への依存: 上の D1 のほかは無い (不具合の報告先の URL・frontmatter の URL・相手の Skill の名前は、頼っていないので問題なし、との報告)。

結末 (直す / 直さない理由) は `dist-read-dispositions.md` に書く。
