# レビュー結果: performance-criteria-review (004 回目)

**日付**: 2026-09-15
**判定**: CHANGES_REQUESTED

## サマリー

`review-003.md` の Major (不一致率の「上界」という主張と実測の食い違い) は、**結論としては解消した**。新設された `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift` と、それを受けた一致判定の 1e-9 pt への絞り込みにより、計数は解き直しの回数を下回らない (= 上界である) ことを、自分の環境の 2 機種のプローブで確認できた。Minor 2 (画像グリッドの観測駆動) も deviation とドライバの doc コメントの両方で整理され、解消している。

一方で、**その結論を支える「確定した事実」として `deviation.md:17` と新テストの doc コメントに書かれた 2 つの記述が、自分の環境では再現しない**。(1)「compositional layout の解き直しは `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` を経由しない (1 度も呼ばれない)」は誤りで、実際には自己サイズ 1 回につき 1 回呼ばれる。(2)「一致と見なしてよい幅は最下位桁の丸め誤差まで」も観測を外挿しすぎで、実際の境界は**画面のピクセル格子への丸め (半画素)** にある — 0.1 pt (0.3 画素) の差では解き直しが起きない。1e-9 という選び方自体は境界の十分内側なので安全側であり、コードの挙動を変える必要はないが、蒸留で ADR / concepts に流れる「確定した事実」が誤っているため Major として差し戻す。Minor 3 (混在 fixture の採取環境) は deviation 側だけ対応され、テストのコメント側が残っている。

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

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox の `reviewer-reproduces-evidence-numbers-by-probe.md` (証跡の数値を自前プローブで再現する)、`check-tests-exercise-production-path-before-accepting-green.md` (テストが本番経路を通っているか)、`report-device-and-os-with-layout-numeric-tests.md` (レイアウトの数値に機種・OS を併記する) を観点に加えた。`do-not-run-review-and-verify-on-same-simulator.md` に従い、ホストおよび前回レビューが使っていない Simulator を選んだ。

## 再現した検証

| 対象 | 実行 | 結果 |
|---|---|---|
| iOS ライブラリ全体 | `xcodebuild test -scheme KsCollectionView` (iPhone Air / iOS 26.5) | **Executed 171 tests, with 0 failures** (`** TEST SUCCEEDED **`) |
| lint 3 本 | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | いずれも 0 件 (禁止 0 / 検査対象 215 ファイル) |

### プローブ (作業ツリーには触れず、パッケージの複製に観測用テストを 1 本足して実行)

`KsSelfSizingInvalidationTests` と同じ構成 (60 件・窓 390x844・同じセルとレイアウトの組み立て) に、`UICollectionViewCompositionalLayout` の派生を差し込んで `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` と `invalidateLayout(with:)` の呼び出しを数え、渡す推定高さを振った。**iPhone 16e / iOS 26.1 (ホストが使った機種) と iPhone 17e / iOS 26.5 で、下表は 1 桁まで完全に同一**。実測の行高はどちらも 36.3333 pt (倍率 3 = 1 画素 0.3333 pt)。

| 渡した推定高さ | 測定回数 | contentSize の高さ | `shouldInvalidateLayout(forPreferred…)` の呼び出し | `invalidateLayout(with:)` |
|---|---|---|---|---|
| 既定値 44 (対照) | 44 | 2471.3 | 44 | 9 |
| 完全一致 (36.33333333333333) | 22 | 2180.0 | 22 | 2 |
| `nextUp` (1 ULP ≒ 7e-15) | 22 | 2180.0 | 22 | 2 |
| +1e-12 | 22 | 2180.0 | 22 | 2 |
| +9e-10 (許容の直下) | 22 | 2180.0 | 22 | 2 |
| +1e-8 (許容の直上) | 22 | 2180.0 | 22 | 2 |
| +0.001 | 22 | 2180.0 | 22 | 2 |
| **+0.1 (0.3 画素)** | **22** | **2186.0** | 22 | 2 |
| +0.2 (0.6 画素) | 44 | 2187.6 | 44 | 9 |
| +8 | 44 | 2484.0 | 44 | 9 |

読み取れること:

1. **deviation の測定回数 (完全一致 22 / `nextUp` 22 / 0.2 pt 44 / 8 pt 44) はそのまま再現した**。ホストの数値に再現性がある。
2. **`shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` は呼ばれている** — 自己サイズ 1 回につき 1 回。「1 度も呼ばれない」は再現しない。派生を `init(sectionProvider:)` で組めば override は効く (`list(using:)` 等のファクトリは基底クラスの実体を返すため override が効かない。観測時にそちらを使った可能性がある)。
3. **一致と見なされる幅は「最下位桁」ではなく「画面のピクセル格子への丸め」**。0.1 pt (0.3 画素) の差では解き直しが起きず、0.2 pt (0.6 画素) で起きる — 閾値は 0.3〜0.6 画素の間、すなわち半画素の丸めと整合する。1e-9 はこの境界の十分内側なので、**計数は解き直しを数え落とさない (上界として成立する)**。review-003 の Major はこの点で解消している。
4. ただし許容の内側 (+0.1) では contentSize が 2186.0 = 36.4333 × 60 になる — **UIKit は一致と見なした範囲では実測値ではなく渡された推定値のまま行を積む**。量子化した値を返すと最大で半画素ぶんの誤差が全行に乗り、10,000 件なら合計で 1,600 pt 規模になる。deviation の「返すのは実測値そのもの」という判断は妥当だが、妥当である理由は「その差で解き直しが起こるから」ではなく「その差は解き直しを起こさないまま合計高さに積み上がるから」である。

## 前回指摘の解消状況

`review-003.md` の全指摘と、`second-opinion-code-003.md` 末尾の突き合わせ表で確定した 1 件。

| # | 出所 | 指摘 | 判定 | 該当箇所 |
|---|---|---|---|---|
| 1 | host Major / 相方 Minor (突き合わせで Major に確定) | 不一致率の「上界」という位置づけが実測と 8 倍食い違う | **解消 (結論)。ただし根拠の記述に誤りが混入 → Major 1** | 一致判定が `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:45` で 1e-9 pt になり、プローブで上界性を確認 (上表 3)。推奨修正 1 の「直接確かめる」を採った形 |
| 2 | host Minor | 計測ドライバに画像グリッドの自動駆動が残り spec と食い違う | **解消** | `deviation.md` 末尾に理由つきで記録され、`samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:7-8` の doc コメントが「滑らかさは自動駆動しない / ここに置くのは足場の問題が無い駆動だけ」と区別を書いている (推奨修正の (a)) |
| 3 | host Minor | 混在 fixture の数値に採取環境が無い | **部分解消** | `deviation.md:3` には「iPhone 17 Pro Max Simulator / iOS 26.0、全件を刻んで走査する当時の計測形。校正後の計測形では未再採取」が入った。一方、同じ数値を写した `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:923-925` は条件なしのまま → Minor 3 |
| 3' | host 所見 | 本番 fixture (混在 2 列) の見積もりがどのテストの対象でもなくなった件を 4.1 / 蒸留で明示する | **未対応** | `tasks.md` の 4.1 も `deviation.md` も変わっていない。実装では決められない所見のため再掲にとどめる |
| 4 | host Suggestion | 実物のフリング結果 JSON は 4.4 待ちでよいが、配列形式の話が事実誤認だった旨を 1 行残す | **未対応** | `review-003.md` にしか残っていない。4.4 の証跡と合わせてで可 |
| 5 | host Suggestion | 倍率だけが変わったときに標本を捨てていない | **未対応** | `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:87-98`。前回「次に触るときで構わない」としたが、このサイクルで同ファイルに触れている → Suggestion 5 として再掲 |

後退 (前回まで満たしていたものが崩れた箇所) は見当たらない。ライブラリ全体は別環境でも 171 件 0 failures で、新テスト 2 本もそこに含まれる。

## 指摘事項

### [🟠 Major] deviation に「確定した事実」として記録された 2 点が、別環境で再現しない

**該当箇所**: `kasane/changes/performance-criteria-review/deviation.md:17`、`ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:14-18`、同 `:44-50` (テスト名を含む)、`ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:41-45`、`ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:106-109`

**問題点**:

計数が上界であるという結論そのものは、プローブで裏が取れた (上表 3)。問題は、その結論に添えられた**機構の説明が 2 つとも誤っている**ことである。deviation は「確定した事実」という強い見出しでこれを記録しており、このまま蒸留されると ADR / concepts に誤った機構の説明が残る。

1. **「compositional layout の解き直しは `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` を経由しない (差し替えたレイアウトで 1 度も呼ばれない)」は誤り**。`UICollectionViewCompositionalLayout` を `init(sectionProvider:)` で派生させて数えると、自己サイズ 1 回につき 1 回呼ばれる (完全一致のとき 22 回 / 不一致のとき 44 回)。`invalidateLayout(with:)` の回数も 2 回 / 9 回と連動する。iPhone 16e / 26.1 と iPhone 17e / 26.5 の両方で同じ。
   この誤りは、新テストが「測定回数」という間接指標を選んだ理由そのものであり (doc コメント `:14-18`)、同時に **同じ change 内の `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:11-13` と真っ向から矛盾する** — そちらは同じメソッドを再解決の機構として引いている (そして、そちらが正しい)。ファイル単独で読んだときにどちらを信じればよいか決まらない。

2. **「最下位桁の差では解き直しが起きず、1 画素未満 (0.2 pt) でも実寸の差があれば起きる」→「一致と見なしてよい幅は最下位桁の丸め誤差まで」は、2 点の観測からの外挿として誤り**。実際の境界は画面のピクセル格子への丸め (半画素) にあり、**0.1 pt (0.3 画素) の差では解き直しは起きない**。テスト名 `test1ピクセル未満でも実寸の差があれば解き直しが起きる` と `:47-48` のコメント (「一致と見なしてよい幅は『画面の画素』ではなく『最下位桁の丸め誤差』までである」) は、0.2 pt という 1 点だけを根拠に一般化している。`KsEstimatedHeightTests.swift:106-109` のテスト名とコメント (「画面の 1 ピクセルに満たない差でも解き直しは起こるため」) も同じ一般化を写している。
   なお `deviation.md:18` の「当初の『1 画素未満なら一致』では 0.2 pt の差を一致に数えてしまい上界にならない」は**正しい** (0.2 pt = 0.6 画素は 1 画素未満だが解き直しが起きる)。誤っているのは、そこから「境界は最下位桁」と結論した部分である。1e-9 の採用は境界の十分内側で安全側なので、**値を変える必要はない**。

**推奨修正**: 挙動は変えず、記録と説明を観測に合わせる。

1. `deviation.md:17` の「経由しない」を削除し、観測どおりに書き直す (「自己サイズ 1 回につき 1 回呼ばれる。測定回数は解き直しが起きたときにだけ倍増するので、そちらを指標にした」)。再現に使った Simulator の機種・OS は現行どおり併記する
2. 「一致と見なしてよい幅」の記述を「画面のピクセル格子への丸め (半画素) が境界であり、1e-9 はその十分内側に置いた保守的な値」に直す。`KsLayoutDiagnostics.swift:43-44` の「画面の 1 ピクセルに満たない差 (倍率 3 で 0.2 pt) でも解き直しは起こる」も、0.2 pt が半画素を超えているから起こる、という形にすると誤読が消える
3. `KsEstimatedHeight.swift:11-13` と `KsSelfSizingInvalidationTests.swift:14-18` の矛盾を解消する (1 を直せば `KsEstimatedHeight` 側の説明が正になる)
4. 量子化した値を返さない理由 (`deviation.md:16`) を、観測に合った理由に置き換える: 半画素の差は**解き直しを起こさないまま渡した推定値のまま行が積まれる**ため、合計高さに全行ぶん積み上がる (上表 4。+0.1 pt で 60 行 6 pt、10,000 件なら 1,600 pt 規模)

### [🟡 Minor] 確定テストが、実際に使っている許容幅 (1e-9) を固定していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:20-60`、`ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:45`、`ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:106-115`

**問題点**: 新テストが比べているのは「完全一致」と「1 ULP 違い」「0.2 pt 違い」の 3 点だけで、`matchTolerance` の値には触れていない。実際の境界は半画素なので、`matchTolerance` を 0.1 pt に緩めても両テストとも緑のままである。`KsEstimatedHeightTests.swift:110-114` も `nextUp` / +0.2 / +1/3 を見るだけで、定数を固定していない。つまり「その幅では解き直しが起きないことを `KsSelfSizingInvalidationTests` で確かめている」(`KsLayoutDiagnostics.swift:8-10`、`KsCollectionEngineTests.swift:796-798`) という主張と、テストが実際に固定している範囲がずれている。

**推奨修正**: 観測を `matchTolerance` に結び付ける 1 件を足す。たとえば「`matchTolerance` の直下 (0.9 × `matchTolerance`) の差では測定回数が増えない」ことと、「解き直しが起きる最小の差として観測した 0.2 pt は `matchTolerance` より大きい」ことを同じテストで固定すれば、定数を緩めたときに落ちる。プローブでは +9e-10 / +1e-8 / +0.001 / +0.1 のいずれも測定回数 22 回のままだったので、上側の対照は 0.2 pt のままでよい。

### [🟡 Minor] 混在 fixture の参考値が、テストのコメント側では条件なしのまま

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:923-925`

**問題点**: `deviation.md:3` には採取環境 (iPhone 17 Pro Max Simulator / iOS 26.0) と測り方 (全件を刻んで走査する当時の計測形・校正後は未再採取) が入ったが、同じ数値 (最頻値で誤差 34.5% / 変化 134 回、平均で 12.0% / 134 回) を写したテストのコメントは条件なしのままである。この数値は「Scenario の GIVEN を読み替える」判断の土台であり、`kasane/lessons/inbox/report-device-and-os-with-layout-numeric-tests.md` が本 change で捕捉したばかりの規律 (レイアウトの数値には機種・OS を併記する) の対象そのもの。コメントだけを読んだ人は、校正前の計測形で採った値だと分からない。

**推奨修正**: 数値の直後に機種・OS・測り方を 1 行で添える (`comment-policy` は作業文書のパス参照を禁じているので、deviation を指す形ではなくコメント内で自己完結させる)。

### [🔵 Suggestion] 確定テストが本番の組み立て経路を通っていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift:81-128`

**問題点**: このテストは `UICollectionView` とレイアウトを手で組み立てており、`KsCollectionViewController` が実際に作るレイアウト (セパレータ・inset・list / grid の分岐を含む) は通っていない。確定させたいのが UIKit 側の一般的な挙動である以上この作りは妥当だが、Major 1 のとおり「差し替えたレイアウトでの観測」は一度外している。本番のレイアウトで同じ境界になることは確認されていない。

**推奨修正**: doc コメントに「本番のレイアウト定義ではなく、同等の最小構成で UIKit の挙動を確かめている」ことを明記する。あるいは `KsCollectionViewController` を通した構成で同じ 2 点 (最下位桁 / 0.2 pt) を確かめれば、前提の置き方ごと解消できる。

### [🔵 Suggestion] 画面の倍率だけが変わったときに標本を捨てていない (再掲)

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:87-98`

**問題点**: `review-003.md` で「次に `KsEstimatedHeight` へ触るときで構わない」とした指摘だが、このサイクルで同ファイルに触れており、条件は満たされた。標本を捨てるのは幅が変わったときだけで、`scale` が変わっても前の倍率の格子で数えた `grid` が残るため、格子が混ざると最頻値の意味が崩れる。

**推奨修正**: 幅と同じ扱いで倍率の変化でも捨てる (`record` の 1 行)。実害の想定される経路は今のところ無いため、優先度は低いまま。

### [🔵 Suggestion] 4.4 で回収する記録 (再掲)

**該当箇所**: `samples/android/benchmark/scripts/testdata/`、`kasane/changes/performance-criteria-review/tasks.md` の 4.4

**問題点**: 実物のフリング結果 JSON を通す回帰テストと、`review-002.md` の「実物の `sampledMetrics` は配列」が事実誤認だった旨の訂正は、どちらも未着手のまま。4.4 まで実物が存在しないので今は手当て不要という判断は変わらない。

**推奨修正**: 4.4 で最初のフリング結果が出たら `scripts/testdata/` に 1 本残して回帰テストを足し、あわせて訂正を 1 行残す。

## アクションプラン

1. **Major 1** — `deviation.md:17` の「確定した事実」を観測に合わせて書き直し、`KsSelfSizingInvalidationTests` / `KsLayoutDiagnostics` / `KsEstimatedHeight` の説明の矛盾を解消する。実装の挙動と 1e-9 の値は変更不要
2. **Minor 2** — 許容幅 `matchTolerance` を固定するケースを新テストに 1 件足す
3. **Minor 3** — 混在 fixture の参考値に機種・OS・測り方をコメント内で自己完結する形で添える
4. **所見 (3')** — 本番 fixture の見積もり悪化を承知でハイブリッドへ進まない判断を、4.1 の証跡か deviation に明示する (実装では決められないためオーナー判断)
5. **Suggestion 4 / 5 / 6** — テストの前提の明記は Major 1 と同時に、倍率の破棄と 4.4 の記録はそれぞれの機会に
