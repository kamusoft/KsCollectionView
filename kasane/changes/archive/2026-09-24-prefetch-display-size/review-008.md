# レビュー結果: prefetch-display-size (008 回目)

**日付**: 2026-09-23
**判定**: APPROVED

## サマリー

second-opinion-code-007 で採用した iOS の計測の足場の 2 件は直っている。1 件目は、可視の判定がはみ出しを切り取る祖先の範囲で狭めるようになった。2 件目は、見張りの周期が見張る相手のいない間は止まり、次に載せられたときに再開する。どちらも新しい UI テストで押さえてあり、レビュアーの実行でも通った。画像グリッドの実際の観測を現行のコードで Simulator で再実行し、`matchedShown=0`、`shown 9 = displayStarts 9`、`violation=0` を再現した。表示範囲の外で前もって組み立てられたセルを数える過大計上は無い。実機の証跡は、tasks 6.6 / 8.2 / 8.3 / 8.4 / 8.5 のチェックと対象の Scenario を裏付けている。ローカル絶対パスと個体識別子も入っていない。ただし再現性と鮮度の観点で Minor を 2 件出す。1 件は、iOS の一部の計測がスクラッチにしか無い足場に依っていること。もう 1 件は、Android の 2 本の証跡が修正サイクル 6 の前のビルドで採られたのに、そのことが書かれていないこと。

## 照合した規約

- ソースコメント規約 (always): サイクル 7 で変わった、または新しく入ったコメントを節ごとに照合した。対象は `ImageLoadingSlotShownProbeView.isOnScreen` の説明、`ImageLoadingSlotShownMonitor` (冒頭・`watched`・`tick` の停止・`isRunning`)、`ImageLoadingSlotShownClipping{Scroll,State,View,Representable}`、`ImageLoadingSlotShownClippingUITests` である。どれも外部文書の ID に頼らず、それだけで読める。comment-policy-lint は禁止 0 件
- テスト実行規約 (テスト実行・結果の報告): 件数を集計して確かめた (下記)。iOS は `Executed N tests` で、Android はクラス単位の XML を合計した。iOS Sample の通常スキームには計測ドライバが入っていない (11 件の内訳で確かめた)
- 実行時挙動の検証規約 (不具合修正の完了判定): 採用した 2 件は UI テストで固定されている。画像グリッドの実際の経路でも、レビュアーの観測で効き目を確かめた (下記)
- Sample のプラットフォーム間一致 (`samples/**`): 検証画面 `ImageLoadingSlotShownClippingView` は、起動引数 `--verify-slot-shown-clipping` でしか開かない UI テスト専用の技術検証画面である。メニューに出ず、デモ画面の集合に入らない (例外枠)。デモ画面の文言・構成・見た目に差分は無い
- iOS 性能検証の手順 / Android 性能検証の手順 / スクロール性能の体感ゲート (性能の証跡を書くとき): evidence の 8.2 / 8.3 / 8.5 を、メモリの手順 (往復・定常判定・未判定の扱い・保持対象の解放) と証跡の規律 (生ログはスクラッチ、抜粋は sanitize、個体識別子を含めない) に照らして読んだ

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行。DerivedData はスクラッチ、Simulator は iPhone 16e / iOS 26.0。起動中の他の機種と重ならない)**
  - iOS パッケージ: **271 tests / 0 failures**
  - Android ライブラリ (`--rerun-tasks`): **219 件 / 失敗 0 / skip 0** (13 クラス)
  - Android Sample (`--rerun-tasks`): **44 件 / 失敗 0** (8 クラス)
  - iOS Sample の通常スキーム: **11 tests / 2 failures**。新しい `ImageLoadingSlotShownClippingUITests` は 2 件とも成功した。失敗の 2 件は `LargeDataCountUITests` の「件数に 0 / 数値でない値を指定すると起動しない」で、失敗の理由は `Expected failure '受け取れない件数では起動が止まる' but none recorded` だった。ホストの報告 (HEAD でも同じく失敗する、XCTest がアプリの異常終了を記録しない環境の問題) と同じ形なので、本 change の起因とはしない
  - comment-policy-lint: 禁止 0。identity-lint / local-path-lint: 違反なし (終了コード 0)
- **second-opinion-code-007 の採用 2 件の修正**
  - **(Major) iOS: `shown` が切り取られた表示を数え得る**: `ImageLoadingSlotShownProbeView.isOnScreen` (`samples/ios/KsCollectionViewSamples/ImageLoadingSlotShownProbeView.swift:39-51`) は、自身から窓までの祖先をたどる。そのうち `clipsToBounds` のものの範囲 (窓の座標) で見える矩形を狭める。スクロールするビューの `bounds` は送り位置を含むので、交差は表示範囲そのものになる。隠れ・透明の判定は従来どおり残っている。`ImageLoadingSlotShownClippingUITests` は 2 点を確かめる。窓の中で表示範囲の外にある下敷きが数えられないこと (2 秒待っても `outside=0`) と、表示範囲へ送った後に数えられることである
  - **(Minor) iOS: 監視対象が空でも周期が続く**: `tick` の終わりで、見張る相手が空なら `invalidate()` して `displayLink = nil` にする (`ImageLoadingSlotShownMonitor.swift:36-40`)。`watch` は `displayLink == nil` なら作り直す。弱参照の表なので、解放された下敷きも `allObjects` から消えて停止の判定に入る。UI テストは「止まる → 足すと数えられる (再開) → 再び止まる」を確かめる
  - 見張りを使うのは、計数を要求した実行の読み込み中 (`CountedImageLoadingPlaceholder`) と検証画面だけである。デモ画面の通常の実行では動かない
- **画像グリッドの実際の経路での再現 (lessons L-001。計測の足場が直前のサイクルで直ったため)**: 現行コードの iOS Sample (Debug) を上記の Simulator に入れ、走行ごとに入れ直した。`--verify-image-prefetch-match-auto --observe-image-loading --count-image-loading-slots` で走らせた結果:

  | 形 | 現れた | 引き当てた | 間に合わない | builtBefore | violation | matchedSized | **matchedShown** | 送りの shown / 表示の要求 | 項目の寸法 |
  |---|---:|---:|---:|---:|---:|---:|---:|---:|---|
  | `memory` / settle / 8 段 | 60 | 51 | 9 | 0 | 0 | 48 | **0** | **9 / 9** | 元寸 400 × 400 (51) |
  | `memory-column` / settle / 8 段 | 60 | 51 | 9 | 0 | 0 | 48 | **0** | **9 / 9** | 358 × 358 (51)、元寸無し 51 |
  | `memory` / 500 ms / 40 段 | 297 | 152 | 145 | 0 | 0 | 140 | **0** | **142 / 145** | — |

  戻しと、メモリのみの消去の後は、3 形とも表示の要求 0・shown 0 だった。形の構造は実機の証跡 (`evidence/device-image-match-ios.md` の修正後の節、`evidence/loader-counts-ios.md`) と同じである。画面に出る前に組み立てられて当たった項目 (`matchedSized` 48 / 140) が shown に 1 件も入っていない。祖先の切り取りの修正は、画像グリッドの実際の経路でも過大計上を出していない。速い送りの「shown 142 < 表示の要求 145」は、画面に出る前に取得を終えた表示の要求の分で、実機の証跡の 137 / 136 と同じ性質である (数え落としではない)
- **実機の証跡と tasks・Scenario の対応**
  - tasks 6.6 / 8.2 (iOS): `evidence/device-image-match-ios.md` の修正後の節と `evidence/loader-counts-ios.md` による。先読みの完了後に画面に出た 138 件 (幅なし・列幅) で、表示の要求 0・`matchedShown` 0・ディスクからの再デコード 0。幅なしは元寸 400 × 400 で、Scenario「原寸の項目を実機でも使う」の iOS 側にあたる。列幅は 255 × 255 で元寸は無く、Scenario「列幅で縮小して載せる」にあたる。対照の `disk` は 147 件すべてが表示の要求を出しており、数え方が空振りしていないことも示されている。修正後の走行は、足場の修正 (切り取りの判定) の後に採られた。証跡は `shown` を「表示範囲で切り取られた表示は数えない」と定義している
  - tasks 8.2 (Android): `evidence/loader-counts-android.md` の修正後の節による。ゆっくり送り・フリングとも、画面に出た時点で先読みが完了していたセルで、表示要求・取得・デコード・`loading-shown` がすべて 0。Scenario「メモリ到達点の後の表示」を満たす。原寸 (ハードウェアビットマップ 400 × 400) の引き当ては、ホストの `KsImageDeviceDecodeTest` 4 / 0 と合わせて Scenario「原寸の項目を実機でも使う」を裏付ける
  - tasks 8.3: iOS / Android とも、列幅で元寸がメモリに 1 件も無いことを示している (Requirement「元寸の画像はメモリに載せない」)。索引込みの定常、離脱後の解放 (iOS はコレクションとセル 15/15、Android は `left:0` / `foreign=0`)、充足 1.000 も示されている。Android の 10,000 件の幅なしの 1 回目 (notSteady:10) は、未判定として残したうえで採り直している (規約どおり)
  - tasks 8.4: `evidence/manual-imageGrid-{ios,android}-after.md` の「8.4」節による。オーナーの目視で「特に無し」、定数は初期値のまま。ソースの定数 (`KsImageMatching` の 0.5 / 4.0) と一致している
  - tasks 8.5: `evidence/disk-wait-{ios,android}.md` による。主因の仮説は対照 (上限の差し替え) つきで、改善は Non-Goals として実装していない
  - 数値の出所: どの証跡も `KS_PROBE` 行などの集計値の転記で、生ログはスクラッチにある。抜粋は sanitize 済みで、集計の定義 (`matched` / `late` / `builtBefore` / `violation`) も書かれている。Android の `許容範囲 (0.25〜2)` は拡大率 (枠 ÷ 項目) での表記で、定数 0.5 / 4 (項目 ÷ 必要寸法) と矛盾しない
- **本体の差分**: サイクル 7 の後に本体 (`ios/Sources`・`android/kscollectionview/src/main`) への差分は無い (`KsCollectionRepresentable.swift` は更新時刻だけが新しく、HEAD との差分は無い)。review-007 で確かめた本体の状態から変わっていない
- **release への持ち込み**: 新しい検証画面と見張りは、既存の計測経路と同じ起動引数の方式で、Release のバイナリには入るが、引数なしでは動かない。これは既存の `--verify-*` と同じ扱いで、second-opinion-code-007 もこの扱いを違反としていない。本体の公開面は増えていない
- **足場**: proposal / design / specs は review-001 より前の更新時刻で、変わっていない。tasks.md の未チェックは 8.1 だけ (採り直し待ち。指摘しない)

## 指摘事項

### 🟡 Minor iOS の読み込み待ちの往復 (8.3) と連続送り・同時数の対照 (8.5) の足場がスクラッチの複製にしか無い
**該当箇所**: `evidence/memory-steady-ios.md` の「読み込み待ちの往復を足した理由」、`evidence/disk-wait-ios.md` の「計測の足場について」
**問題点**: iOS の 8.3 の (1) (元寸を載せない分のキャッシュの大きさの減少) と (4) (充足 1.000) の数値は、読み込み待ちの往復だけから出ている。10,000 件の手順どおりの往復では、先読みが走らずキャッシュが空になるため、これらを示せない。8.5 の iOS の対照 (`dataLoadingQueue` 6 → 64) と連続送りの段も同じである。これらの足場は Sample の複製 (スクラッチ) にだけ足されていて、リポジトリにも change にも残っていない。証跡は足した内容を文章で説明しているが、第三者が同じ走行を採り直せない。蒸留後の drift や回帰の確認、tasks 8.1 の読みで数値を当て直すときに、この経路が失われる。Android の対応する足場 (`measurement/image-memory-loaded/…`、取得経路の上限の差し込み) は計測用ソースセットに入っていて再現できる。そのため、プラットフォーム間で再現性が非対称になっている。なお、定性的な主張の一部 (列幅で元寸が載らない) は、リポジトリにある観測経路でも再現できる (上のレビュアーの走行: `originalAbsent=51`)。
**推奨修正**: 次のどちらかにする。(a) 読み込み待ちの往復 (アニメーションの送り・段ごとの待ち・往復ごとのキャッシュの大きさ) と、連続送り・`--data-loading-limit` を、samples/ios の既存の計測経路 (`PerformanceVerificationView` / `ImagePrefetchMatchProbe`) に起動引数で取り込む。既存の起動引数の方式に揃え、Android と対称にする。(b) 取り込まないなら、その判断と後続 (簡易起票) を tasks.md か deviation.md に残し、証跡の「限界」に「採り直しの手段がリポジトリに無い」と明記する。蒸留の前にどちらにするかを決める。

### 🟡 Minor Android の memory-steady / disk-wait の証跡が修正サイクル 6 の前のビルドで採られたことが書かれていない
**該当箇所**: `evidence/memory-steady-android.md` (全体)、`evidence/disk-wait-android.md` の「副因」3 と「副因」1 の数値
**問題点**: この 2 本は、Android の `KsImage` の表示経路を変えた修正 (画面に出る時点の引き当て、`prefetchPending` のときだけ要求の開始を遅らせる。`KsImage.kt` / `KsImageRequestFactory.kt` / `KsImageMemoryIndex.kt`) より前に採られている。ファイルの更新時刻と、`loader-counts-android.md` の修正前・修正後の節の関係から分かる。しかし本文には、どのビルドかの記載が無い。`disk-wait-android.md` の副因 3 (「先読みの完了後に引き当て直さない」) は現行コードで解消済みである。それでも本文は解消前の書きぶりのままで、副因 1 の二重取得の率 (35〜43%) も修正後は変わっている (上限 64 で 25〜30%。`loader-counts-android.md` の修正後の節)。`memory-steady-android.md` の索引の鍵の件数 (18,769、615〜638) は、表示の鍵を登録する時点に依るので、修正後は変わりうる。結論 (1) (列幅で元寸が無い)・(3) (鍵以外を持たない、`left:0`)・(4) (充足) は、修正が触った経路 (要求の開始時点) に依らない。先読みの項目の寸法、索引の持ち物の型、要求を出すたびに登録する経路は変わっていないので、結論が覆る見込みは低い。レビュアーは実機を使えないので、数値は再現していない。
**推奨修正**: 2 本の冒頭に、採取したビルドが修正前 (画面に出る時点の引き当ての前) であることを明記する。`disk-wait-android.md` の副因 3 には「修正後は解消。`loader-counts-android.md` の修正後の節」と、副因 1 の率には修正後の値への参照を注記する。`memory-steady-android.md` には、結論が修正の影響を受けない理由を 1 段落で書く。索引の鍵の件数のように修正で変わりうる値は「修正前の値」と明記する。測り直せるなら、60 件の読み込み待ちの往復 1 形だけでも現行ビルドで採り直すと確実になる。

### 🔵 Suggestion 修正前・修正後を併記した証跡の冒頭に、現在の結論を置く
**該当箇所**: `evidence/device-image-match-ios.md:3-9` (「状態: 停止中」「tasks 6.6 は未完了のまま」)、`evidence/loader-counts-android.md:5-8` (「フリングでは spec と食い違う形が出る (発見、未修正)」)
**問題点**: どちらのファイルも、冒頭の「状態」「結論」が修正前のままで、修正後の結論 (spec どおり、tasks 6.6 / 8.2 完了) はファイルの末尾の節にある。前者には「修正前の記録として残す」という断り書きがあるが、後者には無い。冒頭だけを読むと、tasks のチェックと食い違って見える。
**推奨修正**: 冒頭に「現在の結論: 修正後 spec どおり (末尾の節)」の 1 行を置き、修正前の節は「修正前の記録」と見出しで明示する。

### 🔵 Suggestion iOS のメモリ判定が画像キャッシュの増減を捉えないという所見を、蒸留の材料に残す
**該当箇所**: `evidence/memory-steady-ios.md` の「`phys_footprint` とキャッシュの大きさ」
**問題点**: 実機で、キャッシュが 387.9 MB あっても `phys_footprint` は約 16〜19 MB だった。iOS 性能検証の手順のメモリの定常判定 (`phys_footprint` だけを見る) が、展開済みの画像の記憶域の増減を見落とす可能性がある。これは本 change の範囲を超えた、手順自体の限界である。証跡の「限界」に書かれているだけでは、蒸留で失われやすい。
**推奨修正**: 蒸留のときに、`kasane/handbook/ios/performance-verification.md` への追記 (画像を扱う変更ではキャッシュの大きさも併せて記録する) か、簡易起票の材料として拾う。本 change での対応は求めない。

## 観察 (指摘ではない)

- 見張りの周期は、窓の中にあって見えない位置に留まる下敷きがある間は動き続ける (例: 再利用の待ちでセルが窓に残る場合)。計数を要求した実行だけのことで、実害は無い
- `SampleLaunchView.swift` で `prefetchDestination` を消した跡に、空行が 2 行続いている (見た目だけ)

## アクションプラン

1. (Minor) iOS の読み込み待ちの往復と連続送り・同時数の対照の足場を、samples/ios の計測経路に取り込むか、取り込まない判断と後続を tasks / deviation に残す。蒸留の前に決める
2. (Minor) `memory-steady-android.md` / `disk-wait-android.md` に、採取ビルドが修正前であること、副因 3 の解消、修正で変わりうる値の扱いを追記する
3. (Suggestion) 修正前・修正後を併記した 2 本の証跡の冒頭に、現在の結論を置く
4. (Suggestion) `phys_footprint` の限界を、蒸留で handbook の追記か簡易起票に拾う
5. tasks 8.1 (iOS 走行 5 の採り直し) へ進む
