# リリースの手順 / 基準

リリースの手順と基準を決め、自動化する。

## 論点

- リリースの手順: 版の付け方・リリースの起動・リリースノート (翻案元 `../KsSettingsView/kasane/decisions/cross/` の 0019 単一バージョン・0020 手動起動と tag の後置・0030 PR 本文からのリリースノート。accepted で運用中 — 自リポジトリの ADR として判断する)
- 大量件数の性能検証をリリース基準に含めるか (実機・件数・計測手順)
- 初回リリースまでに片付ける範囲: 積んである簡易起票 5 件 (`kasane/changes/`) と、申し送りの「確かめること」(実機の読み上げ・iOS 16 / 17) をリリースの条件にするか

### phase-2 からの申し送り (2026-09-03)

- 性能検証の手順と合格基準は [handbook/ios/performance-verification.md](../../../../handbook/ios/performance-verification.md) に昇格済み
- リリース基準に含めるかを決める際は iOS の未実施分を扱う: 基準機 iPhone 11 での hitch 計測 (phase-2 は iPhone 15 で代替)、メモリ絶対値 (Simulator で約 610 MB、内訳未解明) の実機確認
- 推定高さ (`KsEstimatedHeight`) の既知の乖離を長いスクロールで観測する: grid では行高 = 列内最大セル高に対し実測がセル単位のため平均でも過小、直近 32 件の移動平均のため大量件数のスクロール中に contentSize が揺れうる (インジケータ・オフセットの安定性は未測定)

### phase-3 からの申し送り (2026-09-05)

- Android の性能検証は [handbook/android/performance-verification.md](../../../../handbook/android/performance-verification.md) に昇格済み。基準機 Pixel 4a で実測済み (代替機ではない)
- Android は Macrobenchmark で人の操作なしに再実行できるため、リリース基準に含める場合は CI の実機の受け皿だけが課題
- 相対基準 (素の Compose との差 10% 以内) は比較対象にライブラリと同じ既定機能を付けた条件で測るもので、ラッパーそのものの薄さより緩い側にある。リリース基準として引くときは規約の但し書きを読む

### phase-5 からの申し送り (2026-09-29、paging-state-machine)

確かめること:

- 一覧に重ねた表示 (差し替えた読み込み中の表示・Sample の浮いたパネル) に隠れた項目が、iOS の UI テスト (XCUITest) の要素の検索で見つからない。VoiceOver の読み上げに同じ影響があるかは未確認 (paging-state-machine の実装中の観測)

### phase-6 からの申し送り (2026-10-01、drag-reorder)

出典は ../../../../changes/archive/2026-10-01-drag-reorder/deviation.md。

#### 確かめること (drag-reorder)

- 実機の VoiceOver / TalkBack で「前へ移動 / 後ろへ移動」が出ること・動かした後の焦点・iOS で UIKit 標準のドラッグの操作と並ぶ紛らわしさ (基準機での目視は行っていない。自動テストと Simulator の書き出しまで)
- iOS 16・17 での並べ替え (並べ替えハンドラが呼ばれること・隙間の予測・確定位置のずれの揃え方。確かめたのは iOS 18.6・26.5)

### phase-7-1 からの申し送り (2026-10-08、public-repo-verify-ci)

- 検証 CI の iOS / Android の検証は、入力を取らない再利用 workflow になっている (cross/ADR-0014)。リリースの workflow から同じ検証を呼べる。ただし iOS はビルドの確認だけで、テストは実行しない (cross/ADR-0013)。リリースの前に iOS のテストをどこで確かめるか (手元の完了判定に任せるか) を決める
- `main` の保護は、管理者には強制していない。管理者が迂回して `main` 宛ての Pull Request を進めてよい条件とやり方は、決まりが無い
- マージの後に `main` を `develop` へ取り込み直すかどうかは、決まりが無い (`main` の保護は、最新の取り込みを求めない設定)
- 「リリース候補にする節目」(いつ `develop` から `main` 宛ての Pull Request を出すか) の判断の基準は、決まりが無い
- secret の検査や push の保護が secret を検出したときにすること (値の無効化など) は、手順が無い
- `main` の workflow の時間の上限は暫定の値のまま (lint 10 分・iOS 40 分・Android 30 分)。決め直した値 (5 分・15 分・15 分) は `develop` にあり、次の `main` 宛ての Pull Request で入る

### phase-7-2 からの申し送り (2026-10-09、package-distribution)

- 配信用リポジトリ `KsCollectionView-SPM` は、まだ無い。作成と設定 (Issue と Pull Request を閉じ、本リポジトリへ案内する)、写しを送って tag を付ける工程を、このフェーズで作る (cross/ADR-0015)。写しを作る道具 (`scripts/distribution/sync-spm-snapshot.py`) は git を操作せず、行き先には、まだ無いパス・空のディレクトリ・配信用リポジトリの作業コピーだけを受け付ける。commit・push・tag は、道具を呼ぶ側の工程が行う
- Android の公開の設定は入っている。足りないのは、実際に公開する workflow・署名の鍵の受け渡し・Maven Central への送信である。鍵はプロパティで受け取り、無ければ署名を飛ばす。確かめた署名は、パスフレーズなしの使い捨ての鍵だけで、本番の形 (パスフレーズつき) は確かめていない。版が開発中の版のままだと、Maven Central へ送るタスクは最初に失敗する
- 利用者の立場の確認の再利用 workflow (`verify-consumer-ios.yml`・`verify-consumer-android.yml`) は、切り替えと版を入力に取る。リリースの workflow からは、公開済みの形で版を渡して呼べる (cross/ADR-0016)。公開済みの配布物の取得は、公開物が無いので確かめていない。最初のリリースで確かめる。リリースの workflow が作った成果物そのものを、公開の前に利用者役へ渡す形は、まだ無い
- コード縮小を有効にした Android の利用者役は、手元で 1 回起動して一覧が表示されることを確かめた。リリースの節目ごとに起動を確かめる決まりにするかは、決めていない
- 利用者の立場の確認は、外部の依存の取得 (Nuke・Maven の依存) に頼る。コードの誤りでない理由で `main` の必須の検査が止まり得る。上の phase-7-1 からの申し送りの「管理者が迂回してよい条件」と一緒に決める
- 簡易起票が 1 件増えた: `ios-release-build-concurrency-warnings` (本体をリリースの構成でビルドすると、並行性の警告が 2 か所で出る。利用者のビルドの出力に現れる)。論点「初回リリースまでに片付ける範囲」で扱う
- 手順と値は handbook の `cross/package-distribution.md` (配布物を作る側) と `cross/consumer-build-check.md` (利用者役で確かめる側) にある

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
