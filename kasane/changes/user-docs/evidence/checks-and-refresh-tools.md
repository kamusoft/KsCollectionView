# 証跡: 実物への検査の適用と、追従の道具 (tasks グループ 8・9.1〜9.4)

2026-10-10 に手元で確かめた結果。パスはリポジトリのルートからの相対で書く。作業ツリーは commit していない (HEAD は `a064acaefa463c35ccdd292084f3001515c6f0e0`)。

## 8.1 実物に検査を流すテスト

`scripts/ci/tests/test_repository_files.py` に 3 つのクラス (10 件) を足した。今ある README のテスト (見出しの深さの一致・ライセンスと貢献の導線・互いを指す) は変えていない。

| クラス | 確かめること |
|---|---|
| `ReadmeSectionsTest` | README の 2 枚が 9 つの節 (深さ 2 の見出し) をこの順で持つ。スクリーンショットの節が `assets/` の 6 枚を 1 回ずつ指し、6 枚が実在する (画像の中身と大きさは見ない)。Skill への導線の節のリンクが、自分の言語の 2 つの `SKILL.md` と索引だけで、先が実在する |
| `UserDocsCheckTest` | 3 つの検査を今のリポジトリのルートに流す: 最小コード例 (違反 0・一致 4 か所)・インストール例 (違反 0・確かめた行が 1 行以上)・Skill 自身の整合 (違反 0・Skill 4 つ)。2 本のスクリプトの入口も呼び、終了コード 0 を確かめる |
| `SkillsManifestTest` | `skills/.manifest.json` が 3 つの項目を持つ。源泉がどれも、掛かる 1 枚か掛からない理由のどちらかを持つ。掛かる 1 枚が、当たるプラットフォームの Skill の両方の言語に実在する |

`SkillsManifestTest` は、源泉のパスが今もあるか・概念の文書がすべて記録にあるか・記録の commit が履歴にあるかを見ない (源泉だけを変えた push を落とさないため)。

## 8.2 一時のツリーでの 3 つの確かめ

スクラッチのディレクトリに、追跡しているファイルと、まだ追跡していない (無視の指定に当たらない) ファイルの今の内容を 1,315 個写し、使い捨ての git のリポジトリにして commit した。本リポジトリの作業ツリーは変えていない。写しは確かめた後に削除した。

| ツリーの状態 | `python3 scripts/ci/run-tests.py` の結果 |
|---|---|
| 写したまま (基準) | 終了コード 0。実行 484 件・失敗 0 件 |
| `skills/ja/kscollectionview-ios/references/paging.md` の末尾にだけ、見出しを 1 つ足した | 終了コード 1。実行 484 件・失敗 1 件 (`test_repository_files.UserDocsCheckTest.test_Skill自身の整合の検査が違反なしで終わる`。違反の文面は「見出しの深さの並びが、英語版と日本語版で違う」) |
| `kasane/concepts/core/core-model/collection-paging.md` の末尾にだけ、1 行を足した | 終了コード 0。実行 484 件・失敗 0 件 |
| 本体に公開の宣言を 1 つずつ足した (iOS は `KsScrollController` に `public func`、Android は `KsScrollController.kt` に最上位の `public fun`)。`skills/` は変えていない | 終了コード 0。実行 484 件・失敗 0 件 |

最後の状態で、検証 CI の外の道具 `python3 scripts/docs/check-api-coverage.py` を流すと、足した 2 つの名前が両方の言語の漏れとして出て、終了コード 1 で終わった (検証 CI は落ちず、追従のときの道具が拾うことの確認)。

## 8.3 検証 CI の入口の定義

`.github/` の下と、lint の step の一覧を持つ `scripts/ci/tests/test_workflow_files.py`・`scripts/ci/check-workflows.py` は変えていない (`git status --short` に現れない)。`test_workflow_files.py` は変えずに通った。`python3 scripts/ci/check-workflows.py` は「違反は無い」(workflow 5 本)。

## 9.1 追従の記録

`skills/.manifest.json` を作った。

| 項目 | 中身 |
|---|---|
| `version` | 1 |
| `syncedCommit` | `a064acaefa463c35ccdd292084f3001515c6f0e0` (今の HEAD。下の「`record` を流せなかった理由」を参照) |
| `sources` | 20 件。概念の文書 14 件・ビルドの設定 3 件・依存の書き方を決めている文書 1 件・利用者役の画面のファイル 2 件 |
| `apiExclusions` | iOS・Android とも空 (外す名前はオーナーに諮ってから書く) |

概念の文書の 14 件 (`kasane/concepts/` の下の `.md` から、`index.md`・`log.md`・`rules.md` を除いたもの) は、どれも掛かる 1 枚を持つ。外すと書いた源泉は無い。

| 源泉 | 掛かる 1 枚 |
|---|---|
| `core/core-model/collection-items.md` | `references/basics.md`・`references/layout.md` |
| `core/core-model/collection-interaction.md` | `references/basics.md` |
| `core/core-model/collection-paging.md` | `references/paging.md` |
| `core/core-model/collection-reorder.md` | `references/reorder.md` |
| `core/core-model/image-loading.md` | `references/images.md` |
| `core/styling/collection-layout.md` | `references/layout.md` |
| `ios/architecture/collection-engine.md`・`android/architecture/compose-wrapper.md` | `references/basics.md`・`references/layout.md` (そのプラットフォームの Skill だけ) |
| `ios/architecture/paging-engine.md`・`android/architecture/paging-wrapper.md` | `references/paging.md` (そのプラットフォームの Skill だけ) |
| `ios/architecture/reorder-engine.md`・`android/architecture/reorder-wrapper.md` | `references/reorder.md` (そのプラットフォームの Skill だけ) |
| `ios/architecture/image-pipeline.md`・`android/architecture/image-pipeline.md` | `references/images.md` (そのプラットフォームの Skill だけ) |
| `ios/Package.swift` | `SKILL.md` (iOS の Skill だけ) |
| `android/gradle/libs.versions.toml`・`android/kscollectionview/build.gradle.kts` | `SKILL.md` (Android の Skill だけ) |
| `kasane/handbook/cross/public-identifiers.md` | `SKILL.md` |
| 利用者役の画面のファイル (iOS・Android) | `SKILL.md` (そのプラットフォームの Skill だけ) |

プラットフォーム別の概念の文書 8 件は、内部の仕組みが中心だが、利用者に関わる記述 (分かっている限界・してはいけないこと) を持つので、外さずに、同じ主題の 1 枚に掛けた。片方のプラットフォームの Skill にだけ掛かることを書くために、源泉の項目に `platforms` を足した (書かなければ両方に掛かる)。

### 今の実物での `status`

`python3 scripts/docs/skills-refresh.py status` (終了コード 0):

```text
追従の記録の commit: a064acaefa463c35ccdd292084f3001515c6f0e0
比べた範囲: この commit から、今の作業ツリーまで (commit していない変更を含む)

変わった源泉: 2 件
  verification/ios/Sources/VerificationApp/ItemListScreen.swift (足された)
    見直す 1 枚: SKILL.md (ios の Skill だけ)
  verification/android/app/src/main/kotlin/ItemListScreen.kt (足された)
    見直す 1 枚: SKILL.md (android の Skill だけ)

公開の宣言の増減は無い
```

- 対応の決まっていない源泉は出ていない (概念の文書の 14 件が、すべて記録にある)
- 変わった源泉の 2 件は、本変更で足した利用者役の画面のファイルで、まだ commit していないためである

### `record` を流せなかった理由

`python3 scripts/docs/skills-refresh.py record` は、終了コード 1 で終わり、記録を変えなかった (対象のパスの利用者役の画面のファイル 2 つが、まだ commit されていないため)。`syncedCommit` には、今の HEAD の ID を手で入れてある。最後の記録の更新 (12.5) で、commit の後に `record` を流す。

## 9.3 拾った公開の宣言の名前の数と、目で数えた数

道具 (`python3 scripts/docs/check-api-coverage.py --list`) が拾った数:

| プラットフォーム | 名前を持つ宣言 | 名前 (重なりを除く) | 名前を持たない宣言の行 |
|---|---|---|---|
| iOS | 90 個 | 83 個 | 初期化 17 行 |
| Android | 98 個 | 86 個 | `constructor` 1 行・名前の無い `companion object` 1 行 |

目で数えた数 (`grep` と、ソースを読んだ数え上げ。道具の拾い方を通していない):

| プラットフォーム | 数え方 | 数 |
|---|---|---|
| iOS | `public` で始まる行 86 行 (計測用の 2 ファイル `KsLayoutDiagnostics.swift`・`KsItemOffsetLookup.swift` を除く) から `init` の 17 行を引いた 69 行と、公開の `enum` の直下の `case` 21 行 (8 つの `enum`) | 90 個 |
| Android | コメントの行を除いた `public` の語 78 個から `constructor`・`companion` の 2 個を引いた 76 個と、`enum class` の値 14 個 (5 つの `enum class`)、`public` と書かれていないコンストラクタのプロパティ 8 個 (`KsLayout.Grid` の 5 個・`KsColumns.Fixed` の 2 個・`KsColumns.Adaptive` の 1 個) | 98 個 |

名前を持つ宣言の数は、両プラットフォームで道具と一致した。読み取れなかった `public` の行は、両プラットフォームとも 0 行。

- 名前が重なるのは、同じ名前の関数の多重定義 (`groups`・`fixed`・`template`・`KsImage` など) と、違う型の同じ名前の宣言 (`end`・`memory`・`fixed`・`key`・`url`・`item`・`rowSpacing` など) である
- iOS の計測用の宣言 (`@_spi(KsMeasurement)` の付いた 2 つの型と、その中の 5 つの宣言) は拾っていない

### 拾い方の限界

`scripts/docs/public_api.py` の冒頭に書いた。今のソースに当たるものが無いことを、目で確かめた範囲:

| 限界 | 今のソース |
|---|---|
| 複数行にわたる宣言は、名前のある行だけを拾う (続きの行だけを変えても、公開の宣言の増減に出ない) | 当たる宣言がある (`KsCollectionView` の初期化と修飾子・`KsPaging` などのコンストラクタ)。名前の網羅には影響しない。増減の報告の限界として残る |
| 公開でない型の囲みや、公開でない型の `extension` の中に `public` と書かれた宣言があっても拾う | 無い (拾った宣言の外側の型は、すべて公開の型だった) |
| Swift の `case` を複数行に分けて並べたときの、2 行目から後の値は拾わない | 無い |
| 条件付きコンパイル (`#if`) の中かどうかを見ない | 計測用の型だけが `#if DEBUG` の中にあり、印で外れている |
| 演算子の `func` など、名前を読み取れない `public` の行は、読み取れなかった行として別に出す | 無い (0 行) |
| 名前は、Skill の文面のどこかに、同じ字面で現れれば載っていると数える。短い一般の言葉と同じ名前 (`end`・`all`・`key`・`body` など) は、英語の本文の同じ言葉でも現れたことになる | 下の「9.4」で、コードの中だけを数える見方でも確かめた |

## 9.4 網羅の道具を実物に流した結果

`python3 scripts/docs/check-api-coverage.py` (終了コード 1):

```text
iOS: 拾った名前 83 個 (名前を持つ宣言 90 個)・載せないと決めた名前 0 個
  漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): buildBlock — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:11)
  漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): buildExpression — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5)
  漏れ: iOS / 日本語版 (skills/ja/kscollectionview-ios): buildBlock — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:11)
  漏れ: iOS / 日本語版 (skills/ja/kscollectionview-ios): buildExpression — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5)
Android: 拾った名前 86 個 (名前を持つ宣言 98 個)・載せないと決めた名前 0 個
公開の宣言の名前の網羅: 漏れ 4 件
```

- 漏れは、iOS の 2 つの名前 (英日で 4 件) だけである。Android の漏れは 0 件
- 漏れた名前のうち、利用者が使うものは無かったので、Skill に名前は足していない
- 漏れた 2 つは、利用者向けでない名前の候補である (下の表)。`apiExclusions` には、まだ書いていない

| プラットフォーム | 名前 | 何の宣言か | 利用者向けでないと考える理由 |
|---|---|---|---|
| iOS | `buildExpression` | result builder `KsTemplateBuilder` の、式を受け取る関数 | コンパイラが、テンプレートを並べたブロックを組み立てるときに呼ぶ。利用者はコードに書かない。Skill は `KsTemplateBuilder` の名前を出して「自分では呼ばない」と書いている |
| iOS | `buildBlock` | 同じ result builder の、並べた式をまとめる関数 | 同上 |

名前だけの照合の弱さを補うために、手元で、Skill のコード (コードブロックと、文の中のコード) の中だけを数える見方でも流した (道具には入れていない)。結果は同じで、コードの中に現れない名前は iOS の上の 2 つだけ、Android は 0 個だった。

漏れとしては出ないが、利用者が自分で呼ばない名前が、ほかにもある。外す一覧に入れるかどうかを決めるときの材料として書く。

| プラットフォーム | 名前 | 何の宣言か | Skill での現れ方 |
|---|---|---|---|
| iOS | `body` | `KsCollectionView`・`KsImage` が `View` であるための宣言 | 利用者の画面のコード例の `var body` として現れる (ライブラリの宣言の説明ではない) |
| Android | `KsCollectionDsl` | DSL の印の annotation | 名前が Skill に現れている |

## スクリプトのテストの件数

`python3 scripts/ci/run-tests.py`: 実行 484 件・失敗 0 件・スキップ 0 件 (前は 385 件。足したのは 99 件: `test_check_api_coverage.py` 46 件・`test_skills_refresh.py` 43 件・`test_repository_files.py` 10 件)。

標準の lint は、どれも違反なしで終わった: `scripts/local-path-lint.py`・`scripts/identity-lint.py`・`scripts/comment-policy-lint.py` (禁止 0 件)・`scripts/ci/check-workflows.py`。2 本の検査 (`check-skills.py`・`check-readme-examples.py`) も、終了コード 0。

## あわせて直した 1 か所

`skills/{en,ja}/kscollectionview-ios/references/reorder.md` の「Know how the drag behaves on iOS」の表の 1 行目の、Android の動きを添えた括弧の中を直した (英日とも・同じ回に)。見出しとコードブロックは変えていない。

- 前: 指が項目を越えるのに合わせて動く
- 今: 指を動かしている間にも動く。リストでは持ち上げた項目がほかの項目に半分を越えて重なったとき、グリッドでは指がほかの項目の上に入ったとき

出どころは、`kasane/concepts/core/core-model/collection-reorder.md` の両プラットフォームの差の表・`kasane/concepts/android/architecture/reorder-wrapper.md` の行き先の決め方の表・本体の `KsReorderController.kt` の行き先を求める処理の説明・Android の Skill の `reorder.md` で、4 つの記述が一致していることを読んで確かめた。エミュレータで動かして見ることはしていない (未確認)。

## 9.4・9.5 載せない名前の決定と、漏れ 0 件の確認 (2026-10-10)

- 網羅の道具を実物に流して出た漏れは、iOS の `buildExpression`・`buildBlock` の 2 つ (英語版と日本語版に 1 件ずつ、合わせて 4 件) だけだった。Android の漏れは無い。利用者が使う名前の漏れは無かったので、Skill に足した名前は無い
- 指揮側がオーナーに諮り、2 つとも「載せない名前」として記録すると決まった (2026-10-10。オーナーの決定)。理由: テンプレートを並べて書くブロックを、コンパイラが組み立てるときに自動で呼ぶ関数で、利用者は自分のコードに書かない
- `skills/.manifest.json` の `apiExclusions.ios` に、2 つの名前と理由を書いた。`apiExclusions.android` は空のまま
- 流し直した結果 (`python3 scripts/docs/check-api-coverage.py`。終了コード 0):

```
iOS: 拾った名前 83 個 (名前を持つ宣言 90 個)・載せないと決めた名前 2 個
Android: 拾った名前 86 個 (名前を持つ宣言 98 個)・載せないと決めた名前 0 個
公開の宣言の名前の網羅: 漏れ 0 件
```
