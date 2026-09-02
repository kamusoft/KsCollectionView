# レビュー結果: ios-engine-foundation (009 回目)

**日付**: 2026-09-03
**判定**: CHANGES_REQUESTED

## サマリー

修正サイクル 9 の確定リスト 8 件 (Major 1 / Minor 7) のうち 6 件は解消しており、いずれも新規テストか文書の追随を伴っている。特にアンカー復元のクランプ (Minor)、要素内オフセットの数値等式テスト、スクロールインジケータ不動とヘッダー追従の統合テスト、固定待機の除去は、指摘の意図どおりに観測可能な形へ落ちている。本体テストは Debug 60 件 / Release 62 件がすべて成功し (前サイクル 56 / 58 から +4 / +4)、標準 lint 3 本は違反 0 件だった。

一方で 2 件が残っている。(1) メモリ計測の往復は端点ジャンプから 200 件刻みの走査へ変わったが、計測画面の可視項目数を実測すると約 24 件であり、1 段階あたり約 88% の項目はセルが作られない。`evidence/performance-early-measurement.md` の「全項目を通過する走査」「1 往復あたり 20,000 回の項目通過」は実装と一致しておらず、確定リストの Major が求めた状態に達していない。(2) Sample UI テストは本レビューで 7 回実行して 4 回失敗した (他プロセスの影響が無い条件でも 5 回中 2 回失敗)。確定リストは「長押し UI テストの安定化を行い、3 回連続成功を確認する」だったが、待機条件の強化は 3 件中 2 件にしか入っておらず、強化した側も落ちている。

重点として指示された 3 点のうち、(b) 生存セル数のフックは本番の挙動を変えず実害も小さいが、Release にも無条件で載る点を Minor として挙げる。(c) アンカー復元のクランプとオフセット数値テストは妥当で、後退も見つからなかった。

重要度別件数: **Critical 0 / Major 2 / Minor 3 / Suggestion 4**

## 実行結果

Simulator は `xcrun simctl list devices available` で存在を確認した機種・OS を使用した。ビルド生成物はいずれも作業ディレクトリ外の一時 `derivedDataPath` へ出力し、リポジトリに残していない。

| 対象 | コマンド | 結果 |
|---|---|---|
| 本体 Debug | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug` | Executed 60 tests, 0 failures |
| 本体 Release | 同上 + `-configuration Release ENABLE_TESTABILITY=YES` | Executed 62 tests, 0 failures |
| Sample UI (通常スキーム) | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | **7 回実行し 3 回成功 / 4 回失敗** (下記 Major-2) |
| local-path lint | `python3 scripts/local-path-lint.py` | 違反 0 |
| identity lint | `python3 scripts/identity-lint.py` | 違反 0 |
| comment-policy lint | `python3 scripts/comment-policy-lint.py` | 検査対象 61 ファイル / 禁止 0 |
| doc-structure lint | `python3 scripts/doc-structure-lint.py` | exit 1 / 26 件 (すべて `item-chars`。本 change 由来は 1 件 — Suggestion-3) |

Debug 60 / Release 62 は前サイクル (56 / 58) から +4 で、増分はサイクル 9 で追加された 4 件 — アンカーのクランプ 1 件 (`testアンカーの高さが大きく縮む切り替えでもアンカーを表示範囲に残す`)、仮想化 1 件 (`test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める`)、インジケータ不動 1 件 (`test左右の内側余白を変えてもスクロールインジケータをコンポーネント端に保つ`)、ヘッダー追従 1 件 (`testheaderは下方向のスクロールでコンテンツと一緒に画面外へ出る`) に対応する。Release が 2 件多いのは `#if !DEBUG` の 2 件によるもので、両構成を回して初めて全 Scenario が走る構成は維持されている。通常スキームの実行件数は 3 件のままで `PerformanceDriverUITests` を含まず、計測ドライバの分離は引き続き効いている。

`evidence/verification-matrix.md` が引用するテスト名 63 件を、ソース上の `func test...` 67 件 (本体 62 / Sample UI 3 / 計測ドライバ 2) と機械照合した。実在しない引用は 0 件。

### Simulator での操作確認

`kasane/lessons/inbox/verify-interactive-collection-layout-transitions.md` の観測を踏まえ、本サイクルの変更 (アンカー復元のクランプ) が実挙動へ影響していないかを iPhone 17 Pro Simulator (iOS 26.5) の Debug ビルドで確認した。デモデータと標準ステータス表示のみを観測しており、個人情報・端末固有の識別情報は扱っていない。

| 操作 | 結果 |
|---|---|
| スペーシングと余白: スペーシング Slider を連続ドラッグ | つまみとグリッド描画が追従し、跳ね・ちらつきなし |
| グリッド (固定列): grid → list 切替 | 9 行が全幅の一列へ切り替わり、区切り線は先頭上端・行間・最終行下端。乱れなし |
| 大量件数 (10,000 件): 連続フリック 2 回 | Item 143〜166 まで到達。可変行高の混在・1pt スペーシング・grid での区切り線非表示がいずれも安定 |

## 照合した規約

`kasane/handbook/index.md` → `kasane/handbook/cross/index.md` から、`always` と担当範囲 (`ios/` 本体・`samples/ios/`・テスト実行・実行時挙動・evidence) に当たる文書を本文までロードした。ios / core / android ドメインの handbook はまだ存在しない。

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| ソースコメント規約 | 常時 | 適用。lint 0 件に加え、本文基準でも作業文書パス・変更識別子・ローカル通番・履歴記述・デルタスペック構文キーワードの混入がないことを確認。公開 doc コメントへの内部用語混入もなし (ただし記述の正確さは Suggestion-1) |
| テスト実行規約 | テストを実行するとき | 適用。件数併記・Simulator 全件・Release の `ENABLE_TESTABILITY=YES`・スキーム分離を実行手順として使用。「収束を待つアサーション」の節は Major-2 の根拠 |
| 実行時挙動の検証規約 | 実行時挙動の完了判定 | 適用。アンカー復元の変更が実行時挙動に触れるため、観測点表を読んで上記の操作確認を行った |
| Sample のプラットフォーム間一致 | `samples/` を触るとき | 適用。デモ 9 画面・文言・`SampleTheme` の RGBA 参照に本サイクルでの変更なし。検証画面は launch 引数専用でルートメニューに出ない |
| 公開識別子と配布座標 | `ios/Package.swift`・pbxproj を触るとき | 適用。package / product / bundle ID (`jp.kamusoft.kscollectionview.samples.ios` / `.uitests`) が規約表と一致 (本サイクルでの変更なし) |
| ローカル開発環境と Sample の実行 | 環境構築・Sample 実行 (guide) | 適用。記載の本体ビルド・Sample ビルドのコマンドを実際に実行し、記述どおり動くことを確認 |

`kasane/lessons/` に昇格済みルールは無い (inbox 3 件のみ) ため「指摘しないこと」の制約は無い。inbox の `verify-interactive-collection-layout-transitions` (scope: code-review) と `tests-created-in-change-are-in-scope-for-fixes` (scope: process) は昇格前だが観点として妥当なため、それぞれ上記の操作確認と Major-2 の扱い (本 change が追加したテストの不安定さは本 change の範囲内) に取り入れた。参照した決定は core/ADR-0003・0004・0006・0007・0009、ios/ADR-0001〜0004、cross/ADR-0002〜0004。concepts は未作成 (index のみ)。

## 前回指摘の追跡

`second-opinion-code-008.md` の「突き合わせ結果」「オーナー判断」で確定した修正リスト (Major 1 / Minor 7) を追跡する。

| # | 出典 | 重要度 | 状態 | 確認結果 |
|---|---|---|---|---|
| 1 | 相方 Major: メモリ計測が「リスト全体の往復」を実施していない | Major | **未解消 (部分対応)** | `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:58` で刻みが 200 件になり、`:67-72` が 51 個のチェックポイントを往復する形になった。端点ジャンプは解消したが、計測画面の可視項目は約 24 件で 1 段階あたりの生成は約 24 件に留まる。evidence の「全項目を通過する走査」は成立していない → Major-1 |
| 2 | 相方 Minor: dsl-samples の基本例が Swift / Kotlin で 1 対 1 でない | Minor | **解消** | `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:44-62` の Kotlin 例に `contentPadding` / `header` / `footer` が追加され、`:65` の対称性チェックが「語彙8点が1対1」へ更新された。`:390-393` の語彙表にも「余白・区切り線」「ルート補助表示」の行が入り、`:378` の Swift / Kotlin 双方に対応がある |
| 3 | 双方一致: スクロールインジケータ不動に検証記録がない | Minor | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:669-690` が左右余白 40pt → 120pt の変更前後で `contentInset` / `adjustedContentInset` / `verticalScrollIndicatorInsets` がいずれも 0 のままであることを検証。`evidence/verification-matrix.md:21` にも反映済み |
| 4 | 双方一致: アンカーテストが復元方式を固定していない | Minor | **解消** | `KsCollectionEngineTests.swift:1188-1220` の `clipLeadingAnchor(fraction:)` が先頭可視行を高さの半分だけ上へ追い出し (行境界に揃っていないことを `XCTAssertLessThan(clippedOffset, 0)` で担保)、`:1170-1177` の `anchorOffsetFromTop` が `frame.minY - bounds.minY` を返す。`:479-509` (単発) と `:511-543` (8 段階連続) が変更前後のオフセットを `accuracy: 1.5` で突き合わせる。ID 一致だけの観測ではなくなり、UIKit 側の補正と弁別できる形になった |
| 5 | ホスト Minor-1: アンカーの高さが縮む切り替えで表示範囲外に出うる | Minor | **解消** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:545-555` の `clampedAnchorOffsetFromTop` が、控えたオフセットを新レイアウトのアンカー高さと表示範囲高さで挟み込む。`:531-534` で復元時に適用。`KsCollectionEngineTests.swift:587-628` が、アンカーを高さの 9 割まで上へ追い出したうえで 1 列 → 2 列へ切り替え、切り替え後の高さがクリップ量より小さいこと (= クランプが必要な条件であること) を確かめてからアンカーが可視集合に含まれることを検証している。詳細は下記「確認した観点」 |
| 6 | ホスト Minor-3: 「存在しない ID は no-op」テストの固定 200ms 待機 | Minor | **解消** | `KsCollectionViewController.swift:643-652` に `processedCommandCount` が入り、`ios/Tests/KsCollectionViewTests/KsCollectionScenarioTests.swift:273-287` が「無効な命令が処理し切られた」ことを条件ベースで待ってから `contentOffset` の不変を確認する形になった。固定待機は無い |
| 7 | verify 所見 4: Sample UI テストの揺れ (3 回連続成功を確認する) | Minor | **未解消** | `samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:44-58` で長押し系 2 件の待機は 30 秒の条件ベース + `waitUntilHittable` に強化されたが、`:5-18` の `testセル内Buttonの実座標タップを優先する` は対象外のまま。本レビューの 7 回実行で 4 回失敗し、3 回連続成功は成立していない → Major-2 |
| 8 | verify 所見 2: ヘッダーのスクロール追従に観測記録がない | Minor | **解消** | `KsCollectionEngineTests.swift:691-718` が、60pt の header を載せて 60 番目の要素まで送り、header のコンテンツ座標での frame が変わらず (= pin されていない) 表示範囲から外れることを検証。`evidence/verification-matrix.md:23` に反映済み |

`second-opinion-code-007.md` / `code-006.md` / `code-005.md` の確定リストは、いずれも今回のコードで維持されていることを再確認した。アンカー復元へのクランプ追加は捕捉条件 (`KsCollectionViewController.swift:90`) と復元経路 (`:516-542`) の構造を変えておらず、`plan.reconfigure` / `plan.reload` の中身にも触れないため、code-005 Major-3 / Major-4 の修正 (`test挿入時に内容不変の要素のセルプロバイダを再実行しない`)、code-007 Major-1 の reload 優先の除外 (`:392-398`)、code-006 Major-1 の可視セル再構成 (`:331-338`) はいずれも後退していない。

## 指摘事項

### 🟠 Major-1: メモリ計測の往復が全項目を通過しておらず、証跡の記述が実装と一致しない

**該当箇所**: `samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:58` / `:67-72` / `:87-92`、`kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:38` / `:64`、`kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:18`

**問題点**: 走査は `traversalStride = 200` のチェックポイントを `scrollTo(id:position:.start, animated: false)` で順に叩く形になっている。`scrollTo` は `scrollToItem(at:at:animated:)` へ落ちるため、各段階で生成されるセルは移動先の可視範囲分だけで、チェックポイント間の項目はセルが作られない。

計測画面の可視項目数を実測した。同じビルドを iPhone 17 Pro Simulator (iOS 26.5) で `--verify-performance` 起動して先頭を表示すると、可視の項目は Item 1〜24 (Item 22 まで全体が見え、23 / 24 は下端で切れる) だった。また、本レビューの UI テスト失敗ログに残っていたアクセシビリティ要素の列挙も、同画面で可視なのは Item 1〜24 であることを示している。刻み 200 件に対して 1 段階で作られるセルは約 24 件 (先読み分を足しても数十件) であり、**約 88% の項目はセルが 1 度も作られないまま通過される**。

したがって次の記述はいずれも実装と一致しない。

- `performance-early-measurement.md:38`「先頭から末尾まで 200 件刻みで順に通過し…通過した範囲のセルを実際に生成させる (端点間のジャンプでは途中の 10,000 件を通過しないため、計測にならない)」— 刻みを 10,000 から 200 へ縮めただけで、「途中を通過しない」性質は残っている
- `performance-early-measurement.md:64`「1 往復あたり 20,000 回の項目通過が起きる」— 実際は 1 往復あたり数千回程度で、桁が違う。この数字は「件数に比例した増加は起きていない」という判定の分母として使われている
- `verification-matrix.md:18`「全項目を通過する往復を 5 回まで記録」

確定リスト #1 が求めたのは「中間位置を通過する実スクロール」であり、刻みの上限は明示されていないが、同じ change の単体テスト `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1143-1147` は「前後の可視範囲が十分に重ならない刻みでは、UIKit は再利用ではなく作り直しになる」とコメントしたうえで表示範囲の半分ずつ送っている。Sample 側だけがその条件を満たしていない。

併せて、自動検証側の件数も Scenario と食い違う (下記 Minor-2)。この 2 つが重なると、collection-core「大量件数での仮想化・再利用」の 10,000 件・全体走査という条件を満たす証跡が、自動・手動のどちらにも無い状態になる。

参考として、本レビュー中の UI テスト失敗ログに、Simulator 上に残っていた Debug 構成の計測画面の表示値 (1 往復後 58,280,264 bytes / 2 往復後 72,255,816 bytes、+24%) が写っていた。構成が違うため evidence の Release 2 実行 (+1.2% / +0.5%) と直接比較はできないが、2 実行だけでは「増え続けない」の判定に足りない可能性を示している。

**推奨修正**: 刻みを可視範囲の半分以下 (この画面なら 10〜12 件程度) にして計り直し、evidence と verification-matrix の数値・記述を実測に合わせる。刻みを詰めると 1 往復の所要時間が延びるため、往復数を減らすか自動実行経路を使うのが現実的である。刻みを 200 のまま正式な手順とするなら、「全項目を通過する走査」という記述を実際に行った走査 (200 件刻みの抜き取り通過) の記述へ改め、10,000 件の仮想化を何で担保するかを明記する。なお、10,000 件で刻みを詰めた走査は UIKit の `_updateVisibleCellsNow` 再入アサーションに当たり得る (本マシンの診断レポートに、旧版の 1 万件走査テストが同アサーションで停止した記録が残っている) ため、単体テスト側の件数引き上げは実測しながら進めること。

### 🟠 Major-2: Sample UI テストが不安定なまま — 7 回中 4 回失敗し、待機条件の強化が 3 件中 2 件にしか入っていない

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:5-18` / `:44-58` / `:62-66`

**問題点**: 通常スキームを同一コマンドで 7 回実行した結果は次のとおり。

| 回 | 結果 | 失敗したテストと様態 |
|---|---|---|
| 1 | 失敗 | `testセル内Buttonの実座標タップを優先する` — Test crashed with signal kill |
| 2 | 失敗 | `test長押し未宣言時は長押し相当の保持でも通常タップを発火する` — Executed 0 tests / signal kill |
| 3 | 失敗 | `test長押し宣言時は同一タッチの通常タップを発火しない` — Test crashed with signal kill |
| 4 | 成功 | — |
| 5 | 成功 | — |
| 6 | 失敗 | `test長押し宣言時は同一タッチの通常タップを発火しない` — 131 秒かけて 4 アサーション失敗 |
| 7 | 成功 | — |

回 2 / 回 3 はレビュアーが別の Simulator を起動していた時間帯と重なるため負荷の影響を切り分けられないが、**それを除いた 5 回でも 2 回失敗している** (回 1 と回 6)。確定リスト #7 の完了条件「3 回連続成功を確認する」は本環境では成立しない。

回 6 の失敗様態は原因の手掛かりになる。`launchLongPressVerification` の 3 つの待機 (`:52` / `:54` / `:56`) がいずれも 30 秒でタイムアウトし、続く `pressCell` (`:23` 経由) の要素解決も失敗している。そのときアプリが提示していた要素は `performance.completedRoundTrips` / `performance.memory.first` / `performance.memory.second` と大量件数のデモ項目、すなわち**計測画面 (`PerformanceVerificationView`)** だった。`XCUIApplication().launch()` が新しい launch 引数でアプリを起動し直さず、Simulator に残っていた前回のインスタンスへ束縛されている。待機時間を延ばしても解決しない類の失敗であり、`:52-56` の待機強化はこの経路を救っていない。

また `testセル内Buttonの実座標タップを優先する` (`:5-18`) は今回の強化の対象外で、`waitForExistence(timeout: 2)` のあと `waitUntilHittable` を挟まずにタップし、タップ直後に `label` を同期読みしている。handbook「テスト実行規約」の「収束を待つアサーション」が求める 3 条件を満たしておらず、他の 2 件と規律が揃っていない。同 handbook は「手元で通ることは、この形で書けている根拠にならない」とも述べている。

なお、本 change の修正サイクルで追加・強化したテストであるため、`kasane/lessons/inbox/tests-created-in-change-are-in-scope-for-fixes.md` の観点からも本 change の範囲内の修正対象である。

**推奨修正**: (1) 各テストの先頭で `app.terminate()` を呼ぶか、`launchArguments` に加えて `launchEnvironment` で起動ごとに一意な値を渡すなどして、前回インスタンスへ束縛されない起動にする。少なくとも起動直後に「この画面固有の要素」が出るまで待ち、出なければ再起動する経路を持たせる。(2) `testセル内Buttonの実座標タップを優先する` を他の 2 件と同じ待機規律 (`waitUntilHittable` + `waitForLabel`) に揃える。(3) 修正後、同一コマンドで 3 回連続成功することを確認して報告に件数を併記する。

### 🟡 Minor-1: 生存セル数の計数フックが Release にも無条件で載る

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:9-15` / `:42` / `:46-50` / `:168` / `:198-211`

**問題点**: `recordLiveCell(_:)` はセルプロバイダの中 (`:168`) から毎回呼ばれ、`ObjectIdentifier` をキーにした辞書へ弱参照を格納する。件数が 512 を超えたところで辞書全体を走査して畳む。仕組み自体は正しく、`liveCellCount` が「可視範囲 + 再利用プール」を過不足なく数えることも確認した (破棄済みセルは弱参照が nil になって外れ、`ObjectIdentifier` の再利用は生存セルによる上書きになるため過大計上にならない)。実測でも、10,000 件の連続フリック時に表示・追従の劣化は見られなかった。

問題は、この計数が単体テスト (`KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める`) からしか読まれないにもかかわらず、`#if DEBUG` 等のゲートを持たず Release バイナリにも入る点である。セルの dequeue は本ライブラリが性能を約束している最ホットパスであり、そこへ弱参照の生成と辞書挿入が 1 件ずつ乗る。加えて、Major-1 のメモリ計測は Release 構成で行われているため、計測対象に最大 512 件分の弱参照エントリと、セルごとの弱参照サイドテーブルが含まれる。増分の絶対量は観測された増加 (実行 1 で約 11MB) を説明できる規模ではないので実害の指摘ではないが、「計測のための仕組みが計測対象に混ざる」構図は避けられる。

**推奨修正**: 計数を `#if DEBUG` か専用の compile flag で囲い、Release テストで必要なら `ENABLE_TESTABILITY` と同じ経路で有効化する。ゲートせず載せ続ける判断を採るなら、なぜ Release にも残すのかを `:40-41` のコメントに一文足して自己完結させる (現状のコメントは何を数えるかだけを説明しており、常時有効である理由には触れていない)。

### 🟡 Minor-2: 仮想化の自動検証が 2,000 件で、Scenario の 10,000 件を覆っていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:630-668`、`kasane/changes/ios-engine-foundation/evidence/verification-matrix.md:18`、`kasane/changes/ios-engine-foundation/specs/collection-core/spec.md:71`

**問題点**: collection-core「大量件数での仮想化・再利用」の Scenario は 10,000 件を土俵にしている。新設された走査テストは 2,000 件であり、matrix はそれを正直に「2,000 件を…」と書いているが、行の見出しは「10,000 件の仮想化・再利用」のままである。件数に比例しないことを示す試験としては 2,000 件でも意味があるが、Scenario の条件そのものを覆う自動検証は無い。Major-1 で述べたとおり手動計測側も全項目を通過していないため、10,000 件という条件を満たす証跡が現状どこにも無い。

**推奨修正**: 件数を 10,000 へ引き上げられるか実測する (Major-1 の注記のとおり UIKit の再入アサーションに当たり得るため、刻みや `layoutIfNeeded` の呼び方を含めて確認が要る)。引き上げない判断を採るなら、matrix の当該行に「自動検証は 2,000 件。10,000 件は手動計測が担う」旨を書き、手動計測側 (Major-1) がその役割を果たす形にする。

### 🟡 Minor-3: 同時生存セルの上限 400 が、可視範囲と再利用プールの規模として緩い

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:661-666`

**問題点**: `XCTAssertLessThan(maxLiveCellCount, 400)` の 400 は、テストの窓 (390×844) で可視になる行数 (約 20 件) の 20 倍にあたる。「件数に比例しない」ことは示せるが、コメントが謳う「可視範囲 (40 行程度) と再利用プールの規模に留まる」の観測としては桁が緩く、仮に再利用が部分的に壊れて生存セルが 10 倍になっても緑のままになる。なお `ksLiveCellCompactionThreshold` が 512 のため、上限を 512 以上には置けない構造でもある。

**推奨修正**: 実測値をログに出したうえで、可視行数の数倍程度 (例: 100〜150) まで締める。締められない実測値が出るなら、その値と理由をテストのコメントに残して上限の根拠を自己完結させる。

### 🔵 Suggestion-1: `listSeparators` の doc コメントが実際の描画範囲と食い違う (継続)

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView.swift:148`

**問題点**: 「list の**行間**に表示する区切り線の有無を設定します」とあるが、`deviation.md` の合意済み差分により、実際には先頭行の上端と最終行の下端にも全幅で描かれる (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:264-268`、`ios/Sources/KsCollectionView/KsHostingCell.swift:76-87`)。`review-008.md` の Suggestion-1 として挙がり、確定リストでは蒸留送りになったため本サイクルの対象外だが、状態として記録する。公開 doc コメントは利用者が読む唯一の説明であり、`skills/` による本文書化は phase-7 のため当面この一文が正になる。

**推奨修正**: 「list の行の境界 (先頭上端・行間・最終行下端) に表示する区切り線」といった、実際の描画に合う表現へ改める。

### 🔵 Suggestion-2: メモリ増分の「ばらつきより小さい」という判定の余裕が薄い

**該当箇所**: `kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:64`

**問題点**: 「この残る増分は、1 往復後の値そのものが実行間で 61.7 MB / 73.7 MB とばらつく幅より小さく」とあるが、実行 1 の 1→5 往復の増分は 11.3MB、実行間のばらつきは 12.0MB で、差は 0.7MB (6%) しかない。結論 (Simulator では切り分けられない) 自体は妥当だが、根拠としての余裕はほとんど無い。実行 1 では 3 往復後 → 4 往復後の 1 段で 8.7MB 増えており、この段差にも触れていない。

**推奨修正**: Major-1 の再計測に合わせて実行回数を増やし、増分と実行間ばらつきの比較を再構成する。あるいは「実行間のばらつきと同程度の幅に収まる」という表現へ弱め、3→4 往復の段差にも一言触れる。

### 🔵 Suggestion-3: doc-structure lint が exit 1 で終わり、本 change 由来の違反が 1 件残っている (継続)

**該当箇所**: `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:31`

**問題点**: `scripts/doc-structure-lint.py` は 26 件 / 8 ファイル (すべて `item-chars`) を検出して exit 1 で終わる。うち本 change が新しく増やしたのは phase-3 agenda の申し送り 1 項目 (459 字) で、残る 25 件は phase-1 / phase-2 の議論記録など既存文書に由来する。前サイクルから件数・内訳とも変化していない。hook に登録されていない助言的 lint であり、ビルド・テストには影響しない。

**推奨修正**: 本 change 由来の 1 件は、API 候補の列挙を小節または表の行へ移して 200 字以内に収める。既存 25 件の扱いは棚卸し (ksn-drift) へ送る。

### 🔵 Suggestion-4: 蒸留・後続フェーズへ送る継続項目

**該当箇所**: `kasane/changes/ios-engine-foundation/review-008.md` (Suggestion-2 / Suggestion-4)、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:318`、`kasane/handbook/cross/local-development-setup.md:39` / `:89`

**問題点**: 前回から状態が変わっていない項目を記録する。(1) `reconfigureVisibleCells()` 内の `_ = registration(for: configuration.templateKey(item))` には依然として意図のコメントが無く、その場だけを読むと戻り値を捨てる無意味な行に見える。(2) `local-development-setup.md` には「定義元の表は…この節へ追加する」「パスは Sample scaffold の成立時にここへ追記する」という予告文が、追加済みの表・追記済みの行の直前に残っており、どちらが現行か判別しづらい。(3) 親状態の反映が「配列が完全に同値のとき」に限られる射程の利用者向け注記と、`settleAnchorIfNeeded()` の強制レイアウトを含む経路のコストが計測条件に入っていない点。

**推奨修正**: (1)(2) は数行の整理で、次の作業のついででよい。(3) は蒸留 (ksn-distill) で performance-verification 規約へ昇格する際に判断する。

## 確認した観点 (指摘に至らなかったもの)

- **足場の凍結**: `proposal.md` / `design.md` / `specs/*/spec.md` は HEAD から未変更 (`git status` に現れない)。`tasks.md` の差分は機械照合の結果、追加行がすべて `- [x]` のチェック行で本文の書き換えは 0 件。`ui/brief.md` の追記は視覚照合の記録に相当する節で、承認済みモックの内容には触れていない
- **deviation.md**: 記録済み 17 件はいずれも合意済み差分として扱った。本サイクルで増えたのは「性能検証のメモリ計測を Simulator で行う」の 1 件で、確定リストのオーナー判断と一致する。Major-1 は Simulator で計測したこと自体を問題にしていない (往復手順の記述と実装の食い違いを指摘している)。`[付随修正]` は 2 件のまま増えておらず、いずれも ksn-core の同梱条件 (同一能力内・公開 API 非変更・局所的) に収まり、対応するテストがある
- **アンカー復元のクランプの妥当性 (重点 c)**: `clampedAnchorOffsetFromTop` は `margin = min(4, anchorHeight)` として下限を `-(anchorHeight - margin)`、上限を `visibleHeight - margin` に置く。先頭可視要素の性質上、控えるオフセットは `(-anchorHeight, visibleHeight)` の範囲にしか出ないため、クランプが働くのは新レイアウトでアンカーの高さが縮んだときだけで、高さが変わらないスペーシング変更では働かない。連続変更時の滑らかさ (確定リスト #1 のサイクル 8 で入った要件) を保ったまま「表示範囲内に現れる」を回復できており、意図どおり。`anchorHeight > visibleHeight` の場合も `maximum = max(minimum, ...)` で上下限が逆転しない。1pt の空セルのような極小要素では `margin = anchorHeight` となり下限が 0、すなわち全体が可視になる。クランプ後に `clampedVerticalOffset` でスクロール可動域へ丸める順序も、コンテンツが縮んだ場合の破綻を避ける向きで正しい
- **オフセット数値テストの妥当性 (重点 c)**: `clipLeadingAnchor` は「行境界に揃っていない任意 offset から復元させる」ことを `XCTAssertLessThan(clippedOffset, 0)` で自ら担保しており、`scrollToItem(.top)` へ実装を戻すと落ちる。行高を推定値と一致する 44pt に固定して自己サイズ由来の揺れを排したうえで `accuracy: 1.5` を使っており、意味のある等式になっている。クランプのテストは、切り替え後の高さがクリップ量より小さいこと (`XCTAssertLessThan(heightAfter, clippedLength)`) を先に確かめてから可視判定を行うため、クランプが不要な条件で緑になる空振りを排除している
- **生存セル計数の正しさ (重点 b)**: 弱参照の入れ物は破棄済みセルを自動的に外し、`liveCellCount` は読む前に畳むため、返す値は生存セル数と一致する。畳み込みの閾値 512 は可視 + プールの規模から十分離れており、生存数が 512 を超えるのは仮想化自体が壊れている場合に限られる。ホットパスへの追加コスト (辞書挿入 1 回 + 弱参照 1 本、512 回に 1 度の畳み込み) は測定可能な劣化を生む規模ではなく、実機相当の Simulator 操作でも追従の劣化は観測されなかった (常時有効である点は Minor-1)
- **spec 適合の再確認**: 値キー解決 / 未登録キーの snapshot 準備時 assertion と release フォールバック / 重複 ID の debug assertion と release 後勝ち / `id:` キーパス / adaptive の列数式と余剰幅の均等配分 / `contentPadding` と `section.contentInsets` によるインジケータ不動 / 向き別列数の `environment.container.effectiveContentSize` 参照 / 未接続・存在しない ID・複数接続の各 no-op と警告ログ / grid での区切り線非表示 — いずれも実装とテストで成立
- **テストの実質**: 新規 4 件はいずれも実 window または実ホストビューに載せた実 controller で、レイアウト属性・可視 ID・`contentInset` 系・生存セル数という観測可能な事実を見ている。言い訳コメントによる実質スキップは見当たらない。`waitUntil` は実時間 deadline (`ContinuousClock`)・待機対象への実行機会の譲り・超過時の実測値付き失敗の 3 点を満たす。走査テストの `advanceUntilVisible` が 8 段階ごとに実行機会を譲る理由もコメントで自己完結している
- **公開 API の形**: 本サイクルでの公開宣言の変更なし。`KsCollectionLayout` / `KsGridColumns` / `listSeparators` / `header` / `footer` / `KsScrollController` は core/ADR-0006・0007 と `dsl-samples.md` の語彙表に一致。`Template` の明示形と無接頭辞は暫定として `deviation.md` と phase-3 agenda の双方に残っている
- **handbook の更新内容**: `test-execution.md` の iOS 節はこのレビューで実行したコマンドと一致し、`ENABLE_TESTABILITY=YES` の必要性も実際に確認した。`local-development-setup.md` の Sample / 本体ビルドコマンドも記述どおり動く。`runtime-behavior-verification.md` の観測点表は、固定列グリッドの行が Sample で観測可能な内容 (列幅と表示の乱れ) に限定された状態を維持している
- **証跡の衛生**: `evidence/` と `ui/verification/` は静止画と Markdown のみ。identity lint と local-path lint がともに 0 件で、生 trace・端末個体名・開発者識別子・ローカル絶対パスは保存されていない。本レビューで撮影した画面もスクラッチに置き、リポジトリへは追加していない
- **ビルド生成物**: `ios/.build` `DerivedData` `xcuserdata` はいずれも `.gitignore` で除外済み。作業ツリーに未追跡の生成物は残っていない

## アクションプラン

1. **Major-1** 走査の刻みを可視範囲の半分以下へ詰めて計り直し、`evidence/performance-early-measurement.md` と `evidence/verification-matrix.md` の記述・数値を実測に合わせる。刻みを維持する判断なら、「全項目を通過する走査」の記述を実際の走査の記述へ改め、10,000 件の仮想化を何で担保するかを明記する
2. **Major-2** Sample UI テストの起動が前回インスタンスへ束縛されない形に直し、`testセル内Buttonの実座標タップを優先する` を他の 2 件と同じ待機規律へ揃える。修正後、同一コマンドで 3 回連続成功することを件数付きで確認する
3. **Minor-2** 走査テストの件数を 10,000 へ引き上げるか、matrix に自動検証の射程 (2,000 件) を明記する
4. **Minor-1 / Minor-3** 計数フックのゲートと、生存セル上限の締め直し
5. **Suggestion-1 / Suggestion-3 (本 change 由来の 1 件)** はいずれも数行の整理。次の作業のついででよい
6. **Suggestion-2 / Suggestion-4** と Suggestion-3 の既存 25 件は蒸留 (ksn-distill) / 棚卸し (ksn-drift) へ送る
7. 本 change は L 級のため、アーカイブ前に verify (ksn-verify) の再実施が必要である点はレビューの範囲外の残作業として引き継ぐ (`verify-001.md` は Major-1 / Major-2 の修正前の状態を検証している)
