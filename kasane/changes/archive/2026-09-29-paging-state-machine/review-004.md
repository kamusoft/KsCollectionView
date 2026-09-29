# レビュー結果: paging-state-machine (004 回目)

**日付**: 2026-09-29
**判定**: APPROVED

## サマリー

review-003 と verify-002 の後に入った変更を見ました。対象は次の 4 つです。

- 差し替えた「次のページの読み込み中」の表示のタッチを Android でも止める修正
- `bottomOverlapPx()` の KDoc の追記
- 既定の読み込み中の表示から円の下地を外した修正 (両プラットフォーム)
- verification/ の 4 枚の撮り直しと、体感ゲートの 2 つの証跡

下地を外した後も、次の 5 点は両プラットフォームで保たれていました。公開 doc と実装も一致しています。

- 位置: 表示の下端 = 見えている範囲の下端 − (下端の安全領域 + 8)
- タッチ: 既定の表示は全部を下へ通し、差し替えた表示はその範囲のタップを止める
- フェード
- 読み上げ
- 出る条件

試験は下地が無いことを、読み込み中の部品そのものの大きさと下端の位置で確かめています。collection-paging の Scenario「次のページの読み込み中 (既定)」は、verify-002 の表のとおり ⚠️ (deviation 記録済み) のまま成り立っています。

新しい指摘は Minor 2 件と Suggestion 1 件で、どれもマージを止めるものではありません。

- Minor 1: 差し替えた表示の範囲から始めたドラッグで、Android だけ一覧がスクロールしない。スクラッチの写しに一時的な試験を足して確かめた
- Minor 2: 体感ゲートの証跡で、いくつかの項目が抜けている
- review-003 の Suggestion 2 件は、どちらも解消しています

再実行したテスト (すべて絞り込みなしの全件):

- iOS ライブラリ (SwiftPM、新しく作った Simulator `ksn-paging-review4`、iPhone 17 / iOS 26.5): **439 件成功 / 失敗 0**
- iOS Sample UI テスト (通常スキーム、新しく作った Simulator `ksn-paging-review4-ui`、iPhone 17 / iOS 26.5): **34 件成功 / 失敗 0**
  - PagingDemoUITests を含み、計測ドライバは含まない
  - 下地を外した後の初めての実行
- Android ライブラリ (`--rerun-tasks`、Robolectric): **412 件成功 / 失敗 0** (XML を集計)
- Android Sample (`--rerun-tasks`): **146 件成功 / 失敗 0** (19 クラス。XML を集計)

ホストの報告した件数と一致しています。終わった後、2 つの Simulator は停止しました。

## 照合した規約

- **ソースコメント規約** (always)
  - `comment-policy-lint.py --advisory` の結果、禁止は 0 件でした (検査対象 407 ファイル)
  - 今回の差分に当たる要確認は `KsPagingDisplay.kt:48`・`KsTopSafeArea.kt:86` (internal の doc の ADR 参照)、`KsCollectionView+Paging.swift:39` (「同値のままだった場合」の誤検出) です。どれも公開 doc ではなく、適合と判断しました
  - 書き換えた公開 doc (`KsPaging.kt:56-61`・`KsCollectionView+Paging.swift:65-73`) に、ADR ID や内部用語は入っていません
- **スクロール性能の体感ゲート** (`evidence/` の性能証跡)
  - 2 つの証跡とも 6 節 (環境・操作条件・オーナーの体感・数値・判定・限界) がそろっています
  - 節の中の項目の抜けは下の Minor 2 に書きました
- **iOS / Android の性能検証**: 記録手段・取得源・指標名と単位は、各プラットフォームの文書の形に沿っています
- **テスト実行規約**
  - 4 系統とも全件を実行し、件数を確かめました
  - Android は `--rerun-tasks` を付けて XML を集計しました
- **Sample のプラットフォーム間一致**
  - 撮り直した 4 枚の見え方を比べ、下地の有無・置き場・パネルとの位置関係が一致していることを確かめました
  - 標準の部品の形の違い (iOS の放射状 / Android の円弧) は、OS 標準の部品の自然な形の差です

accepted な ADR (core/ADR-0005・0011・0017・0018、ios/ADR-0006・0008・0009・0010、android/ADR-0001・0003・0006) と照合し、反する点はありませんでした。proposed の core/ADR-0019〜0025 は決定ではないため、判定の根拠にはしていません。ADR-0024 の「標準のくるくるだけで文言を持たない」とは、下地を外したことでむしろ近づいています。

## 前回までの指摘の再確認

| 指摘 (出典) | 状態 | 確かめたこと |
|---|---|---|
| 差し替えた表示が操作を持たないとき、iOS だけその範囲のタッチを止める (review-003 Suggestion 1) | 解消 (タップについて) | 修正は `KsCollectionView.kt:705,719-723` の `ksBlockingTouches`、公開 KDoc は `KsPaging.kt:56-61`、試験は `KsPagingAppendingIndicatorTest.kt:174`。押せる部品を持たない差し替えた表示でも、範囲のタップが下の項目へ届かず、範囲の外は通ることを試験が確かめています。ドラッグは下の Minor 1 のとおり、まだ差があります |
| `bottomOverlapPx()` の KDoc が新しい用途を書いていない (review-003 Suggestion 2) | 解消 | `KsTopSafeArea.kt:84-86` に「次のページの読み込み中の表示を、見えている範囲の下端から下端の安全領域の分だけ上げて重ねるために使う」が足されました |
| 既存の解消済みの指摘 (review-001〜002、code-001〜003) | 解消のまま | 取り直しの先頭の規則・しきい値の比べ方・下端の重なりの座標・待ち方の控えの経路は、今回の差分で触れられていません |

## 下地を外した修正の突き合わせ

| 観点 | iOS | Android | 結果 |
|---|---|---|---|
| 既定の見た目 | `KsPagingDefaultIndicator` は `ProgressView().progressViewStyle(.circular)` だけ (`KsPagingDefaultIndicator.swift:5-10`) | `KsPagingAppendingIndicatorDefault` は `CircularProgressIndicator` だけ。直径 24dp・線 2.5dp (`KsPagingDisplay.kt:73-86`) | 一致。撮り直した ios-02 / 02b・android-02 / 02b でも下地はありません |
| 位置 | `safeAreaInsets.bottom + 8` (`KsCollectionViewController.swift:1694-1697`)。入れ物の中身は下端に合わせ、`margins(.all, 0)` で余白を足さない | `bottomOverlapPx() + 8dp` を `offset` で上げる (`KsCollectionView.kt:710-714`) | 一致。どちらも contentPadding を見ていません |
| 位置の試験 | 中身の下端が「高さ − 安全領域 − 8」にあり、中身の大きさが `UIActivityIndicatorView` の大きさと同じ (`KsPagingIndicatorTests.swift:36-47`)。下の余白 0 / 40 / 100 で同じ | 不定の進捗の節点そのものの下端が「高さ − 8」にあり、直径が 24dp (`KsPagingAppendingIndicatorTest.kt:203-207`)。下の余白 0 / 100・list / grid・ナビゲーションバー 48dp | 一致。もし下地が戻ると、部品が枠の中で上がるため、どちらの試験も失敗します。下地の有無と位置を実際に確かめている試験です |
| タッチ (既定) | `isReplaced(.appendingIndicator)` が false のときは `receivesTouches = false` で、`hitTest` が nil を返す | 修飾を付けずに描く | 一致。下の項目のタップが届くことを両方の試験が確かめています (`KsPagingIndicatorTests.swift:135` / `KsPagingAppendingIndicatorTest.kt:134`) |
| タッチ (差し替え) | 中身の範囲だけ受ける | `ksBlockingTouches` で範囲を止める | タップは一致。ドラッグは Minor 1 |
| フェード | 0.2 秒 (変更なし) | 200ms (変更なし) | 一致 |
| 読み上げ | 標準の `ProgressView` が `activityIndicators` として木に出る。Sample の UI テスト (`PagingDemoUITests.swift:203`) が下地を外した後も通過 | `ProgressBarRangeInfo.Indeterminate` を数える試験が通過 | 一致 |
| 出る条件 | `resolve` と `placement == .bottomOverlay` (変更なし) | `appendingIndicator != null && state == Appending` (変更なし) | 一致 |
| 公開 doc | 「標準の読み込み中の表示がそのまま (下地なしで) 出ます。既定の表示はタッチを受けず、下の項目を押せます」(`KsCollectionView+Paging.swift:70-72`) | 「標準の読み込み中の表示が下地なしで出て、タッチは受けずに下の項目へ通します」(`KsPaging.kt:58-60`) | 実装と一致 |

### Scenario 対応 (collection-paging「次のページの読み込み中 (既定)」)

| Scenario | 実装 | テスト | 状態 |
|---|---|---|---|
| 次のページの読み込み中 (既定): 項目があり差し替えていない一覧で状態を追加読み込み中にすると、標準の読み込み中の表示が現れ、文言は出ない | iOS `KsPagingDisplays.swift:20-21` → `KsPagingDefaultIndicator.swift`、`updatePagingIndicator` (`KsCollectionViewController.swift:1631`) / Android `KsPaging.kt:91` → `KsPagingDisplay.kt:81`、`KsCollectionView.kt:698-724` | `KsPagingDisplayTests.swift:48`、`KsPagingIndicatorTests.swift:23,62` / `KsPagingDisplayTest.kt:72`、`KsPagingAppendingIndicatorTest.kt:62,68,76,82` | ⚠️ deviation 記録済み |

- 置き場は「最後の項目の後ろ」から「見えている範囲の下端」に置き換わっています (`deviation.md:10,11`)
- 下地を外したことは `deviation.md:17` と照合結果の 6 にあります
- 「標準の読み込み中の表示が現れ、文言は出ない」は、両プラットフォームで一致しています
- verify-002 の判定から変わっていません。食い違いはありませんでした

## 指摘事項

### [🟡 Minor] 差し替えた「次のページの読み込み中」の範囲から始めたドラッグで、Android だけ一覧がスクロールしない

**該当箇所**:
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:705,719-723,752-758` (`ksBlockingTouches`)
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPaging.kt:59-61` (公開 KDoc)
- 比較: `ios/Sources/KsCollectionView/KsPagingIndicatorView.swift:45-49`、`ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:71-72`

**問題点**:
- `ksBlockingTouches` は重ねた表示の範囲で当たり判定を取ります。その結果、兄弟にあたる `LazyColumn` / `LazyVerticalGrid` にはポインタの入力が届きません
  - 止まるのはタップだけではありません。範囲の中で始めた縦のドラッグ (スクロール) も一覧に届きません
- スクラッチの写しに一時的な試験を足して、Robolectric で確かめました (リポジトリには置いていません)
  - 押せる部品を持たない差し替えた表示 (120×30dp の `Text`) の中から 300dp 上へ swipe すると、先頭の項目の位置は 0dp のまま動きませんでした
  - 範囲の外 (左端) から swipe したとき、および既定の表示の上から swipe したときは、一覧がスクロールしました
- iOS では、入れ物が `UICollectionView` のサブビューです
  - 差し替えた表示がタッチを受けても、一覧のパンのジェスチャーは祖先のビューとしてタッチを受け取ります
  - そのため、範囲の中から始めたドラッグでもスクロールする見込みです。これはビューの階層からの推論で、試験では確かめていません
- 結果として、タップはそろったものの、ドラッグでプラットフォーム差が残っています
  - 公開 KDoc の「表示の範囲のタッチを受け止めて下の項目へ通しません」は、スクロールも止まることまでは読み取りにくい書き方です
  - verify-002 の「両プラットフォームで同じ振る舞いにそろった」は、タップについてだけ成り立ちます
- 起きるのは、利用者が表示を差し替えた一覧で、画面の下端の中央の小さな範囲から指を置いたときだけです
  - 既定の表示と Sample には影響しません (Sample は表示を差し替えていません)
  - 速いフリックの最中に、その範囲に指を置いて止めることもできません

**推奨修正** (どちらか。オーナー判断):
1. Android で、表示の範囲から始めたドラッグを一覧のスクロールへ渡す。例えば、止める側の Box に、一覧の状態を渡した `Modifier.scrollable` (向きは一覧と同じ) を付ける。タップは止め、スクロールは iOS と同じく通すことになる。試験には、範囲の中から始めた swipe でスクロールすることを足す
2. 差として受け入れ、公開 KDoc に「範囲の中から始めたスクロールも一覧へ渡りません」と書く。phase-7 のガイドにも、プラットフォームごとの差として書く。deviation.md に記録する

### [🟡 Minor] 体感ゲートの証跡で、「環境」「操作条件」の項目の一部が抜けている

**該当箇所**:
- `kasane/changes/paging-state-machine/evidence/perf-android-paging.md:3-15`
- `kasane/changes/paging-state-machine/evidence/perf-ios-paging.md:11-15,62-66`

**問題点**:
- 6 節はそろっていますが、`handbook/cross/scroll-performance-gate.md` の「証跡に残す項目」の表が求める項目のうち、次が書かれていません
  - Android の「環境」: OS の版 (機種の Pixel 4a だけ)
  - 両方の「操作条件」: 文字サイズと到達範囲 (どの項目まで送ったか)
  - Android の「環境」: 熱状態は「記録していない」とあり、「限界」にも書かれていて正直です。ただ、次回との比較にはこの値が要ります
- 規約は「節を欠いた記録は次回との比較に使えない」としています。今回は初めての記録のため比較の対象はなく、合否には影響しません。次にこの画面を測り直したときに、条件がそろっているかを判断できなくなります

**推奨修正**: 分かっている事実 (Android の OS の版、文字サイズを既定のまま使ったか、到達した項目の番号の目安) を追記してください。分からない項目は「未記録」と書き、「限界」に並べてください。オーナーの聞き取りが要る項目は、蒸留の前に確かめる程度で足ります。

### [🔵 Suggestion] iOS の 2 つの既定の読み込み中の表示が、同じ中身になった

**該当箇所**: `ios/Sources/KsCollectionView/KsPagingDefaultIndicator.swift:5-10`、`ios/Sources/KsCollectionView/KsPagingDefaultProgress.swift:5-10`

**問題点**:
- 下地を外したことで、`KsPagingDefaultIndicator` と `KsPagingDefaultProgress` は、同じ `ProgressView().progressViewStyle(.circular)` だけの型になりました
- 実害はありません
- 別 change `paging-indicator-color` で色を指定できるようにするときに、片方だけ直す取りこぼしが起きえます

**推奨修正**: 急ぎません。`paging-indicator-color` で色を足すときに、2 つを 1 つにまとめるか、別のままにする理由 (0 件の真ん中と下端とで見た目を分ける余地を残す、など) をコメントに書くかを決めてください。Android は大きさが違う (40dp / 24dp) ため、分けておく理由があります。

## 所見 (指摘ではない)

- **iOS の体感ゲートは、下地を外す前の実装で判定しています**
  - `perf-ios-paging.md` の 2 回目の判定と限界に、「飾りを外すだけでスクロールと追加読み込みの経路は変わらないため取り直さない」と理由付きで書かれています
  - 実装を見ても、変わったのは中身の SwiftUI の見た目 (material の円と影を外した) だけです。描く量は減る向きなので、判定を覆す根拠は見当たりません
  - Android は、下地を外した後の実装で採られています
- **Android の既定の直径 24dp**
  - `KsPagingAppendingIndicatorDefault` の KDoc の「標準の不定の読み込み中の表示を下地なしでそのまま出す」は、大きさを 24dp に指定していることと少しずれた言い方です
  - 直前の定数のコメントに理由 (iOS の標準の大きさに近づける) があり、照合の画像で承認済みのため、指摘にはしません
- **verify-002 の行番号**
  - verify-002 の表の `KsPagingIndicatorTests.swift:23,58` は、今の作業ツリーでは `23,62` です (下地が無いことの確かめを足して行がずれた)
  - Android の `KsPagingAppendingIndicatorTest.kt:59,65,73,79` も、今は `62,68,76,82` です
  - 表の中身の対応は変わっていません
- **足場**
  - proposal / design / specs は HEAD から書き換えられていません
  - tasks 7.2〜7.4 のチェックは、2 つの証跡の判定 (オーナーの目視で問題なし) と一致しており、虚偽ではありません
- **撮り直した 4 枚**
  - ios-02 / 02b・android-02 / 02b のどれも、下地の無い標準の読み込み中の表示が、最後に見えている行 (Item 50) の上、下端の安全領域の上に出ています
  - パネルを広げた 02b でも、表示はパネルの下に見えています
  - 個人を特定する情報は写っていません

## 確認した観点 (問題なし)

- **仕様充足**
  - 上の突き合わせの表のとおりです
  - 「最初の読み込み中 (既定)」は `KsPagingDefaultProgress` のままで変わっていません
  - 「失敗・終端・空は既定では出ない」も、表示の振り分けが変わっていないため保たれています
- **deviation.md と brief の照合結果**: 下地を外したこと (`deviation.md:17`、照合結果 6) は合意済みの差として扱い、違反としていません
- **堅牢性**
  - 差し替えた表示で `EmptyView()` / 何も描かない Composable を渡したときも、範囲の大きさが 0 になるだけです。タッチを余計に止めることはありません
  - 消えるフェードの間も `rememberUpdatedState` で同じ中身を描き、止めるかどうかは差し替えの有無だけで決まるため、フェードの途中で振る舞いが変わりません
- **Kotlin (kotlin-impl-skill)**
  - `ksBlockingTouches` は `pointerInput(Unit)` の中で `awaitPointerEvent` を回すだけで、消費しません。そのため、中の部品 (ボタン) は変わらずタッチを受け取れます (`KsPagingAppendingIndicatorTest.kt:147` の `clickable` の試験が通過)
  - キャンセルは `pointerInput` のコルーチンの取り消しに任せていて、`CancellationException` を握りつぶしていません
  - `!!`・`GlobalScope`・`runBlocking` は使っていません
- **テスト**
  - 下地の有無・位置・タッチ (既定 / 差し替え、タップ)・フェード・読み上げが、両プラットフォームで試験されています
  - 待ち方は条件で待つ形 (`waitUntil`・`awaitCondition`) で、固定の待ちはありません
- **ソースコメント**: 新しいコメントと KDoc は、外部文書の ID に頼らずに読めます (ADR ID は internal のコメントだけ)

## アクションプラン

1. **(Minor・オーナー判断)** 差し替えた表示の範囲から始めたドラッグの Android と iOS の差を、そろえるか (推奨修正 1)、受け入れて公開 KDoc と deviation.md に書くか (推奨修正 2) を決める
2. **(Minor)** 体感ゲートの証跡に、Android の OS の版・文字サイズ・到達範囲を追記するか、「未記録」として限界に並べる
3. **(任意)** `paging-indicator-color` で、iOS の 2 つの既定の読み込み中の表示をまとめるかを決める

---

再実行の記録:

- iOS は、このレビュー用に作った Simulator `ksn-paging-review4` (ライブラリ) と `ksn-paging-review4-ui` (Sample UI テスト) (どちらも iPhone 17 / iOS 26.5) で実行し、終わった後に停止しました。既存の Simulator・エミュレータ・実機には触れていません
- Minor 1 の確かめは、`android/` をスクラッチに写した中にだけ一時的な試験を足して行い、リポジトリの作業ツリーは変えていません。写しは確認の後に trash で片付けました
- Android は Robolectric (エミュレータなし) です
