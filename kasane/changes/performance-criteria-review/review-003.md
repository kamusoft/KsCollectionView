# レビュー結果: performance-criteria-review (003 回目)

**日付**: 2026-09-15
**判定**: CHANGES_REQUESTED

## サマリー

前回 (`review-002.md` と `second-opinion-code-002.md` の突き合わせ表) で採用された 6 件は、**4 件が解消、2 件が部分解消**。最大の懸案だった Critical 1 (合計高さの再検証テストが環境依存で落ちる) は、deviation に記録された校正 (一様配列への読み替え・解析値との比較・0.1% 超の変化だけを数える) の上で解消しており、ホストが使っていない 6 番目の環境 (iPhone 17e / iOS 26.4) でもライブラリ 169 件が 0 failures で通った。退行の対照も自前プローブで再現でき、推定を固定値に潰すと同じテストが落ちることを確認した。

一方で、**部分解消とした相方 Major 1 (量子化した一致判定) の核心が残っている**。一致の判定は「量子化後の比較」から「差そのものが 1 ピクセル未満なら一致」に変わったが、`KsLayoutDiagnostics` の説明・エンジンテストのコメント・design Decision 2 はこの計数を「レイアウトの解き直しが起こりうる回数の**上界**」として扱い続けている。自前プローブで同じ fixture を厳密比較 (`measured == original`) で数え直すと不一致率は **0.100 → 0.825** になり、上界の主張は 8 倍外れる。差の内訳は「完全一致 1,754 / 差 1e-9 未満 7,340 / 1 ピクセル以上 1,014」で、1e-9〜1 ピクセルの間の差は 1 件も無い — つまり食い違いは実寸の差ではなく浮動小数の最下位桁だが、UIKit が最下位桁の差を無視するかは未検証のままである。グループ 4.1 の主指標がこの計数なので、判定に入る前に整理が要ると考え CHANGES_REQUESTED とする。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `kasane/handbook/cross/comment-policy.md` | always |
| `kasane/handbook/cross/test-execution.md` | テストを実行する・テスト結果を報告する |
| `kasane/handbook/cross/runtime-behavior-verification.md` | 実行時挙動の検証・完了判定 |
| `kasane/handbook/cross/sample-parity.md` | `samples/**` を触る |
| `kasane/handbook/cross/scroll-performance-gate.md` (本 change の成果物) | スクロール性能の完了判定・証跡 |
| `kasane/handbook/ios/performance-verification.md` / `kasane/handbook/android/performance-verification.md` (同上) | 各 platform の計測手順 |
| `kasane/decisions/cross/0006-perceived-smoothness-as-performance-gate.md` (proposed) | 参照のみ。proposed のため指摘の根拠にしていない |

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox の code-review 系 (証跡の自前再現 / テストが本番経路を通っているか / 兄弟契約の確認) と、本 change で捕捉された 2 本 (機種・OS の併記 / 基準値の fixture 追跡) を観点に加えた。

## 再現した検証

ホストとは別の環境で回した (iOS は前回レビューで使った 5 機種とも別の iPhone 17e / iOS 26.4)。

| 対象 | 実行 | 結果 |
|---|---|---|
| iOS ライブラリ | `xcodebuild test -scheme KsCollectionView` (iPhone 17e / iOS 26.4) | **Executed 169 tests, with 0 failures** |
| 2.4 のテストの実測値 | 同上の出力 | 初回 72,773.3 / 解析値 72,666.7 / 誤差 **0.147%** / 0.1% 超 **2 回** / 0.1% 以下 1 回 (基準 ±5% と 3 回を満たす) |
| 計測スキーム | `xcodebuild build-for-testing -scheme KsCollectionViewSamplesPerformance` (TestAction = Release) | **TEST BUILD SUCCEEDED** |
| Android Sample | `./gradlew :app:testDebugUnitTest --rerun-tasks` → XML 集計 | 32 tests / 0 failures / 0 errors (7 クラス) |
| 事後検証スクリプト | `python3 -m unittest discover -s samples/android/benchmark/scripts` | 26 tests OK |
| lint | `local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py --advisory` | 0 / 0 / 禁止 0 件・要確認 14 件 (14 件はいずれも本 change の diff 外) |

### プローブ (作業ツリーには触れず、`ios/` の複製に手を入れて実行。いずれも iPhone 17e / iOS 26.4)

| プローブ | 結果 |
|---|---|
| 推定を固定 44pt に潰した対照 | 誤差 **20.99%** (初回 87,920 / 解析値 72,666.7) で 2.4 のテストが落ちる。deviation の「iPhone 17 で 20.96% / 17 Pro Max で 20.95%」を別環境で再現 |
| 推定を固定 20pt に潰した対照 | 誤差 **44.08%**、0.1% 超の変化 **4 回** で 2 つのアサーションとも落ちる |
| 不一致率を厳密比較で数え直す | 自己サイズ 9,495 件 / 不一致 **7,829** 件 / 率 **0.825** (現行の許容つき判定では 950 件 / 0.100) |
| 差の大きさの分布 | 完全一致 1,754 / 差 1e-9 未満 **7,340** / 0.01 以上 1 ピクセル未満 **0** / 1 ピクセル以上 1,014 |

対照の 2 本から分かること: 校正後の「0.1% 超の変化 3 回以下」は**推定が小さすぎて段階的に伸びる破綻**では効く (20pt で 4 回) が、**推定が大きすぎる破綻**では 0 回にしかならず (44pt)、その場合に破綻を捕まえているのは誤差 ±5% のアサーションだけである。deviation の「校正後も捕まえられる」は成立しているが、担保しているのは 2 つの基準のうち片方だけという読み方になる。

## 前回指摘の解消状況

`review-002.md` の指摘と `second-opinion-code-002.md` 末尾の突き合わせ表で採用された全件。

| # | 出所 | 指摘 | 判定 | 該当箇所 |
|---|---|---|---|---|
| 1 | host Critical | 2.4 のテストが Simulator 3/5 で決定的に失敗し、完了印と実態が食い違う | **解消** | `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:925` が一様配列 (1 列) の fixture に変わり、合計高さを「最頻の行高 × 件数」の解析値で持ち、変化回数は合計の 0.1% 超だけを数える。読み替えと校正は `deviation.md` に 5 機種の実測表つきで記録済み。6 番目の環境でも通過 (上表) |
| 2 | host Major | `MeasurementRoundTripCountingTest` の assert が順序を固定しない | **解消** | `samples/android/app/src/testDebug/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementRoundTripCountingTest.kt:55-60`。テンプレート内の `DisposableEffect` で独立に数えた「載っている項目数」と `MeasurementLifetime.alive` の**一致**を要求する形になり、数え直しが効果の段階へ戻れば (子の効果が先に走るため) 両者がずれて落ちる |
| 3 | host Minor | 実物の結果 JSON がフリング判定の指標の容器を通っていない | **部分解消** | `samples/android/benchmark/scripts/test_verify_fling_results.py:114-165` の `real_shaped_benchmark` / `real_context` が実物の入れ物 (`context` と `benchmarks[]` のキー構成) をひな型にし、合格・不合格・未判定の 3 経路がその形を通るようになった。ただし `frameDurationCpuMs` がどちらの容器に入るかは依然として仮定 (実物のフリング結果はグループ 4.4 まで存在しない)。→ Suggestion 4 |
| 4 | host Suggestion | 機種 / OS の併記を規律として捕捉する | **対応** | `kasane/lessons/inbox/report-device-and-os-with-layout-numeric-tests.md` (scope: impl) として起票済み |
| 5 | 相方 Major | 量子化した高さの一致を「レイアウト再解決なし」とみなし、計数が上界にならない | **部分解消** | 比較は `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:49-64` で「差そのものが 1 ピクセル未満」に変わり (deviation 記録済み)、`KsCollectionEngineTests.swift:835` が「渡された高さと比べる」ことを固定した。しかし「上界」という位置づけは変わっておらず、厳密比較との差は 8 倍ある。→ Major 1 |
| 6 | 相方 Major | 計測スキームの TestAction が Debug で spec の Release 要求と不一致 | **解消** | `samples/ios/KsCollectionViewSamples.xcodeproj/xcshareddata/xcschemes/KsCollectionViewSamplesPerformance.xcscheme:27` と `:53` が Release。`LargeDataCountUITests` を計測スキームの除外に追加。Release の build-for-testing が成立することも確認した (上表) |

後退 (前回まで満たしていたものが崩れた箇所) は見当たらない。

## 指摘事項

### [🟠 Major] 不一致率の「上界」という位置づけが、実測と 8 倍食い違ったまま残っている

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:5-7`、同 `:49-64`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:795-797`、`kasane/changes/performance-criteria-review/design.md` の Decision 2 (基準 1 の根拠)

**問題点**:

一致の判定は「差が画面の 1 ピクセル未満なら一致」になった (`deviation.md` に記録済みの合意事項であり、この判定規則そのものを違反として指摘するものではない)。問題は、その計数に付いている**説明**が変わっていないことである。

- `KsLayoutDiagnostics.swift:6-7`: 「この計数はその『違った回数』の**上界**を与えるもの」
- `KsCollectionEngineTests.swift:796`: 「不一致率は解き直しが起こりうる回数の**上界**であり」
- design Decision 2 の代替案: 「セル側の不一致回数が呼出回数の**上界**になるのでそれで代替」

同じ fixture (高さ 2 種類 6 : 1 の 2,000 件) を厳密比較 (`measured == original`) で数え直すと、不一致は 950 件 → **7,829 件**、率は 0.100 → **0.825** になる。差の内訳は「完全一致 1,754 / 差 1e-9 未満 7,340 / 1 ピクセル以上 1,014」で、**1e-9 と 1 ピクセルの間の差は 1 件も無い**。つまり許容幅が実寸の差を隠しているのではなく、隠れているのは浮動小数の最下位桁の差だけである。

ここから 2 つのことが言える。

1. UIKit がその最下位桁の差を無視するなら計数は妥当だが、その場合 deviation が「量子化した値を返さない」理由として挙げた「量子化した値はセルが返す高さと最下位桁で食い違うから完全一致にならない」は、**実測値を返しても 77% が完全一致していない** (7,340 / 9,495) 以上、成立していない
2. UIKit が最下位桁の差で invalidate するなら、この計数は解き直しの回数を 8 倍**過少**に報告しており、「0.20 以下」は上界としての意味を持たない

どちらであるかは今の成果物からは判別できない。グループ 4.1 は不一致率を主指標にして最頻値化の効果を判定するため (design Decision 2)、この未確定のまま判定に入ると「主指標は合格だが解き直しは減っていない」を見分けられない。

**推奨修正**: 次のいずれかで、計数と現象の結び付きを成果物の中で確定させる。

1. 最下位桁の差で解き直しが起きるかを直接確かめる (例: エンジンテストで、推定と同じ高さに測られるセルだけを可視化したときにレイアウトの再解決が起きないことを、`invalidateLayout` を数えるテスト用のレイアウト差し替えか contentSize の再計算回数で観測する)。結び付きが確認できたら、その根拠をコメントに書いて「上界」の語を残す
2. 確かめられないなら、`KsLayoutDiagnostics.swift:5-7` と `KsCollectionEngineTests.swift:795-797` から「上界」の主張を落とし、「1 ピクセル以上ずれたセルの割合」という観測どおりの説明に直したうえで、`deviation.md` に「この計数は解き直し回数の上界ではない」ことと 4.1 の判定での扱い (占有率との併読) を追記する

なお 1 ピクセル以上ずれたセルは 1,014 件 = 0.107 で、許容つきの実測 0.100 とほぼ一致する。少数派 (1/7 ≈ 0.14) に対する基準 0.20 の位置づけ自体は、この読み方でも変わらない。

### [🟡 Minor] 計測ドライバに画像グリッドの自動駆動が残り、spec の「メモリの自動往復だけを持つ」と食い違う

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:19`、`kasane/changes/performance-criteria-review/specs/samples/spec.md` の Requirement「iOS の計測ドライバの構成」

**問題点**:

spec は「iOS Sample の計測ドライバは、メモリの自動往復 (…) **だけを持つ** (SHALL)」と書いている。tasks 2.6 の対象だった自動フリック 2 本と `ScrollWindowSignpost` は削除されているが (HEAD では 4 本 → 現在 2 本)、`test画像グリッドで基準点を切り送って戻す` が残っている。これは image-loading の「戻ってきたときの再表示」を観測するための駆動で、滑らかさの計測ではないが、`drag(_:times:forward:)` で自動的にスクロールを駆動する点は同じであり、「だけを持つ」の文言には収まらない。`deviation.md` にも記録が無い。

計測スキームは `InteractiveControlUITests` と `LargeDataCountUITests` だけを除外するため、スキームを素直に実行するとこの駆動も走る。

**推奨修正**: どちらかを選んで揃える。(a) この駆動が image-loading の観測手順として現役なら、`deviation.md` に「滑らかさの駆動ではない観測用の駆動は残す」ことを理由つきで記録し、`PerformanceDriverUITests` の doc コメントにもその区別を書く。(b) 現役でないなら 2.6 と同じ理由 (使われない足場を残さない) で退役させる。**spec の文言そのものの是非はレビューでは決められないため、(a) を採るなら合意の所在を deviation に残すことを求める。**

### [🟡 Minor] 混在 fixture の数値に採取環境が無く、この change で捕捉した規律に反している

**該当箇所**: `kasane/changes/performance-criteria-review/deviation.md:3`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:920-924`

**問題点**:

一様配列の実測は 5 機種の表になり、不一致率 0.158 にも機種・OS が付いた。一方で、**読み替えの根拠になっている混在 2 列グリッドの数値** — 「平均 (12.0% / 134 回) でも最頻値 (34.5% / 134 回) でも基準を満たさない」 — には機種・OS も測り方も書かれていない。同じ文がテストのコメント (`:920-924`) にも参考値として写されている。

この数値は「Scenario の GIVEN を読み替える」という判断の土台であり、かつ本 change が `kasane/lessons/inbox/report-device-and-os-with-layout-numeric-tests.md` として捕捉したばかりの規律 (レイアウトの数値には機種・OS を併記する / 1 機種の緑を根拠に deviation へ書かない) の対象そのものである。手元のプローブでも、混在 fixture の数値は測り方 (全件を刻んで走査するか、末尾へ 1 回で送るか) で大きく変わることを確認した。

**推奨修正**: 混在 fixture の 12.0% / 34.5% / 134 回にも、採取した機種・OS・件数・窓・測り方 (走査の形) を併記する。テストのコメント側は、数値を写すのをやめて deviation を指すだけにするか、同じ条件を 1 行で添える。

**あわせての所見 (実装では決められない)**: 読み替えの結果、**本番 fixture (Sample「大量件数」= 混在 2 列) での合計高さの見積もりは、どのテストの対象でもなくなった**。deviation が記録する数値をそのまま読むと、最頻値化はこの fixture で平均より悪い (12.0% → 34.5%)。design の Risks は「合計高さの見積もりが崩れたら Decision 1 の代替 (ハイブリッド) へ」としているので、4.1 の判定または蒸留で「本番 fixture の見積もりの悪化を承知のうえでハイブリッドへ進まない」ことを明示的に記録しておかないと、後から見たときに検討漏れと区別が付かない。

### [🔵 Suggestion] 実物のフリング結果 JSON は 4.4 待ちのままでよいが、記録を 1 つ訂正しておきたい

**該当箇所**: `samples/android/benchmark/scripts/testdata/memory-benchmarkData.json:69`、`review-002.md` の Minor 3

**問題点**: `review-002.md` は「実物の `sampledMetrics` は `[]` (配列)」を根拠に `metric_of` の配列対応を勧めていたが、実物は `"sampledMetrics": {}` (空の辞書) である。`metric_of` の辞書のみの探索は実物と食い違っていない。現状の `frame_counts_of` は標本の並びにも対応しており、4.4 で実物のフリング結果が出るまでこれ以上の手当ては不要と考える。

**推奨修正**: 4.4 で最初のフリング結果が出たら `scripts/testdata/` に 1 本残して回帰テストを足す (前回と同じ)。あわせて、次のレビュー・蒸留が古い記述を引き継がないよう、配列形式の話が事実誤認だったことを `deviation.md` か 4.4 の証跡のどこかに 1 行残す。

### [🔵 Suggestion] 画面の倍率だけが変わったときに標本を捨てていない

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:85-96`

**問題点**: 標本を捨てるのは幅が変わったときだけで、`scale` が変わっても前の倍率の格子で数えた標本が残る。別倍率の画面へ移す経路 (外部ディスプレイ) は今のところ Sample にも無く実害は想定しにくいが、格子が混ざると最頻値の意味が崩れる。

**推奨修正**: 幅と同じ扱いで倍率の変化でも捨てる (1 行)。優先度は低く、次に `KsEstimatedHeight` へ触るときで構わない。

## アクションプラン

1. **Major 1** — 不一致率と実際の解き直しの結び付きを確定させる。確かめられないなら「上界」の主張を落とし、4.1 の判定での扱い (占有率との併読) を deviation に書く。グループ 4.1 に入る前提
2. **Minor 2** — 画像グリッドの駆動を残すなら deviation に記録、残さないなら退役
3. **Minor 3** — 混在 fixture の数値に採取環境と測り方を併記。本番 fixture の見積もり悪化を承知で進む判断を 4.1 / 蒸留で明示
4. **Suggestion 4 / 5** — 4.4 の実物 JSON の回収時にまとめて。倍率変化の破棄は次に触るときで可
