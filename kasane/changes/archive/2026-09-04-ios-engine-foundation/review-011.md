# レビュー結果: ios-engine-foundation (011 回目)

**日付**: 2026-09-03
**判定**: APPROVED

## サマリー

サイクル 11 の確定リスト Minor 2 件は、いずれも成果物の上で解消を確認した。計測走査は往復ごとに通過集合を数え直し、`traverse` が「端へ到達したか」「全段階で位置を確定できたか」を返し、不成立の往復はメモリ実測値を定常化判定に加えないまま `KS_PERF_STEADY=no` で終わる形になっている。計測スキームを実行すると、1 往復目・2 往復目のそれぞれ直後に `直近往復の通過: 10000 / 10000` が成立することを実測で確認できた。証跡の「3 倍」は 2 箇所とも「4 倍未満 (安全余裕込みの上限)、実測は約 2.95 倍」へ訂正され、テストの `visibleCellCount * 4` と一致する。

前サイクルの Major 2 件の再燃はない。通常スキームは 2 回連続で 3 tests / 0 failures、`local-path-lint.py` は exit 0 (違反 0) で、`ios/DerivedDataRelease/` は存在せず `.gitignore` に `DerivedData*/` が入っている。

残る指摘は低優先の Minor 1 件 (証跡の計測値がハーネス修正前の実行で採られたことの明示) と Suggestion 1 件で、いずれも蒸留 (ksn-distill) で処理できる。追加の修正サイクルは要らない。

重要度別件数: **Critical 0 / Major 0 / Minor 1 / Suggestion 1**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS (iPhone 17 Pro / iOS 26.5) を使用した。個体識別子は記載しない。実行前に `pgrep -fl xcodebuild` で他の `xcodebuild` が走っていないことを確認し、逐次で実行した。`-derivedDataPath` はリポジトリ外 (`/private/tmp/` 配下) を指定した。

| 対象 | コマンド | 結果 |
|---|---|---|
| Sample UI (通常スキーム) 1 回目 | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` (`samples/ios/`) | **Executed 3 tests, with 0 failures** — TEST SUCCEEDED (28.8 秒) |
| Sample UI (通常スキーム) 2 回目 | 同上 | **Executed 3 tests, with 0 failures** — TEST SUCCEEDED (26.7 秒) |
| Sample 計測スキーム | 同上 `-scheme KsCollectionViewSamplesPerformance` | **Executed 2 tests, with 0 failures** — TEST SUCCEEDED (101.9 秒) |
| comment-policy lint | `python3 scripts/comment-policy-lint.py` | exit 0 / 禁止 0 件 (検査対象 61 ファイル) |
| local-path lint | `python3 scripts/local-path-lint.py` | **exit 0 / 違反 0 件** |
| identity lint | `python3 scripts/identity-lint.py` | exit 0 / 違反 0 件 |
| 本体 (`ios/`) | 未実行 | 本サイクルの変更が `ios/` を触っていないため (下記) |

本体を再実行しなかった根拠: 本サイクルで書き換わったのは `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift`、`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift`、`evidence/verification-matrix.md`、`evidence/performance-early-measurement.md` の 4 ファイルのみで、`ios/Sources/` と `ios/Tests/` は前サイクル (review-010 の時点) から変更されていない。

計測スキームの内訳: 通常スキーム 3 件に計測ドライバ 2 件が含まれていないこと (3 + 2 で重複なし) を確認した。スキーム分離は効いている。

計測スキームの 2 本目 `PerformanceDriverUITests.test大量件数を全件通過で2往復してメモリを表示する` は 87.3 秒で成功し、往復 1 回目・2 回目のそれぞれ直後の `performance.visitedItems` ラベルが `直近往復の通過: 10000 / 10000` に一致した。累積ではなく往復単位で全件通過していることを、レビュー側の実行でも確かめている。

## 照合した規約

domains 定義プロジェクトのため、作業ドメイン `ios` + `cross` の index を見た。`kasane/handbook/ios/` は未作成のため、適用は cross のみ。本サイクルの diff は計測ハーネス (Sample の検証画面と計測ドライバ) と証跡 2 件に限られるため、前サイクルより適用範囲が狭い。

| 文書 | 適用のきっかけ |
|---|---|
| cross/comment-policy.md | **常時** (always) |
| cross/test-execution.md | テストを実行し結果を報告するため |
| cross/runtime-behavior-verification.md | 走査・再利用というランタイム挙動の証跡を判定するため |

適用外と判定: `cross/sample-parity.md` (デモ画面・文言の追加変更がなく、触ったのは起動引数でのみ到達する検証画面のため)、`cross/public-identifiers.md` (ビルド定義・パッケージ宣言に変更なし)、`cross/local-development-setup.md` (本サイクルでは未変更)。

ADR / 概念: 本サイクルの diff に該当する新規の決定はない。`kasane/lessons/` は inbox のみで昇格済みルールファイル (`code-review.md`) が無いため、inbox の `verify-interactive-collection-layout-transitions.md` (scope: code-review) を重点観点として参照した。他の 4 件は scope: process のためレビュー観点には使っていない。

足場の凍結: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD と差分なし。`deviation.md` 記録済みの乖離 (Simulator での再計測・定常化の許容差と往復上限を含む) は合意済み差分として扱い、違反に数えていない。

## 前回指摘の追跡

`review-010.md` と `second-opinion-code-010.md` 末尾「突き合わせ結果」で確定した Minor 2 件、および却下・処理済みとされた Major 2 件を追跡する。

| 確定項目 | 状態 | 確認結果 |
|---|---|---|
| Minor: 計測走査の往復単位 fail-closed 化 | **解消** | 下記のとおり 4 点すべてを確認 |
| Minor: 証跡の「3 倍」→「4 倍未満 (実測約 2.95 倍)」訂正 | **解消** | `evidence/verification-matrix.md:18` と `evidence/performance-early-measurement.md:75` の双方が「可視セル数の 4 倍未満 (安全余裕込みの上限)」+「実測は可視 39 件に対し最大 115 件で約 2.95 倍」の形になり、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:650` の `liveCellLimit = visibleCellCount * 4` と一致する。リポジトリ内に残る「3 倍」は同ファイル:645 のコメント (実測値 115/39 を「可視の約 3 倍」と述べる箇所) だけで、直後に上限 4 倍の根拠が続くため矛盾しない |
| Major-1 (却下: UI テスト不安定 = 環境要因) | **再燃なし** | 他の `xcodebuild` が走っていない状態で通常スキームを 2 回連続実行し、いずれも 3 tests / 0 failures。`Restarting after unexpected exit, crash, or test timeout` は 1 度も出ていない |
| Major-2 (処理済み: `ios/DerivedDataRelease/`) | **再燃なし** | `.gitignore:53`〜`:55` に `DerivedData/` と `DerivedData*/` があり、`DerivedData*/` を足した理由がコメントで自己完結している。`ios/` 配下に `DerivedDataRelease` は存在しない。`local-path-lint.py` は exit 0 (前サイクルは違反 430 件) |

fail-closed 化の 4 点:

1. **往復ごとのリセット** — `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:115` が往復の先頭で `var visited: Set<Int> = []` を作り直し、同:118 で直近 1 往復分だけを `visitedItemsInLastRoundTrip` に反映する。表示 (同:36) も `直近往復の通過:` に変わり、累積でないことがラベル自身から読める
2. **`traverse` の到達・settle の伝播** — 同:160 が `(reachedEnd: Bool, settled: Bool)` を返す。段数上限 (`maximumStepsPerDirection`) で打ち切った経路 (同:192) は `reachedEnd: false` を返し、`settle` (同:197) がタイムアウトで `false` を返した段階があれば `settledEveryStep` が `false` のまま伝播する。戻り値を捨てている箇所はない
3. **不成立往復の判定除外** — 同:140 の `guard reachedBothEnds, settledEveryStep, coveredEveryItem` を通らない往復は `footprints.append` に到達せず (同:148)、定常化判定の材料にならない。不成立時は `KS_PERF_ROUND_TRIP_INVALID=` に 3 条件の内訳が出るため、どれで落ちたかが後から分かる
4. **`KS_PERF_STEADY=no` での終了** — 同:80〜97 の `runUntilSteady` は不成立の往復に出会った時点で `break` し、最終判定は `everyRoundTripIsValid && hasSteadied(footprints)` の論理積 (同:95)。初回の往復が不成立なら `footprints` が空で `hasSteadied` も `false` になるため、二重に閉じている

UI テスト側 (`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:50`・`:60`) は、往復 1 回目・2 回目のそれぞれ直後に `直近往復の通過: 10000 / 10000` を要求する形になった。1 往復目で 9,000 件、2 往復目で残り 1,000 件という通り方は 1 回目の `XCTAssertEqual` で落ちる。前サイクルで指摘された「2 往復の累積でも成立してしまう」経路は塞がっている。

後退の確認: 通常スキームの 3 件 (`InteractiveControlUITests` のセル内 Button・長押し宣言時・長押し未宣言時) は 2 回とも成功しており、本サイクルの変更が触っていない `ios/Sources/` `ios/Tests/` にも書き換えはない。lint 3 本はいずれも違反 0 で、前サイクルから悪化した箇所はない。

## 指摘事項

### [🟡 Minor] 証跡のメモリ計測値は fail-closed 化の前に採られており、「1 往復あたり 10,000 / 10,000 件」が全往復分は裏取りできていない

**該当箇所**: `evidence/performance-early-measurement.md:57` (「両実行とも 1 往復あたりの通過項目は 10,000 / 10,000 件だった」)

**問題点**: 証跡に載っている 2 実行 (5 往復 / 4 往復で定常化、610.68 MB / 610.67 MB) の数値は前サイクルから変わっておらず、計測ハーネスの修正より前に採られたものである。当時の `KS_PERF_MEMORY_ROUND_N=… visited=` は通過集合が累積だったため、その実行の出力から 1 往復単位の全件通過を裏取りできるのは 1 往復目だけで、3〜5 往復目については同じ形の主張を支える出力が残っていない。

走査の刻み・待機・端点計算そのものは今回の修正で変わっていないため、記録された数値自体が疑わしいとは考えない。レビュー側の計測スキーム実行でも、修正後のハーネスで 1 往復目・2 往復目が独立に 10,000 / 10,000 件を通過することを確認している。それでも証跡は「実装が保証している範囲をそのまま書く」ことが求められる文書であり、この 1 文だけは採取時の出力より強い。本 change で 3 周にわたり争点になったのが同じ型 (証跡が実装より強い主張になる) であるため、低優先ではあるが残す。

**推奨修正**: 次のいずれか (どちらも 1〜2 行で済む)。

1. 自動実行モードを修正後のハーネスで 1 度だけ計り直し、`KS_PERF_VISITED_ITEMS_LAST_ROUND=` と `KS_PERF_STEADY=yes` を含む出力を根拠として表に添える
2. 計り直さないなら、この 1 文を「1 往復目の通過項目は両実行とも 10,000 / 10,000 件。往復単位の全件通過は計測ドライバ (`PerformanceDriverUITests.test大量件数を全件通過で2往復してメモリを表示する`) が往復ごとに検証する」のように、担保している単位で書き分ける

蒸留 (ksn-distill) で処理して差し支えない。この 1 件のために修正サイクルを追加する必要はない。

### [🔵 Suggestion] 自動実行モードは定常化を確認できなくても終了コード 0 で終わる

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:49`・`:96`

**問題点**: `runUntilSteady` は不成立の往復や定常化未達を `KS_PERF_STEADY=no` として出力するが、その直後の `exit(EXIT_SUCCESS)` は判定に依らない。現状この経路を叩くのは人の手であり、手順 (`evidence/performance-early-measurement.md:37`) も出力を読む前提なので実害はないが、終了コードだけを見る呼び出し方をすると未判定が成功に見える。`KS_PERF_STEADY=no` のときに `EXIT_FAILURE` で終われば、将来この経路をスクリプト化したときも閉じたままになる。

**推奨修正**: `exit(isSteady ? EXIT_SUCCESS : EXIT_FAILURE)` 相当にし、証跡の手順に終了コードの意味を 1 行足す。優先度は低い。

## 確認した観点

指摘に至らなかったが確認した範囲を残す。

- `runUntilSteady` の境界: 往復上限 (10) まで回して定常化しない場合は `everyRoundTripIsValid` が `true` でも `hasSteadied` が `false` になり `KS_PERF_STEADY=no`。初回不成立時は `footprints` が空で `hasSteadied` が `guard footprints.count >= 3` で `false`。`hasSteadied` の許容差 (1 往復後の値の 2%) と直近 2 増分という判定式は前サイクルから変わっていない
- 不成立往復でも `completedRoundTrips` の加算とメモリラベルの更新は行われる。直後に `KS_PERF_ROUND_TRIP_INVALID=` が内訳付きで出るためログは自己記述的で、通過件数の不足は計測ドライバの `XCTAssertEqual` が往復単位で捕まえる
- 通過件数の表示は `Text(verbatim:)` で桁区切りが入らない形になっており、UI テストの期待値 `直近往復の通過: 10000 / 10000` がロケール依存にならない。コメント (同:34〜35) がその理由を自己完結して説明している
- コメント規約: 本サイクルで書き換えた 2 ファイルのコメントに、作業文書のパス・change 名・レビュー通番・デルタスペック構文キーワードは無い。lint の検出範囲より広く本文から確認した。公開 doc コメントは本サイクルの diff に含まれない
- テスト実行規約: 通常スキームと計測スキームを分けて実行し、双方の実行件数を報告した。計測ドライバ 2 件が通常スキームの 3 件に混ざっていないことを件数で確認した
- `evidence/verification-matrix.md:18` の「10,000 件の仮想化・再利用」行が、自動検証の射程 (2,000 件) と Simulator 計測 (10,000 件) を分けたままであること、計測経路として計測スキーム限定である旨が残っていること
- 据え置き確定分は再指摘していない: 手動モードが 2 往復で頭打ち (定常判定に到達できない)、`local-development-setup.md` の埋め済み節に残る指示文、phase-3 agenda の doc-structure 超過 1 件、GCD → Swift Concurrency の置き換え。いずれも review-010 の Suggestion または突き合わせで蒸留送りが確定している
- 計測ハーネスが UIKit のビュー階層を歩いて `UICollectionView` を取る形 (同:230〜269) は、`contentOffset` と可視セルが SwiftUI から読めないための計測専用の踏み込みであり、その理由がコメントに書かれている。本体 (`ios/Sources/`) には波及していない

## アクションプラン

1. (蒸留時) 証跡の「1 往復あたり 10,000 / 10,000 件」を、計り直すか担保単位で書き分けるかのどちらかで揃える (Minor-1)
2. (任意) 自動実行モードの終了コードを判定に連動させる (Suggestion-1)

追加の修正サイクルは不要。本 change は蒸留 (ksn-distill) へ進める状態にある。
