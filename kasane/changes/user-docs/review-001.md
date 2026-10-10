# レビュー結果: user-docs (001 回目)

**日付**: 2026-10-10
**判定**: CHANGES_REQUESTED

## サマリー

スクリプト・テスト・README・利用者役・追従の記録は、spec と design の形どおりで、検査が黙って空振りする経路もよく塞がれている。スクリプトのテストは 484 件・失敗 0、2 本の検査は違反なしを、自分で流して確かめた。
Skill の文書は、抜き取った事実の大半が実物と合っていたが、iOS の `references/basics.md` の不正入力の表に、実物と違う記述が 1 件ある (Major)。ほかは、文面の軽微なずれと、検査の拾い方の隙間 (Minor) である。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always) — 足したスクリプト・テスト・`MainActivity.kt` のコメント
- `kasane/handbook/cross/verification-ci.md` — `scripts/ci/` を触った (検査のロジックはスクリプトに置きテストを付ける・標準のライブラリだけ・lint の step を増やさない)
- `kasane/handbook/cross/consumer-build-check.md` — `verification/` を触った
- `kasane/handbook/cross/public-identifiers.md` — インストール例に書く値
- `kasane/handbook/cross/test-execution.md` — テストを足した・件数の報告
- `kasane/lessons/code-review.md` — L-001 (証跡の数値を自分で再現する)。L-002 は動きの過程を持つ機能の変更が無いので当たらない

ロードしたスキル: ksn-review、kotlin-impl-skill

## 確認した観点

自分で流したもの:

- `python3 scripts/ci/run-tests.py`: 実行 484 件 / 失敗 0 件 / スキップ 0 件 (証跡と一致)
- `scripts/ci/check-readme-examples.py .`: 違反なし (最小コード例 4 つ・依存の宣言の行 12 行)
- `scripts/ci/check-skills.py .`: 違反なし (Skill 4 つ・Markdown 24 枚)
- `scripts/docs/check-api-coverage.py`: iOS 83 個 (宣言 90 個)・Android 86 個 (宣言 98 個)。漏れは iOS の `buildExpression`・`buildBlock` の 4 件だけ (渡された状態と一致。証跡の数とも一致)
- `scripts/docs/skills-refresh.py status`: 変わった源泉は利用者役の画面の 2 ファイル (足された) だけ。対応の決まっていない源泉は無い
- `scripts/comment-policy-lint.py`: 禁止 0 件
- Simulator・エミュレータ・実機は使っていない。テスト 4 系統と利用者の立場のビルドの確認は流し直していない (証跡 `evidence/local-completion.md` の記載に依る)

仕様充足:

- 利用者役 (consumer-verification): iOS は 1 ファイルでモデルと画面を持ち `public` もコメントも無い。Android は package の宣言が無く import から始まる。入口は名前だけの import で呼ぶ。実物を見るテストが `scripts/ci/tests/test_verify_consumer_ios.py`・`test_verify_consumer_android.py` に足されている。古い名前 (`VerificationListScreen`・`VerificationItem`) の残りは、archive と証跡の外には無い
- README (user-readme): 9 つの節の並び・英日の一致・6 枚の画像の実在・Skill への導線・最小コード例と利用者役の一致・インストール例の値・未公開の 1 文・貢献とライセンスの導線。対応プラットフォームの表の値は、`ios/Package.swift`・`android/kscollectionview/build.gradle.kts`・`android/gradle/libs.versions.toml` と突き合わせた
- Skill の構成 (user-skills): 4 つのディレクトリが同じ 6 枚だけを持つ。frontmatter の 5 項目。本文の 5 つの節の順。できることの表が 5 枚を指す。各 `SKILL.md` の最小の動く例が利用者役のファイル (= README の例) と 1 文字も違わないことを、機械で確かめた (4 枚とも 66 行目からのブロック)
- 相手のプラットフォームのコードブロックは無い。相手の Skill は `SKILL.md:12` で名前だけ。差は各機能の場所に括弧書きで書かれ、差をまとめた節は無い (`reorder.md` の「Know how the drag behaves on …」は、そのプラットフォームの動きの説明の節である)
- 検査 (user-docs-consistency): Scenario はすべてテストに対応がある。テストは `main` を通して終了コードと違反の文面を見ている。実物への適用は `scripts/ci/tests/test_repository_files.py` の `UserDocsCheckTest`。源泉とのずれ・公開の宣言の網羅は、検証 CI のテストに入っていない
- 追従 (user-docs-refresh): 記録の 3 項目。概念の文書 14 枚がすべて `sources` にある。`status`・`record`・網羅の報告の Scenario にテストがある。公開の宣言の拾い方を、独立の grep と行単位で突き合わせた (下)
- tasks.md: チェック済みのタスクに、成果物・証跡の無いものは見つからなかった。未完了は 9.4・9.5・12.4・12.5 で、渡された状態のとおり
- 足場 (proposal・design・specs) は、作業ツリーの差分に含まれない (変わっていない)
- deviation.md は蒸留送りの 4 行だけで、付随修正の行は無い

Skill の事実の抜き取り (実物との突き合わせ。調査ワーカー 2 本に抜き取らせ、食い違いとして挙がったものは自分で実物を読んで確かめた):

- iOS `SKILL.md`: 最低の OS・Swift tools・Nuke の版・`enableSharedDiskCache()`・クロージャの隔離の段落 (`onLoadMore`・`retry`・`onMove` だけが `@MainActor`) ほか 11 箇所
- iOS `references/basics.md`: イニシャライザの引数の順と既定・`KsTemplate`・`.observedValue`・タップの modifier・`KsScrollController` の 3 つの命令と既定・不正入力の表の各行 ほか
- iOS `references/layout.md`: `.grid`・`.list`・`.fixed`・`.adaptive` の引数と型・区切り線の太さと既定色・`.groups` の 2 つの形 ほか
- iOS `references/paging.md`: `.paging(_:threshold:onLoadMore:)` と 6 つの表示の modifier の宣言 (自分でも `ios/Sources/KsCollectionView/KsCollectionView+Paging.swift` と突き合わせた)・発火の式・`retry` の条件 ほか
- iOS `references/reorder.md`: `.reorder` の引数の順と型・`KsReorderMove`・`KsReorderDestination`・`canDrop` の 1 行の例 (自分でも確かめた) ほか
- iOS `references/images.md`: `KsImage` の 5 つの呼び方・`KsImageSource` の 3 つの case・`KsResource`・`KsWidth`・`KsImageCache` ほか
- Android `SKILL.md`: 座標・`minSdk`・package・api で届く依存・`androidx.startup` の登録 ほか
- Android `references/basics.md`: `KsCollectionView` の引数 22 個の名前・順・型・既定・`KsScrollController`・不正入力の表 (デバッグの判定と `IllegalStateException`) ほか
- Android `references/layout.md`・`paging.md`・`reorder.md`・`images.md`: `KsLayout`・`KsColumns`・`KsGroups`・`KsPaging` (9 引数)・`KsPagingState`・`KsReorder`・`KsImage` の 2 つの形・`KsResource`・`KsImageCache` ほか

英語版と日本語版: 24 枚とも行数が同じで、コードブロックは機械の検査で一致。地の文は、各 1 枚で 5 段落以上を並べて読ませ、数値・既定値・否定の向きの食い違いは見つからなかった (軽微な語のずれは指摘 5)。

内部の事情の漏れ: ADR の番号・フェーズ・concepts・handbook・利用者役などの語は、Skill の 24 枚に無い (`concepts` の 1 件は英語の一般の語)。internal の型を使えるものとして書いた箇所は無い。計測用 (`@_spi`) の型の名前も出ていない。

公開の宣言の拾い方 (L-001 に沿った再現): `(public|open) ` を含む行を独立に grep し、道具が拾った行と行単位で比べた。iOS は grep の 93 行のうち道具に無いのは `@_spi(KsMeasurement)` の 2 つの型の 7 行だけ。Android は grep の 74 行をすべて拾っている。道具だけが拾う行は、enum の case・値と、`public` と書かれないコンストラクタのプロパティだけで、意図どおりである。

設計・コードの品質: 検査は標準のライブラリだけ。違反なしでも比べた数が 0 なら失敗にする二重の歯止めがある。`skills-refresh.py` は git を読むだけで、`GIT_OPTIONAL_LOCKS=0` で index も触らない。`record` は書く前に書き換えた文面を読み直している。コメントは単独で読め、作業文書への参照は無い。

決定との関係 (所見。指摘ではない):

- accepted の cross/ADR-0005 は「`SKILL.md` と `references/` は Skill 外のファイル・URL への参照を持たない」と書いている。Skill は、Package URL・Releases・Issues の URL と frontmatter の `source` を持つ。これは spec (Skill の外への参照) と proposed の cross/ADR-0019 が定めた形で、proposal が蒸留のときに 0019 を上げて 0005 に印を付けると申し送っている。実装は spec に従っているので、違反として扱わない。蒸留で 0019 を上げ損ねると、accepted の決定と実物が食い違ったまま残る

## 指摘事項

### [🟠 Major] iOS の Skill: 同じキーに `KsTemplate` を 2 つ登録したときのデバッグビルドの動きが、実物と違う

**該当箇所**: `skills/en/kscollectionview-ios/references/basics.md:313`・`skills/ja/kscollectionview-ios/references/basics.md:313`
**問題点**: 表は、デバッグビルドで「Assertion failure / assertion で停止」と書いている。実物 (`ios/Sources/KsCollectionView/KsTemplateRegistry.swift:9-18`) は、`Dictionary(..., uniquingKeysWith:)` で後勝ちに畳み、数が減っていれば `logger.warning` を出すだけで、`#if DEBUG` も `assertionFailure` も無い。デバッグでもリリースでも、止まらずに後の登録が使われる。利用者 (とそのエージェント) は、重複がデバッグで止まると読むので、止まらないことを「重複していない」と取り違える。
源泉の `kasane/concepts/core/core-model/collection-items.md:93` は「assertion」と書いているので、Skill は源泉を写している。食い違っているのは源泉とコードで、Android (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:334-336`) はデバッグで止める。この行は、使わせる確認の 5 つの課題が触らない。
**推奨修正**: 本変更はライブラリの挙動を変えない (proposal の Non-Goals) ので、Skill の英日の行を、今のコードの動き (デバッグでも止まらず、警告をログに出して後の登録を使う。Android では止まる) に合わせる。コードが契約 (concepts・core/ADR-0011) から外れていることは、本変更では直さず、指揮側がオーナーに諮る (簡易起票か、deviation.md の蒸留送りの行)。

### [🟡 Minor] iOS の Skill: 列数が 0 以下のとき、リリースビルドで警告のログは出ない

**該当箇所**: `skills/en/kscollectionview-ios/references/basics.md:307`・`:316`、`skills/ja/kscollectionview-ios/references/basics.md:307`・`:316`
**問題点**: 表の前の文が「リリースビルドでは、ログに警告を残す」と、表の全行に掛かる形で書いている。列数の行は、実物では `assert` だけ (`ios/Sources/KsCollectionView/KsCollectionLayout.swift:83-85`) で、リリースは `max(1, count)` で黙って 1 列にする (`ios/Sources/KsCollectionView/KsLayoutMetrics.swift:12-14`)。deviation.md の 4 行目が、この動きを concepts の側の直しとして蒸留に送っているので、実装者は動きを知っている。Skill の文面だけが、この行でログが出ると読める。
**推奨修正**: 列数の行に「この場合はログに何も出ない」と添えるか、前の文を「表に断りの無いかぎり」の形にする (英日とも)。

### [🟡 Minor] インストール例の検査が、決めた形でない行に書かれた具体の版を通す

**該当箇所**: `scripts/ci/check-readme-examples.py:116-120`・`:330-342`
**問題点**: 依存の宣言の行として数えるのは、3 つの正規表現にちょうど当たる行だけである。決めた形の行が 1 つあれば、同じコードブロックに足した次の行は、数えられず、違反にもならない。作業用の写しで試して、どれも終了コード 0 だった。

- `implementation("jp.kamusoft:kscollectionview:1.0.0") // pinned` (行末のコメント)
- `implementation 'jp.kamusoft:kscollectionview:1.0.0'` (Groovy の書き方)
- `api("jp.kamusoft:kscollectionview:1.0.0")`
- 複数行に分けた `.package(url: ..., exact: "1.0.0")`

spec の「例の中に具体の版が無い」は、この形では守られない。今の README と `SKILL.md` に当たる行は無い。
**推奨修正**: コードブロックの中で、利用者役の座標 (`group:artifact`) か Package URL を含む行を別に拾い、決めた形に当たらないものを違反にする。その異常のテストを足す。直さないなら、拾い方の限界としてスクリプトの冒頭と書き方の決まりの草稿に書く。

### [🟡 Minor] Skill の整合の検査が、HTML で書いた Skill の外へのリンクを見ない

**該当箇所**: `scripts/ci/check-skills.py:69-70`・`:182-192`
**問題点**: リンクの先を拾うのは、Markdown の `[..](..)` と参照の定義だけである。`<a href="../../../../README.md">` を `references/` の 1 枚に足して試すと、違反なしで終わった (`<img src>` も同じ拾い方)。spec の「相対のリンクの先が、その Skill のディレクトリの中に実在する」の抜け道になる。README は `<img>` を使っているので、同じ書き方が Skill に入ることはあり得る。
**推奨修正**: `href="…"` と `src="…"` の値もリンクの先として拾い、テストを 1 件足す。

### [🟡 Minor] Skill の文面の、軽微なずれ (5 か所)

**該当箇所と問題点**:

- `skills/{en,ja}/kscollectionview-android/references/reorder.md:270` — 自動スクロールの範囲を「端から 64 dp」と書いている。実物は `minOf(64 dp, 高さ / 4)` (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsReorderController.kt:419`) で、高さが 256 dp に満たない一覧では縮む
- `skills/{en,ja}/kscollectionview-android/references/images.md:93` — 失敗した画像は「下のキャッシュの操作の後」に再試行されると書いている。再試行が起きるのは `clear(All)` と `remove(source)` だけで、`clear(Memory)` では起きない (`.../KsImageCache.kt:50`)
- `skills/{en,ja}/kscollectionview-android/references/layout.md:59` — 「`KsLayout` の値が 5 つのプロパティを持つ」と書いている。`KsLayout` は中身の無い sealed interface で、`List` が持つのは 3 つ、`Grid` が 5 つ (`.../KsLayout.kt:12`・`:26-30`・`:68-74`)。`KsLayout` 型の値に `layout.columns` と書くとコンパイルできない
- `skills/en/kscollectionview-ios/references/basics.md:203` と `skills/ja/…:203` — 英語は "Rows, headers, and displays"、日本語は「行・見出し・ページングの表示」。日本語の「見出し」はグループの見出しの語で、ヘッダーとフッターが入るかが英語と揃っていない
- `skills/{en,ja}/kscollectionview-ios/references/reorder.md:214` — 「Simulator で、メインスレッドの CPU の約 5〜8%」。開発のときの計測値で、利用者の環境での値ではない。値の根拠は Skill からも本体のソースからもたどれない

**推奨修正**: 上の 3 つは実物の条件を 1 句ずつ足す (英日とも)。4 つ目は語を揃える。5 つ目は「いくらか増える」のような量を言わない書き方にするか、載せるかどうかを検収でオーナーに諮る。

### [🟡 Minor] Android の「利用する側に求める下限」(Android Gradle Plugin 8.6.0・Kotlin 2.3) は、ビルドで確かめていない

**該当箇所**: `README.md:29`・`README_ja.md:29`、`skills/en/kscollectionview-android/SKILL.md:47-48`・`skills/ja/kscollectionview-android/SKILL.md:47-48`
**問題点**: `evidence/readme-and-screenshots.md` が自分で書いているとおり、2 つの値は AAR と Kotlin のメタデータから読み取った値で、その組み合わせで利用する側のプロジェクトをビルドしてはいない。ビルドして確かめたのは、利用者役の今の設定 (9.4.0・2.4.10) だけである。README と Skill は、これを下限として断定の形で書いている。
**推奨修正**: 検収 (12.4) で、未確認の値であることをオーナーに伝える。載せ方 (そのまま載せる・下限の組み合わせで 1 回ビルドして確かめる・公開までに確かめる作業を phase-7-4 へ申し送る) をオーナーが選ぶ。

### [🔵 Suggestion] Android の Skill: Compose Foundation が「届かない」は、実際と違う可能性がある

**該当箇所**: `skills/{en,ja}/kscollectionview-android/SKILL.md:54`・`:100`、`README.md` と `README_ja.md` の最小コード例の後の 1 文
**問題点**: 本体は Foundation を `implementation` にしている (`android/kscollectionview/build.gradle.kts:209`) が、`api` で届けている `coil-compose` (`:201`) が、Coil 3.5.0 のモジュールのメタデータでは Foundation を api の側に持つ。調査ワーカーが手元の Gradle のキャッシュのメタデータを読んだ結果で、Foundation を宣言しない利用する側のプロジェクトをビルドしては確かめていない。文書どおりに宣言しても害は無い。
**推奨修正**: 急がない。確かめるなら、利用者役の依存の木 (`:app:dependencies` の compile classpath) で、Foundation がライブラリ経由で届くかを見る。届くなら「宣言を勧める」の言い方に改める。

### [🔵 Suggestion] Skill の索引の「同じ見出しの並び」を確かめるテストが無い

**該当箇所**: `scripts/ci/tests/test_repository_files.py:185-235` (索引は、導線の先の実在だけを見ている)
**問題点**: spec (Skill の索引) は、`skills/README.md` と `skills/README_ja.md` が同じ見出しの並びを持つことを求める。今の 2 枚は一致している (深さ 1 が 1 つ・深さ 2 が 3 つ) が、片方だけを直したときに気付く検査が無い。ルートの README と CONTRIBUTING には、同じ形のテストがある。
**推奨修正**: 既存の `heading_levels` で、索引の 2 枚の一致を見るテストを 1 件足す。

## アクションプラン

1. (Major) iOS の `references/basics.md:313` を、英日とも今のコードの動きに合わせる。コードと concepts の食い違いは、オーナーに諮る件として記録する
2. (Minor) iOS の `references/basics.md` の列数の行と、Skill の文面の軽微なずれ 5 か所を直す (英日を同じ回に)。直した後に `check-skills.py` と `check-api-coverage.py` を流し直す
3. (Minor) 2 本の検査の拾い方の隙間 (具体の版・HTML のリンク) を塞ぎ、異常のテストを足す。直さないものは、限界として書く
4. (Minor) Android の下限の 2 つの値が未確認であることを、検収でオーナーに伝える
5. (Suggestion) Foundation の届き方の確認と、索引の見出しのテストは、余裕があれば行う
