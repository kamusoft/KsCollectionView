# レビュー結果: performance-criteria-review (005 回目)

**日付**: 2026-09-15
**判定**: CHANGES_REQUESTED

## サマリー

`review-004.md` の Major のうち、**再現しなかった 2 つの記述 (「`shouldInvalidateLayout(forPreferred…)` を経由しない」「境界は最下位桁」) は訂正され、訂正後の記述は自分のプローブで再現した**。新たに書かれた「戻り値は解き直しの有無と連動しない (差が大きくても `false`)」も、倍率 3 と倍率 2 の 2 機種で再現している (差 8 pt でも 44 回すべて `false`、それでも `invalidateLayout(with:)` は 10 回)。Minor 2 (許容幅の固定) と Minor 3 (混在 fixture の条件併記) も解消し、相方の Major (1e-9 の内側が未検証) も新テストで裏付けられた。

一方で **新しい確定テストと、同じサイクルで足されたエンジンテスト 1 本が、画面の倍率が 2 の機種で決定的に失敗する**。半画素の境界を「0.1 pt / 0.2 pt」という倍率 3 前提の固定値で書いているためで、iPad Pro 11-inch (M5) / iOS 26.4.1 では 172 件中 3 件が失敗した (残り 169 件は緑なので、倍率に弱いのはこのサイクルで足したテストだけ)。テスト失敗は単独で CHANGES_REQUESTED である。加えて `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:10-15` の機構説明が、この change が確定させた事実と真っ向から矛盾したまま残っている (review-004 の推奨修正 3 が片側だけ対応)。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `kasane/handbook/cross/comment-policy.md` | always (コメントの新設・書き換えがある) |
| `kasane/handbook/cross/test-execution.md` | テストを実行する・結果を報告する |
| `kasane/handbook/cross/runtime-behavior-verification.md` | 実行時挙動の検証・完了判定 |
| `kasane/handbook/cross/sample-parity.md` | `samples/**` を触る |
| `kasane/handbook/cross/scroll-performance-gate.md` (本 change の成果物) | スクロール性能の完了判定・証跡 |
| `kasane/handbook/ios/performance-verification.md` / `kasane/handbook/android/performance-verification.md` (同上) | 各 platform の計測手順 |
| `kasane/decisions/cross/0006-perceived-smoothness-as-performance-gate.md` (proposed) | 参照のみ。proposed のため指摘の根拠にしていない |

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox の `reviewer-reproduces-evidence-numbers-by-probe.md` (証跡の数値を自前プローブで再現する)、`report-device-and-os-with-layout-numeric-tests.md` (レイアウトの数値を持つテストは画面サイズまたは倍率の異なる 2 機種以上で通す)、`tests-created-in-change-are-in-scope-for-fixes.md` を観点に加えた。`do-not-run-review-and-verify-on-same-simulator.md` に従い、ホスト (iPhone 16e / 26.1、iPhone 17 Pro Max / 26.0) および `review-004.md` (iPhone Air / 26.5、iPhone 17e / 26.5) が使っていない Simulator を選んだ。

## 再現した検証

| 対象 | 実行 | 結果 |
|---|---|---|
| iOS ライブラリ全体 | `xcodebuild test -scheme KsCollectionView` (iPhone 17 Pro / iOS 26.4.1) | **Executed 172 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| iOS ライブラリ全体 | 同 (iPad Pro 11-inch (M5) / iOS 26.4.1、倍率 2) | **Executed 172 tests, with 3 failures** (`** TEST FAILED **`) → Major 1 |
| 確定テスト 2 クラスのみ | 同 `-only-testing` (iPad Pro 11-inch (M5) / iOS 26.4.1) | 22 件中 2 件失敗 (全件実行と同じ 2 件) |
| lint 3 本 | `comment-policy-lint.py` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件 (検査対象 215 ファイル、要確認 14 件はいずれも本 change 由来ではない) |

### プローブ (作業ツリーには触れず、パッケージの複製に観測用テストを 1 本足して実行)

`KsSelfSizingInvalidationTests` と同じ構成 (60 件・窓 390x844・同じセルとレイアウトの組み立て) に `UICollectionViewCompositionalLayout` の派生を差し込み、`shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の**呼び出し回数と戻り値**、`invalidateLayout(with:)` の回数、セルを測った回数、そのとき preferred と original の高さがどれだけ違っていたか、コンテンツ全体の高さを採った。

**iPhone 17 Pro Max / iOS 26.4.1 (倍率 3、実測の行高 36.3333 pt)**

| 渡した推定高さ | 測定回数 | 合計高さ | `shouldInvalidate…` 呼び出し (うち `true`) | `invalidateLayout` | preferred と original の最大差 |
|---|---|---|---|---|---|
| 既定値 44 (対照) | 44 | 2471.3 | 44 (0) | 10 | 7.667 |
| 完全一致 | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| `nextUp` | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| +9e-10 (`matchTolerance` × 0.9) | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| +1e-8 | 22 | 2180.0 | 22 (0) | 2 | 0.0 |
| +0.1 (半画素未満) | 22 | **2186.0** | 22 (0) | 2 | 0.0 |
| +0.2 (半画素超) | 44 | 2187.6 | 44 (0) | 9 | 0.333 |
| +8 | 44 | 2484.0 | 44 (0) | 10 | 8.0 |

**iPad Pro 13-inch (M5) / iOS 26.4.1 (倍率 2、実測の行高 36.5 pt、半画素 = 0.25 pt)**

| 渡した推定高さ | 測定回数 | 合計高さ | `shouldInvalidate…` 呼び出し (うち `true`) | `invalidateLayout` |
|---|---|---|---|---|
| 既定値 44 (対照) | 72 | 2460.0 | 72 (0) | 10 |
| 完全一致 | 24 | 2190.0 | 24 (0) | 1 |
| `nextUp` / +9e-10 / +1e-8 | 24 | 2190.0 | 24 (0) | 1 |
| +0.1 | 24 | **2196.0** | 24 (0) | 1 |
| **+0.2 (倍率 2 では半画素未満)** | **23** | **2202.0** | 23 (0) | 1 |
| +8 | 72 | 2478.0 | 72 (0) | 10 |

読み取れること:

1. `deviation.md:18` の訂正 (**1 回につき 1 回呼ばれる / 戻り値は解き直しと連動しない**) は**両機種で再現した**。差 8 pt でも戻り値は全件 `false` のまま、`invalidateLayout(with:)` は 10 回走る。`init(sectionProvider:)` で派生させないと override が効かない点も再現した
2. `deviation.md:19` の回数表 (完全一致 22 / `nextUp` 22 / +0.1 22 / +0.2 44 / +8 44) は倍率 3 で再現した
3. `matchTolerance` の直下 (+9e-10) でも測定回数は増えない — 相方の Major (nextUp と 1e-9 の間が未検証) は解消している
4. **境界は倍率に対して相対である**。倍率 2 では 1 画素 = 0.5 pt・半画素 = 0.25 pt となり、**+0.2 pt では解き直しが起こらない** (測定回数 24 → 23、合計だけが 12 pt = 60 行 × 0.2 伸びる)。許容の内側では「渡した高さのまま行が積まれる」という性質も倍率 2 で同じ
5. 許容の内側では preferred と original の差が常に 0.0 — **セル側 (`KsHostingCell.preferredLayoutAttributesFitting`) が渡された高さをそのまま返している**。解き直しが起きない理由はここにあり、レイアウトの戻り値ではない (Major 2 の根拠)
6. +0.1 pt のときの合計は **2186.0** (= 2180.0 + 60 × 0.1) で、`deviation.md:20` の **2,185.3 (差 5.3 pt)** は再現しない (Minor 1)

## 前回指摘の解消状況

`review-004.md` の全指摘と、`second-opinion-code-004.md` 末尾の突き合わせ表で確定した 1 件。

| # | 出所 | 指摘 | 判定 | 該当箇所 |
|---|---|---|---|---|
| 1 | host Major | 「`shouldInvalidateLayout(forPreferred…)` を経由しない」が再現しない | **解消** | `deviation.md:18` が「1 回につき 1 回呼ばれる。ただし戻り値は連動しない」に訂正され、`ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:16-20` も同じ記述。プローブで再現 (上表 1) |
| 1' | host Major | 「一致と見なしてよい幅は最下位桁」が外挿 | **解消** | `deviation.md:19`・`ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:41-46`・テスト名 `test半画素を超える差は解き直しを起こす` が「境界は半画素、1e-9 はその内側」に統一。プローブで再現 (上表 2) |
| 1'' | host Major | 量子化しない理由を「積み上がる」に置き換える | **解消** | `deviation.md:16` と `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:17-22` が積み上がりの説明になった。ただし数値が再現しない → Minor 1 |
| 1''' | host Major | `KsEstimatedHeight` との矛盾を解消する | **未解消** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:10-15` は戻り値に機構を帰したまま → Major 2 |
| 2 | host Minor / 相方 Major (突き合わせで確定) | 確定テストが `matchTolerance` を固定していない | **解消** | `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:98-136` が `matchTolerance × 0.9` の差で解き直しと積み上がりが無いことを固定。許容幅を 0.1 pt に緩めると合計高さの比較 (行 60 × 0.09 = 5.4 pt) で落ちる |
| 3 | host Minor | 混在 fixture の参考値に条件が無い | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:923-925` に機種・OS・計測形が入った |
| 4 | host Suggestion | 確定テストが本番の組み立て経路を通っていない旨の明記 | **解消** | `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:25-26` |
| 5 | host Suggestion | 倍率だけが変わったときに標本を捨てていない | **未対応** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:86-97` → Suggestion 再掲 |
| 6 | host Suggestion | 4.4 で回収する記録 | **未対応 (予定どおり)** | 4.4 未着手 |
| 3' | host 所見 | 本番 fixture の見積もり悪化を承知で進む判断の明示 | **未対応** | `tasks.md` 4.1・`deviation.md` とも変わらず。オーナー判断のため再掲にとどめる |

後退: 無し。ただし**新規の後退リスク**として、このサイクルで足したテストが倍率 2 で落ちる (Major 1)。

## 指摘事項

### [🟠 Major] このサイクルのテスト 3 件が倍率 2 の機種で決定的に失敗する

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:60-95` (特に `:68-69`)、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:854-860`

**問題点**:

`test半画素を超える差は解き直しを起こす` は、半画素未満 / 半画素超の対照を **0.1 pt / 0.2 pt という固定値**で書いている。この 2 値が対照になるのは 1 画素 = 0.3333 pt の倍率 3 だけで、倍率 2 では 1 画素 = 0.5 pt・半画素 = 0.25 pt となり **0.2 pt も半画素未満**になる。テストは `displayScale` を読んでおらず、doc コメント (`:63-64`) にも倍率の前提が書かれていないため、値だけを見ると絶対値の境界に見える。

実測 (iPad Pro 11-inch (M5) / iOS 26.4.1 で全件実行。172 件中 3 件失敗、他の 169 件は緑。倍率 2 での境界そのものは iPad Pro 13-inch (M5) / iOS 26.4.1 のプローブでも確認した):

```
KsSelfSizingInvalidationTests.swift:83: 半画素を超える差で無効化が増えませんでした (完全一致 1 回 / 0.2pt 違う 1 回)
KsSelfSizingInvalidationTests.swift:89: 半画素を超える差で測り直しが増えませんでした (完全一致 24 回 / 0.2pt 違う 23 回)
KsCollectionEngineTests.swift:856: いまの推定値と測った高さが同じでは、比較の相手の違いを見分けられません (0.0 > 0.5 が偽)
```

3 件目 (`testレイアウトを渡した後に推定値が動いても渡された高さと比べて数える`) は前提を確かめるガードの失敗で、倍率 2 では推定値と実測が一致してしまい「比較の相手が違う状況」を作れていない。どちらも製品コードの欠陥ではないが、**倍率 2 の機種ではライブラリのテストが赤になる**。本ライブラリは iPad を含む iOS 16+ が対象で、倍率 2 の機種を検証から外す宣言はどこにもない。`kasane/lessons/inbox/report-device-and-os-with-layout-numeric-tests.md` が求める「画面サイズ**または倍率**の異なる 2 機種以上で通す」に照らしても、ホストの 2 機種 (iPhone 16e / 17 Pro Max) はどちらも倍率 3 で、倍率の違いを踏んでいない。

**推奨修正**:

1. 刻みを画面から導く。`displayScale` (または `window.screen.scale`) から `pixel = 1 / scale` を作り、半画素未満 = `pixel * 0.3`、半画素超 = `pixel * 0.6` のように相対値で振る。失敗メッセージにも倍率と刻みを載せる (倍率 3 では現行と同じ 0.1 / 0.2 になる)
2. `KsCollectionEngineTests.swift:854-860` は、ガードを落とすのではなく、推定値と実測が一致してしまう環境でも「比較の相手の違い」を作れる形にする (例: 渡す高さを実測 ± 半画素超に取る)。それが難しければ `XCTSkipIf` で理由つきに落とし、緑の一部として数えない
3. 倍率を変えて通したことを実装報告に残す (`report-device-and-os-with-layout-numeric-tests` の要求)

### [🟠 Major] `KsEstimatedHeight` の機構説明が、この change が確定させた事実と矛盾したまま

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:10-15`、対する記録は `kasane/changes/performance-criteria-review/deviation.md:18` と `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:19-20`

**問題点**:

`KsEstimatedHeight` は、多数派のセルで再解決が起きない理由を「`shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` は preferred が original と同じなら invalidate を要求しない」と、**そのメソッドの戻り値**に帰している。ところが同じ change が確定させた事実は「**戻り値は解き直しの有無と連動しない (差が大きくても `false` が返る)**」であり、これは自分のプローブでも倍率 3 / 倍率 2 の両方で再現した (差 8 pt で 44 回すべて `false`、それでも `invalidateLayout(with:)` は 10 回)。つまり 2 つのファイルが同じ機構について逆のことを書いており、`KsEstimatedHeight` を単独で読んだ人は誤った機構を信じる。`review-004.md` の推奨修正 3 が求めていたのはこの矛盾の解消だが、訂正されたのは deviation とテスト側だけである。

観測に基づく正しい機構は上表 5 のとおり: **渡された高さが実測と半画素以内なら、セル側の `preferredLayoutAttributesFitting` が渡された高さをそのまま返す (preferred == original)。だから解き直しが起きない。** レイアウトの戻り値にはこの判断が現れない。

**推奨修正**: `:10-13` の括弧の説明を観測に合わせて書き直す。たとえば「セルが返す高さ (preferred) が渡されていた高さ (original) と同じなら解き直しは起きない。UIKit はこの 2 つの差で判断しており、その判断は `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` の戻り値には現れない (`KsSelfSizingInvalidationTests` で確認)」。`:14-15` の「再解決の判定がセルの preferred と original の比較で行われる」は正しいので残せる。挙動の変更は不要。

### [🟡 Minor] 積み上がりの実測値 (5.3 pt / 2,185.3 pt / 900 pt 規模) が再現しない

**該当箇所**: `kasane/changes/performance-criteria-review/deviation.md:16`、同 `:20`

**問題点**: deviation は「差 0.1 pt で 60 行のとき 5.3 pt」「+0.1 pt のとき合計が 2,180 → 2,185.3 pt」「10,000 件なら 900 pt 規模」と書くが、同じ構成での実測は **2,186.0 pt (差ちょうど 6.0 pt = 60 × 0.1)** である。倍率 3 の iPhone 17 Pro Max / 26.4.1 と倍率 2 の iPad Pro 13-inch (M5) / 26.4.1 (2,190.0 → 2,196.0、やはり差 6.0) の双方、および `review-004.md` が別の 2 機種で採った値 (2,186.0) と一致する。4 機種で 5.3 は出ない。判断そのもの (量子化した値を返さない) は正しいが、数値が誤っているとその根拠の大きさを読み違える。

外挿の方も、10,000 件・差 0.1 pt なら 1,000 pt、量子化で起こりうる最悪 (半画素 = 倍率 3 で 0.167 pt) なら約 1,670 pt で、900 pt より大きい。

**推奨修正**: 採り直した値に差し替える。外挿は「渡す値が格子へ丸めた値になるときの最悪は半画素ぶん × 件数」であることに合わせる。値には機種・OS・倍率を併記する (すでに `:17` に併記の形があるので、そこに倍率を足せば足りる)。

### [🔵 Suggestion] 画面の倍率だけが変わったときに標本を捨てていない (再掲 2 回目)

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:86-97`

**問題点**: 標本を捨てるのは幅が変わったときだけで、`scale` が変わっても前の倍率の格子で数えた `grid` が残るため、格子が混ざると最頻値の意味が崩れる。`sampledScale` は上書きされるので、平均を載せ直す格子と標本の格子もずれる。実害の想定される経路は今のところ無く、優先度は低いまま。

**推奨修正**: 幅と同じ扱いで倍率の変化でも捨てる (`record` の 1 行)。

### [🔵 Suggestion] 4.4 で回収する記録 (再掲)

**該当箇所**: `samples/android/benchmark/scripts/testdata/`、`kasane/changes/performance-criteria-review/tasks.md` の 4.4

**問題点**: 実物のフリング結果 JSON を通す回帰テストと、`review-002.md` の「実物の `sampledMetrics` は配列」が事実誤認だった旨の訂正は、どちらも未着手のまま。4.4 まで実物が存在しないので今は手当て不要という判断は変わらない。

### 所見 (指摘ではない)

- 本番 fixture (混在 2 列) の見積もりがどのテストの対象でもなくなった件を 4.1 の証跡か deviation に明示する、という `review-003.md` 以来の所見は依然として未対応。実装では決められないためオーナー判断として再掲する
- `design.md:9` は Apple 文書を根拠に「preferred が original と同じなら invalidate 不要」と書いており、Major 2 の誤りの出所はここにある。design.md は足場なので書き換えは求めない。蒸留で concepts / ADR に流すときに、観測に基づく機構 (セル側が渡された高さをそのまま返す) の方を正として書くこと

## アクションプラン

1. **Major 1** — 半画素の対照を画面の倍率から導く形に直し、`KsCollectionEngineTests.swift:854-860` のガードも倍率 2 で成立する形にする。倍率 3 と倍率 2 の 2 機種で全件を通して報告する
2. **Major 2** — `KsEstimatedHeight.swift:10-13` の機構説明を観測に合わせて書き直す (挙動と定数は変更不要)
3. **Minor 1** — `deviation.md:16` / `:20` の積み上がりの数値を採り直し、倍率を併記する
4. **Suggestion** — 倍率変化での標本破棄は次に同ファイルへ触れる機会に、4.4 の記録はその機会に
5. **所見** — 本番 fixture の判断の明示はオーナー判断。蒸留時に機構の正を Major 2 の形で残す
