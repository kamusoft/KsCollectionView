# レビュー結果: performance-criteria-review (001 回目)

**日付**: 2026-09-15
**判定**: CHANGES_REQUESTED

## サマリー

規約 3 本 (cross 新設 + platform 2 本の書き換え) は Decision 6 / 8 / 9 の意図どおりに書けており、証跡 4 本も 6 節の雛形へ揃っている。iOS の最頻値化 (`KsEstimatedHeight`)・Android の事後検証スクリプトはいずれも設計どおりで、ビルドとテストはホストとは別の Simulator / 別の実行でも全件通過した (iOS ライブラリ 165 件 0 失敗、Android Sample 31 件 0 失敗、スクリプト単体テスト 16 件 0 失敗、lint 3 本 禁止 0 件)。

一方で、**「検査したつもりで検査できていない」型の欠陥が 3 件**ある。(1) iOS の不一致率カウンタが Debug 構成でしか存在せず、同じ change の規約が定める計測構成 (Release) では読めないため、グループ 4 の主指標が取得できない。(2) Android の同時生存カウンタの数え直しが `LaunchedEffect` の中にあり、項目の `DisposableEffect` との実行順が保証されないため、`left == 0` の assert が構造的に成立しない可能性がある。(3) 実測値の上限を守ることを担保する唯一のテストが、最頻値化によって上限を外しても通る空テストになった。いずれも group 4 を走らせる前に潰すべきなので CHANGES_REQUESTED とする。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `handbook/cross/comment-policy.md` | always |
| `handbook/cross/test-execution.md` | テスト実行・テスト結果の報告 |
| `handbook/cross/runtime-behavior-verification.md` | 実行時挙動の検証・完了判定 |
| `handbook/cross/sample-parity.md` | `samples/**` を触る |
| `handbook/cross/scroll-performance-gate.md` (本 change の成果物) | 性能の完了判定・証跡 |
| `handbook/ios/performance-verification.md` / `handbook/android/performance-verification.md` (同上) | 各 platform の計測手順 |
| `decisions/cross/0006-perceived-smoothness-as-performance-gate.md` (proposed) | 参照のみ。proposed のため指摘の根拠にはしていない |

`kasane/lessons/` に昇格済み scope ファイルは無い。inbox の code-review 系 4 本 (証跡の自前再現 / テストが本番経路を通っているか / 包含条件の全経路 / 兄弟契約) を観点に加えた。

## 再現した検証

- iOS ライブラリ: `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone Air'` → **Executed 165 tests, with 0 failures**
- iOS Sample 通常スキーム: `-scheme KsCollectionViewSamples` を別の Simulator で実行 → **Executed 8 tests, with 0 failures**。`LargeDataCountUITests` の 3 件 (件数指定・0 指定・数値でない値) を含み、起動失敗を期待する 2 件も意図どおり通った
- Android Sample: `./gradlew :app:testDebugUnitTest --rerun-tasks` → XML 集計で **31 tests / 0 failures (6 クラス)**。`MeasurementLifetimeTest` 3 件を含む
- 事後検証スクリプト: `python3 -m unittest discover -s samples/android/benchmark/scripts` → **16 tests OK**
- lint: `comment-policy-lint.py --advisory` 禁止 0 件 / 要確認 14 件 (すべて本 change の diff 外)、`local-path-lint.py` / `identity-lint.py` とも違反 0
- `KsEstimatedHeight.value` の算法を写した自前 probe で、上限 32 件の適用有無を切り替えて比較 (指摘 3 の根拠)

## 指摘事項

### [🟠 Major] 不一致率のカウンタが Debug 構成にしか無く、本 change の規約が定める計測構成 (Release) では読めない

**該当箇所**: `ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:1`、`samples/ios/KsCollectionViewSamples/LargeDataMeasurementBar.swift:15`、`kasane/handbook/ios/performance-verification.md:34`

**問題点**:
`KsLayoutDiagnostics` と Sample の計数表示はどちらも `#if DEBUG` で囲まれている。一方、同じ change で書き直した `handbook/ios/performance-verification.md` は「基準機は iPhone 11 相当、**構成は Release**」(34 行目)、「Sample を **Release 構成**で基準機にインストールする」(38 行目) と定めている。Sample の Xcode プロジェクトは `SWIFT_ACTIVE_COMPILATION_CONDITIONS` を明示しておらず Xcode 既定に従うため、Release ビルドでは `DEBUG` が定義されず、この型も帯の計数も存在しない。

その結果、tasks 4.1 が証跡に残すことを求める 4 基準のうち主指標である**不一致率を、規約どおりの構成では端末から読み出せない**。加えて、書き直した iOS 規約の「取り出す数値」(50〜52 行目) には hitch 指標と time profile しか並んでおらず、不一致率をどこから取るかがどこにも書かれていない。規約だけを読んで 4.1 を実施する worker は、この数値に到達できない。

副次的に、仮に Debug 構成で計ることにした場合は `LargeDataMeasurementBar.swift:16` の `TimelineView(.periodic(from: .now, by: 1))` が計測窓の中で毎秒の再描画を起こす。本 change が「自動駆動は土俵を汚す」として退役させたものと同じ種類の汚染が、規模は小さいものの計測対象の画面に載ることになる。

**推奨修正**: 次のいずれかを採り、iOS 規約の「取り出す数値」に不一致率の取得源を明記する。
1. 計数を Release でも持てるようにし (起動引数で有効化するなど、`--large-count` 指定時だけ働く形)、帯の更新を周期タイマーではなく操作の区切り (タップ) で行う
2. 不一致率は Debug 構成の別実行で採り、占有率・体感は Release で採る 2 実行構成であることを規約に書き、「2 つの数値が同じ実行のものではない」ことを証跡の限界に残す規則も添える

### [🟠 Major] 同時生存カウンタの数え直しが項目の `DisposableEffect` より後になりうる (Android)

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:90`

**問題点**:
`MeasurementLifetime.reset()` は `LaunchedEffect(items, maxRoundTrips)` の本体 1 行目にある。一方 `MeasurementLifetime.enter()` は項目のテンプレート内 `DisposableEffect(item.id)` (同ファイル 196 行目) で呼ばれ、これは Lazy 系のサブコンポジション (layout フェーズ) で走る。`LaunchedEffect` の本体はディスパッチされたコルーチンで始まるため、両者の前後関係は Compose の契約として保証されていない。

初期可視分の N 項目が reset より先に `enter()` を済ませていた場合、reset で `invoked` / `disposed` が 0 に戻るため、その N 項目が後で破棄されるときの `leave()` だけが `disposed` に積まれる。`alive = invoked - disposed` は恒久的に N だけ小さくなり、離脱後は **負値**になる。`LargeDataMemoryBenchmark.kt:123` の `left == 0L` は成立し得ず、Scenario「配列の置換と画面離脱で保持が解放される」が常に落ちる (あるいは、漏れが N 件以下のときはその分を打ち消して見えなくする)。

同じファイルで画面内の集合は `remember(items) { ... }` (コンポジションフェーズ) で初期化しており、プロセス側のカウンタだけが実行順の保証の無い場所に置かれている点が非対称である。`MeasurementLifetimeTest` はカウンタ単体しか触らないため、この順序はどのテストでも通らない。

**推奨修正**: 数え直しを実行順の保証がある場所へ移す (例: `remember(items) { MeasurementLifetime.reset() }` のようにコンポジションフェーズで 1 回だけ行う)。あわせて、`alive` が負になったら 0 に丸めずそのまま失敗させる形を保ったうえで、`MemoryRoundTripScreen` を Robolectric で 1 本動かし、初期可視分が数え落とされないことを固定する。

### [🟠 Major] 実測値の上限を守ることを担保するテストが、最頻値化で空テストになった

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsEstimatedHeightTests.swift:104`

**問題点**:
`test保持上限を超えた分は古い実測値から捨てる` は、32 件の 10 を入れてから 32 件の 200 を入れ、`value == 200` を期待する。平均だった頃はこれで上限の適用を検出できたが、最頻値では上限を外しても検出できない。上限が効かず 64 件すべてが残ると 10 が 32 回・200 が 32 回の同数になり、`value` の「同数なら新しい方」の規則によって同じく 200 が返るためである。

`KsEstimatedHeight.value` の算法をそのまま写した probe で確認した結果:

```
上限が効いている場合: 200.0
上限を外した場合  : 200.0
```

`specs/collection-core/spec.md` の Requirement「大量件数での仮想化・再利用」は「推定高さの実測は項目単位ではなく**上限つきの固定長**で保持する (SHALL)」と定めており、このテストがその唯一の担保である。現状は緑のまま上限の退行を素通りさせる。

**推奨修正**: 古い値が多数派として残っていたら落ちる形にする。例えば上限いっぱいの 10 を入れた後に `sampleCapacity` より少ない件数 (例: 20 件) の 200 を入れ、`value == 200` を期待する (上限が効いていれば古い 10 は 12 件しか残らず 200 が最頻、効いていなければ 10 が 32 件で最頻になり落ちる)。もしくは `samples.count` を直接読める seam を足して件数そのものを固定する。

### [🟡 Minor] 「コレクションの破棄で全て解放される」のテストが Scenario の GIVEN を再現していない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:994`

**問題点**:
`specs/collection-core/spec.md` の Scenario「コレクションの破棄で全て解放される」の GIVEN は「2,000 件を**全件往復した**コレクションと、そのエンジンへの弱参照」である。テストは 2,000 件を用意するものの、`setContentOffset(y: bounds.height)` で 1 画面分だけ送って解放しており、全件往復 (再利用プールが埋まった状態) を作っていない。同じグループの `test配列の置換で同時生存セルが可視範囲の規模に戻る` は `advanceUntilVisible` で全件往復しているため、経路を弱めたのはこのテストだけである。

弱参照が nil になることの確認という主眼は満たされるが、GIVEN の読み替えは `deviation.md` に記録が無い (同ファイルに記録済みの読み替えは collection-layout の「合計高さ」1 件のみ)。

**推奨修正**: `advanceUntilVisible` で末尾まで送ってから解放するか、GIVEN を弱めた理由 (弱参照の消滅はセル生成数に依らない) を `deviation.md` に記録する。

### [🟡 Minor] 置換後の同時生存の上限が同じ実行の観測値 (peak) で、独立した上限になっていない (Android)

**該当箇所**: `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/LargeDataMemoryBenchmark.kt:121`、`kasane/handbook/android/performance-verification.md:105`

**問題点**:
assert は `replaced <= peak` で、`peak` は同じ走査中に観測した最大の同時生存である。置換で古い項目の保持が残る欠陥は検出できるが、`peak` 自身に上限が無いため「走査中からすでに同時生存が可視範囲 + 先読み分を超えていた」場合は素通りする。tasks 3.6 の「同時生存が可視範囲 + 先読み分を超えたら失敗」のうち、走査中の分は検査されていない。

規約側 (`performance-verification.md:105`) も「走査中に観測した最大の同時生存 (= その土俵の可視範囲 + 先読み分)」と、成立を前提にした等式を rule として書いている。iOS 側が `visibleCellCount * 4` という観測から独立した上限を使っているのと非対称である。

**推奨修正**: `peak` に独立した上限を与える (例: 結果画面の印に可視行数または可視項目数も載せ、`peak <= 可視項目数 × 係数` を assert する)。規約の括弧書きも「観測値をその代用とする」と、前提であることが分かる書き方にする。

### [🟡 Minor] 事後検証スクリプトが、別々の実行の結果をファイル指定で受け取れる

**該当箇所**: `samples/android/benchmark/scripts/verify-fling-results.py:14`、`samples/android/benchmark/scripts/test_verify_fling_results.py:177`

**問題点**:
`specs/samples/spec.md` の Requirement「性能計測の自動実行」は「計測結果は事後検証のスクリプトが**最新 1 実行の結果だけを読み**」「…複数実行の混在…はいずれも非 0 で終了する (SHALL)」と定める。実装はディレクトリを渡された場合だけ結果 JSON が 1 つであることを求め、ファイルを 2 つ並べて渡す経路は docstring で明示的に許している (`test_別々の実行でも環境が同じなら判定する` がその挙動を固定している)。

`environment_of` が見るのは機種・OS・fingerprint・`compilationMode` だけで、実行の時刻も対象アプリの版も見ない。したがって「同じ端末で、別の日に、別のコードで測った 2 つの結果」を突き合わせても合格になる。相対比較の土台としては危うい経路であり、`deviation.md` にも記録が無い。

**推奨修正**: 2 ファイル指定を残すなら、結果 JSON に含まれる実行の識別 (出力ディレクトリ名・タイムスタンプ等) を環境照合に足して「別実行と分かる場合は入力不正」にするか、片側ずつ測る運用を許す旨を spec の逸脱として `deviation.md` に記録する。

### [🟡 Minor] 事後検証スクリプトの単体テストが、実物の結果 JSON の形を一度も通っていない

**該当箇所**: `samples/android/benchmark/scripts/test_verify_fling_results.py:34`

**問題点**:
16 件すべてが `make_context` / `make_benchmark` の手書き JSON に対する検証で、実機で出力された `benchmarkData.json` (あるいはその sanitize 済みの抜粋) を通す経路が無い。`context.compilationMode`・`build.version.sdk`・`metrics` / `sampledMetrics` のどこに `frameCount` と `frameDurationCpuMs` が入るか、はすべて手書き側の仮定であり、実物と食い違っていてもテストは緑のままになる。食い違った場合の挙動は「入力不正で非 0」なので静かに緑になる危険は無いが、判定の要を担うスクリプトが初回実行まで一度も実物で確かめられない。

なお `context.compilationMode` は手書き fixture では常に両側に入るため、実物に同名のキーが無い場合 (両側 `None` で一致) にビルド構成の照合が無音で素通りすることも、このテストでは分からない。

**推奨修正**: グループ 4 で最初に実機計測したときの結果 JSON を `log-sanitize.py` に通して `evidence/` に 1 本残し、それを読む回帰テストを 1 件足す。

### [🔵 Suggestion] 不一致率のカウンタが controller とプロセス全体の 2 系統に重複している

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:64`、`ios/Sources/KsCollectionView/KsLayoutDiagnostics.swift:16`

`recordMeasuredSize` は同じ事実を controller のインスタンス変数とプロセス全体の `KsLayoutDiagnostics` の両方へ数えている。テストが実行間で汚れないためにインスタンス側が要る、Sample が読むためにプロセス側が要る、という理由は分かるが、2 つの数が食い違う余地が構造として残る (片方だけ `reset` された状態など)。プロセス側を単一の実体にして controller から参照だけを返す (Debug 構成で controller 生成時にプロセス側を数え直す) 形にすると、数の出所が 1 つになる。

あわせて、`KsLayoutDiagnostics` はライブラリに追加された初の Debug 限定 `public` 型である。Release には出ないため破壊的変更ではないが、Debug で本ライブラリを使う利用者には補完に現れる。意図した公開範囲かどうかをオーナーに確認しておくとよい。

### [🔵 Suggestion] 起動失敗の UI テストが XCTest の失敗文言 (`crashed`) に依存している

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/LargeDataCountUITests.swift:50`

`options.issueMatcher = { $0.compactDescription.contains("crashed") }` は、XCTest が起動失敗をどう表現するか (`crashed` / `Failed to launch` / `terminated`) に依存する。手元の再実行では 2 件とも意図どおり通ったが、文言が変わると `XCTExpectFailure` が strict なため「期待した失敗が起きていない」として落ちる。落ちる向きの壊れ方なので黙って緑にはならないが、`fatalError` のメッセージ自体 (`--large-count に正の整数以外が…`) を照合に含めておくと、意図した理由で止まったことまで固定できる。

### [🔵 Suggestion] 置換後の同時生存の待機が「完了条件そのもの」を見ていない

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:268`

`awaitStableAlive` は 200ms 間隔の 2 標本が同値になった時点で確定する。破棄が遅れて始まる区間ではまだ動く前の値で確定しうる。実時間の上限で区切り、超過時に実測値をそのまま返す点は `handbook/cross/test-execution.md` の「収束を待つアサーション」に沿っているが、判定に使う値なので「置換後に到達すべき水準」を条件として書けると強い (例: 置換前の項目の識別子が 1 つも生きていないことを識別子の集合で見る)。

## アクションプラン

1. **Major 1** — iOS の不一致率の取得経路を決め、`handbook/ios/performance-verification.md` の「取り出す数値」に書く。Debug 構成で採るなら帯の周期更新を止める。グループ 4 に入る前提条件
2. **Major 2** — `MeasurementLifetime.reset()` をコンポジションフェーズへ移し、初期可視分が数え落とされないことを 1 本のテストで固定する。これも 4.6 の前提条件
3. **Major 3** — `test保持上限を超えた分は古い実測値から捨てる` を、上限を外したら落ちる形に書き直す
4. **Minor 4・5・6・7** — 破棄テストの GIVEN (再現するか deviation に記録)、Android の `peak` の独立上限、スクリプトの別実行受け入れ、実物 JSON の回帰テスト。4 と 6 は記録だけでも可
5. **Suggestion** — 計数の一本化と `KsLayoutDiagnostics` の公開範囲の確認、起動失敗テストの照合強化、置換後の待機条件
