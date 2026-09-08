# レビュー結果: image-loading (010 回目)

**日付**: 2026-09-08
**判定**: CHANGES_REQUESTED

## サマリー
群 1 (レビュー 9 周目の指摘対応) は 6 件すべてに手が入っており、実機テストの `Assume` 化と実機側の対の検査
(`displayAfterMemoryPrefetchDecodesOnceInLoader`) は、基準機 (Pixel 4a) で私が独立に実行しても 4 件成功・skip 0 で再現した
— つまり「読み出せない元寸を初回描画に使わない」経路は基準機でも実際に踏まれている。クラッシュ修正の証跡も現行実装・現行 A/B
に書き直されており、暫定回避の時期の記録は歴史として分離されている。群 2 (iOS の計測用の変更) は配布構成で不活性であり
(起動引数が無ければ従来どおり)、`xcodebuild build-for-testing` も通る。

一方で、その「基準機でも `cachedImage` は null になる」という再現結果は、**Android の到達点メモリの証跡 (tasks 7.4 / 7.5) と
両立しない**。7.4 の到達点メモリの記録は「送り先の初出要素すら読み込み中を経由しない (`lines=0`)」であり、これは
`allowHardware(false)` が付いていたビルドでしか成立しない。deviation 自身が「7.5 の到達点 memory と 7.4 の memory 側は
指定を外した状態で測り直す」「到達点メモリの値は C (指定の撤去) の反映後に測り直す」と 2 度約束しているのに、tasks 7.4 / 7.5 は
`[x]` になり、証跡の状態欄は「全系統を計測し終えた」「未判定として残るもの: なし」と書いている。これは
「測っていないことを測ったことにしない」に反する。加えて群 2 の駆動テストに、ソースコメント規約が禁止する参照が 2 件入っている。

## 照合した規約
- `handbook/cross/comment-policy.md` (always) — 新規のコメントを書いた群 2 を節ごとに照合 (「禁止する参照」で違反 2 件)
- `handbook/cross/sample-parity.md` (`samples/**` を触るため) — 文言・件数・初期選択・許容される差異・追跡の節を照合
- `handbook/cross/test-execution.md` (テストを実行・報告するため)
- `handbook/cross/runtime-behavior-verification.md` (不具合修正の完了判定 — クラッシュ修正の証跡)
- `handbook/ios/performance-verification.md` (tasks 7.1 の合否基準・手順・証跡の節)
- `handbook/android/performance-verification.md` (tasks 7.5 の 3 系統・上限 10 往復・集計での判定)
- `decisions/core/0002` (対称性の粒度)・`cross/ADR-0004` (Sample のパリティ) — 群 2 の非対称の判定に使用。`core/ADR-0012` は `proposed` のため判定根拠にしていない
- `lessons/inbox`: `reviewer-reproduces-evidence-numbers-by-probe` (基準機で実機テストを自前実行)・`exercise-device-only-branches-on-real-hardware`・`do-not-run-review-and-verify-on-same-simulator` (Simulator を起動しない形でビルド確認)・`record-runtime-verification-evidence-before-checking-task`・`check-sibling-contracts-when-fixing-a-review-finding`。`lessons/code-review.md` は未作成のため「指摘しないこと」は無し

## 実行したビルドとテスト
- `android/` `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` → BUILD SUCCESSFUL。`build/test-results` 集計で **130 tests / 0 failures / 0 errors / 0 skipped**
- `android/` `./gradlew :kscollectionview:assembleDebugAndroidTest` → 最新で up-to-date。**基準機 Pixel 4a** に APK を install し
  `am instrument -w -e class jp.kamusoft.kscollectionview.KsImageDeviceDecodeTest …` → **OK (4 tests)**。`-r` で生の状態も確認し、
  **前提 (`Assume`) による skip は 0 件** — Pixel 4a では先読みの元寸が `Bitmap.Config.HARDWARE` で載り、`prepare` の `cachedImage` は
  null、ローダーのデコードは 1 回、という現行実装の契約が基準機でも成立している (証跡の Pixel 6a の結果を別機で再現)
- `xcodebuild build-for-testing -project samples/ios/KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples
  -destination 'generic/platform=iOS Simulator'` → **TEST BUILD SUCCEEDED** (Simulator は起動していない)
- `python3 scripts/comment-policy-lint.py --advisory` → 禁止 0 件 / 要確認 14 件。ただし機械検査の検出範囲は規約より狭く、下記 Major 2 は検出されない
- iOS 本体のユニットテストは本便で変更されていないためホスト報告 (156 / 0) を採り、Simulator は起動していない

## 指摘事項

### [🟠 Major] Android の到達点メモリの計測・観測が「撤去前のビルドの値」のまま完了扱いになっている

**該当箇所**: `tasks.md:54` (7.5) / `tasks.md:56` (7.4) / `evidence/image-grid-measurement-android.md:3-16` と `:254` /
`evidence/image-behavior-observation.md` (「結果 (到達点メモリ) — クラッシュ修正後の初計測」の節) / `deviation.md:83` `:91`

**問題点**:
deviation は 2 度、到達点メモリの再計測を約束している。

- `deviation.md:83`「7.5 の到達点 memory と 7.4 の memory 側は**指定を外した状態で測り直す**」
- `deviation.md:91`「tasks 7.5 (Android、クラッシュ修正後・`allowHardware(false)` **適用中の値**) … 到達点メモリの値は
  C (指定の撤去) の反映後に**測り直す**」

`deviation.md:91` が列挙している値 (ディスク 6.4 / 6.2 ms・メモリ 18.2 / 20.6 ms) は、現在の
`evidence/image-grid-measurement-android.md` のスクロール表と同一である。つまり証跡に載っている到達点メモリの値は
**撤去前のビルドで取った値**であり、再計測は行われていない。それにもかかわらず、

- `tasks.md` の 7.4 / 7.5 は `[x]`
- 証跡の状態欄は「規約どおり全系統を計測し終えた」「**未判定は残っていない**」、末尾の「未判定として残るもの」は「**なし**」
- 証跡本文には、値がどのビルドのものかの断りが一切ない (`allowHardware(false)` の語が出るのは
  `:186` と `:270` の考察部分だけで、そこでは現行実装の説明として書かれている)

撤去は到達点メモリの費用構造そのものを変える (同期縮小が走らなくなり、代わりにローダーの縮小デコードが 1 回入る) ため、
18.2 / 20.6 ms は現行実装の値ではない。`:270`「到達点メモリの超過が到達点ディスクの約 3 倍である点を読む —
`allowHardware(false)` により…」も、現行実装には存在しない指定を原因候補として残しており、次に読む人を誤らせる。

さらに 7.4 の到達点メモリの観測 (`image-behavior-observation.md`) は、**現行実装と両立しない結論を合格の根拠に含んでいる**。

> 加えて、この土俵では**送り先の初出の要素 (ID 16〜45) すら読み込み中を経由していない** — 到達点メモリの先読みが
> 表示より先にメモリへ載せているためである。

初出の要素で読み込み中を経由しないためには `prepare` が元寸から同期縮小できる (画素を読める) 必要がある。本レビューで
基準機 Pixel 4a に対して実機テストを走らせた結果、**先読みの元寸は `HARDWARE` で載り `cachedImage` は null** になる
(skip 0 で 4 件成功)。同じ Pixel 4a で取った `lines=0` は、`allowHardware(false)` が付いていた時期の観測でしか成立しない。
`deviation.md:84` 自身も「実機では通常、読み込み中を一瞬経由する」と書いており、証跡と食い違っている。
帰結として `deviation.md:87`「iOS では到達点 memory でも送り先の初出要素は読み込み中を経由する (**Android は経由しない**)」も、
現行実装の事実ではないプラットフォーム非対称を蒸留の原料として残すことになる。

なお、到達点**ディスク**側の値と観測は撤去の影響を受けないため、この指摘の対象外である。

**推奨修正**: 次のいずれかを取る。

1. 撤去後のビルドで 7.5 の到達点メモリ (スクロール 3 試行・メモリ定常化 2 系統・件数比) と 7.4 の到達点メモリの観測を測り直し、
   証跡を差し替える。その際、レビュー 9 周目 Minor 2 の求めどおり **その実行で元寸がどちらの画素構成だったか** を証跡に添える
2. 再計測を後続便に送るなら、`tasks.md` の 7.4 / 7.5 を `[x]` から戻し、証跡の状態欄と「未判定として残るもの」に
   「到達点メモリの値と観測は `allowHardware(false)` 適用中のビルドのもので、撤去後の値は未取得」と明記する。
   `evidence/image-grid-measurement-android.md:270` の原因考察と `deviation.md:87` の非対称も同じ扱いに直す

### [🟠 Major] 計測用の駆動テストにソースコメント規約が禁止する参照が入っている

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:106` および `:108`

**問題点**:
`cross/comment-policy.md` (always) の「禁止する参照」に、次の 2 件が正面から該当する。

- `:106` `/// 「戻ってきたときの再表示」を基準点機構で観測するための駆動です (tasks 7.4)。`
  → 「**タスクのローカル通番**」(規約の例示は `タスク 2.4`)。tasks.md はアーカイブされるため、番号だけでは意味が追えなくなる
- `:108` `/// 手順は証跡 (`evidence/image-behavior-observation.md` の「判定の手順」) と同じ順序で、`
  → 「**作業文書のパス**」。`kasane/changes/image-loading/evidence/` 配下であり、アーカイブ後は指す先が動く

このファイルは change がアーカイブされた後もリポジトリに残る計測の足場であり、規約が防ごうとしている「アーカイブ済み文書への
依存」がそのまま残る形になる。機械検査 (`comment-policy-lint.py`) はこの 2 類型を検出しないため禁止 0 件だが、規約本文は
「検査の検出範囲は本規約より狭い — コードレビューが規約本文から判定する」と定めている。

**推奨修正**: 通番とパスを外し、そのファイルだけで意味が通る説明に書き直す
(例: 「初回表示の収束を待ち、印を叩いて観測区間を切ってから、同じ表示サイズのまま送って戻す駆動」)。
手順の一致を担保したいなら、駆動が出力する印 (`KS74`) の書式で自己完結させる。

### [🟡 Minor] クラッシュ修正の証跡の見出しが、現行実装で未実施の確認まで含んで「解消済み」と断定している

**該当箇所**: `evidence/image-grid-memory-prefetch-crash-fix-android.md:3-7` と `:119-122`

**問題点**:
冒頭は「**解消済み。** 修正前は基準機で必ず落ち、修正後は同じ操作で落ちない」と書くが、同じ文書の末尾は
「基準機 (Pixel 4a) での実機目視 … **未取得 (再計測便で取る)**」と認めている。`cross/runtime-behavior-verification.md` の
規約 2 は「修正後に**同一手順**で解消を確認する」ことを求めており、同一手順とは冒頭の「手順」節が定める
Sample のフリック操作である。撤去後の実装でその手順を踏んだ記録は無く、あるのは別機 (Pixel 6a) の instrumentation テストと
分岐の無効化による A/B — 経路は押さえているが、症状の手順ではない。

なお本レビューで **基準機 Pixel 4a の instrumentation テスト 4 件は取得した** (skip 0 で成功)。フリックによる目視だけが未取得である。

**推奨修正**: 冒頭の断定を、現行実装で確かめた範囲 (実機テストと分岐の A/B) と未取得の範囲 (基準機でのフリック操作) に分けて書く。
本レビューの Pixel 4a の実行を使うなら、機材・手順・結果を証跡に取り込んでよい。

### [🟡 Minor] iOS の計測窓が実測 5.98 秒に伸びた理由が「駆動のオーバーシュート」と断定されている

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:57-63` /
`evidence/image-grid-measurement-ios.md`「区間の長さがそろわないこと」

**問題点**:
証跡は区間が 3.0〜6.0 秒に伸びる理由を「1 回のフリックが終わるまで止まらないため」と断定している。しかし窓の長さは、
少なくとも次の 2 つの要因を分離できていない。

1. `XCUIElement.swipeUp` はジェスチャ後にアプリの静止 (quiescence) を待つ。画像の取得・デコードが走っている土俵では
   この待ちが秒単位になりうる。その時間は**フリックしていない時間**だが窓には入る
2. 区間の印は Darwin 通知を受けたアプリ側の run loop で出す (`ScrollWindowSignpost`)。主スレッドがスクロール中は配送が遅れうるため、
   `end` の印が実際のフリック終了より後ろにずれる可能性がある

どちらも窓を伸ばす向き、すなわち hitch time ratio を**合格側に薄める**向きに働く。実際に伸びたのは 3 試行のうち試行 1 だけで、
合格したのもその試行 1 だけである (5.98 s / 1.47 ms/s)。証跡は「3.0 秒で割り直しても合否は変わらない (試行 1 は 2.92 ms/s)」と
補足しており判定そのものは動かないが、`deviation.md:93` が今後この駆動を改善して再計測すると書いている以上、
原因の切り分けは残しておく価値がある。

**推奨修正**: 区間内のフリック回数 (または `swipeUp` の呼び出し回数と各回の所要時間) を駆動から出力し、証跡に添える。
「区間の実測長で割る」判定を続けるなら、窓に含まれる無操作時間の見積もりを限界の節に書く。

### [🟡 Minor] iOS 7.1 の証跡だけを読むと、この値が最終であるかのように読める

**該当箇所**: `evidence/image-grid-measurement-ios.md:3-16` / `deviation.md:93`

**問題点**:
`deviation.md:93` は不合格の切り分け結果として「対応: 駆動の改善 (座標を先に確定・区間 3.00 s 固定) と対照 (大量件数) を取って
**再計測**し、それでも落ちるなら規約 (窓・閾値) の改訂をオーナー判断へ」と書いている。一方 `image-grid-measurement-ios.md` は
「計測としては完了、性能の合否としては不合格」で止まっており、再計測の予定にも、hitch が 1 件 = 1 リフレッシュで
「3 秒窓 × 5 ms/s は実質フレーム落ち 0 と同値」という切り分けにも触れていない。証跡は蒸留の原料になるため、
deviation にしかない結論は後から見つけにくい。

**推奨修正**: 証跡に「次に必要なこと」相当の節を足し、切り分け結果 (`KsImage` の経路は hitch 時刻に不在・計測の足場が主スレッドの
11〜17% を占める) と再計測の予定を書く。Android 側の証跡が同じ形 (「次に必要なこと」) を持っており、揃う。

### [🔵 Suggestion] `--prefetch` の解釈が 2 箇所に重複している

**該当箇所**: `samples/ios/KsCollectionViewSamples/ImagePrefetchChoice.swift:17-25` /
`samples/ios/KsCollectionViewSamples/SampleLaunchView.swift:21-24` と `:40-46`

**問題点**: 起動引数の綴りと値の対応 (`none` / `disk` / `memory`) が 2 箇所で独立に書かれている。現状は両者の結果が一致するが、
綴りを変えたときに片方だけが追随しても誰も落ちない (デモ画面は初期選択に戻り、計測経路は `.disk` に倒れる) ため、
計測の到達点が静かに食い違う形の壊れ方をする。

**推奨修正**: `SampleLaunchView` 側を `ImagePrefetchChoice.requested` に寄せ、引数の解釈を 1 箇所にする。

### [🔵 Suggestion] iOS 7.4 の「送り先の行数」の帰属が内訳と一致していない

**該当箇所**: `evidence/image-behavior-observation.md` (iOS の「判定」節)

**問題点**: 「送り先の ID 16〜45 が `Δsized >= 1` を記録している (ディスクで **45 行**、メモリで **39 行**)」と書かれているが、
45 行 / 39 行はその `session` の全行数であり、内訳表が別に数えている ID 13〜15 の 3 行と、戻す区間の ID 19〜21 の 3 行を含む。
また ID 16〜45 は 30 件しかないため、45 行には同一要素の複数回の構成が含まれている。空振りでないことの裏付けとしては十分だが、
数の帰属としては表と本文が食い違う。

**推奨修正**: 「その `session` の全行数」と「送り先の初出要素の行数」を分けて書く。

## 確認して問題が無かった観点
- **群 2 が配布構成で不活性**: `ScrollWindowSignpost.enableIfRequested()` は `--signpost-scroll-window` が無ければ待ち受けを登録せず、
  `ImagePrefetchChoice.requested` は `--prefetch` が無ければ `nil` を返して画面の初期選択 (`.disk`) に落ちる。通常起動の
  デモ画面の見た目・文言・初期選択は不変
- **sample-parity**: 画面の集合・文言・件数・列数・初期値は両プラットフォームで不変。`--prefetch` による初期選択の差し替えは
  iOS だけの手立てだが、Android には対応する計測経路 (`measurement/image/<件数>/<到達点>`) があり、
  この構造の非対称は `deviation.md:71` に、今回の iOS 側の追加は `deviation.md:89` に記録されている。
  規約の「許容される差異 (画面文言に出ないコード上の差)」と「追跡が残っている一時的な不一致は違反ではない」に収まる
- **群 1 の doc と実装の一致**: `KsCoilImageLoading` / `KsImageRequestFactory` / `KsImage` の説明は撤去後の経路
  (指定を付けない・読み出せない元寸は初回描画に使わない・読み込み中を一瞬経由する) を現在形で書いており、
  「常にではない」の幅も 3 箇所で揃っている。公開 doc (`KsPrefetchDestination`) は不変で、今回の帰結を誤って約束していない
- **前回 Major 2 の実機側の対**: `displayAfterMemoryPrefetchDecodesOnceInLoader` は `SingletonImageLoader.setUnsafe` で
  観測付きローダーを差しつつ、要求の生成は `KsCoilImageLoading` → `KsImageRequestFactory.prepare` の本番経路を通しており、
  `finally` で `reset()` + `shutdown()` まで戻している。基準機での実行でも 4 件が独立に成立した
  (`check-tests-exercise-production-path-before-accepting-green` の型に該当しない)
- **`Assume` 化の副作用**: 前提が崩れる端末では skip されるだけで、契約のアサーション (落ちない・枠を超えない・デコード 1 回) は
  前提の後ろに残っている。Pixel 4a の実行では前提が成立し skip 0 だった
- **足場アーティファクト**: `specs/image-loading/spec.md` は未変更 (`git status` で確認)。書き換えによる辻褄合わせは無い
- **ライブラリ本体 (iOS)**: 群 2 で `ios/Sources/` に変更は無く、計測のための本体改変は行われていない

## アクションプラン
1. Android の到達点メモリ (tasks 7.4 / 7.5) を撤去後のビルドで測り直すか、`[x]` を戻して証跡・deviation:87 に
   「撤去前のビルドの値」であることを明記する (Major 1)
2. `PerformanceDriverUITests.swift:106,108` の禁止参照を自己完結する説明に書き直す (Major 2)
3. クラッシュ修正の証跡の「解消済み」の射程を、確かめた範囲と未取得の範囲に分けて書く (Minor 1。基準機の実機テスト 4/0 は本レビューで取得済み)
4. iOS 計測窓の長さのばらつきの原因を切り分けられる出力を駆動に足す (Minor 2)
5. iOS 7.1 の証跡に切り分け結果と再計測の予定を書く (Minor 3)
6. `--prefetch` の解釈を 1 箇所へ、iOS 7.4 の行数の帰属を正確に (Suggestion 2 件)

## 前回指摘 (review-009) の解消判定
| 前回の指摘 | 判定 | 根拠 |
|---|---|---|
| Major 1: 破れる SHALL が deviation に 1 件しか無い | **解消** | `deviation.md:84` に「デコードのやり直しもなし」の逸脱・費用の帰結・環境依存・解消先を追記 |
| Major 2: 「再デコードしない」の unit テストが代替実装の上でだけ緑 | **解消** | テストを `memoryDestinationAvoidsSecondDecodeWhenPrefetchedPixelsAreReadable` に改名し KDoc で射程を限定。実機側に対の検査を新設し、基準機でも成立を確認 |
| Major 3: クラッシュ修正の証跡が現行実装と逆 | **解消** (残 Minor 1) | 暫定回避の節と現行の節に分離し、現行の A/B (分岐の無効化) と 4 件の契約に差し替え。静止画も暫定回避時のものと明記。ただし「解消済み」の断定の射程は残課題 |
| Minor 1: 実機テストが環境条件を assert している | **解消** | `assumeGraphicsBacked` / `assumeTrue` に移し、契約のアサーションだけを残した |
| Minor 2: 実機挙動の記述の幅が 3 箇所で食い違う | **部分解消** | doc と deviation は「常にではない」で揃った。「再計測の証跡にその実行の構成を添える」は再計測自体が未実施のため未達 (Major 1 に含む) |
| Suggestion: iOS との非対称が deviation に無い | **解消** | `deviation.md:84` 末尾に記録 |
