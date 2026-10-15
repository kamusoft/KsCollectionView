# 読ませる確認: 英語版・iOS (タスク 10.1)

- 日付: 2026-10-10
- 渡したもの: `skills/en/kscollectionview-ios/` の写し 1 ディレクトリ (空の作業用の置き場。リポジトリの外)。リポジトリのパス・ほかの文書は渡していない
- 読ませた相手: リポジトリを知らない新しいエージェント。置き場の外を読まない・Web を使わない・事前の知識を使わない、と指示した
- 返ってきたもの: 6 枚をすべて読んだうえでの指摘の番号 49 個 (重大 1・欠け 13・軽微 35。返ってきた集計は 51 件で、O2 は M17 と同じ指摘として M17 に数え、N1・N2 は複数の見出し・作業をまとめた 1 行ずつにした)。コンパイルはしていない (読んだだけの判断)

## 冒頭

何のライブラリか・プラットフォーム・いつ使うかは、SKILL.md の最初の画面で分かった。指摘なし。

## 指摘 (返ってきた番号のまま)

重さ: 重大 = 誤ったコードを書いてしまう / 欠け = 推測が要る / 軽微

| 番号 | 重さ | 場所 | 指摘 |
|---|---|---|---|
| U1 | 軽微 | images.md 冒頭・「Enable the disk cache at launch」・「Use Nuke's own views」 | `ImagePipeline.shared`・pipeline・`ImagePipeline.Delegate`・`dataCache`・`LazyImage`・NukeUI が、知っている前提で出る |
| U2 | 軽微 | basics.md「What happens with invalid input」 | 「the unified log」の見方が無い |
| U3 | 軽微 | basics.md「Handle taps and long taps」 | 「the standard highlight」の色と見え方が無い |
| U4 | 軽微 | basics.md「Switch templates by item type」 | 「reuse pool」の説明が無い |
| U5 | 欠け | basics.md「Scroll from code」 | 「位置は `contentPadding` の内側で測る」で、`.start` が上端にぴったり付くのか余白の下なのか分からない |
| U6 | 軽微 | reorder.md「Know how the drag behaves on iOS」 | 「the gap」「lifted preview」「settles」の定義が無い |
| U7 | 軽微 | 同上 | 「standard UIKit reordering behavior」「UIKit's small default preview」が UIKit の知識を前提にしている |
| U8 | 軽微 | 各 1 枚の Android の動きの添え書き | Android の言葉 (`Bundle`・ripple・composition から外す・矢印) が説明なしに出る |
| U9 | 軽微 | paging.md モデルの決まりの表 | 「in the same turn」が分かりにくい |
| U10 | 軽微 | layout.md グループ | 見出しの無いグループが「区切り線の単位になる」は、区切り線の節を読むまで分からない |
| M1 | 欠け | basics.md「Show an array of items」 | イニシャライザの引数のラベルの並びの全体が無い (`id:`・`template:` と `layout:` を組み合わせるときの並びが推測になる) |
| M2 | 欠け | SKILL.md「Setup」 | Package URL は `KsCollectionView-SPM` なのに、版は `KsCollectionView` の releases で調べる。版の番号が同じか・タグの形が無い |
| M3 | 欠け | SKILL.md「References」の前 | `@Observable` のモデルが iOS 17 以上で使えるかが無い |
| M4 | 欠け | basics.md「Read parent state inside a row」 | `.observedValue` が、ヘッダー・フッター、ページングの 6 つの表示、行の View が自分で持つ `@ObservedObject`・`@EnvironmentObject`・`@Environment` に効くかが無い |
| M5 | 欠け | basics.md「Keep state that must survive scrolling in your model」 | 行から書き戻す例 (`TextField`・`Toggle` と `Binding`) が無い。入力のたびの作り直しでフォーカスが残るか分からない |
| M6 | 軽微 | 全体 | 項目の型に `Sendable` が要るかが無い (例によって付いていたり、いなかったりする) |
| M7 | 欠け | basics.md「Update the list by replacing the array」 | 途中までスクロールした状態で、見えている範囲より上に項目を足したときの位置が無い |
| M8 | 欠け | paging.md | ページングを使わない一覧の、空のときの表示の作り方が無い |
| M9 | 軽微 | basics.md 不正入力の節 | `KsGridColumns.adaptive(minItemWidth:)` のリリースビルドでの動きが無い |
| M10 | 軽微 | basics.md スクロールの表 | `scrollToEnd` が見せない「フッター」に、ページングの失敗・終端の表示が入るか、待機中の一覧で読み込みが始まるかが無い |
| M11 | 欠け | paging.md「Reload from your own code」 | もう一方の方式 (取り直し中が描かれてから差し替える) のコードが無く、文も実装できる形になっていない |
| M12 | 軽微 | paging.md「Know when a running load is cancelled」 | 「先に `.appending` にしてからタスクを始める」の例が無い |
| M13 | 軽微 | paging.md | `retry` の型が書かれていない |
| M14 | 軽微 | paging.md「Add pull to refresh」 | 自分のコードで取り直している間の引っ張りが受け付けられるか・受け付けられないときの見え方が無い |
| M15 | 欠け | reorder.md「Offer move actions to VoiceOver users」 | `KsReorderAccessibilityActions(previous:next:)` の引数の型 (`String` か `LocalizedStringKey` か) が無い |
| M16 | 軽微 | reorder.md | `onMove` が呼ばれるスレッドが無い (`canMove`・`canDrop` はある) |
| M17 | 欠け | images.md「Enable the disk cache at launch」 | `ImagePipeline.Delegate` を使うアプリが自分で `ImagePipeline.shared` を組むコードが無い。Nuke を自分で依存に足すときの URL と版も無い |
| M18 | 軽微 | 同上 | `enableSharedDiskCache()` の上限・置き場・捨て方が無い |
| M19 | 軽微 | images.md「Show an image in a cell」 | `KsImage` の引数の一覧と並びが無い。失敗の表示の色が無い |
| M20 | 軽微 | images.md「Clear or remove cached images」 | `.file` の源に対する `remove` の動きが無い |
| M21 | 軽微 | layout.md「Place the list full screen under the bars」 | 横向きの左右の安全領域で、行が切り欠きの下に入るのか分からない |
| M22 | 軽微 | 全体 | 項目が class のインスタンスでよいかが無い |
| M23 | 軽微 | SKILL.md | UIKit のアプリから使う方法が無い |
| M24 | 軽微 | SKILL.md「Setup」 | `Package.swift` の断片に `platforms: [.iOS(.v16)]` が無い |
| O1 | 軽微 | SKILL.md「Setup」 | 版は releases のページで調べるしかない |
| O3 | 軽微 | reorder.md「Know how the drag behaves on iOS」 | 「standard UIKit reordering」を知っている前提 |
| C1 | 重大 | paging.md「Write the model...」「Know when a running load is cancelled」 | 「取り消された取得はたいてい `CancellationError` を投げる」とあり、例は `catch is CancellationError` のほかをすべて失敗にする。`URLSession` の async の関数は、取り消しで `URLError` の `.cancelled` を投げるので、例のとおりに書くと、読み込み中に一覧が消えたときに失敗の状態になる |
| C2 | 欠け | basics.md「What happens with invalid input」 | 「項目を落とさない」と、ID の重複の行の「後の要素が勝つ」が合わない |
| C3 | 軽微 | paging.md 状態の表 | `.refreshing` の行の「次の差し替えは先頭から表示される」が、「Reload from your own code」の条件 (一度描かれた後だけ) より強く書かれている |
| C4 | 軽微 | paging.md「Defaults」 | 「3 つの表示は最低限渡す」と書きながら、同じ 1 枚の例 3 つが渡していない |
| C5 | 軽微 | reorder.md「Move items across groups」 | 「`move(_:)` の `else` の分岐」とあるが、`else` は 1 つだけ |
| C6 | 軽微 | reorder.md「Reorder a list that is sorted」 | 本文の `model.isReordering && !model.isSorted` に当たるプロパティを持つモデルが、同じ 1 枚に無い |
| C7 | 軽微 | basics.md・paging.md | 例の名前 `FeedScreen` が 2 枚で重なっている |
| C8 | 軽微 | basics.md「Scroll from code」 | 「命令は落とされない」と、次の項目の「つながっていない・ID が無いときは何もしない」が合わない |
| C9 | 軽微 | basics.md「Read parent state inside a row」 | 「無いと届かない」と「無いと毎回作り直される」が、注意して読まないと食い違って読める |
| C10 | 軽微 | reorder.md | ドラッグの動きを「iOS 18 と iOS 26 で見た」とあるが、下限は iOS 16。16・17・27 に触れていない |
| C11 | 軽微 | reorder.md `moveAndSave` | 保存の失敗で `restore(original)` すると、保存中に行った後の移動も消える。注意が無い |
| N1 | 軽微 | SKILL.md の表と References | 表にも要約にも無く、ファイルを開かないと見つからない見出しがある (セルの大きさと位置・スクロールの目印・読み込みの取り消し・ソート済みの一覧の並べ替え・ドラッグ中に止まるもの・起動時のディスクキャッシュ・Nuke のビュー) |
| N2 | 欠け | — | 行き先も「対応していない」の記述も無い作業: スワイプの操作・選択・コンテキストメニュー・横スクロール・スクロール位置の読み取りと復元・上へ向かう読み込み・ページングなしの空の表示・編集できる行・`.searchable`・グループの折りたたみ・グループの見出しのタップ |

外への依存: O1・O3 と M17 (Nuke の文書を前提にしている) のほかは無い。不具合の報告先の URL・frontmatter の URL・相手の Skill の名前は、頼っていないので問題なし、との報告。コンパイルできないと考える例は無い、との報告。

結末 (直す / 直さない理由) は `dist-read-dispositions.md` に書く。
