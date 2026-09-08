# レビュー結果: image-loading (011 回目)

**日付**: 2026-09-08
**判定**: CHANGES_REQUESTED

## サマリー
前回 (レビュー 10 周目 + 相方 010) の指摘は 9 件すべてに手が入っており、**実質的にはすべて解消している**。
とくに最大の指摘だった「Android の到達点メモリを撤去前のビルドの値で完了扱いにしている」は、C 反映後の
基準機で 7.5 (スクロール・メモリ定常化・件数比) と 7.4 (計数の基準点機構) を測り直した値に差し替えられ、
撤去前の値は履歴節へ退避された。証跡の結論 (「送り先の初出要素は読み込み中を経由する」24 行) は、
本レビューが**基準機で実機テストを独立に実行して確かめた機構** (元寸はグラフィックス側に載り初回描画に使えない、
4 件成功・skip 0) と整合する。iOS 側も駆動の改善後に測り直され、証跡は不合格を不合格として書いている。

残るのは 1 点だけである。相方 Major「収束待機がタイムアウトで黙って戻る」の修正で、**実装は直ったが
直前の doc コメントが旧仕様 (「待ち切れなかった場合もそのまま進み」) のまま残り、同じ関数に 2 つの
食い違う説明が並んでいる**。修正そのものを次の読み手が読み違える形なので、Minor だが優先度は高いと判断した。
他の 2 件は Suggestion (証跡・deviation の読み違え予防) である。

## 照合した規約
- `handbook/cross/comment-policy.md` (always) — 本便で書き換えられた駆動テスト・Sample のコメントを節ごとに照合。
  「禁止する参照」の 2 件は解消済み。新たに「実装と食い違う説明」が 1 件 (下記 Minor)
- `handbook/cross/test-execution.md` (テストを実行・報告するため) — 「収束を待つアサーション」の 3 条件で
  `waitUntilMarkSettles` を照合。実装は 3 条件を満たす。「Sample の UI テストと計測ドライバを分けて実行する」も照合
- `handbook/cross/sample-parity.md` (`samples/**` を触るため) — `--prefetch` の一本化で画面の文言・件数・初期選択が
  変わらないことを照合
- `handbook/ios/performance-verification.md` (tasks 7.1 の手順・合格基準・証跡の節)
- `handbook/android/performance-verification.md` (tasks 7.5 の系統と判定)
- `handbook/cross/runtime-behavior-verification.md` (クラッシュ修正の完了判定 — 基準機の目視)
- `handbook/cross/local-development-setup.md` (実機での実行手順)
- `decisions/cross/ADR-0004` (Sample のパリティ)。`core/ADR-0012` は `proposed` のため判定根拠にしていない
- `lessons/inbox`: `reviewer-reproduces-evidence-numbers-by-probe` (基準機で実機テストを自前実行)・
  `do-not-run-review-and-verify-on-same-simulator` (Simulator は使わず実機のみ)・
  `record-runtime-verification-evidence-before-checking-task`・`check-sibling-contracts-when-fixing-a-review-finding`
  (`--prefetch` の一本化に対する Android 側の対を確認 — Android のデモ画面は起動引数ではなく経路で到達点を渡すため
  同型の重複は無い)・`stop-asking-per-cycle-when-fix-is-specified`。`lessons/code-review.md` は未作成のため
  「指摘しないこと」は無し

## 実行したビルドとテスト
- **iOS Sample の UI テスト (基準機 iPhone 11・実機)**: `xcodebuild test -project KsCollectionViewSamples.xcodeproj
  -scheme KsCollectionViewSamples -destination 'platform=iOS,id=<基準機>'` → **TEST SUCCEEDED / Executed 5 tests,
  with 0 failures** (`ImageLoadingSlotUITests` 2 件・`InteractiveControlUITests` 3 件)。
  `PerformanceDriverUITests.swift` は**コンパイルはされ**、スキームの `SkippedTests` により**実行されていない**
  (test-execution の「分離が効いている確認」)。署名は作業ツリーを汚さないよう `DEVELOPMENT_TEAM` と
  `-allowProvisioningUpdates` をコマンドラインで与え、`-derivedDataPath` もスクラッチへ逃がした。
  実行後に `git status` で `samples/ios` に新たな差分が出ていないことを確認済み
- **Android 実機テスト (基準機 Pixel 4a)**: `./gradlew :kscollectionview:assembleDebugAndroidTest` → BUILD SUCCESSFUL。
  APK を基準機へ install し `am instrument -w -r -e class jp.kamusoft.kscollectionview.KsImageDeviceDecodeTest …` →
  **OK (4 tests)**、`Assume` による skip は 0 件。証跡が新たに主張する「到達点メモリの初出要素は読み込み中を経由する」
  の機構 (先読みの元寸はグラフィックス側に載り `cachedImage` が null になる) が、基準機で現行コードのまま成立している
- `python3 scripts/comment-policy-lint.py --advisory` → **禁止 0 件** / 要確認 14 件 (いずれも既存の Sample 内部型の
  ADR 参照で本便の追加ではない)。`local-path-lint.py` / `identity-lint.py` → いずれも検出 0 件
- iOS 本体のユニットテストと Android のユニットテストは本便で変更されていないためホスト報告を採り、
  Simulator は起動していない (lessons: `do-not-run-review-and-verify-on-same-simulator`)

## 指摘事項

### [🟡 Minor] 収束待機に doc コメントが 2 つ並び、前半が現行の契約と逆のことを書いている

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:237-249`

**問題点**:
`waitUntilMarkSettles` の宣言の前に doc コメントが 2 ブロックあり、その間に `@MainActor` が挟まっている。

- `:237-246` (前半、旧仕様のまま): 「**待ち切れなかった場合もそのまま進み**、収束しなかったことは出力された印の値から
  読み取れるようにします。」 + `- Parameters:` の 3 項目
- `:247` `@MainActor`
- `:248-249` (後半、新仕様): 「締切までに静止しなければテストを失敗させ `false` を返します
  (黙って戻ると、未収束のまま基準点を切っても緑になってしまうため)。」

実装 (`:269-270`) は後半のとおり `XCTFail` + `false` であり、呼び出し側も `guard … else { return }` で後続を中止する。
つまり**前半は現行の契約と正反対**で、`cross/comment-policy.md` が最低条件とする「そのファイルだけを読んでいる人に
とって意味が通る」を満たしていない。この関数は相方 Major「黙って戻る待機」の修正対象そのものであり、
旧説明を残したままだと次に触る人が「静止しなくても進んでよい」と読んで復元しかねない。
`- Parameters:` の帰属も宣言から切り離されている。

同種の取り残しがもう 1 件ある。`samples/ios/KsCollectionViewSamples/ImagePrefetchChoice.swift:16` の
「名前は `SampleLaunchView` の計測用の起動経路と同じものを使います。」は、本便で綴りの解釈を
`ImagePrefetchChoice` へ一本化した結果 (`SampleLaunchView.swift:35-37` は `resolved` を呼ぶだけになった)、
指す先が無くなっている。

**推奨修正**: 前半の doc ブロックを削除し、`- Parameters:` の 3 項目を後半のブロックへ移して 1 つにまとめる
(`@MainActor` は doc ブロックの後ろへ)。`ImagePrefetchChoice.swift:16` の一文は削除するか、
「起動引数を読む経路はすべてこの型を通す」旨に書き直す。

### [🔵 Suggestion] deviation の旧エントリが、解消済みのプラットフォーム非対称を現在形のまま残している

**該当箇所**: `deviation.md:87` (「iOS では到達点 `memory` でも送り先の初出要素は読み込み中を経由する
(Android は経由しない)」)

**問題点**: 同じ日付の後続エントリ (`deviation.md:94`) が「送り先の初出要素は読み込み中を経由する
(iOS と同形。適用中の『送り先も経由しない』の非対称は解消)」と書いており、証跡側 (
`evidence/image-behavior-observation.md:163-166`) も撤去後は同形になったと記録している。したがって
`:87` の括弧内は現行の事実ではない。deviation は日付順の記録なので追えなくはないが、両エントリが
**同じ日付**で、`:87` は現在形の断定のため、蒸留でプラットフォーム非対称として拾われる余地が残る。

**推奨修正**: `:87` の末尾に「(後述の C 反映後の取り直しで解消)」の一言を添える (エントリ自体は履歴として残す)。

### [🔵 Suggestion] iOS の対照 (「大量件数」) で、根拠に使った画面更新回数が表に載っていない

**該当箇所**: `evidence/image-grid-measurement-ios.md:229-244`

**問題点**: 対照の読み取りとして「画面の更新回数は両者ほぼ同じ (130〜143 回) なので、走った量の違いでもない」と
書いているが、130〜143 回は**画像グリッド側の値**であり (`:216-220` の表)、対照 3 試行の画面更新回数と `KS71` の
出力 (空打ち・区間内のフリック回数・各回の所要) は載っていない。対照は「画像グリッドの残り 1 件は足場由来ではない」
という切り分けの土台なので、その根拠の片方が読み手から確かめられない状態になっている。

**推奨修正**: 対照 3 試行についても `:216` と同じ列 (空打ち・フリック回数・各回の所要・区間内の画面更新・fps) を
表に足す。取り直しが要るなら「対照の更新回数は記録していない」と限界に書く。

## 確認して問題が無かった観点
- **収束待機の修正の中身**: `waitUntilMarkSettles` は実時間 deadline で区切り (`:256` `:259`)、ループ内で
  `Thread.sleep(0.5)` により待機対象へ実行機会を譲り (`:260`)、超過時は最後の印を載せて失敗する (`:269`)。
  `test-execution.md` の 3 条件をすべて満たす。呼び出し側 3 箇所 (`:210` `:217` `:221`) すべてが
  `guard … else { return }` で後続の基準点・ドラッグ・出力を中止する
- **禁止参照の除去**: `PerformanceDriverUITests.swift:185-192` はタスク通番も証跡パスも持たず、`KS74` という
  出力の印だけで手順を自己完結して説明している。`:48-70` の新しい doc も、参照は起動引数と
  `ScrollWindowSignpost` (リポジトリ内のコード識別子) に限られる。機械検査でも禁止 0 件
- **`--prefetch` 一本化の挙動同値**: 旧 `SampleLaunchView` は `none → nil` / `memory → .memory` / それ以外 (未指定・
  綴り違いを含む) `→ .disk`、新 `ImagePrefetchChoice.resolved` は `requested ?? .disk` で `requested` が
  `none/disk/memory` 以外に `nil` を返すため、**すべての入力で結果が一致する**。デモ画面の初期選択も `.disk` のまま
- **群 1 の駆動改善が計測の主張と整合**: 座標は `flickForFixedWindow` の冒頭で 1 度だけ確定され (`:76-84`)、
  ループ内は `flick` (絶対座標の press-drag) のみで要素解決が無い。終わりの印は別キューの
  `asyncAfter(wallDeadline:)` で締切ちょうどに送られる (`:98-101`)。証跡の区間実測長 3.01〜3.04 s は、
  印の配送遅れが 40 ms 以下に収まっていることの裏付けにもなっている
- **証跡が「測っていないことを測ったことにしていない」か**:
  Android 側は到達点ディスクの系統を「撤去の影響を受けないため測り直していない」と明示し
  (`image-grid-measurement-android.md:10-11` `:203`)、撤去前の値は履歴節へ退避、`MemoryUsageMetric` の
  GPU 欄については「移った先をこの記録では確かめられていない」と限界を書いている。iOS 側は前半の値を
  履歴に落とし「比較しない」と明記し、区間内のフリック投入が 1 回であること・無操作時間が合格側に薄める向きで
  あることを限界に書いている。**数値と判定の整合も確認した** — Android の 24 行 (証跡) と
  クラッシュ修正証跡の「初出 24 件」、iOS の行数の帰属表 (45 = 3 + 42 + 0 / 39 = 3 + 36 + 0) と
  重複行の内訳 (12 件 / 6 件が 2 行) はいずれも一致する
- **クラッシュ修正証跡の射程**: 「未取得」節が「なし」になったのは基準機の目視 (`:119-133`) を取ったためで、
  静止画は「写ったこと」だけを経由の証拠に使い、非発現の主張には使わないと明記されている
  (オーナーの判断軸「静止画の非発現を根拠にしない」と整合)
- **tasks の `[x]` と不合格の並存**: 7.1 / 7.5 の task 文言は「計測し証跡に残す」であり、計測は実施済みで
  証跡も不合格を不合格と書いている。性能の合否・規約改訂・「大量件数」の超過はいずれも
  `deviation.md:93` `:97` と両証跡の「次に必要なこと」でオーナー判断待ちとして明示されており、
  虚偽のチェックではない。ただし**性能面の完了として報告できる状態ではない** (両 handbook の合格基準を
  満たしていない) 点は、完了報告の側で落とさないこと
- **足場アーティファクト**: `specs/image-loading/spec.md` は未変更 (`git status`)。書き換えによる辻褄合わせは無い
- **ライブラリ本体**: 本便で `ios/Sources/` `android/kscollectionview/src/main/` に変更は無く、
  計測のための本体改変は行われていない

## アクションプラン
1. `PerformanceDriverUITests.swift:237-249` の doc コメントを 1 つに統合し、旧仕様の記述を消す。
   併せて `ImagePrefetchChoice.swift:16` の指す先の無い一文を直す (Minor)
2. `deviation.md:87` に解消済みである旨を添える (Suggestion)
3. iOS 証跡の対照節に、対照 3 試行の `KS71` と画面更新回数を足すか、記録していないことを限界に書く (Suggestion)

## 前回指摘の解消判定

### レビュー 10 周目 (review-010)
| 前回の指摘 | 判定 | 根拠 |
|---|---|---|
| Major 1: Android の到達点メモリが撤去前のビルドの値のまま完了扱い | **解消** | C 反映後に基準機で 7.5 (P99 4.6 / 4.4 ms・定常化 114 / 119 MB・件数比 1.05〜1.10) と 7.4 (24 行) を測り直し、撤去前の値は `image-grid-measurement-android.md:299-328` の履歴節へ退避。状態欄も「撤去後の値」と明示。7.4 の観測は「送り先の初出要素は経由する」に訂正され、本レビューの基準機実機テスト (4/0・skip 0) が機構を裏づける |
| Major 2: 駆動テストの禁止参照 (タスク通番・証跡パス) | **解消** | `PerformanceDriverUITests.swift:185-192` を書き直し、`KS74` の出力だけで自己完結。lint も禁止 0 件 |
| Minor 1: クラッシュ修正証跡の「解消済み」の射程 | **解消** | 基準機 (Pixel 4a) の目視を `:119-133` に追記し、「未取得」を「なし」に更新。静止画の読み方の限界も明記 |
| Minor 2: 計測窓が伸びた理由の切り分け | **解消** | 駆動が `KS71` で空打ち・フリック回数・各回の所要を出力し、証跡 `:212-227` に画面更新回数と無操作時間の見積もりを追加。窓は 3.01〜3.04 s にそろった |
| Minor 3: 7.1 証跡だけを読むと値が最終に見える | **解消** | `:281-305` に「次に必要なこと」節を新設 (切り分け済みの 4 点とオーナー判断が要る 3 点) |
| Suggestion 1: `--prefetch` の解釈が 2 箇所 | **解消** | `ImagePrefetchChoice.requested` / `initialSelection` / `resolved` に一本化。挙動は全入力で同値 |
| Suggestion 2: iOS 7.4 の行数の帰属 | **解消** | `image-behavior-observation.md:255-266` に帰属の表と重複行の内訳を追加 |

### 相方レビュー 10 周目 (second-opinion-code-010)
| 相方の指摘 | 判定 | 根拠 |
|---|---|---|
| Major: 撤去前の Android 計測を現行結果として完了扱い | **解消** | 上記 Major 1 と同じ |
| Major: `waitUntilMarkSettles` がタイムアウトで黙って戻る | **解消 (残 Minor)** | `:269-270` で最後の印を載せて `XCTFail` し `false` を返す。呼び出し側は `guard` で後続を中止。ただし旧仕様の doc コメントが残存 (本レビュー Minor) |
| Minor: 駆動コメントのタスク通番・証跡パス | **解消** | 上記 Major 2 と同じ |
| Minor: iOS 証跡の「規約どおり」が区間の乖離と矛盾 | **解消** | `image-grid-measurement-ios.md:5` を「合意済みの乖離 (区間の投入回数・窓の閉じ方) を含む立て直し手順で」に改めた |
