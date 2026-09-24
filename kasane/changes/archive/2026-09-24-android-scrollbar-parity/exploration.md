# Exploration: android-scrollbar-parity

## 課題 / 動機

Android の `KsCollectionView` ではスクロールバー (スクロールインジケータ) が表示されない。iOS は `UICollectionView` が標準で表示するため、同じ Sample「大量件数」を両基準機で並べるとスクロールバーの有無が違う。プラットフォーム間パリティの穴 (cross/ADR-0004 の観点)。

発見の文脈: `performance-criteria-review` の探索中、cross/ADR-0006 の手順で Pixel 4a の「大量件数」をオーナーが手動フリックした際に気づいた (2026-09-08)。性能とは無関係で、オーナー判断で別 change として起票。

### 現状 (2026-09-24 の探索で確認)

- **iOS**: インジケータ系のプロパティに一切触れておらず UIKit の既定のまま (スクロール中だけ出て消える・つまめない)。エンジンが設定するのは `backgroundColor` / `alwaysBounceVertical` / `delegate` / `prefetchDataSource` / `contentInsetAdjustmentBehavior = .never` だけ (`ios/Sources/KsCollectionView/KsCollectionViewController.swift:292-297`)。公開 DSL にも設定は無く、利用者が SwiftUI の `.scrollIndicators(.hidden)` を付けても、橋渡し (`ios/Sources/KsCollectionView/KsCollectionRepresentable.swift:10-15`) が environment を読まないため内側の `UICollectionView` に届かない。
- **iOS の高さの見積もり**: 測った行は実測、未測定の行は直近の実測の最頻値で見積もる (`ios/Sources/KsCollectionView/KsEstimatedHeight.swift`)。そのため iOS のインジケータも新しい行が測られるたびに長さ・位置が少しずつ動き、進むほど落ち着く。
- **Android**: `BoxWithConstraints(modifier = modifier)` の中に `LazyVerticalGrid(Modifier.fillMaxSize())` を置く構造で、`LazyGridState` はコンポーネント内部で所有 (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:142`, `:223`, `:258-264`)。バーを重ねる差し込み位置は `LazyVerticalGrid` の後ろ (`:348` 直後) で、同じスコープから gridState を参照できる。項目・header・footer のすべてに `ksAnimatedHeight` が掛かり、行の高さはばらつく前提。
- **Compose の能力**: 採用中の foundation 1.11.4 / material3 1.4.0 (`android/gradle/libs.versions.toml`) に描画まで担う公式のスクロールバーは無い。あるのは数値を読むための `ScrollIndicatorState` (`scrollOffset` / `contentSize` / `viewportSize`) と `LazyGridState.scrollIndicatorState` だけ (Gradle キャッシュの aar のクラス一覧・javap・文字列検索で確認。1.12.0 にも `Modifier.scrollIndicator` / `ScrollIndicatorFactory` は無い)。リリースノートには 1.11.0-alpha01 で `Modifier.scrollIndicator` を追加したとあるが、安定版には無く、取り下げられたと推測 (取り下げの記載は未発見)。
- **公式の推定の性質**: `LazyGridState` の `contentSize` は「総行数 × 可視行の平均高さ + 行間 + 前後の padding」、`scrollOffset` は「可視行の平均高さ × 先頭可視行の行番号 + 行内のずれ」。可視行の平均から全体を推すため、高さが混ざると長さが伸び縮みし、平均が変わった瞬間に位置が逆向きに戻ることがある。高さが揃った画面ではほぼ正確。

## 検討した選択肢 (却下案と理由を含む)

### 論点 1: ゴールと範囲

- **A: Android にだけ、iOS 既定と同じ「スクロール中だけ出て消える・つまめない」インジケータを出す。設定は足さない** — 採用
- B: A + 両方に表示 / 非表示の設定を足す (iOS の `.scrollIndicators(.hidden)` の穴も塞ぐ) — 却下。オーナー判断で非表示の選択肢は不要
- C: B + つまんで動かせるようにする — 却下。iOS 既定 (つまめない) とずれ、可変行高では指の位置 → 項目位置の対応が難しい

### 論点 2: Android の描画手段

- **1: ライブラリ内で自前で描く** — 採用。細い角丸のバーをスクロール中だけ出してフェードで消すだけで短く書け、利用者アプリに推移的な依存を持ち込まない
- 2: サードパーティ (nanihadesuka/LazyColumnScrollbar、MIT) に依存 — 却下。つまむ操作・設定の大半が使われず、依存が 1 つ増える。core/ADR-0012 が Coil に直接依存したのは画像ローダーそのものが製品価値だったためで、同じ理由は立たない
- 3: 公式の描画 API を待つ — 却下。1.11 系の安定版に無く、1.12 は compileSdk 37 を強いるため android/ADR-0002 により上げられない。取り下げられた可能性もある

### 論点 3: 可変行高での位置・長さの精度

- **a: 公式の数値 (`scrollIndicatorState`) をそのまま使い、高さの混ざる画面をオーナーが目視して、気になれば c へ進む** — 採用。インジケータは「だいたいの位置」を示すもので iOS も見積もりで動いており、困るかどうかは実物を見ないと決まらない
- b: 公式の数値 + 表示側で逆戻りを抑えてなだらかにする — 却下。見た目のごまかしで、実際の位置とずれる
- c: 測った行の高さを覚える独自の推定 (iOS と同じ考え方) — 保留 (a で気になった場合の次の手)。データの差し替えで行番号がずれる・列数の変化・高さのアニメーションのたびに記録の捨て直しが要り、ラッパーに状態管理が 1 つ増える

### 論点 4: 性能

- **a: 体感ゲート (cross/ADR-0006) を掛け、論点 3 の目視確認・見た目の確認と合わせて基準機での確認を 1 回で済ませる。再コンポーズを起こさないことはテストで押さえる** — 採用。スクロールの通り道に毎フレームの描画が増えるため、結果次第で作り直しがありうる (測っても何も決まらない計測ではない)
- b: 目視のついでに体感を聞くだけ (計測器・証跡なし) — 却下。証跡が残らず次回と比較できない
- c: 性能の確認をしない — 却下。スクロールの通り道を変えるのに確認しないことになる

### 論点 5: Sample のパリティ

事実で決着 (選択肢なし)。公開 API を増やさず iOS も変えないため、新しいデモ画面は不要。Android が iOS に追いつくことで「大量件数」の見た目の差が消え、片側先行も既定値の差も生まれない。

## 決定事項

- Android の `KsCollectionView` に、iOS の既定と同じ振る舞い (スクロール中だけ表示・止まるとフェードで消える・つまめない) の縦スクロールインジケータを**常に**出す。表示 / 非表示の設定はどちらのプラットフォームにも足さない (公開 API の変更なし)
- iOS の `.scrollIndicators(.hidden)` が内側の `UICollectionView` に届かない件は、意図して見送る
- 描画はライブラリ内で自前で行う。外部依存は増やさない
- 位置と長さは `LazyGridState.scrollIndicatorState` の値をそのまま使う。高さの混ざる画面で揺れが気になれば、独自の推定 (論点 3 の c) を後続で検討する
- 見た目 (太さ・色・端からの距離・最短の長さ・消えるまでの時間) は iOS の既定のインジケータの実物に数値で合わせる
- バーの描画は描画フェーズでだけ状態を読み、スクロールで再コンポーズを起こさない。これをテストで押さえる
- 完了条件の基準機確認は Pixel 4a で 1 回にまとめる: 「大量件数」(7 件ごとに長文が混ざり、グリッドで行の高さがばらつく) で体感ゲートの固定の操作列 + 証跡 6 節、同じ回に揺れの目視と見た目の確認。目視の対象に「テンプレート切り替え」も入れる。iOS は変更しないため対象外
- Sample の追加・変更はしない

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

なし。決定はいずれも Android の内部の可逆な選択で、公開 API も core の契約も変えないため選別基準 (覆すコスト高 / 境界を越える / 将来を制約) に該当しない。

## 未決の論点

- iOS 既定のインジケータの実際の値 (太さ・色・端からの距離・最短の長さ・フェードまでの時間) は実装時に iOS の実物から確かめる
- 公式の推定が全幅の header / footer を 1 行として数えるか (推測。長さの誤差に効くが、a の目視判定に含まれる)
- 論点 3 の目視で揺れが気になった場合の独自推定 (c) は、この change に含めるか後続の change に切るかをその時点で決める

## UI 素材 (ui/references/ の一覧と注釈)

なし (目指す見た目は iOS の既定のインジケータの実物)

## 変更級の推奨: S

触るのは Android のラッパー 1 か所 (バーを重ねる描画の追加) だけで、公開 API・core の契約の変更なし、ADR 候補なし、可逆。目指す見た目は iOS の実物に数値で合わせると決まっており、モックもライブ調整も要らない。オーナー確認済み (2026-09-24): S 級で直接実装 (Plan モード + テスト)。完了条件は再コンポーズを起こさないテストと、基準機での確認 1 回 (体感ゲート + 目視)。
