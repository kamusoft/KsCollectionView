# レビュー結果: performance-criteria-review (008 回目)

**日付**: 2026-09-16
**判定**: APPROVED

## サマリー

review-007 の修正サイクルを再確認した。Major 1 件・Minor 3 件・Suggestion 1 件が解消し、残る Suggestion 1 件は review-007 自身が 7.3 送りとしたものなので未着手で妥当。とくに Major (塊の件数が変わる更新で ios/ADR-0006 の可視セル再構成が落ちる) は、早期 return と再構成を分離する形で直され、**修正前なら落ちる形の回帰テスト**が付いている — 項目数が塊の件数以下 (snapshot が組み直しても同一になる) の系を含めているため、差分適用の副作用で偶然緑になる逃げ道が塞がっている。

新規の指摘は Minor 1 件・Suggestion 2 件で、いずれも 6.3 の実機計測を妨げない。Minor は「Sample の通し番号変換を本体へ寄せた」修正の副作用として、Release 構成にも載る `@_spi(KsMeasurement)` の公開宣言が 1 型増えたこと (design / deviation に記録が無く、表面が必要より広い) である。**6.3 の計測は現状のビルドで進めてよい** と判断する。

テストはレビュアー側でも独立に実行した (ホストとは別の機種・OS):

| 実行 | 環境 | 結果 |
|---|---|---|
| 全件 (絞り込みなし、Debug) | iPhone 17 Pro Max Simulator / iOS 26.4.1 | **184 tests / 0 failures** |
| `KsCollectionEngineTests` | iPad Simulator (11-inch, @2x) / iOS 26.5 | 52 tests / 0 failures |
| `KsSectionChunkingTests` | 同上 | 8 tests / 0 failures |

塊の構造を数値で固定する新規テスト (section ごとの件数列) は画面サイズ・倍率の異なる機種でも決定的に通る (テスト側が窓を 390x844 に固定しているため機種非依存。lessons `report-device-and-os-with-layout-numeric-tests` の要求を満たす)。lint は comment-policy (禁止 0 件 / 要確認 14 件はすべて本 diff 外の既存分)・local-path・identity とも違反 0。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| cross/comment-policy.md | **常時** (全ソースコード) | 適用。新規・改訂コメントに作業文書パス・通番・仮称・履歴記述・SHALL 等の混入なし。`apply` 内の `ios/ADR-0006` 参照は非公開メソッドの実装側コメントで許容形式。`KsItemOffsetLookup` の公開 doc コメントには ADR・change・デルタスペック由来の語が無い (ただし内部構造の説明が入っている点は Minor 1 で扱う) |
| cross/test-execution.md | テストを実行するとき・テスト結果を報告するとき | 適用。絞り込みなしの全件実行で件数 (184 tests / 0 failures) を確認。新規テストの待機はすべて既存の `waitUntil` (実時間 deadline + 実行機会の譲り + 失敗時の実測値付きメッセージ) に乗っており、固定時間待機の追加は無い |
| cross/sample-parity.md | `samples/**` を触るとき | 適用。変更は通過記録の数え方と import 修飾だけで、画面・文言・デモデータ・DSL 引数はいずれも不変。Android 側に追随の要る差分は生じていない |
| cross/public-identifiers.md | 公開識別子・配布座標を決めるとき | 適用。新設の型名は `Ks` 接頭辞の PascalCase で既存の規則どおり。SwiftPM の package / product 構成は不変 |
| ios/performance-verification.md | iOS エンジンの描画・再利用・レイアウト経路に触れるとき・大量件数を扱う変更の完了を判定するとき | 本スライスは計測も完了判定も行わないため未発火 (6.3 / 9 系で発火する) |
| cross/scroll-performance-gate.md | 性能の完了を判定するとき・手動フリック計測・性能の証跡 | 同上、未発火 |
| cross/runtime-behavior-verification.md | 実行時挙動の不具合調査・不具合修正の完了判定 | 塊の境界の見た目は 7.1・7.2 の責務として残る (review-007 の所見のまま)。本 diff は不具合修正ではないため未発火 |
| cross/local-development-setup.md | 環境構築・Sample の起動 | 該当なし |

lessons は昇格済みルール (`kasane/lessons/<scope>.md`) が未生成のため `kasane/lessons/inbox/` を参照した。`review-inclusive-requirement-on-all-paths` (包含条件の外側の経路も検査する) を Major の再確認に、`check-tests-exercise-production-path-before-accepting-green` (テストが本番と同じ経路か) を回帰テストの評価に、`report-device-and-os-with-layout-numeric-tests` を数値アサーションの機種依存確認に、`do-not-run-review-and-verify-on-same-simulator` を実行機種の選択に適用した。

## review-007 の指摘の解消状況

| # | 指摘 | 状態 | 根拠 |
|---|---|---|---|
| 🟠 Major | 塊の件数が変わる更新で同値配列の可視セル再構成 (ios/ADR-0006) が落ちる | **解消** | `KsCollectionViewController.swift:442-453` で `itemsAreEqual` の判定と早期 return を分離し、塊の件数が変わって後段へ落ちる場合も `reconfigureVisibleCells(rebuildingContent:)` を必ず通す。回帰テスト `KsCollectionEngineTests.swift:868` が adaptive (幅 390 / 最小幅 120 → 3 列) で 2,000 件と 300 件の両方を通し、300 件側は組み直し後の snapshot が現在と同一になるため、差分適用ではなくこの再構成だけが可視セルを作り直す系になっている (修正前なら決定的に落ちる) |
| 🟡 Minor 1 | 塊の構造を固定するテストが list の 1 通りしかなく、layout → 塊の件数の配線が未検査 | **解消** | `KsCollectionEngineTests.swift:820` が list `[500,500,500,500]`・固定 3 列 `[501,501,501,497]`・向き別 (2,3) `[504,504,504,488]` を controller 経由の実 snapshot で固定。`:844` が adaptive の配線 (未解決 500 → 解決後 501) も固定。`currentChunkSize()` が 1 を返すような退行はこれで落ちる |
| 🟡 Minor 2 | Sample の通し番号変換がテスト側ヘルパと別実装で、どのテストも通らない | **解消 (方式変更)** | 変換規則を本体の `KsItemOffsetLookup` へ一本化。Sample (`PerformanceVerificationView.swift:232`) とテストヘルパ (`KsItemOffsetSupport.swift:32,38`) が同じ入口を通り、その入口自体を `KsCollectionEngineTests.swift:789-793,806-812` が直接アサートしている。写しは残っていない。ただし副作用として下記 Minor 1 (新規) が生じた |
| 🟡 Minor 3 | デルタスペックに lcm の縮退規則が無く、実装・ADR-0009 とずれている | **解消 (合意済み)** | `deviation.md` 末尾に記録済み。spec 本文の追随は蒸留時と明記されている |
| 🔵 Suggestion 1 | `maximumColumnMultiple = 2_000` の由来がコメントから読めない | **解消** | `KsSectionChunking.swift:13-15` に「1 つの塊に載せても滑らかさを保てた実測上の件数 (基準 500 件の 4 倍)」と、塊の件数が最小公倍数の倍数へ切り上がる関係まで書かれた。作業文書への参照を使わずに現在形で完結している |
| 🔵 Suggestion 2 | 解決列数の記録がレイアウト解決の副作用で、7.3 の検知経路と二重になりうる | **未解消 (意図的)** | `KsCollectionViewController.swift:592` は変わらず section provider 内で書いている。review-007 自身が「試作の段階で直す必要はない」「7.3 の設計時に決める」としたものなので、この判定では指摘に戻さない (下の Suggestion 2 として 7.3 への申し送りに残す) |

## 指摘事項

### [🟡 Minor] Release にも載る `@_spi` の公開宣言が 1 型増え、design / deviation に記録が無い

**該当箇所**: `ios/Sources/KsCollectionView/KsItemOffsetLookup.swift:1-15`・`:38-64`、`samples/ios/KsCollectionViewSamples/PerformanceVerificationView.swift:2`、`ios/Tests/KsCollectionViewTests/KsItemOffsetSupport.swift:4`

**問題点**:
Minor 2 の解き方として、通し番号の変換が本体へ移り `@_spi(KsMeasurement) public enum KsItemOffsetLookup` になった。写しが消えたのは良い解だが、次の 3 点が未整理のまま残っている。

1. **Release 構成にも載る**。既存の同じ SPI 群 `KsLayoutDiagnostics.swift:1,73` は `#if DEBUG` で囲われており、配布物に公開宣言が増えない形になっている。`KsItemOffsetLookup.swift:1` のガードは `#if canImport(UIKit)` なので Release にも載る。メモリ往復ドライバが Release 構成で走る (samples の Requirement「iOS の計測ドライバの構成」) 以上 `#if DEBUG` には置けないので、**前例と意図的に違う形**になっているが、その判断がどこにも書かれていない。
2. **表面が必要より広い**。Sample が使うのは `itemOffset(of:in:)` だけで、`indexPath(forItemOffset:)` (`:41-56`) と `totalItemCount(in:)` (`:59-64`) はテストターゲットからしか使われていない。同ターゲットの他ファイル (`KsCollectionEngineTests.swift:3`、`KsSelfSizingInvalidationTests.swift:4` 等) は `@testable import` を併用しており、`KsItemOffsetSupport.swift:4` も `@testable` にすれば internal のままで足りる。
3. **記録が無い**。design Decision 10 と ios/ADR-0009 は「塊の情報は `internal` に閉じ、公開 API・DSL・Android には現れない」と書き、spec の Requirement「配列の内部分割 (iOS)」も「塊の分け方は公開 API と利用者の宣言に現れない (SHALL NOT)」とする。塊の件数・塊の順番そのものは確かに internal のままなので厳密な違反ではないが、**公開 doc コメント (`:4-9`) が「配列を内部で複数のセクションに分けて載せるため」と内部構造を説明している**うえ、設計が想定していなかった配布面の変化なので、`deviation.md` に無いのは追えない。蒸留時に「なぜ計測用の入口が Release に 1 つ増えたのか」を再構成する羽目になる。

**推奨修正**:
コードの直しは (b) だけで足り、残りは記録で閉じる。

- (a) `deviation.md` に 1 行足す — 「計測ドライバが Release 構成で走るため、通し番号の変換だけは `#if DEBUG` に置けず `@_spi(KsMeasurement)` で Release にも載せる。塊の件数・塊の順番は internal のまま」。design Decision 10 の記述と食い違う点を明示する
- (b) SPI の表面を Sample が実際に使う `itemOffset(of:in:)` 1 本へ絞り、`indexPath(forItemOffset:)` / `totalItemCount(in:)` は internal へ落として `KsItemOffsetSupport.swift` を `@_spi(KsMeasurement) @testable import` にする
- (c) 公開 doc コメント (`:4-9`) から内部構造の説明を落とし、契約 (「画面に載っている項目を、先頭を 0 とする通し番号で数える」「範囲外は nil」) だけにする。comment-policy の「公開 doc コメントは機能と契約だけを書く」に沿う

6.3 の実機計測はこの指摘の影響を受けない (計測経路の挙動は変わらない) ため、計測を止める必要はない。7 系の着手までに閉じること。

### [🔵 Suggestion] 塊の組み直しがアニメーション付きの差分適用になる

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:147-153`・`:551`

**問題点**:
`update(configuration:)` は常に `animatingDifferences: true` で `apply` を呼ぶ。塊の件数が変わる組み直し (500 → 501 等) では、先頭の 1 塊を除くほぼ全項目が別のセクションへ移る差分になるため、10,000 件なら 1 万件規模の move / insert がアニメーション付きで適用される。adaptive の列数変化 (回転・Split View の幅変更) のたびに発火しうる経路で、Decision 12 が同時にアンカー復元も行う予定なので、アニメーションと復元が重なる。現時点では試作の範囲で観測可能な不具合は出ていないが、7.3 で組み直し経路を組むときに触る箇所である。

**推奨修正**: 7.3 で、**塊の件数の変化だけが理由の再適用は `animatingDifferences: false` で行う**ことを検討する (項目の増減は無いのでアニメーションに意味が無く、アンカー復元とも干渉しない)。試作の段階で直す必要はない。

### [🔵 Suggestion] 解決列数の「初回の確定」も組み直しの契機に要る (7.3 への申し送り)

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:435-436`・`:592`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:844`

**問題点**:
adaptive (および最小公倍数が縮退した向き別列数) では、初回の snapshot は `resolvedColumnCount` が未解決のため必ず倍数 1・塊 500 件で組まれる。最初のレイアウトパスで列数が 3 に確定しても、次の `apply` が届くまで塊は 500 件のままで、塊の境界に列数に満たない行が残る。新規テスト `:844` はこの挙動をそのまま固定している (`update` を明示に呼んで初めて 501 へ組み直る)。

design Decision 10 は「初回で未解決なら 1 で組み、**最初のレイアウトで列数が確定したとき** C が割り切れなければ組み直す」と書いており、組み直しの発火自体は Decision 12 (7.3) の責務なので試作の不足ではない。ただし Decision 12 の本文は「adaptive の列数**変化**を `viewDidLayoutSubviews` のコンテナサイズ変化で検知する」と書かれており、**コンテナサイズが一度も変わらない初回の確定 (nil → n) はこの条件から漏れる**。7.3 の実装でそのまま書くと、「adaptive で表示して一度も更新が届かない画面」が永続的に不完全な行を持つ。review-007 の Suggestion 2 (解決列数の記録経路をどちらに寄せるか) と同じ箇所の判断なので、併せて決めること。

**推奨修正**: 7.3 の設計時に、組み直しの契機を「コンテナサイズの変化」ではなく「`currentChunkSize()` の値の変化 (未解決からの確定を含む)」で定義する。試作の段階で直す必要はない。

## 次段に進むうえでの所見 (指摘ではない)

- **6.3 の計測は現状のビルドで進めてよい**。fixture「大量件数」は `.grid(columns: .fixed(2))` で `columnMultiple` が宣言列数 2 に確定し (`KsLayoutMetrics.swift:11-12` のとおり固定列数は clamp されない)、塊は 500 件・10,000 件で 20 塊 250 行ずつに均等に割れる。`resolvedColumnCount` に依存しないため `chunkSizeChanged` も発火せず、今回触れた分岐は一度も通らない。
- 境界の見た目 (`KsCollectionViewController.swift:363` の `indexPath.item == 0` による上線判定、塊ごとの内側余白・ヘッダー / フッター) は 7.1・7.2 のまま未実装で、500 件超のリストや余白・ヘッダーを宣言した配列では塊ごとに現れる。review-007 の所見と変わらない。
- テストに残る `IndexPath(item:section: 0)` の直書きは 3 箇所だけで、いずれも妥当: `KsCollectionEngineTests.swift:802` は「先頭の塊の末尾」を指す意図的な期待値、`:1822` は data source を介さない合成レイアウト属性、`:2204` は先頭 section のヘッダー属性 (7.2 でヘッダーを先頭の塊だけに付けるようになっても先頭は section 0 のまま)。
- `KsItemOffsetLookup.itemOffset(of:in:)` は先行セクションの件数を毎回積む O(セクション数) なので、Sample の走査は 1 段階あたり 可視セル数 × 塊数 (10,000 件なら約 20) の `numberOfItems(inSection:)` 呼び出しになる。メモリ往復の判定に影響する大きさではないため指摘にはしないが、9.3 の計測で走査が遅いと感じたら最初に見る箇所。

## アクションプラン

1. **Minor**: `KsItemOffsetLookup` の SPI 表面を `itemOffset(of:in:)` 1 本へ絞り、`deviation.md` に「計測が Release で走るため通し番号の変換だけ Release にも載せる」旨を記録する。公開 doc コメントは契約だけに絞る (7 系の着手までに)
2. **6.3 の実機計測は現状のビルドで進めてよい** — 上の所見のとおり、今回の分岐も 7.1・7.2 の不在も本 fixture では発火しない
3. **Suggestion 1・2**: 塊だけが変わる再適用のアニメーション無効化と、組み直しの契機を「塊の件数の変化 (未解決からの確定を含む)」で定義すること — どちらも 7.3 の設計時に決める
