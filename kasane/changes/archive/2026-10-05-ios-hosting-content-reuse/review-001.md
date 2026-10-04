# レビュー結果: ios-hosting-content-reuse (001 回目)

**日付**: 2026-10-04
**判定**: CHANGES_REQUESTED

## サマリー

ソースの変更 (`prepareForReuse` の版の分岐と、中身を当てない分岐で中身を外す 1 行) は、deviation.md の最後の「状態の扱い」と ios/ADR-0012 (proposed) のとおりで、コードに Critical / Major は無い。テストは iOS 27.0・18.6・17.5 の 3 つの版で全件成功し、レビュー側のプローブでも、表示に出る動き (state・高さ・アニメーション) に変更前との差は見つからなかった。

判定を CHANGES_REQUESTED にした理由は 1 件で、コードではなく確かめ方の側にある。決定事項の「完了の判定」(基準機の「大量件数」の走行・不一致率・体感の合否) が済んでおらず、その差が deviation.md に記録されていない。ソースの修正は要らない。

## 実行したテスト (観測)

Simulator はこのレビュー専用のものを新しく作り、終了後に削除した (`ksn-review842019-27` / `-186` / `-175`、プローブの追加分に `ksn-review842019b-186` / `-27`)。

| 系統 | 版 (機種) | 結果 |
|---|---|---|
| iOS 本体 (作業ツリー、Debug、絞り込みなし) | iOS 27.0 (iPhone 17) | `Executed 535 tests, with 0 failures` (147.6 秒、ビルド込み 168 秒) |
| iOS 本体 (同上) | iOS 18.6 (iPhone 11) | `Executed 535 tests, with 0 failures` (132.5 秒、ビルド込み 139 秒) |
| iOS 本体 (同上) | iOS 17.5 (iPhone 11) | `Executed 535 tests, with 0 failures` (142.5 秒、ビルド込み 150 秒) |
| iOS Sample (通常スキーム) | iOS 27.0 (iPhone 17) | 48 件 (ユニットテスト 37 件・UI テスト 11 件)、失敗 0 (ビルド込み 198 秒)。計測ドライバは含まない |

Android の 2 系統は、この変更が Android のソースに触れないため流していない。

## レビュー側のプローブ (観測。スクラッチの複製だけに置いた)

作業ツリーの複製と HEAD の複製 (`git archive HEAD`) に同じプローブのテストを入れ、iOS 18.6 と 27.0 (1 つ目は 17.5 も) で流した。作業ツリーにプローブは入れていない。

| 見たこと | 作業ツリー (iOS 18.6 / 27.0) | HEAD (同じ版) |
|---|---|---|
| 項目 0 の state を変え、可視範囲の半分ずつ送る。項目 0 のセルが載せた別の項目の `body` が、変えた state で評価された回数 | **最初に再利用された 1 項目で 1 回** (18.6 は項目 29、27.0 は項目 28)。その後に載せた項目では 0 回 | 0 回 |
| その 1 項目の出来事の順 (iOS 18.6) | `body(true)` → `body(false)` → `onAppear(false)`。3 つとも同じ runloop の周回の中。`onChange` は呼ばれない。セルの高さは直後から 44 (展開時は 88) | `body(false)` → `onAppear(false)` |
| 再利用された項目ごとの `body` の評価の回数 | 2 回 (どちらも初期値) | 1 回 |
| state に `.animation(.linear(duration: 0.4), value:)` を付けた行で、再利用された次の項目に補間の途中の値が出るか | 出ない (0 個)。高さは 0〜600 ms のどの時点も 44 | 出ない |
| 再利用の列に高さの違う中身を溜めた後、アニメーション付きの挿入で表示へ入るセルの中身のレイヤーに付いたアニメーション | なし (セルのレイヤーに `opacity` だけ) | 同じ |
| 同じ送り方で見た中身のビューの数 (iOS 18.6) | 37 (セルは 19) | 379 (セルは 19) |
| iOS 17.5 | 別の項目が変えた state で評価された回数は 0。中身のビューの数は 396 (HEAD は 380) | — |

読み:

- 表示に出る結果は変更前と同じである。state は表示の前に初期値へ戻り、`onAppear` は初期値を見て、state のアニメーションも高さの持ち越しも出なかった。証跡の「展開の state で描かれた項目は無かった」は、表示に出た結果としては再現した
- ただし iOS 18 以降では、OS が state を戻すのは、次の項目の中身を当てた後である。state を変えたセルが最初に再利用されるとき、次の項目の `body` が前の項目の state で 1 回評価される (下の Minor)
- 入れ物を使い回すこと (iOS 18 以降) と、作り直すこと (iOS 17.5) は、中身のビューの数で再現した。証跡の計数 (生成 9 / 解放 0) と向きが合う
- 主スレッドの CPU 時間と基準機の数値は、レビュー側では測り直していない (基準機は手元に無い)

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/test-execution.md` (テストを実行・追加・報告するため)
- `kasane/handbook/cross/scroll-performance-gate.md` (性能の証跡と完了の判定を含むため)
- `kasane/handbook/ios/performance-verification.md` (iOS エンジンの再利用の経路に触れるため)
- `kasane/handbook/cross/runtime-behavior-verification.md` は、不具合の調査・修正ではないため適用外と判断した
- 決定: ios/ADR-0002 (accepted。本文を読んだ)、ios/ADR-0012 (proposed。決定としては扱わず、合意済みの最終の形の記述として読んだ)。ios/ADR-0006・0008 (表示中のセルの作り直し) と cross/ADR-0006・0008 (体感ゲート・テストの合計時間) は、handbook とソースコメントが引く範囲で照合し、本文は開いていない
- 教訓: `kasane/lessons/code-review.md` の L-001 (証跡の値をプローブで再現する)・L-002 (動きの過程を見る)

ロードしたスキル: ksn-review (ios ドメインに code-review 用のプロジェクト固有スキルは無い)

## 確認した観点

仕様充足

- 合意スコープ (決定事項 + deviation.md) との一致: ソースは最終の形と一致。確かめ方は 1 件の不足 (下の Major)
- 足場の書き換え: exploration.md の決定事項は案 A のまま残り、実装の結果に合わせた書き換えは無い
- deviation.md に無い逸脱: ソースには無い。確かめ方に 1 件 (下の Major)
- 付随修正 (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:660`): 本務で触るファイル・公開 API に触れない・1 行・ユーザーの選択なしで、同梱条件に収まる。この分岐を通すテストは無いが、差分データソースが持つ項目が配列に無いときだけ通る分岐で、通常の操作では到達しない。既存のテスト全件の通過で担保されていると判断した
- 範囲: 補助ビュー (`KsHostingSupplementaryView`)・公開 API・Sample・Android に差分なし

テスト

- 全件成功と実行件数 (上の表)
- 新規テスト 5 件: 決定事項が求める 4 種 (入れ物・高さ・`onAppear` と `.task`・表示中の作り直しの state) に対応。1 件目は版で期待を分けており、iOS 17.5 では作り直しを確かめる
- 待機の書き方 (`ios/Tests/KsCollectionViewTests/KsHostingReuseTests.swift:289`): 実時間の期限・`Task.sleep` で譲る・期限切れは実測値つきで失敗、の 3 つを満たす
- 再利用が実際に起きたことの確認: 3 件とも、先頭で表示していたセルが再利用されたことをセルの同一性で確かめている
- 手抜き (実質スキップ・言い訳コメント): なし
- 所要時間: iOS 本体は 535 件で 132〜148 秒 (変更前の記録は 530 件 144 秒)。合計 10 分の枠に影響しない

設計品質

- ios/ADR-0002 (accepted) との関係: 「ホスティングを作り直す」の部分と食い違うが、amends として ios/ADR-0012 が起票済みで、契約 (state を保持しない) はどの版でも保たれている。iOS 18 より前は 0002 のまま
- 版の分岐 (`ios/Sources/KsCollectionView/KsHostingCell.swift:175`): 1 か所で、対応 OS の下限 (iOS 16) と合う
- 読み上げの部品の有無が変わったとき: 中身の型が変わるので UIKit が中身のビューを作り直す。前の state は残らない (コードの読み)
- 中身を外さないことで残るもの: 高さの受け口と読み上げの操作は従来どおり `prepareForReuse` で外れる。背景の構成・区切り線・タッチの表示も従来どおり
- メモリ・解放: 同時生存セルと解放の既存テストが全件の中で通っている。証跡の Simulator のメモリは定常
- コメント: 単独で読める。禁止参照なし (`scripts/comment-policy-lint.py` で iOS のファイルに禁止 0 件・要確認 0 件)。実態に合わなくなった 2 か所は直っている
- オーバーエンジニアリング: なし (再利用の回数・識別の値は最終の形に残っていない)
- 入力検証・機密情報: 該当なし

## 指摘事項

### [🟠 Major] 決定事項の「完了の判定」が済んでおらず、その差が deviation.md に無い

**該当箇所**: `exploration.md` の「確かめ方とやめる基準」の 4、`evidence/perf-hosting-reuse-device.md` の「判定」と「限界」、`evidence/verify-hosting-reuse-stage2.md` の「最終の形の結果」の限界

**問題点**: 決定事項は完了の判定として、基準機で「大量件数」と「並べ替え」の 2 つの fixture を変更前・変更後で 1 走行ずつ採り、合否をオーナーの体感で決め、不一致率を「大量件数」の Debug 構成で読むと定めている。証跡にあるのは次のとおりで、足りない分が deviation.md に記録されていない。

- 基準機の走行は「並べ替え」だけ。「大量件数」は採っていない (`kasane/handbook/ios/performance-verification.md` は、エンジンの土台に触る変更の fixture を「大量件数」と定めている)
- 不一致率は採っていない
- 体感の合否が書かれていない (「この記録では書かない」)。段階ごとの体感とムラも聞き取れていない。`kasane/handbook/cross/scroll-performance-gate.md` は、判定が未判定のままでは完了と報告しないと定めている
- 基準機に入れた「変更後」は最終の形のソースからビルドしたものではない。iOS 18 以降の動きは同じと読めるが (レビュー側でも Simulator で入れ物の使い回しを再現した)、最終の形のバイナリでの基準機の走行は無い

deviation.md の 1 行目 (基準機で比べてから決める) は、進めるかどうかの判断の話で、完了の判定の省略を合意した記録ではない。

**推奨修正**: 次のどちらか。ソースの修正は要らない。

- 最終の形のビルドで、基準機の「大量件数」(と、必要なら「並べ替え」) の走行・不一致率・体感の合否を採り、証跡に書く
- 採らない項目があるなら、オーナーの判断として deviation.md に記録する (どの項目を、なぜ省くか)

### [🟡 Minor] state を変えたセルが別の項目へ再利用される経路を通す恒久のテストが無く、その経路で起きることが記録に無い

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsHostingReuseTests.swift` (該当するテストが無い)、`ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:342`、`kasane/decisions/ios/0012-reuse-hosting-and-reset-state-on-reuse.md` の Consequences

**問題点**: ios/ADR-0012 は、iOS 18 以降で state が戻ることを OS に頼り、「状態が初期値へ戻るテストで確かめ続ける」としている。そのテスト (`KsCollectionScenarioTests.swift:342`) は離れた位置へ一度に送って戻す形で、証跡 (`evidence/verify-hosting-reuse-ios17.md` の 1 節) 自身が書いているとおり、state を変えたセルが別の項目に再利用される経路を通らない。同じ項目へ戻ったときに state が初期値であることだけを見ている。別の項目に state が出ないことを確かめたのは、作業ツリーに入っていないスクラッチの観測用テストだけである。新規の `KsHostingReuseTests` は再利用の経路を通るが、state を変えていない。

あわせて、レビュー側のプローブで次が分かった (上の表)。iOS 18.6 と 27.0 では、state を変えたセルが最初に再利用されるとき、次の項目の `body` が前の項目の state で 1 回評価され、同じ runloop の周回の中で初期値で評価し直される。表示・`onAppear`・`onChange`・アニメーションには出なかったので、利用者に見える動きは変わらない。ただし、再利用のたびに `body` が 2 回評価されること、`body` が一時的に前の項目の state を見ることは、ADR にも証跡にも書かれていない。

**推奨修正**:

- `KsHostingReuseTests` に 1 件足す: 先頭の項目の state を変えてから中ほどを経由して先へ送り、先頭のセルが再利用された項目について、落ち着いた後の state と `onAppear` の時点の state が初期値であることを確かめる。iOS 17.5 でも通る形にする (その版は作り直しで初期値になる)
- `body` が前の項目の state で 1 回評価されることを、証跡の限界に 1 行足す。ADR の Consequences に載せるかは、ADR を書く側の判断に任せる

### [🔵 Suggestion] 途中の形を前提にした記述が、証跡と ADR の名前に残っている

**該当箇所**: `evidence/perf-hosting-reuse-device.md` の冒頭の表と「読み取れないこと」、`evidence/perf-hosting-reuse-stage1.md` の全体、`evidence/verify-hosting-reuse-ios17.md` の「先に」と 1 節の「読み」、`kasane/decisions/ios/0012-reuse-hosting-and-reset-state-on-reuse.md` のファイル名

**問題点**: verify の 2 ファイルには「最終の形の結果は末尾」という断り書きがあるが、perf の 2 ファイルには無く、「作業ツリーの案 A (番号を付ける形)」を作業ツリーとして書いたままである。`verify-hosting-reuse-ios17.md` の前半には「ios/ADR-0012 が受け入れている帰結」「ios/ADR-0012 の『iOS 16・17 では…残りうる』」とあるが、今の ADR-0012 にその記述は無い。ADR のファイル名 (`reset-state-on-reuse`) は、ライブラリが state を戻す案のときの名前で、題 (OS に任せる) と合っていない。蒸留のときに読み違える余地がある。

**推奨修正**: perf の 2 ファイルの冒頭にも同じ断り書きを足す。ADR のファイル名は、accepted にする前に題に合わせるかを指揮の側で決める (index.md のリンクも同時に直す)。

## アクションプラン

1. (Major) 完了の判定の不足を埋める: 最終の形のビルドで基準機の「大量件数」の走行・不一致率・体感の合否を採るか、採らない項目をオーナーの判断として deviation.md に記録する
2. (Minor) state を変えたセルが別の項目へ再利用される経路の恒久のテストを 1 件足し、`body` が前の state で 1 回評価されることを証跡の限界に書く
3. (Suggestion) perf の証跡 2 ファイルに断り書きを足し、ADR のファイル名を題に合わせるかを決める
