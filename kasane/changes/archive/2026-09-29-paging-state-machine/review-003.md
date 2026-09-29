# レビュー結果: paging-state-machine (003 回目)

**日付**: 2026-09-28
**判定**: APPROVED

## サマリー

review-002 の後の主な変更は 5 つです。次のページの読み込み中の表示を見えている範囲の下端に重ねる形に変えたこと、公開 API の改名、iOS のルートのヘッダー / フッターの枠の測り直し ([付随修正])、両 Sample のパネルの置き方、SwiftUI の `.refreshable` の経路の試験です。どれも deviation.md の 6 項目と brief の照合結果 (2 回目) のとおりに、両プラットフォームで同じ観察可能な振る舞いとして実装されていました。重ねる形に変えたことで、他の Scenario・読み上げ・タッチ・フェード・0 件の表示・フッターの枠の高さとの食い違いは見つかりませんでした。前回までに解消した指摘も戻っていません。

新しい指摘は Suggestion 2 件だけです (差し替えた表示のタッチの通し方の小さなプラットフォーム差、internal の KDoc の用途の書き漏れ)。マージを止めるものではありません。tasks 7.2〜7.4 (目視と体感ゲート) は未チェックのまま正直に残っており、オーナーのゲートとして残っています。

再実行したテスト (すべて絞り込みなしの全件):

- iOS ライブラリ (SwiftPM、新しく作った Simulator `ksn-paging-review3`、iPhone 17 / iOS 26.5): **439 件成功 / 失敗 0**
- iOS Sample UI テスト (通常スキーム、新しく作った Simulator `ksn-paging-review3-ui`): **34 件成功 / 失敗 0** (PagingDemoUITests を含む。計測ドライバは含まない)
- Android ライブラリ (`--rerun-tasks`、Robolectric): **411 件成功 / 失敗 0** (25 クラス。XML を集計)
- Android Sample (`--rerun-tasks`): **146 件成功 / 失敗 0** (19 クラス。XML を集計)

ホストの報告した件数と一致しています。終わった後、2 つの Simulator は停止しました。

## 照合した規約

- **ソースコメント規約** (always)
  - `comment-policy-lint.py --advisory` の結果、禁止は 0 件でした (検査対象 407 ファイル)
  - 要確認のうち、今回の変更に当たるのは次の 2 種類です。どちらも適合と判断しました
    - `KsPagingDisplay.kt:52`: internal な enum の companion の doc で、公開 doc ではありません
    - `KsCollectionView+Paging.swift:39`・`KsCollectionViewController.swift:1839`: 「同値のままだった場合」という条件の言い回しを拾った誤検出です
  - 改名した公開 doc (`pagingAppendingIndicator`・`KsPaging.appendingIndicator`) に、ADR ID や内部用語は入っていません
- **Sample のプラットフォーム間一致** (`samples/**` を触る)
  - パネルの置き方は両プラットフォームで同じ構造です
    - 一覧の下の余白は下端の安全領域の分だけにしている
    - パネルを「下端の安全領域の境目 + 上げる量」の位置に浮かせている
  - 上げる量の差 (iOS 100pt・Android 128dp) は deviation.md に理由付きで記録されています
  - 文言・件数・構成の差は見つかりませんでした
- **テスト実行規約** (テストの実行・報告)
  - 4 系統とも全件を実行し、件数を確かめました
  - Android は `--rerun-tasks` を付けて XML を集計しました
- **実行時挙動の検証規約** ([付随修正] は不具合修正のため)
  - 余白の変化で枠が測り直されない症状は、Simulator の実レイアウトの試験 (`KsContentPaddingChangeTests`) で再現できる種類です
  - 下の「A/B の確認」のとおり、修正を外すと失敗し、入れると通ることを確かめました
- **スクロール性能の体感ゲート・iOS / Android の性能検証** (スクロール経路・大量件数)
  - `evidence/perf-ios-paging.md` は、1 回目の走行を「未判定」とし、直した後の実装で採り直すとしています
  - Android の体感ゲートの証跡はまだありません
  - tasks 7.2〜7.4 は未チェックのままです。オーナーの目視のゲートなので、このレビューでは合否を判断していません

accepted な ADR (core/ADR-0005・0011・0017・0018、ios/ADR-0006・0008・0009・0010、android/ADR-0001・0003・0006) と照合し、反する点はありませんでした。proposed の core/ADR-0019〜0025 は決定ではないため、判定の根拠にはしていません。次のページの読み込み中の表示の置き場の変更 (ADR-0024 の「いちばん下の項目のすぐ下」との差) は deviation.md にあります。ADR 本文への反映は蒸留で扱う事項です。

## 前回までの指摘の再確認 (戻っていないこと)

| 指摘 (出典) | 状態 | 確かめたこと |
|---|---|---|
| 取り直しの先頭の規則が描画の回のまとまり方で効かない (review-001 NEEDS_DISCUSSION) | 解消のまま | 両プラットフォームで、`isPullRefreshing` の間の差し替えを先頭にする経路は変わっていません。公開 doc の説明も残っています |
| iOS の大きいしきい値で落ちる (review-001 Major / code-001) | 解消のまま | `KsPagingRequester.swift` の変更は review-002 の時点から無く、`Double` のまま比べています |
| Android の下端の重なりの座標の混在 (review-001 Major / code-001) | 解消のまま | `KsTopSafeArea.bottomOverlapPx()` の変更は review-002 の時点から無く、下のとおり、次のページの読み込み中の表示の置き場もこの値を使っています |
| 待ち方の控えを捨てる判定 (review-001 Minor) | 解消のまま | iOS の `update(configuration:)` の冒頭の `observe`、Android の `SideEffect` の `observe` はそのままです |
| 取り直しが配列を変えずに終わったときの iOS と Android の差 (review-002 Minor) | deviation.md に記録済み | 合意済みの差として扱います |
| iOS の SwiftUI `.refreshable` を通る先頭の試験が無い (review-002 Suggestion) | 解消 | `KsPullToRefreshTests.swift:467` `testSwiftUIのrefreshableで取得がすぐ終わる取り直しでも先頭が表示される` が足されました。`ObservableObject` の VM を `UIHostingController` に載せる形です |

## 重ねる形への変更と他の契約との突き合わせ

パッケージの重点の依頼に沿って、Scenario と観点ごとに両プラットフォームを突き合わせました。

| 観点 | iOS | Android | 結果 |
|---|---|---|---|
| 出る条件 | `KsPagingDisplay.resolve` が `(.appending, false)` のときだけ `.bottomOverlay` を返す。`updatePagingIndicator()` は init と毎回の update で呼ばれる | `visible = appendingIndicator != null && state == Appending` (項目が 1 件以上のときだけ `appendingIndicator` が作られる) | 一致。「VM が始めた取り直しの間は項目の上に何も出さない」「状態だけが変わったとき」「失敗・終端・空は既定では出ない」は、重ねる経路でも成り立つ |
| 高々 1 つ | 0 件の入れ物・フッターの枠と排他 (`placement` で振り分け) | `isFooter` で振り分け、0 件では作らない | 一致 (下の所見のフェードの重なりを除く) |
| 置き場 | 表示範囲 (`frameLayoutGuide`) に固定し、下端から「`safeAreaInsets.bottom` + 8」 | `BottomCenter` に置き、「`bottomOverlapPx()` + 8dp」だけ上げる | 一致。contentPadding を見ないことは両方の試験で確かめている (iOS: 余白 0 / 40 / 100、Android: list / grid) |
| スクロールで動かない | 試験で 600 / 1,200 へ送っても frame が同じ | `scrollBy` の後も同じ位置 | 一致 |
| フッターの枠の高さ | 追加読み込み中も枠の高さと表示範囲が変わらない (`test待機に戻ると消えフッターの枠の高さは追加読み込み中の間も変わらない`) | `footerSlotHeightDoesNotChangeWhileAppending` | 一致。design の Risks の「フッターの枠の高さが状態だけで変わる」は、失敗・終端の出入りだけになった |
| フェード | 0.2 秒。フェードの途中でまた出すと消さない (`removeAllAnimations` の前に印を立てる順序を確認) | `fadeIn` / `fadeOut` の 200ms。消える間も `rememberUpdatedState` で同じ中身を描く | 一致 |
| タッチ (既定) | `receivesTouches = false` で `hitTest` が nil。下の項目の選択が届く | タッチの修飾を付けず、下の項目へ通る | 一致 |
| タッチ (差し替え) | 中身の範囲だけ受け、外は通す | 中身が受ける修飾を持てば受け、外は通す | ほぼ一致 (下の Suggestion 1) |
| 読み上げ | `UIActivityIndicatorView` として木に出る。Sample の UI テスト (`PagingDemoUITests.swift:203`) が、項目があるときの読み込み中を `activityIndicators` で見つけている。ライブラリは読み上げの名前を与えていない | `ProgressBarRangeInfo` の不定の進捗 (`KsPagingAppendingIndicatorTest`・`KsPagingDisplayTest.kt:315`) | 一致 |
| 0 件の表示 | `KsPagingPlaceholderView` と真ん中の置き方は変わっていない | 変わっていない | 変更なし |
| 発火の判定 | 表示は一覧のサブビューで、セルでも補助ビューでもないため、数える対象に入らない | `pagingInput` は lazy の項目だけを数え、重ねた表示は lazy 要素ではない | 一致 (「見出しとフッターは数えない」) |
| 端への挿入 (collection-core) | 「末尾」はフッターの枠の下端のまま。追加読み込み中に枠が伸びなくなったため、末尾の定義は失敗・終端の表示だけを含む | 同じ | 一致。「追加読み込みで届いたページは今の位置の下に現れる」の試験は両方とも通過 |

**追加の確認 (リポジトリには置いていない)**

- iOS で重ねた入れ物は `UICollectionView` のサブビューです。スクロールでセルが足されたときに、差し替えた表示がセルの下に回ってタッチを受けなくなる恐れを疑いました
- 作業ツリーの写しに一時的な試験を足し、差し替えた表示を出したまま 600 / 1,200 / 2,400 / 3,000 へ送って、その都度 `window.hitTest` を調べました
- 結果は、どの位置でも差し替えた表示がタッチを受けました。入れ物はサブビューの並びの後ろから 3 番目に留まり、セルはその手前 (下) に挿し込まれていました

**A/B の確認 ([付随修正])**

- 同じ写しで、`update(configuration:)` の余白の変化での作り直し (`KsCollectionViewController.swift:286-288`) を外し、`KsContentPaddingChangeTests` を実行しました
- 修正を外すと 4 件中 4 件が失敗しました
  - 枠が縮まない / 伸びない (ページングの有無 × フッターの有無のうち、中身から高さを決める 3 通り)
  - ヘッダーの枠が測り直されない
  - 作り直しの回数が増えない
- 修正を入れた作業ツリーでは、全件の実行で通過しています
- 同梱の条件にも収まっています
  - 本務で触るファイル 1 つと試験 1 ファイルで、公開 API・ADR に触れない
  - 局所的で、分岐をユーザーに選ばせるものではない
- ヘッダーの無い構成で `rootHeader` の枠を名指しして測り直させても、落ちないことを試験で確かめています (`makeConfiguration` は上の余白 0・ヘッダーなし)

## 指摘事項

### [🔵 Suggestion] 差し替えた「次のページの読み込み中」が操作を持たないとき、iOS だけその範囲のタッチを止める

**該当箇所**:
- `ios/Sources/KsCollectionView/KsPagingIndicatorView.swift:45-49` (`hitTest`)
- `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift:70-72` (公開 doc 「その表示の範囲だけタッチを受けます」)
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsPaging.kt:56-60` (公開 KDoc 「表示の範囲の外のタッチは下へ通します」)

**問題点**:
- 利用者が文言だけの表示 (ボタンを持たない `Text` など) に差し替えた場合、両プラットフォームで振る舞いが分かれます
  - iOS: その範囲のタッチを入れ物が受け、下の項目のタップが届きません
  - Android: 中身がタッチの修飾を持たなければ、下の項目へ通します
- ボタンを持つ表示では、両方とも中身が受けます。両プラットフォームの試験も、中身がタッチを受ける形 (iOS は UIView の背景、Android は `clickable`) で書かれています
- 公開 doc もこの差のとおりに書き分けられており、誤りではありません
- 起きるのは、差し替えた表示の上をタップしたときだけで、狭い範囲です

**推奨修正** (どちらか。急がない):
1. 差として受け入れる。phase-7 のガイドで、差し替えた表示の下の項目を押せるかどうかをプラットフォームごとに書く
2. iOS も「中身の中の操作できる部品だけが受ける」にそろえる。例えば、ホスティングの中身自体が当たったときは nil を返す。ただし SwiftUI の中身のどこが当たるかの判定は UIKit から見分けにくいため、1 が現実的です

### [🔵 Suggestion] `bottomOverlapPx()` の KDoc が、新しい用途 (次のページの読み込み中の置き場) を書いていない

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsTopSafeArea.kt:81-89`

**問題点**:
- KDoc は用途を「項目が 0 件のときのページングの表示を、上下の安全領域を除いた範囲の真ん中に置くために使う」とだけ書いています
- 今は `KsCollectionView.kt:709` の、次のページの読み込み中の表示の縦の位置にも使われています
- internal のコメントで実害はありません。ただ、この値を変えるときに影響の範囲を読み違える恐れがあります

**推奨修正**: 用途に「項目があるときの次のページの読み込み中の表示を、下端の安全領域の上に置くためにも使う」を足してください。

## 所見 (指摘ではない)

- **フェードの間の重なり**
  - 状態が追加読み込み中から失敗 / 終端に変わると、下端の読み込み中の表示が 0.2 秒で消える間に、フッターの枠に失敗 / 終端の表示が出ます
  - 両プラットフォームとも同じで、「短いフェードで出入りする」(照合結果 2 回目で承認) の帰結です。「高々 1 つ」の違反とは扱いません
- **tasks.md 6.3 の文面**
  - 「一覧の下の余白にパネルの高さの分を入れる」のままチェックされています
  - deviation.md の「パネルを上げて浮かせる」項目で置き換えられた合意済みの差なので、虚偽のチェックとは扱いません
- **足場**: proposal / design / specs は HEAD から書き換えられていません
- **既存の文面との整合**
  - 公開 doc と KDoc に、改名前の `pagingAppendingFooter` / `appendingFooter` の残りはありません (ライブラリ・Sample・試験のソース)
  - design.md の Decision 1 の表と tasks 1.1 は旧名のままですが、足場のため触れない扱いが正しいです。蒸留で concepts に書くときは新しい名前を使ってください
- **依存の追加**
  - `compose-animation` は BOM の管理下で、版を持たずに足されています (`libs.versions.toml:68`)
  - Foundation が推移で持ち込む版と同じもので、新しい版の組み合わせは入っていません
- **verify-001.md**: review-002 以降の変更 (重ねる形・改名) を反映していません。蒸留の前に一致検証を取り直すかは、orchestrator が判断してください

## 確認した観点 (問題なし)

- **仕様充足**
  - collection-paging の「ページングの表示」「追加読み込みの発火」「判定し直すきっかけ」「再試行」「Pull to Refresh のインジケータ」「追加読み込みの間は引っ張れない」の各 Scenario と、重ねる形の突き合わせは上の表のとおりです
  - collection-core の 3 つの MODIFIED Scenario と 4 つの ADDED Scenario の経路も見ました。samples の「末尾の表示が操作に隠れない」は、両 Sample の試験がパネルの最下行より下に失敗の表示と「再試行」があり、押せることを確かめています
- **deviation.md と brief の照合結果**: 合意済みの妥協 7 件と deviation の全項目は、違反として扱っていません
- **堅牢性**
  - iOS の入れ物は初めて要るときに作られ、ページングを外すと消えます
  - 消えるフェードの完了で中身を外し、フェードの途中でまた出したときは消しません
  - Android は項目が 0 件に変わったときに作らず、0 件の表示と重ならないようにしています
- **Kotlin (kotlin-impl-skill)**
  - `offset { }` の中で snapshot state を読み、配置の段でだけ位置が変わります。コンポジションをやり直しません
  - `rememberUpdatedState` で、消える間の中身を保っています
  - `!!`・`GlobalScope`・`runBlocking` は使っていません
  - 公開の `KsPaging.appendingIndicator` は explicitApi のもとで KDoc 付きです
- **テスト**
  - 置き場・スクロールで動かないこと・下の余白によらないこと・下端の安全領域・フッターの枠の高さ・フェード・タッチ (既定 / 差し替え)・読み上げを、両プラットフォームで試験しています
  - 固定の待ちではなく条件で待つ形 (`waitUntil`・`awaitCondition`) で書かれています
- **ソースコメント**: 新しいコメントは外部文書の ID に頼らず、単独で読めます (ADR ID は internal のコメントだけ)

## アクションプラン

1. **(任意・低優先)** Suggestion 1: 差し替えた「次のページの読み込み中」のタッチの通し方の差を、受け入れて phase-7 のガイドへ申し送るか、そろえるかを決める (オーナー判断)
2. **(任意)** Suggestion 2: `KsTopSafeArea.bottomOverlapPx()` の KDoc に新しい用途を足す
3. **(マージ前のゲート)** tasks 7.2〜7.4: 直した後の実装で、iOS の体感ゲートを採り直し、Android の体感ゲートと跳ねの目視を行う (オーナー)
4. **(蒸留の前)** verify を取り直すかを orchestrator が決める

---

再実行の記録:

- iOS は、このレビュー用に作った Simulator `ksn-paging-review3` (ライブラリと追加の確認) と `ksn-paging-review3-ui` (Sample UI テスト) (どちらも iPhone 17 / iOS 26.5) で実行し、終わった後に停止しました
- 追加の確認 (差し替えた表示のタッチ・付随修正の A/B) の一時的な変更は、スクラッチの写しの中にだけ置き、確認の後に trash で片付けました
- Android は Robolectric (エミュレータなし) です
