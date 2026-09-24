# レビュー結果: image-loading (001 回目)

**日付**: 2026-09-07
**判定**: CHANGES_REQUESTED

## サマリー

両プラットフォームのビルド・テストはすべて成功し (件数は下記)、デルタスペックの Requirement / Scenario は
`deviation.md` に記録された 14 件の合意済み差分を除いて実装とテストに対応が取れている。台帳による寿命管理
(参照数・配列差し替え・破棄) は両プラットフォームで対称に組まれ、統合テストは実ローダーの取得層をスタブして
到達点ごとのキャッシュ契約を実際に判定できている。証跡は「静止画では捉えられないものをログで数える」という
手段の選定から限界の明記まで誠実で、未実施の実機計測も欠測箇所が特定できる形で書かれている。

Critical / Major は無い。ただし、①`samples/` にデモ画面を足したときの handbook の明文の追随が漏れている、
②Android の新公開 API `KsImageCache` に、利用者が回避手段を持てない release クラッシュ経路がある、の 2 件は
いずれも小さい修正で塞げるため CHANGES_REQUESTED とする。それ以外は Minor / Suggestion で、蒸留時の
文言整備でも足りる。

## 実行したビルドとテスト

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<iPhone 17 Pro / 26.5>' -configuration Debug` | **Executed 129 tests, with 0 failures**。`warning:` 0 件 |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples` | **Executed 3 tests, with 0 failures** (計測ドライバは含まれず、分離が効いている) |
| Android 本体 | `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | **108 tests / 0 failures / 0 skipped** (9 クラス。新規は `KsAppContextTest` 2 / `KsCollectionViewPrefetchTest` 7 / `KsCollectionViewPublicApiTest` 4 / `KsImageCacheContractTest` 5 / `KsImagePrefetchWindowTest` 12 / `KsImageTest` 12) |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` | **13 tests / 0 failures / 0 skipped** (2 クラス) |
| lint | `comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件 / 0 件 / 0 件 (comment-policy の要確認 13 件はすべて `samples/` の既存パターンで、別途 `sample-comment-policy-cleanup` が起票済み) |

なお `-destination ...,name=iPhone 17 Pro,OS=26.0` は当環境の OS 表記 (26.0.1) と一致せず、
**テスト 0 件のまま終了コード 0** で終わる。件数の確認まで行わないと空振りに気づけない
(テスト実行規約「実行件数の確認までが検証」)。上表は UDID 指定で取り直した結果。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` にデモ画面「画像グリッド」を追加 |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と結果の報告 |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | Sample のデモ画面の追加と、実行時挙動 (取り消し・再表示・消去後の再取得) の証跡 |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | `ios/Package.swift` / `build.gradle.kts` / `libs.versions.toml` / AndroidManifest を変更 |
| [iOS 性能検証の手順と合格基準](../../handbook/ios/performance-verification.md) | 大量件数 (10,000 件) を扱う変更の完了判定 |
| [Android 性能検証の手順と合格基準](../../handbook/android/performance-verification.md) | 同上・ラッパーのスクロール経路に触れる |

参照した決定: core/ADR-0002・0008・0011・0012 (proposed)、android/ADR-0001・0002、cross/ADR-0003・0004。
`kasane/lessons/code-review.md` は未作成のため重点観点・除外観点なし。

## 指摘事項

### [🟡 Minor] デモ画面を追加したのに実行時挙動の観測点表へ追随していない

**該当箇所**: `kasane/handbook/cross/runtime-behavior-verification.md:50-62` (表の末尾は「大量件数」と
iOS / Android 固有の検証画面 2 行のまま)

**問題点**: 同文書は「観測点の一覧 (どのデモ画面で何を確認するか) は、**Sample のデモ画面が生まれる時点で
この節へ追記する**」と定めている。本 change は `samples/ios` / `samples/android` に「画像グリッド」を新設し、
さらに `--verify-image-behavior` / `ImageBehaviorVerificationScreen` というプラットフォーム固有の技術検証画面も
足しているが、観測点表にはどの行も足されていない。`evidence/image-behavior-observation.md` には実質的な観測点が
書かれているものの、これは change 配下でアーカイブされる作業文書であり、規範層には残らない。追記の予定も
`deviation.md` / `evidence/user-notes-source.md` に無く、追跡が切れている。

**推奨修正**: 観測点表に「画像グリッド」の行 (例: プリフェッチ 3 択の切り替えが以後のスクロールに効くこと、
キャッシュ消去後に可視セルが読み込み中を経て再取得されること、フリングで画面外に出たセルの読み込みが
取り消され戻ったセルが読み込み中を経ないこと) を追記する。技術検証画面の 2 行も、既存の
「検証: 行の高さ変化 (iOS 固有)」に倣って足す。実装フェーズで規範層を触る運用でないなら、少なくとも
`deviation.md` か `evidence/user-notes-source.md` に蒸留での追随項目として残し、追跡を切らないこと。

### [🟡 Minor] Android: `KsImageCache` が未初期化時に例外を投げ、利用者に回避手段が無い

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAppContext.kt:22-27`
(呼び出し元は `.../KsImageCache.kt:33` と `.../KsImageCache.kt:56`)

**問題点**: `KsAppContext.current` は未初期化なら `IllegalStateException` を投げ、公開 API
`KsImageCache.clear` / `remove` はそれをそのまま利用者アプリへ伝播させる。App Startup の
`InitializationProvider` を `tools:node="remove"` で外して初期化を自前で行う構成は androidx.startup が公式に
案内する運用であり、そのアプリでは release ビルドが公開 API 呼び出しで落ちる。しかも
`KsAppContextInitializer` は `internal` なので、利用者が `AppInitializer.initializeComponent(...)` で手動初期化
することもできず、**回避手段が無い**。core/ADR-0011 が定める release の共通方針「落とさず・消さず・黙らず」は
文言上は不正入力 (重複 ID・未登録テンプレートキー) を対象にしており本件を直接は縛らないが、
「利用者のアプリをライブラリ側の事情で落とさない」という同じ判断がここにも当てはまる。
`deviation.md` の該当項目 (`androidx.startup` の相乗り) も、初期化が走らない構成の扱いには触れていない。

**推奨修正**: `KsAppContext.current` を nullable にし、`KsImageCache.clear` / `remove` は未初期化なら
debug では assertion、release では警告ログを出して no-op で戻る (ADR-0011 の表と同じ形)。キャッシュの
インスタンスを引けない状態なので消すものも無く、no-op で契約 (「戻った時点で削除が完了している」) と
矛盾しない。あわせて、初期化が走らない構成でも使えるよう `KsAppContextInitializer` を公開するか、
context を明示的に渡す初期化 API を持つかは、公開面が増えるためオーナー判断としてよい。

### [🟡 Minor] `clear(.disk)` の公開 doc とデルタスペックの記述が実挙動と食い違い、両プラットフォームで観測差が出る

**該当箇所**: `ios/Sources/KsCollectionView/KsImageCache.swift:24-26` /
`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:28-30`

**問題点**: どちらの公開 doc も「`all` と `disk` では、表示中の `KsImage` が読み込み中の表示に戻って取得を
やり直します」と書いている (デルタスペック Requirement「キャッシュのクリア」の文をそのまま写している)。
しかし `clear(.disk)` はメモリキャッシュを消さないため、iOS は世代を進めて `LazyImage` を作り直しても
Nuke が同期でメモリ項目を返し、**読み込み中の表示には戻らない** (この同期ヒットは Scenario「戻ってきたときの
再表示」を成立させている経路そのもので、`evidence/image-behavior-observation.md` の「要求が起きない」と
一致する)。一方 Android は `rememberConstraintsSizeResolver()` で寸法確定を待つため非同期経路に入り、
一瞬 `Loading` を経由しうる。結果として同じ宣言・同じ操作でプラットフォーム間の見え方が変わる。

**推奨修正**: 公開 doc を実挙動に合わせる (「`disk` はディスクの元データを消し、以後メモリから追い出された
画像はネットワークから取り直される。表示中の画像はメモリに残っている限りそのまま」等)。デルタスペックの
文自体が `clear(.disk)` に対して物理的に満たせない要求になっているため、**足場は書き換えず**、蒸留で
concepts に落とすときにこの差を明記すること。挙動を spec の字面へ寄せる (disk 消去でメモリも捨てる) のは
利用者の不利益が大きく、推奨しない。

### [🟡 Minor] `KsImage` が表示枠の大きさを利用者に要求することが公開 doc に無く、未指定時の壊れ方が非対称

**該当箇所**: `ios/Sources/KsCollectionView/KsImage.swift:67-73` /
`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:60,123`

**問題点**: iOS は `body` の根が `GeometryReader` なので、大きさを与えないと提案された空間を貪欲に占める
(`HStack { KsImage(...); Text(...) }` では Text が潰れる)。Android は `Box` が wrap で内側の `fillMaxSize()` が
無制約側に効かないため、同じ宣言で高さ 0 になる。design.md Decision 5 の代替案 A は「`KsImage` がセル全体を
占めるとは限らず (サムネイル + テキストの行など)」を根拠に自己計測を選んでいるのに、その利用形で両
プラットフォームが**別々の壊れ方**をする。公開 doc は「表示枠の大きさが決まるまでは読み込みを始めません」と
書くだけで、大きさを与えるのが利用者の責務であることを言っていない。core/ADR-0002 が守ろうとしている
「片方で書いた宣言をもう片方へ機械的に書き写せる」に実質的な穴が空く。

**推奨修正**: 最低限、両プラットフォームの `KsImage` の公開 doc に「表示枠の大きさは利用者が与える
(`.frame(...)` / `.aspectRatio(...)` / `Modifier.size(...)` 等)」を明記する。余力があれば iOS の計測を
`background`/`overlay` の `GeometryReader` (レイアウトに影響しない形。design.md が言う「`onGeometryChange`
相当の内部実装」) へ寄せ、大きさ未指定時の挙動を Android と揃える。

### [🔵 Suggestion] iOS `remove` の公開 doc「消えるのは…あらゆる表示サイズの画像」が実装より強い

**該当箇所**: `ios/Sources/KsCollectionView/KsImageCache.swift:44-45`

**問題点**: 実装は縮小指定付きのメモリ項目を列挙できないため消しておらず、世代を進めて**到達不能にする**だけで、
実体は LRU に追い出されるまでメモリを占める (`KsImageCache.swift:61-62` の実装コメントは正確)。spec の
SHALL NOT (「削除前のキャッシュ項目に当たらない」) は満たしているが、公開 doc の「消える」は利用者に
メモリが即座に解放されると読ませる。`evidence/user-notes-source.md` の 5 は正しく書けているので、doc だけの齟齬。

**推奨修正**: 「以後どの表示サイズで要求しても削除前の画像には当たりません」に言い換える。

### [🔵 Suggestion] `enableSharedDiskCache()` が保存先を作れないときに黙って何もしない

**該当箇所**: `ios/Sources/KsCollectionView/KsImagePipeline.swift:25`

**問題点**: `try? DataCache(name:)` が失敗すると無言で `return` する。利用者は「有効にした」つもりで
ディスクキャッシュが無いまま動き、プリフェッチの到達点 `disk` が効かないことに気づく経路が無い
(core/ADR-0011 の「黙らず」と同じ性質)。

**推奨修正**: 失敗時に警告ログを出す (debug では assertion でもよい)。

### [🔵 Suggestion] Android `remove` がメモリキャッシュの全鍵を走査する

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:60`

**問題点**: `memory.keys.toList()` で全鍵のスナップショットを作って線形に走査する。`remove` は同期契約なので
呼び出しスレッド (通常は main) を項目数に比例して止める。前置一致の判定自体は `deviation.md` に best-effort と
記録済みで指摘対象外だが、計算量は記録に無い。

**推奨修正**: 実測で問題にならないなら現状でよい。気になるなら、走査が要るのは接尾辞付きの鍵だけなので
完全一致 (`MemoryCache.Key(cacheKey)`) を先に消し、走査は残りの派生鍵に限る旨をコメントで明示しておく。

## 所見 (指摘ではない)

- **core/ADR-0012 (proposed) の Decision 本文と実装の乖離**: ADR-0012 は「ライブラリの初回利用時に
  ディスクキャッシュが未設定なら…差し替える」と書いているが、実装は `deviation.md` の合意に従って
  明示 API `KsImagePipeline.enableSharedDiskCache()` になった。proposed の ADR は決定ではないので指摘には
  しないが、**蒸留で ADR-0012 を accepted 化するときに、この箇条書きと Consequences (「入れるだけで効く」) を
  実装に合わせて書き直す必要がある**。design.md の「ADR 候補」節も Decision 1 の追記を前提に書かれている。
- **iOS のみの公開型 `KsImagePipeline`**: core/ADR-0002 の 1 対 1 に対する非対称だが、`deviation.md` と
  `evidence/user-notes-source.md` の 7 に理由つきで記録済みの合意済み差分。
- **`deviation.md` の付随修正 3 件**は、いずれも本務で触るファイル内・局所・公開 API 不変で、ksn-core の
  同梱条件に収まっている (`libs.versions.toml` のコメント削除、本 change 内テストの `AtomicInteger` 化 —
  間欠失敗の再現という根拠つき、`MemoryRoundTripScreen` の引数化 — 既定値は従来どおりで既存テストが通過)。
- **未実施の実機計測 (tasks 7.1 / 7.2 / 7.5)** は合意済みの進行状態。証跡の書き方は良い —
  「何が測れて何が測れていないか」を表で分離し、エミュレータで代替しない判断 (Android 性能検証規約) と
  Simulator でメモリ定常化のみを判定する範囲 (iOS 性能検証規約) を明示している。`performance-regression-android.md`
  が「この 1 件が欠けているので先読み窓の上乗せはまだ判定できていない」と自己申告しているのは正しい態度。
- **良かった点**: 収束待ちが `awaitCondition` (実時間 deadline + 実行機会の譲り + 実測値つき失敗) で
  統一されておりテスト実行規約に沿う / 統合テストが Coil の `NetworkClient` 差し替えでディスクキャッシュ経路を
  迂回しない形に直されている (deviation 記録) / 承認モックとの照合結果が残差と合意済み差分に分けて書かれている /
  デモ画像の seed が決定的で、両プラットフォームのスクリーンショットに同じ絵が並ぶことがパリティの証拠に
  なっている。

## アクションプラン

1. **[Minor]** `handbook/cross/runtime-behavior-verification.md` の観測点表に「画像グリッド」と新設の
   技術検証画面を追記する (規範層を実装で触らない運用なら、蒸留での追随項目として `deviation.md` か
   `evidence/user-notes-source.md` に残して追跡を切らない)
2. **[Minor]** Android `KsImageCache` の未初期化時の挙動を、例外から「debug は assertion / release は警告ログ + no-op」へ
   変える (回避手段の公開が要るかはオーナー判断)
3. **[Minor]** `clear(.disk)` の公開 doc を実挙動へ合わせ、プラットフォーム間の観測差を蒸留の concepts に残す
4. **[Minor]** 両プラットフォームの `KsImage` の公開 doc に「表示枠の大きさは利用者が与える」を明記する
5. **[Suggestion]** iOS `remove` の doc 文言 / `enableSharedDiskCache()` の無言 no-op / Android `remove` の
   走査コメント — 蒸留までに直せば足りる
6. 上記と独立に、蒸留では **core/ADR-0012 の Decision と Consequences を実装 (明示 API) に合わせて確定する**
