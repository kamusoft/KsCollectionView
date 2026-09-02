# レビュー結果: ios-engine-foundation (010 回目)

**日付**: 2026-09-03
**判定**: CHANGES_REQUESTED

## サマリー

修正サイクル 10 の確定リスト 5 件のうち、Major「メモリ計測の全項目走査と再計測」と Minor 3 件 (生存セルフックの Release 除外・仮想化テスト上限・コメント 2 件) は解消している。メモリ計測は端点ジャンプから「可視範囲の半分ずつ送る全件走査」へ実際に書き換わっており、evidence に書かれた許容差 (連続 2 往復の増分がいずれも 1 往復後の 2% 以内) と上限 10 往復は `PerformanceVerificationView.hasSteadied` の判定式と一致し、記録された 2 実行の打ち切り往復数 (5 / 4) も判定式から再現できる。定常化の主張は spec の「増え続けない」に対して誠実になった。

一方、確定リストのもう 1 件「Sample UI テストの安定化」は解消していない。通常スキームを 4 回連続で実行して 3 回失敗した (前サイクルの 7 回中 4 回失敗から改善していない)。加えて、Release 構成のテストが作るビルド生成物 `ios/DerivedDataRelease/` が `.gitignore` に載っておらず、`scripts/local-path-lint.py` が違反 430 件で exit 1 になる — 前サイクルは違反 0 だった箇所の後退である。

重要度別件数: **Critical 0 / Major 2 / Minor 2 / Suggestion 3**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS (iPhone 17 Pro / iOS 26.5) を使用した。個体識別子は記載しない。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 Debug | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` (`ios/`) | **Executed 60 tests, with 0 failures** — TEST SUCCEEDED |
| 本体 Release | 同上 + `-configuration Release ENABLE_TESTABILITY=YES` | **Executed 61 tests, with 0 failures** — TEST SUCCEEDED |
| Sample UI (通常スキーム) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` (`samples/ios/`) を 4 回連続 | **1 回成功 / 3 回失敗** (下記 Major-1) |
| Sample 計測スキーム | 未実行 (コンテキストパッケージの指示どおり) | — |
| local-path lint | `python3 scripts/local-path-lint.py` | **exit 1 / 違反 430 件** (下記 Major-2) |
| identity lint | `python3 scripts/identity-lint.py` | exit 0 / 違反 0 |
| comment-policy lint | `python3 scripts/comment-policy-lint.py` | exit 0 / 検査対象 61 ファイル・禁止 0 件 |
| doc-structure lint | `python3 scripts/doc-structure-lint.py` | exit 1 / 26 件 (前回と同数。本 change 由来は 1 件 — Suggestion-3) |

本体 Release の実行件数は前サイクル報告の 62 件から 61 件へ 1 件減っている。これは `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` が `#if DEBUG` に入った (確定リストの Minor 対応) ことによるもので、Debug 側 60 件は据え置き。意図した減少であり、テストの取りこぼしではない。

## 照合した規約

domains 定義プロジェクトのため、作業ドメイン `ios` + `cross` の index を見た。`kasane/handbook/ios/` は未作成のため、適用は cross のみ。

| 文書 | 適用のきっかけ |
|---|---|
| cross/comment-policy.md | **常時** (always) |
| cross/test-execution.md | テストを実行し結果を報告するため |
| cross/runtime-behavior-verification.md | スクロール・再利用・レイアウト変更という実行時挙動の完了判定を見るため |
| cross/sample-parity.md | `samples/` を触る変更のため |
| cross/public-identifiers.md | `Package.swift` / Sample の bundle ID を含むため |
| cross/local-development-setup.md | 本 change が更新した guide のため (kind: guide) |

適用外と判定: なし (cross の全 6 文書が該当)。

ADR / 概念: `core/ADR-0003` `core/ADR-0004` `core/ADR-0006` `core/ADR-0007` `core/ADR-0009`、`ios/ADR-0001`〜`ios/ADR-0004`。`kasane/lessons/` は inbox のみで昇格済みルールファイル (`code-review.md`) が無いため、inbox の `verify-interactive-collection-layout-transitions.md` (scope: code-review) を重点観点として参照した。

足場の凍結: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD と差分なし。`deviation.md` 記録済みの乖離 (メモリ判定の許容差・往復上限を含む 17 件) は合意済み差分として扱い、違反に数えていない。

## 前回指摘の追跡

`second-opinion-code-009.md` 末尾「突き合わせ結果」の確定リストを追跡する。

| 確定項目 | 状態 | 確認結果 |
|---|---|---|
| Major: メモリ計測を全項目通過の走査にし、定常化する条件で再計測 | **解消** | `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:80` の `traversalStepRatio = 0.5` で可視範囲の半分ずつ送り、同ファイル:141 の `settle` が固定待機ではなく目的 offset 到達と可視セルの存在を条件に待つ。判定は同ファイル:212 の `hasSteadied` (基準 = 1 往復後の値、許容差 2%、直近 2 増分) で、`evidence/performance-early-measurement.md:52` の記述および記録値の打ち切り往復数 (実行 1 = 5、実行 2 = 4) と一致する |
| Major: Sample UI テストの安定化 (3 回連続成功) | **未解消** | 4 回連続実行で 3 回 TEST FAILED。下記 Major-1 |
| Minor: 生存セル計測フックを Release から外す | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:9` `:43` `:205` が `#if DEBUG` で囲われ、Release ビルドのセル供給経路から辞書更新が消えた。テスト側も `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:630` で同じ条件に揃っている |
| Minor: 仮想化テストの上限を可視行数に基づく値へ | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:650` が固定 400 から `visibleCellCount * 4` になり、直前のコメントに実測値 (可視 39 件 / 実測最大 115 件) と 4 倍を選んだ根拠が書かれている。ただし証跡側の記述が追随していない (Minor-1) |
| Suggestion: コメント 2 件の追随 | **解消** | `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:6` は環境非依存の「メモリ計測用の検証画面」に、`ios/Sources/KsCollectionView/KsCollectionView.swift:148` は「先頭行の上端・行間・最終行の下端」に更新済み |
| 据え置き: GCD → Swift Concurrency | 据え置きのまま | `KsCollectionViewController.swift` の命令フラッシュは `DispatchQueue.main.async` のまま。突き合わせで据え置きが確定しているため指摘には数えない |

後退の確認: アンカーのクランプ・要素内オフセット・スクロールインジケータ不動・ヘッダー追従・存在しない ID の条件ベース待機は、いずれも前回確認した形のまま残っており、本体テストも全件成功している。後退は Major-2 の 1 件のみ。

## 指摘事項

### [🟠 Major] Sample UI テスト (通常スキーム) が通しで成功しない — 4 回中 3 回失敗

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:64`〜`:81` (`launchVerification`)、同ファイル:26 / :37 (長押し 2 件)

**問題点**: 確定リストの要求は「Sample UI テストが通しで安定すること (3 回以上の連続成功)」だった。同一 Simulator・逐次実行で 4 回連続実行した結果は 1 回成功 / 3 回失敗 (exit 65) で、前サイクル (7 回中 4 回失敗) から改善していない。

失敗の症状は前回と同一で、アサーション失敗ではなく `Restarting after unexpected exit, crash, or test timeout` である。失敗した回のログはいずれも次の形をとる。

```
Test Case '-[... test長押し未宣言時は長押し相当の保持でも通常タップを発火する]' started.
    t = 0.03s Set Up
    t = 0.03s Terminate jp.kamusoft.kscollectionview.samples.ios:<pid>
    t = 1.12s Open / Launch jp.kamusoft.kscollectionview.samples.ios
    t = 1.34s     Setting up automation session
    t = 2.15s     Wait for jp.kamusoft.kscollectionview.samples.ios to idle
(以降、そのテストは結果を報告しないまま Runner が落ちる)
```

失敗するテストは実行ごとに入れ替わる (`test長押し宣言時…` / `test長押し未宣言時…` / `testセル内Button…` のいずれも失敗例がある) ため、特定のアサーションではなく起動シーケンス側の問題である。今回追加された `launchVerification` は 1 テストにつき `app.terminate()` → `app.launch()` を最大 2 セット行うが、`XCUIApplication.launch()` 自身が既存インスタンスの終了と再起動を含むため、直前の明示 `terminate()` は automation session の破棄と生成を重ねる形になっている。ハングはこの直後の `Wait for … to idle` で起きており、待機の追加ではなく起動回数そのものが不安定要因になっている疑いが強い。

なお本機には passcode ロック中の実機 (iPhone 15) がペアリングされており、失敗中のログには `DTDKRemoteDeviceConnection: Failed to start remote service … The device is passcode protected.` が 20 秒以上繰り返される。これは環境要因だが、hitch 計測に使った実機と同一であり、このプロジェクトの標準的な開発機がその状態である。環境要因で落ちるなら、その環境で落ちない書き方に寄せるか、環境前提を `cross/test-execution.md` に明記して再現条件を固定する必要がある (現状はどちらも無い)。

**推奨修正**: 次のいずれか。

1. `launchVerification` の明示 `terminate()` を外し、起動引数を設定した `app.launch()` 1 回に統一する。起動画面の取り違えは、`rootIdentifier` の待機に加えて `longPress.declaresLongTap` のようなモード表示の内容一致で判定すれば検出できる (既に `launchLongPressVerification` が行っている)
2. テストごとの再起動をやめ、画面遷移で検証モードを切り替える (Sample にモード切替の入口を設ける)
3. 上記で安定しない場合、`cross/test-execution.md` に「実機がペアリングされた状態では通常スキームが不安定になる」ことと回避手順を規約として明記し、その条件下での 3 回連続成功を証跡に残す

いずれの場合も、修正後は絞り込みなしの通常スキームを 3 回以上連続で通し、実行件数 (3 tests / 0 failures) を証跡に残すこと。

### [🟠 Major] Release 構成のビルド生成物 `ios/DerivedDataRelease/` が ignore されず、local-path lint が exit 1 になる

**該当箇所**: `.gitignore:53` (`DerivedData/`)、`kasane/handbook/cross/test-execution.md` の iOS Release 実行手順

**問題点**: `python3 scripts/local-path-lint.py` が違反 430 件で exit 1 になる。違反はすべて `ios/DerivedDataRelease/` 配下 (`Build/Intermediates.noindex/…/OutputFileMap.json`、`XCBuildData/PIFCache/…`、`ModuleCache.noindex/Session.modulevalidation`、`info.plist` 等) にあり、内容はビルド機のローカル絶対パスである。

このディレクトリは、本 change が handbook に書いた Release テスト手順 (`xcodebuild test -scheme KsCollectionView … -configuration Release ENABLE_TESTABILITY=YES` を `ios/` で実行) を実行すると生成される。本レビューでその手順をそのまま実行した結果として生まれたものであり、実装者の手元にも同じものができる。`.gitignore` は `DerivedData/` は除外しているが `DerivedDataRelease/` を除外していないため、`git add ios/` で数百 MB のビルド生成物とローカル絶対パスがそのまま追跡対象に入る。`kasane/` を commit する前提のプロジェクトで、public 化前の防波堤である local-path lint が赤のままになる。

前サイクルのレビューは lint 違反 0 を報告しているため、これは Release 構成のテストを回した時点で表面化する後退である (前回のレビュアーは作業ディレクトリ外の一時 `derivedDataPath` を明示して回避していた)。

**推奨修正**: `.gitignore` に `DerivedDataRelease/` を追加する (Release 以外の構成でも同じ命名規則で増えうるため、`DerivedData*/` のような形が確実)。`samples/ios/` 側も Release ビルドで同じ命名の兄弟ディレクトリができるため、同じ 1 行で両方を覆えることを確認すること。追加後に `python3 scripts/local-path-lint.py` が exit 0 になることを確認し、既に生成済みの `ios/DerivedDataRelease/` は `trash` で片付ける。

### [🟡 Minor] 生存セル上限について、証跡の記述 (可視の 3 倍未満) とテストのアサーション (可視の 4 倍未満) が食い違う

**該当箇所**: `evidence/verification-matrix.md:18`、`evidence/performance-early-measurement.md:75`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:650`

**問題点**: 証跡 2 箇所が「同時生存セル数が可視セル数の **3 倍未満** に留まることを検証」と書いているが、実際のアサーションは `liveCellLimit = visibleCellCount * 4` に対する `XCTAssertLessThan` であり、可視の 4 倍未満しか検証していない。テスト側のコメントは実測最大が約 3 倍だったことと上限を 4 倍に置いた理由を正しく説明しており、食い違っているのは証跡の側だけである。

サイクル 8〜9 で Major になったのは「証跡の説明が実装より強い主張になっていた」ことであり、これは規模の小さい同型の再発である。証跡はレビュー・検証・蒸留が根拠として読む文書なので、実装が保証している境界をそのまま書く必要がある。

**推奨修正**: 証跡 2 箇所を「可視セル数の 4 倍未満に留まることを検証 (実測の最大は約 3 倍)」のように、アサーションの境界と実測値を分けて書く。

### [🟡 Minor] 「1 往復あたり全項目を通過」の自動検証が 2 往復の累積集合になっている

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:100`・`:103`、`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:57`、`evidence/performance-early-measurement.md:57`

**問題点**: `performRoundTrip` は `visitedItems` を往復ごとにリセットせず累積する (`var visited = visitedItems` → `visitedItems = visited`)。計測ドライバの `XCTAssertEqual(visited, "通過: 10000 / 10000")` は 2 往復を終えた後の表示を見るため、1 往復目が 9,000 件、2 往復目で残り 1,000 件を拾った場合でも成立する。一方 evidence は「両実行とも **1 往復あたり**の通過項目は 10,000 / 10,000 件だった」と 1 往復単位で主張している。

主張の根拠は自動実行モードが出す `KS_PERF_MEMORY_ROUND_1=… visited=` の 1 往復目の値であり、そちらは 1 往復単位で正しい。しかし通しで回せる自動検証の側は 1 往復単位の全件通過を担保しておらず、刻みが粗くなる後退 (この change で 3 周にわたり争点になった箇所) を捕まえられない。

**推奨修正**: 往復ごとの通過集合を別に保持し (`visitedItems` は累積のまま、往復単位の件数を `lastRoundTripVisitedCount` 等で公開する)、計測ドライバのアサーションを 1 往復目の時点で `10000 / 10000` を要求する形に変える。evidence の文言は、担保している単位に合わせて書き直す。

### [🔵 Suggestion] 計測画面の手動モードが 2 往復で頭打ちで、定常判定に到達できない

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:23`・`:29`〜`:33`

**問題点**: 「1 往復する」ボタンは `completedRoundTrips >= 2` で無効化され、表示ラベルも 1 往復後・2 往復後の 2 つしかない。定常判定 `hasSteadied` は最低 3 往復を要するため、手動操作では判定に到達できない。判定に届くのは自動実行モードだけで、手動モードは 2 往復設計だった頃の名残になっている。

**推奨修正**: ボタンの無効化条件を `maximumRoundTrips` 基準に変え、表示を「直近の往復後」+「往復ごとの一覧」に置き換える。あるいは手動モードを廃止し、自動実行モードだけを計測経路として残す。

### [🔵 Suggestion] `local-development-setup.md` に、既に埋めた節の「実構成の確定後に追記する」指示文が残っている

**該当箇所**: `kasane/handbook/cross/local-development-setup.md` の「版の定義元」節と「デモ画面一覧はどこを見るか」節

**問題点**: 「定義元の表 … は、各プラットフォームのビルド構成が成立した時点でこの節へ追加する」という指示文の直後に、その表が既に置かれている。「定義元ファイル (iOS / Android それぞれの `SampleScreen`) のパスは、Sample scaffold の成立時にここへ追記する」も、直後に iOS の定義元が書かれた状態で残っている。読み手には未着手の節に見え、`kind: guide` の文書として手順の現在地が読み取りにくい。

**推奨修正**: 埋まった分の指示文を削り、未着手の Android 分だけを残す (「Android の定義元はビルド構成の成立後に追加する」等)。

### [🔵 Suggestion] doc-structure lint の本 change 由来 1 件が未解消 (前回からの持ち越し)

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:31`

**問題点**: 本 change が追記した「値キーテンプレートの推論形が書けない」の箇条書き 1 項目が 459 字で、`doc-structure` lint の上限 200 字を大きく超える (lint 全体は 26 件だが、本 change 由来はこの 1 件)。前サイクルでも Suggestion として挙がっており、未対応のまま。

**推奨修正**: 症状・暫定形・API 候補・決定軸を小節または表の行に割る。

## 確認した観点

指摘に至らなかったが確認した範囲を残す。

- デルタスペック 15 Requirement / 24 Scenario と `evidence/verification-matrix.md` の対応。実在するテスト名で埋まっており、自動検証が無い欄は「自動検証なし」と明示されている
- `tasks.md` の全チェック。5.3 (`Template` の 3 形) と 8.1 (基準機 iPhone 11) は実装と食い違うが、いずれも deviation.md に記録済みの合意差分
- deviation.md の `[付随修正]` 2 件 (iOS 26 のセル登録準備 / 空配列での初回 snapshot)。どちらも collection-core 内の局所修正で、対応する統合テストがある。同梱条件を超えていない
- 差分更新・重複 ID の後勝ち・未登録テンプレートキーの Release 縮退・prefetch seam・スクロール命令の順序保証・アンカー復元 (通常 / 連続変更 / 高さ縮小 / アンカー削除)・自己サイズ・header / footer・区切り線・タップと長押しの排他・touchFeedback
- `#if DEBUG` / `#if !DEBUG` の対称性。Release 専用 2 件 (`testReleaseでは重複IDを後勝ちで解決して表示を継続する` / `testReleaseでは未登録キーを空セルへ解決する`) が Release 実行に含まれ、Debug 専用 1 件が Debug 実行に含まれることを件数 (60 / 61) の内訳で確認した
- `ui/mock/approved.png` と `ui/verification/` 5 枚、`evidence/` の向き 3 枚の存在と `ui/brief.md` の照合記録
- sample-parity: 検証画面 3 種 (`InteractiveControlVerificationView` / `LongPressVerificationView` / `PerformanceVerificationView`) は起動引数でのみ到達しルートメニューの 9 画面に含まれないため、規約の「プラットフォーム固有の技術検証画面」ではなくデモ画面集合の外にある。片側先行は phase-3 agenda の申し送りで追跡されている
- comment-policy: 公開 doc コメントに ADR ID・change 名・デルタスペック構文キーワードが無いこと (lint の検出範囲より広く、`ios/Sources/KsCollectionView/KsCollectionView.swift` の公開メンバーを本文から確認)
- `DispatchQueue.main.async` による命令フラッシュ (突き合わせで据え置き確定のため指摘に数えない)

## アクションプラン

1. Sample UI テストの起動シーケンスを直し、通常スキームの 3 回以上の連続成功を実測で示す (Major-1)。安定化できないなら、環境前提と回避手順を `cross/test-execution.md` に規約として書き、その条件下での連続成功を証跡に残す
2. `.gitignore` に Release 構成の DerivedData を追加し、`local-path-lint.py` が exit 0 になることを確認する。生成済みディレクトリは `trash` で片付ける (Major-2)
3. 証跡 2 箇所の「3 倍」をアサーションの境界に合わせて直す (Minor-1)
4. 往復ごとの通過件数を担保する形に計測ドライバのアサーションを変える (Minor-2)
5. Suggestion 3 件 (計測画面の手動モード・guide の指示文・doc-structure) は、上記の修正に同梱できる範囲で対応する
6. 修正後、本体 Debug / Release、Sample 通常スキーム 3 回以上、4 本の lint を同じ構成で再確認する
