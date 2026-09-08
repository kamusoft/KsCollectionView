# 配布 / ドキュメント

パッケージ配布・利用者ドキュメントの整備。サンプルアプリは各フェーズの完了条件で育つため本フェーズの対象外 (roadmap 前提参照)。

## 論点

- 配布: SPM / Maven のパッケージング (翻案元 `../KsSettingsView/kasane/decisions/cross/` の 0018 SPM 配信リポジトリ・0019 lockstep 単一バージョン・0020 dispatch リリース/tag 後置/version CI 注入は翻案元でも proposed — 本フェーズで自リポジトリの ADR として判断する)
- 検証 CI の構成と保証範囲 (翻案元 cross/0025・0026: platform 別再利用 workflow + 入口、パス絞り込みなし、テスト 0 件は緑でも失敗)
- skills/ 方式の利用者ドキュメントの実制作 (方針は [cross/ADR-0005](../../../../decisions/cross/0005-user-docs-as-agent-skills-and-root-readme.md) で accepted 済み)
- 大量件数の性能検証をリリース基準に含めるか (実機・件数・計測手順)

### phase-2 からの申し送り (2026-09-03)

- 性能検証の手順と合格基準は [handbook/ios/performance-verification.md](../../../../handbook/ios/performance-verification.md) に昇格済み
- リリース基準に含めるかを決める際は iOS の未実施分を扱う: 基準機 iPhone 11 での hitch 計測 (phase-2 は iPhone 15 で代替)、メモリ絶対値 (Simulator で約 610 MB、内訳未解明) の実機確認
- 推定高さ (`KsEstimatedHeight`) の既知の乖離を長いスクロールで観測する: grid では行高 = 列内最大セル高に対し実測がセル単位のため平均でも過小、直近 32 件の移動平均のため大量件数のスクロール中に contentSize が揺れうる (インジケータ・オフセットの安定性は未測定)
- CI での性能自動化 (XCUITest + `XCTOSSignpostMetric`) は実機の受け皿ができた時点で再訪 (ios-engine-foundation design Decision 6 の代替案)

### phase-3 からの申し送り (2026-09-05)

- Android の性能検証は [handbook/android/performance-verification.md](../../../../handbook/android/performance-verification.md) に昇格済み。基準機 Pixel 4a で実測済み (代替機ではない)
- Android は Macrobenchmark で人の操作なしに再実行できるため、リリース基準に含める場合は CI の実機の受け皿だけが課題
- 相対基準 (素の Compose との差 10% 以内) は比較対象にライブラリと同じ既定機能を付けた条件で測るもので、ラッパーそのものの薄さより緩い側にある。リリース基準として引くときは規約の但し書きを読む
- maven-publish の設定は基盤では行っていない (composite build の明示 substitution で Sample が本体を参照)。配布座標 `jp.kamusoft:kscollectionview` は cross/ADR-0003 どおり Sample で実地確認済み

### phase-8 からの申し送り (2026-09-08)

- 利用者ドキュメント (skills/ 方式) に画像ロードの運用を含める。原料は concepts `core/core-model/image-loading.md` の責務境界と「してはいけないこと」。含める項目は次の表

| 項目 | 要点 |
|---|---|
| 先読みに宣言する URL | グリッドにはサムネイル用途の寸法で配信される URL を宣言する |
| iOS のディスクキャッシュ | 起動時に `KsImagePipeline.enableSharedDiskCache()` を一度呼ぶ。delegate を使うアプリは自分でパイプラインを組む |
| iOS の `remove` | 消したソースはローダー付属ビューとキャッシュを共有しなくなる |
| Android のキャッシュ操作 | androidx.startup の初期化が前提。無効化した構成では警告だけで何もしない |

- 検証 CI の構成に、実機が接続されていないと実行できないテスト (`android/kscollectionview/src/androidTest/`、到達点メモリの実機分岐 3 件) の受け皿を含めるか決める。実機の受け皿は性能計測の CI 化 (phase-2 / phase-3 の申し送り) と同じ課題
- iOS Sample にはユニットテストターゲットが無く、計測入口の土俵一致や観測ログの分類はテストで担保していない (Android は持つ)。ターゲット追加は project ファイルの変更を伴うため、配布・CI の構成を決めるときに併せて判断する

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
