# レビュー結果: performance-criteria-review (006 回目)

**日付**: 2026-09-15
**判定**: APPROVED

## サマリー

`review-005.md` の Major 2 件・Minor 1 件と、`second-opinion-code-005.md` の相方 Minor 1 件は**すべて解消している**。倍率依存で落ちていたテストは対照を `displayScale` から導く形になり、自分が選んだ**倍率 3 と倍率 2 の 2 機種でライブラリ全件 172 件が 0 failures** で通った。訂正された機構説明 (`KsEstimatedHeight` / `KsLayoutDiagnostics`) と、訂正された積み上がりの実測値 (6.0 pt) は、いずれも自前プローブで**両方の倍率で一字一致で再現**した。

残るのは、deviation の 1 行に機種名が無いこと (低優先 Minor) と、前回から据え置きの Suggestion 2 件・オーナー判断の所見のみ。Critical / Major は無い。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `kasane/handbook/cross/comment-policy.md` | always (コメントの書き換えがある) |
| `kasane/handbook/cross/test-execution.md` | テストを実行する・結果を報告する |
| `kasane/handbook/cross/runtime-behavior-verification.md` | 実行時挙動の検証・完了判定 |
| `kasane/handbook/cross/sample-parity.md` | `samples/**` を触る (今周の差分は iOS 本体のみ。前周までの範囲として確認) |
| `kasane/handbook/cross/scroll-performance-gate.md` (本 change の成果物) | スクロール性能の完了判定・証跡 |
| `kasane/handbook/ios/performance-verification.md` / `kasane/handbook/android/performance-verification.md` (同上) | 各 platform の計測手順 |
| `kasane/decisions/cross/0006-perceived-smoothness-as-performance-gate.md` (proposed) | 参照のみ。proposed のため指摘の根拠にしていない |

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox から `reviewer-reproduces-evidence-numbers-by-probe.md` (証跡の数値を自前プローブで再現する)、`report-device-and-os-with-layout-numeric-tests.md` (レイアウトの数値は画面サイズまたは倍率の異なる 2 機種以上で通し、機種と OS を証跡に併記する)、`tests-created-in-change-are-in-scope-for-fixes.md` を観点に加えた。`do-not-run-review-and-verify-on-same-simulator.md` に従い、ホスト (iPhone 16e / 26.1、iPad Pro 11-inch (M5) / 26.4、iPhone 17 Pro Max / 26.0)、`review-005.md` (iPhone 17 Pro / 26.4.1、iPad Pro 11-inch (M5) / 26.4.1、iPad Pro 13-inch (M5) / 26.4.1)、`review-004.md` (iPhone Air / 26.5、iPhone 17e / 26.5) のいずれとも重ならない Simulator を選んだ。

## 実行した検証

| 対象 | 実行 | 結果 |
|---|---|---|
| iOS ライブラリ全体 | `xcodebuild test -scheme KsCollectionView` (iPhone 17 / iOS 26.5、**倍率 3**) | **Executed 172 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| iOS ライブラリ全体 | 同 (iPad mini (A17 Pro) / iOS 26.4、**倍率 2**) | **Executed 172 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| lint 3 本 | `comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py` | いずれも終了コード 0。comment-policy は禁止 0 件 (検査対象 215 ファイル) |

前周に倍率 2 で落ちていた 3 件 (`KsSelfSizingInvalidationTests` の 2 件と `KsCollectionEngineTests.swift:856` のガード) は、**倍率 2 の機種で 172 件すべてが緑**になったことで解消を確認した。

### プローブ (作業ツリーには触れず、パッケージの複製に観測用テストを足して実行)

`KsSelfSizingInvalidationTests` と同じ構成 (60 件・窓 390x844・同じセルとレイアウトの組み立て) に `UICollectionViewCompositionalLayout` の派生を差し込み、`shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の呼び出し回数と戻り値、`invalidateLayout(with:)` の回数、セルを測った回数、preferred と original の最大差、コンテンツ全体の高さを採った。

**iPhone 17 / iOS 26.5 (倍率 3、1 画素 0.3333 pt、実測の行高 36.33333 pt)**

| 渡した推定高さ | 測定回数 | 合計高さ | `shouldInvalidate…` (うち `true`) | `invalidateLayout` | preferred と original の最大差 |
|---|---|---|---|---|---|
| 既定値 44 (対照) | 44 | 2471.3 | 44 (0) | 10 | 7.667 |
| 完全一致 | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| `nextUp` | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| +9e-10 (`matchTolerance` × 0.9) | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| **+ 画素 × 0.3 (= 0.1)** | **22** | **2186.0** | 22 (0) | 2 | 0.0 |
| **+ 画素 × 0.6 (= 0.2)** | **44** | 2187.6 | 44 (0) | 9 | 0.333 |
| +8 | 44 | 2484.0 | 44 (0) | 10 | 8.0 |

**iPad mini (A17 Pro) / iOS 26.4 (倍率 2、1 画素 0.5 pt、実測の行高 36.5 pt)**

| 渡した推定高さ | 測定回数 | 合計高さ | `shouldInvalidate…` (うち `true`) | `invalidateLayout` |
|---|---|---|---|---|
| 既定値 44 (対照) | 72 | 2460.0 | 72 (0) | 10 |
| 完全一致 | 24 | 2190.0 | 24 (0) | 1 |
| `nextUp` / +9e-10 | 24 | 2190.0 | 24 (0) | 1 |
| **+ 画素 × 0.3 (= 0.15)** | **24** | 2199.0 | 24 (0) | 1 |
| **+ 画素 × 0.6 (= 0.3)** | **48** | 2200.8 | 48 (0) | 9 |
| +0.1 | 24 | **2196.0** | 24 (0) | 1 |
| **+0.2 (倍率 2 では半画素未満)** | **23** | 2202.0 | 23 (0) | 1 |
| +8 | 72 | 2478.0 | 72 (0) | 10 |

読み取れること:

1. **対照を画素から振る形は両方の倍率で成立する**。`画素 × 0.3` では測定回数も `invalidateLayout` も完全一致と変わらず、`画素 × 0.6` では倍率 3 で 22 → 44 回、倍率 2 で 24 → 48 回に増える。前周に落ちた原因だった「固定値 0.2 pt は倍率 2 では半画素未満」も、倍率 2 の行 (+0.2 で 23 回・解き直し無し) として同じプローブで再現できた
2. **積み上がりは 6.0 pt ちょうど**。倍率 3 で 2180.0 → 2186.0、倍率 2 で 2190.0 → 2196.0 (どちらも 60 行 × 0.1 pt)。`deviation.md` の訂正後の値と一字一致する。前周に問題にした 5.3 pt は、私が採った 2 機種でも出ない
3. **許容の内側では preferred と original の差が常に 0.0**。セル側が渡された高さをそのまま返しており、`shouldInvalidateLayout(forPreferred…)` の戻り値は差 8 pt でも全件 `false` のまま `invalidateLayout(with:)` は 10 回走る。訂正後の `KsEstimatedHeight` / `KsLayoutDiagnostics` / `KsSelfSizingInvalidationTests` の機構説明はこの観測と一致する
4. 追加で確かめた点: window に入れる前の `UICollectionView` でも `traitCollection.displayScale` は 3.0 を返した (倍率 0 の経路は再現しなかった)。後述の Suggestion 1 の射程はあくまで「倍率が途中で変わる」場合に限られる

## 前回指摘の解消状況

`review-005.md` の全指摘と、`second-opinion-code-005.md` 末尾の突き合わせ表で確定した 1 件。

| # | 出所 | 指摘 | 判定 | 該当箇所 |
|---|---|---|---|---|
| 1 | host Major | このサイクルのテスト 3 件が倍率 2 の機種で決定的に失敗する | **解消** | `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:61-69` が `baseline()` から `pixel = 1 / displayScale` を取り、対照を `pixel * 0.3` / `pixel * 0.6` で振る。失敗メッセージ (`:69` の `condition`) にも倍率・画素・両対照値が載る。`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:854-878` はガードを撤去し「2 つの向きのうち少なくとも一方が比較の相手の違いで落ちる」形にした。倍率 2 の機種で 172 件 0 failures |
| 2 | host Major | `KsEstimatedHeight` の機構説明が確定事実と矛盾 | **解消** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:10-16` が「preferred が original と同じなら再解決は起きない。その判断は `shouldInvalidateLayout(forPreferred…)` の戻り値には現れない」に書き直された。プローブ 3 と一致 |
| 3 | host Minor | 積み上がりの実測値 (5.3 pt / 2,185.3 / 900 pt 規模) が再現しない | **解消** | `kasane/changes/performance-criteria-review/deviation.md` の当該行が「6.0 pt ちょうど。倍率 3 で 2,180.0 → 2,186.0、倍率 2 で 2,190.0 → 2,196.0。10,000 件なら 1,000 pt、最悪 (半画素) なら約 1,670 pt」に訂正。プローブ 2 と一致 |
| 4 | 相方 Minor (突き合わせで採用) | `KsLayoutDiagnostics.swift:6` の「高さが違うたびに解き直す」が確定挙動と矛盾 | **解消** | `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:6-10` が「差が半画素を超えると解き直しが起こる / この計数はその内側の許容幅を除いた差を数えるので上界」に。`:43-45` の 0.1 / 0.2 pt の例にも「倍率 3 では」の限定が付いた |
| 5 | host Suggestion | 倍率だけが変わったときに標本を捨てていない | **未対応** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:87-98` → Suggestion 1 (3 回目の再掲) |
| 6 | host Suggestion | 4.4 で回収する記録 | **未対応 (予定どおり)** | 4.4 未着手 |
| 7 | host 所見 | 本番 fixture (混在 2 列) の見積もり悪化を承知で進む判断の明示 | **未対応** | オーナー判断のため所見として再掲 |

後退: 無し。前周に緑だった 169 件は今周も緑で、倍率 2 での 3 件も回復している。

### ガード撤去の妥当性 (今周の変更点として個別に検証)

`KsCollectionEngineTests.swift:854-878` は「推定値と実測が 0.5 pt 以上離れていること」を確かめる前提ガードを撤去した。撤去後も検出力が落ちないことを、実装 (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:335-346` が `matchesLayout(measured:original:)` に渡す相手) と突き合わせて確認した。

- 比較の相手を誤って「いまの推定値」にした実装を仮定すると、いまの推定値がセルの返す高さと**違う**環境では前半 (`:858-867`、一致のはずが不一致に数えられる) が落ち、**同じ**環境では後半 (`:869-878`、不一致のはずが一致に数えられる) が落ちる
- どちらか一方は必ず成立するため、環境 (倍率) に依らず誤りを捕まえられる。`:854-856` のコメントはこの理屈を単独で読める形で書いている

## 指摘事項

### [🟡 Minor・低優先] 「倍率 2 では +0.2 pt でも解き直しが起きない」に機種・OS が併記されていない

**該当箇所**: `kasane/changes/performance-criteria-review/deviation.md` の Requirement「推定高さと一致するセルの自己サイズ (iOS)」の 4 つ目の小項目 (「境界の大きさは画素に対して相対である。倍率 2 (1 画素 0.5 pt・半画素 0.25 pt) では +0.2 pt でも解き直しは起きない」)

**問題点**: 同じ箇条書きの他の数値には機種と OS が付いている (冒頭の括弧に「判定は iPhone 16e / 26.1 と iPhone 17 Pro Max / 26.0 の両方で成立」、3 つ目の小項目に「倍率 2 の iPad Pro 11-inch (M5) / 26.4」) が、この行の「+0.2 pt でも起きない」という**倍率 2 固有の数値**だけ採取機が書かれていない。冒頭の括弧が名指しする 2 機種はどちらも倍率 3 なので、括弧から補うと誤った機種に帰属する。`kasane/lessons/inbox/report-device-and-os-with-layout-numeric-tests.md` は、レイアウトの数値を deviation に書くとき機種と OS を必ず併記することを求めている。

事実そのものは私の環境でも再現した (iPad mini (A17 Pro) / iOS 26.4 で測定回数 24 → 23、解き直し無し)。誤りではなく帰属の欠落なので優先度は低い。

**推奨修正**: この小項目に採取機を 1 つ足す (例: 「倍率 2 (iPad Pro 11-inch (M5) / 26.4。1 画素 0.5 pt・半画素 0.25 pt) では +0.2 pt でも解き直しは起きない」)。

### [🔵 Suggestion] 画面の倍率だけが変わったときに標本を捨てていない (再掲 3 回目)

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:87-98`

**問題点**: 標本を捨てるのは幅が変わったときだけで、`scale` が変わっても前の倍率の格子で数えた `grid` が残るため、格子が混ざると最頻値の意味が崩れる。`sampledScale` は上書きされるので、平均を載せ直す格子と標本の格子もずれる。

今周は実害の経路を 1 つ潰した: window に入る前の `UICollectionView` でも `displayScale` は 3.0 を返し、`record(height:width:scale:)` の `scale <= 0` ガード (`:93`) が発動して 1 pt 格子の標本が混ざる経路は**再現しなかった**。残る経路は外部ディスプレイへの移動など倍率そのものが変わる場合に限られ、そのとき行の幅が変わらない状況は想定しにくい。優先度は低いまま。

**推奨修正**: 幅と同じ扱いで倍率の変化でも捨てる (`record` の 1 行)。次にこのファイルへ触れる機会で足せば足りる。

### [🔵 Suggestion] 4.4 で回収する記録 (再掲)

**該当箇所**: `samples/android/benchmark/scripts/testdata/`、`kasane/changes/performance-criteria-review/tasks.md` の 4.4

**問題点**: 実物のフリング結果 JSON を通す回帰テストと、`review-002.md` の「実物の `sampledMetrics` は配列」が事実誤認だった旨の訂正は、どちらも未着手のまま。4.4 まで実物が存在しないので今は手当て不要という判断は変わらない。

### 所見 (指摘ではない)

- 本番 fixture (混在 2 列) の見積もりがどのテストの対象でもなくなった件を 4.1 の証跡か deviation に明示する、という `review-003.md` 以来の所見は依然として未対応。実装では決められないためオーナー判断として再掲する
- `design.md:9` は Apple 文書を根拠に「preferred が original と同じなら invalidate 不要」と書いており、`shouldInvalidateLayout(forPreferred…)` の戻り値に判断が現れるかのように読める。足場なので書き換えは求めない。蒸留で concepts / ADR に流すときは、観測に基づく機構 (許容の内側ではセルが渡された高さをそのまま返すため preferred == original になる / レイアウトの戻り値は連動しない) を正として書くこと
- `tasks.md` 5.2 (lint) は未チェックだが、今回 3 本とも終了コード 0 で通ることを確認済み。虚偽チェックではない (未着手のまま正しく未チェック)

## アクションプラン

1. **Minor 1** — `deviation.md` の倍率 2 の小項目に採取機 (機種 / OS) を 1 つ足す。1 行の追記で、再計測は不要
2. **Suggestion 1 / 2** — 倍率変化での標本破棄は次に `KsEstimatedHeight.swift` へ触れる機会に、4.4 の記録はそのタスク着手時に
3. **所見** — 本番 fixture の判断の明示はオーナー判断。蒸留時に機構の正を上記の形で残す
