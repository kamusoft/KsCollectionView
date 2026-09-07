# レビュー結果: image-loading (004 回目)

**日付**: 2026-09-07
**判定**: APPROVED

## サマリー

3 周目の指摘 (ホスト Major 2 / Minor 2 / Suggestion 1、相方 Major 3 / Minor 1) は**全件が解消**していた。
とくに 3 周連続で出ていた「テストが本番経路を通っていない」型は、iOS の `makeRequest` を削除して
表示に使う要求を 1 本へ統合し、Scenario の検査を `prepare` と実表示 (`KsImageDisplayTests`) へ
移すことで構造ごと解消している。**4 周目で初めて Major / Critical が 0 件**になった。

判断を仰がれた 2 点は、いずれも**指摘に当たらない**と判定した。根拠は下記「判断を仰がれた 2 点」に
実測値とともに書いた。iOS の既定表示のアクセシビリティは、副作用とされていた「名前を持たない要素が
1 つ残る」が**この変更で新たに生まれたものではない** (成功状態は元から同じ形) ことを実測で確認した。
公開 API の非対称は design.md の Decision に理由つきで明記済みで、既存の
`touchFeedback(color:)` ⇔ `touchFeedbackColor` と同じ扱いに揃っている。

残った指摘は Minor 2 件 (Android 側の対のテストが入らなかった / 利用者向け注記の原料が実装に
追随していない) と Suggestion 2 件で、いずれも実装をやり直す性質のものではない。ビルド・全テスト・
lint はすべて緑 (件数は下記)。

## 実行したビルドとテスト

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 17 Pro>' -configuration Debug` | **Executed 153 tests, with 0 failures** (前周 144 → +9) |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **Executed 3 tests, with 0 failures** (計測ドライバは含まれず分離が効いている) |
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **128 tests / 0 failures / 0 skipped** (9 クラス。前周 122 → +6。内訳: `KsAppContextTest` 3 / `KsCollectionViewCoreTest` 14 / `KsCollectionViewInteractionTest` 22 / `KsCollectionViewLayoutTest` 30 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 5 / `KsImageCacheContractTest` 12 / `KsImagePrefetchWindowTest` 14 / `KsImageTest` 21) |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` | **18 tests / 0 failures / 0 skipped** (3 クラス: `ImageGridMeasurementFixtureTest` 5 / `SampleDemoScreenTest` 9 / `SampleScreenParityTest` 4) |
| lint | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | 禁止 0 件 / 0 件 / 0 件 (検査対象 196 ファイル) |

件数は XML レポート (`build/test-results/testDebugUnitTest/TEST-*.xml` の `tests` / `failures` /
`errors` / `skipped` 属性) のクラス単位の集計まで取った。

`comment-policy-lint.py --advisory` は要確認 14 件を報告するが、**すべて Sample とベンチマークの
内部型の doc コメント内の ADR 参照**で、ライブラリ利用者から見える公開メンバーではない。既存
ファイル (`SampleTheme.kt` / `LargeDataScrollBenchmark.kt` ほか) と同じ書き方で、本体
(`ios/Sources/` / `android/kscollectionview/src/main/`) には 1 件も無い。規約本文の
「公開メンバーの doc コメント」の対象外と判定した。

今周の変更範囲はコード 8 ファイルに絞られている (前周のレビュー時刻以降に更新されたソース:
`android/.../KsImage.kt`、`android/.../KsImageTest.kt`、`ios/Sources/KsCollectionView/KsImage.swift`、
`ios/Sources/KsCollectionView/KsImageRequestFactory.swift`、iOS テスト 4 本)。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` のデモ画面「画像グリッド」と計測用画面 |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と結果の報告 |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動の証跡と、同文書自身への観測点の追記 |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | `Package.swift` / `libs.versions.toml` / AndroidManifest を変更 |
| [ローカル開発環境と Sample の実行](../../handbook/cross/local-development-setup.md) | 本体・Sample のビルドとテスト実行 (guide) |
| [iOS 性能検証の手順と合格基準](../../handbook/ios/performance-verification.md) | 大量件数 (10,000 件) を扱う変更の完了判定 |
| [Android 性能検証の手順と合格基準](../../handbook/android/performance-verification.md) | 同上・ラッパーのスクロール経路に触れる |

用途キー `code-review` (android) で解決した **kotlin-impl-skill** をロードして適用した
(null 安全・sealed / data class・structured concurrency・コード衛生)。今周更新された Kotlin ソースに
`GlobalScope` / `runBlocking` (本番) / `!!` / `Thread.sleep` (本番) / `CancellationException` の
握り潰しは無い。`KsImage` は Explicit API mode 下で `public` に KDoc を持ち、`@param` が全引数を
網羅している。`drawablePainter` の例外捕捉は `Resources.NotFoundException` に限定され、
握り潰しではなく戻り値 (`null`) で呼び出し元へ返している。

参照した決定: core/ADR-0002・0008・0011 (accepted)、core/ADR-0012 (proposed — 判定根拠にはしていない)。
`kasane/lessons/code-review.md` は未作成のため重点観点・除外観点なし
(`kasane/lessons/inbox/` の 5 件は昇格前なので判定には使っていない)。

## 前周の指摘の解消状況

| 前周の指摘 | 状況 | 確認した根拠 |
|---|---|---|
| ホスト Major 1: iOS で一度表示した画像を表示し直すと読み込み中を経由する | **解消** | `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:110-124` が表示に使う要求を `displayRequest` 1 本へ統合し、発行する鍵と引き当てる鍵が一致した。`KsImageCacheContractTests.test一度表示した画像は表示を作り直しても読み込み中を経由しない` が、先読みを使わずに一度表示 → 作り直し → 読み込み中スロットの構成回数 0 と、対象 URL の取得回数 1 を検査する |
| ホスト Major 2: iOS の Scenario 検査が本番の呼ばない `makeRequest` に対して行われている | **解消** | `makeRequest` は削除され、`ios/Sources/KsCollectionView/` に定義も参照も無い。`KsImageTests` の縮小・削除まわりの検査はすべて `prepare` の戻り値の `request` を見る形になった |
| 相方 Major 1: Android の有効な XML drawable がクラッシュする | **解消** | `android/.../KsImage.kt:325-336` の `drawablePainter` が `getDrawable` で一度 drawable に起こしてから描く。`KsImageTest.xmlDrawablesThatAreNotVectorsAreDisplayed` が状態リスト (`list_selector_background`) と重ね合わせ (`progress_horizontal`) を実表示で通す |
| 相方 Major 2: 「戻ったときに読み込み中を経由しない」の証跡が観測値と矛盾 | **解消** | `evidence/image-behavior-observation.md:66-108` が結論を取り下げ、「測れているのはネットワークへ出ていないことだけ」と明記したうえで測り直しの手順を 4 点に固定した。冒頭の「確認できている範囲 / 未確認」も更新済み。tasks 7.4 のチェックが外れている |
| 相方 Major 3: iOS の「3 種のソースを表示」が実表示経路を通っていない | **解消** | `ios/Tests/KsCollectionViewTests/KsImageDisplayTests.swift` を新設。リモートは実 URLProtocol、ファイルは実際の一時 PNG を通し、`UIHostingController` に載せて描いた**中心ピクセルの色**まで検査する。アセットの成功だけは端で確かめられない理由が deviation に実測つきで記録されている |
| ホスト Minor 1: `removeMakesTheDisplayedImageReload` の待機が原理的に落ちうる | **解消** | `android/.../KsImageTest.kt:648-655` の 1 段目が「取得が始まった」から「メモリの項目になった」へ変わった。`awaitCondition` に `detail` 引数が足され、期限切れ時に `memory=` の実測値が出る。`fetchDelayMillis = 200L` で取得に幅も持たせている |
| ホスト Minor 2: 表示の組み立て中の同期縮小の費用が未記録 | **解消** | deviation.md に「到達点メモリを選んだときの、表示の組み立て中の同期縮小 (費用の記録)」として、走る頻度・費用の比例先・到達点ディスクでは通らないことまで書かれた |
| 相方 Minor 1: 読み込み・失敗の状態で画像のアクセシビリティ情報が失われる | **解消** | Android は `KsImage.kt:81` で根の `Box` に `imageSemantics(contentDescription)` を置き、子の `Image` は `contentDescription = null` にした。iOS は既定ビューを 1 要素にまとめた。両プラットフォームにテストがある (Android 3 件 / iOS 5 件)。**実測で裏取りした** — 下記参照 |
| ホスト Suggestion 1: iOS の `prepare` が body 評価中に共有キャッシュへ書き込む | **解消 (doc で対応)** | `KsImageRequestFactory.swift:48-51` の「呼び出し側の注意」と `KsImage.swift:110-114` に明記。body の外へ出せない理由も deviation に記録された |

**降格に値する前周の指摘は今周も 0 件。**

## 判断を仰がれた 2 点

### 1. iOS の既定の失敗表示のアクセシビリティ — **妥当。副作用も許容できる**

実装は記号を隠す代わりに、既定ビュー (`KsImageDefaultLoadingView` /
`KsImageDefaultFailureView`) へ `.accessibilityElement(children: .ignore)` を置いた。

**レビュー用の一時テストで実際の要素を数えた** (`isAccessibilityElement` の要素を再帰的に集め、
名前と trait を出力。確認後に削除):

| 状態 | 説明あり | 説明なし |
|---|---|---|
| 成功 (`Image(uiImage:)`) | 要素 1 / 名前あり / image trait | 要素 1 / **名前なし** / image trait |
| 読み込み中 (実 `KsImage` 経由) | 要素 1 / 名前あり / trait なし | 要素 1 / **名前なし** / trait なし |
| 失敗 (実 `KsImage` 経由) | 要素 1 / 名前あり / trait なし | 要素 1 / **名前なし** / trait なし |

判定の根拠は 3 点ある。

- **副作用は新しく生まれたものではない。** SwiftUI の `Image(uiImage:)` は元から名前を持たない
  アクセシビリティ要素になる (上表の成功・説明なしの行)。つまり「名前を持たない要素が 1 つ残る」
  状態は成功時から存在しており、今回の変更は**その形を 3 状態でそろえた**ことになる。
  記号だけを隠す案を採っていたら、読み込み中・失敗のときだけ要素が消え、**状態によって
  読み上げの木の形が変わる**という、相方 Minor 1 が Android について指摘したのと同じ問題を
  iOS 側に作っていた
- **利用者が付けた説明は 3 状態すべてで残る。** 実 `KsImage` の読み込み中・失敗で実測済み
  (成功は同じビュー構成で確認)。実装側が「そのままだと説明が丸ごと消える」と報告した観測は
  再現できる筋になっており、判断の前提として正しい
- **説明を付けない場合の逃げ道が公開 API の範囲にある。** `.accessibilityHidden(true)` を付けると
  要素が完全に消える (実測: 要素数 0)。Sample の `ImageGridCell.swift:11` が実際にこれを使って
  おり、Android 側が `contentDescription = null` を渡しているのと**振る舞いが一致する**

残るのは trait だけで、これは Suggestion に落とした (下記)。

### 2. 公開 API の非対称 (`contentDescription`) — **core/ADR-0002 に反しない**

`design.md:144` が既にこの 2 件を Decision として明記している。

> Kotlin 側の `prefetchDestination` は、フラットな名前付き引数で `destination` だけでは何の
> 到達点か読めないため接頭辞を付ける (`touchFeedback(color:)` ⇔ `touchFeedbackColor` と同じ扱い。
> 宣言構造の対応は保つ)。Android の `contentDescription` は Compose の画像コンポーネントの慣例
> (アクセシビリティ) で、iOS は `accessibilityLabel` modifier を利用者が付ける流儀 (記法差)。

core/ADR-0002 は「揃えるもの = コンポーネント名・パラメータ名・宣言構造」と定める一方、
「各プラットフォームの流儀に残すもの」として **modifier 記法**を名指ししている。
`contentDescription` はまさにこの線の上にある。

- **機能の対称性は保たれている。** iOS は `.accessibilityLabel(_:)` で同じことができ、
  3 状態すべてで効くことを上記のとおり実測した。**片方にしかできないことは無い**
- **既存の適用例と揃っている。** `listSeparators` / `listSeparatorColor` (Android の 2 つの
  フラット引数) ⇔ `.listSeparators(_:)` / `.listSeparatorColor(_:)` (iOS の 2 つの modifier)、
  `touchFeedbackColor` ⇔ `.touchFeedback(color:)` は既に accepted 済みの実装に入っている。
  `prefetchDestination` ⇔ `prefetchResources(destination:)` はこの前例をそのままなぞっている
- **design.md は足場の凍結対象で、今周書き換えられていない** (`git status` に現れない)。
  提案段階のスペックレビューを通った判断であり、実装がそれに従っている

なお `dsl-samples.md` の対応表に「画像の取得元・到達点」の行が足され、書き写しの読者から見て
両プラットフォームの語彙が 1 対 1 で引ける状態になっている。core/ADR-0002 の主目的
(片方で書いた画面をもう片方へ機械的に書き写せること) はこの表で担保されている。

## 指摘事項

### [🟡 Minor] Android に、iOS へ入れた「作り直しても読み込み中を経由しない」の対のテストが無い

**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageTest.kt`
(欠落) / `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageRequestFactory.kt:82`

**問題点**: 前周のアクションプラン 1 は「**先読み無しで一度表示 → 作り直す → 読み込み中スロット
0 回」のテストを iOS と Android の両方に入れる (現在どちらにも無い)**」を求めていた。iOS には
`KsImageCacheContractTests.test一度表示した画像は表示を作り直しても読み込み中を経由しない` が
入ったが、**Android には対応するテストが入っておらず、入れなかった理由も deviation.md に無い**。

Android の既存テスト `KsImageTest.loadingSlotIsNeverComposedWhenTheImageIsAlreadyInMemory` は
`loader.execute(...)` (寸法を付けない、先読みと同じ形の要求) でメモリを温めてから始まる。
つまり検査しているのは「先読みが載せた元寸を引き当てられるか」であって、
**「表示要求が自分で書いた `displayKey` の項目を、次の表示が引き当てられるか」ではない**。

本番の作りは正しい — `KsImageRequestFactory.kt:82` の `.memoryCacheKey(displayKey)` により、
表示要求の結果は次の `prepare` が引く鍵と同じ場所へ入る。前周のレビューも一時プローブで
Android 0 回を実測している。したがって**現時点の挙動に不具合は無い**。指摘は、この change で
3 周連続して壊れた継ぎ目 (発行する鍵と引き当てる鍵の一致) が、**片方のプラットフォームだけ
回帰テストで固定されていない**ことに対するもの。iOS はまさにここが壊れており、Android で同じ
ことが起きても現在のテスト一式は緑のままになる。

**推奨修正**: `KsImageTest` に、先読みを使わず `KsImage` で一度表示し、メモリに `displayKey` の
項目が入ってから同じソース・同じ寸法で組み立て直して読み込み中スロットの構成回数 0 を数える
テストを 1 件足す (iOS の対応テストと同じ数え方)。入れない判断をするなら、その理由を
deviation.md に記録する。

### [🟡 Minor] 利用者向け注記の原料が今周の実装に追随していない

**該当箇所**: `kasane/changes/image-loading/evidence/user-notes-source.md:83-84`

**問題点**: この文書は tasks 8.1 の成果物 (蒸留で concepts へ回す原料) だが、今周の実装変更を
反映していない箇所が 1 つと、今周増えた**利用者から見える挙動**の記載漏れが 2 つある。

- **実装と食い違う記述**: 「リソースは Coil を通さず Compose の `painterResource` で同期的に
  描くため」と書かれているが、今周の修正で描画経路は `Context.getDrawable` から起こした
  drawable に変わった (`KsImage.kt:325-336`)。「Coil を通らないので消すキャッシュ項目が無い」
  という結論自体は変わらないが、名指ししている手段が実装に無い
- **記載漏れ 1 (debug での停止)**: 読めないリソース ID に対して debug ビルドで
  `IllegalStateException` を投げる扱いが新設された (`KsImageTest.resourcesThatCannotBeDrawnStopInDebug`
  が検査)。これは利用者のアプリが debug で止まる挙動であり、`enableSharedDiskCache()` の副作用が
  「tasks 8.1 の利用者向け注記に含める」と明記されているのと同じ性格の情報
- **記載漏れ 2 (アクセシビリティの記法差)**: Android は `contentDescription` 引数、iOS は
  `.accessibilityLabel` modifier、説明を付けない iOS の `KsImage` は名前を持たない要素を 1 つ残す
  (`.accessibilityHidden(true)` で消せる)。この文書の「7. Android には共有キャッシュを有効化する
  API が無い」節は、まさに**公開面が 1 対 1 にならない箇所を理由つきで残す**ために書かれており、
  同じ枠に収まる

deviation.md には 3 点とも記録があるので、**合意済み差分としての記録漏れではない**。指摘は、
アーカイブされない側へ渡る原料が実装に追随していない点に対するもの
(ソースコメント規約が「作業文書はアーカイブされて文脈を追えなくなる」ことを前提に置いているのと
同じ理由で、この文書の正確さが蒸留後の唯一の手がかりになる)。

**推奨修正**: 上記 3 点を `user-notes-source.md` に反映する。`painterResource` の記述は現在の
手段に直すか、手段を名指しせず「ローダーを通らないため消す項目が無い」だけにする。

### [🔵 Suggestion] iOS の既定表示に画像の trait が無く、状態によって読み上げの性格が変わる

**該当箇所**: `ios/Sources/KsCollectionView/KsImage.swift:229-256`
(`KsImageDefaultLoadingView` / `KsImageDefaultFailureView`)

**問題点**: 実測 (上表) のとおり、説明を付けた `KsImage` の要素は成功状態では image trait を
持つが、読み込み中・失敗では trait を持たない。VoiceOver の読み上げは「説明 + イメージ」から
「説明」だけへ変わる。Android は `KsImage.kt:106-107` で
`role = Role.Image` を状態によらず根に置いているため、この点だけ非対称になっている。

実害は小さい (名前は 3 状態で保たれる) ので必須ではない。

**推奨修正**: 入れるなら、既定ビューに `.accessibilityAddTraits(.image)` を足す。ただし利用者が
スロットを差し替えた場合はその内容の trait が優先されるため、完全な対称にはならない。
入れない判断でも構わないが、その場合は Android の `Role.Image` を状態によらず置いている理由と
あわせて、蒸留時に concepts へ「読み上げの契約は名前だけを保証する」と書いておくと非対称が
再発見されない。

### [🔵 Suggestion] deviation の「既存の利用者にとっては debug で新たに落ちる変化」は事実と異なる

**該当箇所**: `kasane/changes/image-loading/deviation.md` (末尾から 2 番目「Android のリソース描画」)

**問題点**: 「core/ADR-0011 の『debug では assertion』に従うものだが、**既存の利用者にとっては
debug で新たに落ちる変化になる**」と書かれているが、`KsImage` は本 change で新設された公開 API
であり (`android/.../KsImage.kt` は未追跡 = 一度もコミットされていない)、**既存の利用者は存在しない**。
「従来は黙って失敗表示」の「従来」も、同じ change の未コミットの前段を指している。

この記述のまま蒸留に入ると、実在しない移行注意として concepts や利用者向け注記に書かれかねない。
なお**新設 API に core/ADR-0011 の表と同じ扱い (debug は停止 / release は継続 + 警告ログ) を
適用したこと自体は ADR に完全に沿っており、指摘ではない** — `KsDiagnostics.assertValid` は
`KsItemsPlan.kt:68` / `KsCollectionView.kt:137` が既に使っている同じ機構で、判定軸も
「組み込み先アプリの debuggable フラグ」で統一されている。

**推奨修正**: 「新設 API のため既存利用者への影響は無い。読めない ID を渡す利用者コードは
debug で止まる」に書き直す。

## 所見 (指摘ではない)

- **今周の修正で新たな不具合は見つからなかった。** 変更のあった 4 本の本番ソースを行単位で見て、
  次を確認した — iOS の `prepare` は表示に使う鍵が 1 本になり、「元寸あり → デコード後の縮小 /
  元寸なし → デコード時の縮小」の使い分けは画像の作り方としてだけ残って要求の形には出ない
  (deviation の記述と実装が一致)。`ImageProcessors.Resize(upscale: false)` により枠より小さい
  画像は拡大されない。Android の `drawablePainter` は `getDrawable` の投げる
  `Resources.NotFoundException` (存在しない ID・非 drawable の ID・XML の読み取り失敗が
  すべてここに集まる) だけを捕まえ、他の例外は握り潰していない
- **Android の「3 種のソース」テストの判定基準が、根への semantics 移動に追随している。**
  `contentDescription` が状態によらず出るようになったため、説明の有無だけでは成功と言えなくなる。
  `threeSourceKindsAreDisplayed` は読み込み中・失敗のスロットがどちらも 0 件であることまで
  見る形に直され、その理由がテストの doc に書かれている
  (`kasane/lessons/inbox/check-sibling-contracts-when-fixing-a-review-finding.md` が捉えている型を、
  今周は実装側が自分で塞いでいる)
- **図形 (shape) 形式のリソースの直接テストが無い**ことは deviation に記録済みで、落ちる機序
  (ベクター以外の XML ルートタグ) が状態リスト・重ね合わせと同一である説明も付いている。
  受容できる範囲と判断した
- **`clear` / `remove` のフェンスがオーナー未確認**である旨は deviation に残ったまま
  (「この受容はオーナー未確認 — 完了報告で提示する」)。**完了報告での提示が実際に行われたかは
  蒸留の前に確認が要る** (前周からの持ち越し)
- **`sample-parity`**: 「画像グリッド」の画面タイトル・3 択の文言・説明行・「キャッシュを消去」は
  両プラットフォームで一致したまま。`ImageGridCell` の 1 セル構成も一致しており、
  アクセシビリティの扱い (Android `contentDescription = null` ⇔ iOS `.accessibilityHidden(true)`)
  まで意図が揃っている
- **付随修正の同梱条件**: deviation の `[付随修正]` は今周増えていない (8 件のまま)。既存分は
  いずれも本務で触るファイル内・局所・公開 API 不変で ksn-core の同梱条件に収まっている
- **core/ADR-0012 は依然 proposed**。実装は明示 API (`enableSharedDiskCache()`) で、ADR 本文の
  「初回利用時に自動で差し替える」と Consequences は蒸留で accepted 化するときに書き直しが要る
  (1〜3 周目と同じ所見)
- **未実施の実機計測 (tasks 7.1 / 7.2 / 7.4 / 7.5)** は合意済みの進行状態。7.4 のチェックが
  外れて未完了に戻っており、証跡側も結論の取り下げと測り直しの手順まで書き切れている。
  **未計測そのものは指摘にしていない**
- **良かった点**: 3 周連続で出ていた構造的な弱点 (「テストが本番経路を通っていない」) に対し、
  今周は個別のテストを足すのではなく **本番が呼ばない関数を削除して経路を 1 本にする**という
  形で根を断っている。同じ型の見落としが起きる余地そのものが減った

## アクションプラン

1. **[Minor]** Android に「先読み無しで一度表示 → 作り直す → 読み込み中スロット 0 回」の
   テストを 1 件足す (iOS の対応テストと同じ数え方)。入れないなら理由を deviation.md へ
2. **[Minor]** `evidence/user-notes-source.md` を実装に追随させる — リソース描画の手段の記述を
   直し、debug での停止とアクセシビリティの記法差を追記する
3. **[Suggestion]** iOS の既定表示に image trait を足すか、「読み上げの契約は名前だけを保証する」
   ことを蒸留時に concepts へ書く
4. **[Suggestion]** deviation の「既存の利用者にとっては debug で新たに落ちる変化」を、新設 API
   である事実に合わせて書き直す
5. 上記と独立に、蒸留では **core/ADR-0012 の Decision と Consequences を実装 (明示 API) に
   合わせて確定し、消去範囲の 2 択と `clear(.all)` の実挙動、表示層がキャッシュ消去のフェンスの
   対象外である限界、公開面が 1 対 1 にならない 3 箇所 (`enableSharedDiskCache` /
   `prefetchDestination` / `contentDescription`) を concepts に明記する**
6. 蒸留の前に、**フェンスの受容がオーナーへ提示されたか**を確認する (deviation に「オーナー未確認」
   と残っているため)
