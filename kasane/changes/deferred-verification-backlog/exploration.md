# Exploration: deferred-verification-backlog

## 課題 / 動機

先行フェーズの change で確かめられなかったこと、決めなかったことのうち、簡易起票になっていないものを集めた。ロードマップ v1-foundation の phase-7-4 (リリースの手順) の議論で、オーナーの決定により「初回リリースの基準と片付ける範囲」をロードマップの論点から外した (2026-10-14)。外したままでは、ロードマップを archive した後に誰も追わなくなるので、追跡が切れないようにここに積む。どれも、それぞれの change の完了判定では扱わないと決めた範囲で、実害は確かめていない。

出どころの一覧は、phase-7-4 の agenda の「ロードマップの外へ出したもの」(`kasane/roadmaps/archive/2026-10-15-v1-foundation/phases/phase-7-4-release-pipeline/agenda.md`。ロードマップの archive 後は `kasane/roadmaps/archive/*-v1-foundation/` の下)。

### 性能 (phase-2・phase-3 の申し送り)

- iOS の基準機 iPhone 11 での hitch の計測 (phase-2 は iPhone 15 で代替した)。この申し送り (2026-09-03) は、性能の合否をオーナーの体感に改めた cross/ADR-0006 より前のもの。今の規約 (`kasane/handbook/cross/scroll-performance-gate.md`・`kasane/handbook/ios/performance-verification.md`) で、まだ計測が要るかから確かめる
- iOS のメモリの絶対値 (Simulator で約 610 MB、内訳は未解明) を、実機で確かめる
- 推定高さ (`KsEstimatedHeight`) の既知の乖離を、長いスクロールで観測する。grid では行の高さが列の中の最大のセルの高さなのに、実測はセル単位なので平均でも小さめに出る。直近 32 件の移動平均なので、大量件数のスクロール中に contentSize が揺れ得る (インジケータ・オフセットの安定性は測っていない)
- Android の性能は、Macrobenchmark で人の操作なしに再実行できる。リリースの基準に含めるなら、CI の実機の受け皿だけが課題 (`kasane/handbook/android/performance-verification.md`)。相対基準 (素の Compose との差 10% 以内) をリリースの基準として引くときは、規約の但し書きを読む

### 読み上げと古い iOS (phase-5・phase-6 の申し送り)

- 一覧に重ねた表示 (差し替えた読み込み中の表示・Sample の浮いたパネル) に隠れた項目が、iOS の UI テスト (XCUITest) の要素の検索で見つからない。VoiceOver の読み上げに同じ影響があるかは確かめていない (`kasane/changes/archive/2026-09-29-paging-state-machine/` の実装中の観測)
- 実機の VoiceOver / TalkBack で「前へ移動 / 後ろへ移動」が出ること、動かした後の焦点、iOS で UIKit 標準のドラッグの操作と並ぶ紛らわしさ。基準機での目視は行っておらず、確かめたのは自動テストと Simulator の書き出しまで (`kasane/changes/archive/2026-10-01-drag-reorder/deviation.md`)
- iOS 16・17 での並べ替え (並べ替えハンドラが呼ばれること・隙間の予測・確定位置のずれの揃え方)。確かめたのは iOS 18.6・26.5 (同上)

### 利用者の環境 (phase-7-2・phase-7-3 の申し送り)

- コード縮小を有効にした Android の利用者役は、手元で 1 回起動して一覧が表示されることを確かめた。リリースの節目ごとに起動を確かめる決まりにするかは、決めていない (`kasane/changes/archive/2026-10-09-package-distribution/`)
- Android の利用する側の下限は、minSdk と compileSdk だけを示している。Android Gradle Plugin と Kotlin の下限を、ビルドして確かめて README と Skill に載せるか。Compose Foundation が本ライブラリを通して届くかも、同じときに確かめる (`kasane/changes/archive/2026-10-10-user-docs/`)
- 利用者向け Skill のコード例は、コンパイルとビルドまでで確かめた。実行時の動きは確かめていない (同上)

### release-pipeline から (2026-10-15)

変更 `release-pipeline` (初回のリリース 0.1.0-beta.1。記録は `kasane/changes/archive/2026-10-15-release-pipeline/`) で、確かめきれなかったこと:

- リリースの Skill (`.agents/skills/release/`) を実物で使って、事前の確認・確認のメッセージ 1 回・Pull Request のマージ・起動・見守りが手順の文書のとおりに進むこと。初回は手順の草稿で行い、Skill は使っていない。2 回目のリリースが最初の実地になる
- 共同作業者でないアカウントで、配信用リポジトリに Issue・Pull Request を作れないこと (設定の値と、サインインしない状態の Issue の画面が 404 になることまでは確かめた)
- `develop` から起動した run の、Environment `release` を指定したジョブが保護で止まること (リリースの workflow は `validate` が先に止めるので、正規の起動では起きない。確かめるには一時の workflow が要る)
- secret の検査 (gitleaks) の指紋の形が、commit の前の走査と検証 CI の走査で違うか (`.gitleaksignore` に足した指紋が両方に効くか)。最初の本物の誤検出のときに確かめる

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補

## 未決の論点

- 未探索 (簡易起票)
- 項目ごとに、確かめるか、確かめずに閉じるかを決める。性能の 1 件目のように、今の規約では要らなくなっているものがあり得る
- これらのどれかを、リリースの前に満たす条件にするか。phase-7-4 の論点から外したので、決めるならロードマップの外で決める
- 1 つの change に収まらない (実機での確かめと、README と Skill の追記が混ざる) なら、分けて起票し直す

## UI 素材

## 変更級の推奨

未判定
