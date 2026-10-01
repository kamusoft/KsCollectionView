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

### phase-8 からの申し送り (2026-09-24、prefetch-display-size)

- 利用者ドキュメントの画像ロードの項目に、先読みの要素 `KsResource` の幅と任意キーの運用を足す。原料は concepts `core/core-model/image-loading.md` の「先読みの幅」「任意キー」の節と「してはいけないこと」。足す項目は次の表

| 項目 | 要点 |
|---|---|
| 先読みの幅 | グリッドの幅いっぱいの画像は列幅、セル内の固定サイズの画像は固定値。概算でよく、大きめに書く (小さめだと引き当てに外れるか見た目が甘くなる)。幅は取得とディスクの量を減らさない |
| 任意キー | 署名付き URL のように URL が変わる画像に使う。先読みの要素とセルの `KsImage` の 2 か所に同じキーを書き (モデルから両方を作る関数を 1 つ用意すると食い違わない)、違う画像に同じキーを付けない |
| キー付きの画像の削除とローダー付属ビュー | `KsImageCache.remove` には同じキーを付けたソースを渡す。キー付きの項目はローダー付属ビュー (`LazyImage` / `AsyncImage`) とキャッシュを共有しない |

### phase-4 からの申し送り (2026-09-26、sections-grouping)

利用者ドキュメントに載せる事項 (原料は concepts `core/core-model/collection-items.md` / `core/styling/collection-layout.md`):

- グループの宣言 (iOS `.groups(by:pinnedHeaders:header:)` / Android `KsGroups`) と、同じグループの項目を配列の中で続けて並べる責任が利用者にあること (離れて現れる同じ値は不正入力)
- 全画面に広げた一覧 (iOS `.ignoresSafeArea()` / Android edge-to-edge) では、ルートのヘッダーは安全領域に被ってよく、バーの分の大きさは利用者がルートのヘッダーで調整すること。ライブラリが合わせるのは固定中の見出しだけ (core/ADR-0017)
- Android のグループの値は状態保存に載る型 (Bundle に入る型) であること
- グループの値の取り出し方 (キーパス / ラムダ) は表示中に切り替えてよいこと

### phase-5 からの申し送り (2026-09-29、paging-state-machine)

ページング・Pull to Refresh の利用者向けガイド (Skill) に書く約束ごと。出典は ../../../../changes/archive/2026-09-29-paging-state-machine/deviation.md と core/ADR-0019〜0025、公開契約の現在の形は concepts/core/core-model/collection-paging.md。

- 項目があるときの取り直しの失敗は失敗の状態にせず元の状態に戻し、知らせはアプリが出す (core/ADR-0019)
- 最初の読み込みはライブラリが頼むので VM は自分で始めない (始めるなら状態を先に書き換える)。続きありのまま空のページで待機に戻すと頼み続ける (core/ADR-0020)
- 失敗・終端・空は既定で出ない。失敗の表示を設定しないと再試行の手段が出ず (Pull to Refresh が無ければ止まる)、空の表示を設定しないと 0 件の一覧は真っ白 (core/ADR-0024)
- 続きのページが同じグループの値で始まればそのグループが伸び、並び順を崩さないのは利用者の責任 (素材: phases/phase-5-paging-state-machine/artifacts/group-extends-across-pages.md)
- 状態と配列は同じ回に書き換える。次ページ要求の処理から戻る前に状態を追加読み込み中にする。VM が自分で取り直すときは古い読み込みの結果を捨てる (core/ADR-0021・0022・0023 の負の帰結)
- VM が自分で始める取り直しを先頭から見せたいときは、取り直し中が一覧に届いてから差し替えるか、差し替えと一緒に先頭へのスクロール命令 (`scrollToStart`) を出す。Pull to Refresh の取り直しはライブラリが先頭を表示する (core/ADR-0021)
- 差し替えた「次のページの読み込み中」の表示は、その範囲のタップを止め、範囲から始めたドラッグは一覧のスクロールになる。既定の表示はタッチを受けない
- Pull to Refresh の取り直しのインジケータを出している間にスクロールして失敗し配列を変えずに状態を戻すと、iOS は先頭へ戻り、Android はその位置に残る (両プラットフォームの差として受け入れ済み)
- Android では `onLoadMore` / `onRefresh` が投げた例外 (取り消し以外) をライブラリは握りつぶさず、コルーチンと同じく伝える

確かめること:

- 一覧に重ねた表示 (差し替えた読み込み中の表示・Sample の浮いたパネル) に隠れた項目が、iOS の UI テスト (XCUITest) の要素の検索で見つからない。VoiceOver の読み上げに同じ影響があるかは未確認 (paging-state-machine の実装中の観測)

### phase-6 からの申し送り (2026-10-01、drag-reorder)

並べ替えの利用者向けガイド (Skill) に書く約束ごと。出典は ../../../../changes/archive/2026-10-01-drag-reorder/deviation.md と core/ADR-0026〜0034・ios/ADR-0011・android/ADR-0007、公開契約の現在の形は concepts の core/core-model/collection-reorder.md。

#### ガイドに書く約束ごと (drag-reorder)

- 受け入れたら配列を並べ替えて渡す。受け入れたのに並べ替えないと、次に配列が届くまで表示と配列がずれる。保存の失敗は元の並びの配列を渡し直して表す (core/ADR-0027)
- 行き先は項目で届く。行き先の項目が配列から消えていたら受け入れないと返す (core/ADR-0028)
- グループをまたぐときは、VM が動かした項目のグループの値を書き換える。空のグループへは移せない (core/ADR-0029)。グループの宣言を付け外しできる画面では、外している間に動かした項目のグループの値も隣の項目に合わせる
- 「ここに置けるか」はドラッグ中に何度も呼ばれるので、軽い同期の判定にする (core/ADR-0030)
- 並べ替えのスイッチが有効の間は長押しの知らせが呼ばれない。常に有効にする一覧では長押しの知らせを使えない (core/ADR-0031)
- 読み上げの移動操作は、文言を渡さないと出ない (core/ADR-0032)。iOS は、文言を渡した一覧で並べ替えのスイッチが有効の間、行の組み立ての負荷が増える (Simulator で主スレッドの CPU 約 5〜8%)
- ドラッグ中に届いた配列は指を離すまで表示に出ず、ドラッグ中は追加読み込みも始まらない (core/ADR-0033・0034)
- ソート中の 2 つの書き方: ソート中は並べ替えのスイッチを無効にする / 置いたときの処理で手動の並びへ切り替える
- 両プラットフォームで動きが違う点: iOS は UIKit 標準の並べ替えの動きに従う (隙間は指を止めてから動く・別のグループの末尾へはいったん手前に入れてから最後の項目の上で止める・受け入れないときは置いた位置に収まってから戻る・取りやめは指を離したときに戻る・一覧の外ではプレビューが小さくなる)。Android は指の位置で決まり、見出しより上なら前のグループの末尾に直接置ける
- Android は、テンプレートの根が背景を塗らないと、持ち上げた項目の影が透けて見える

#### 確かめること (drag-reorder)

- 実機の VoiceOver / TalkBack で「前へ移動 / 後ろへ移動」が出ること・動かした後の焦点・iOS で UIKit 標準のドラッグの操作と並ぶ紛らわしさ (基準機での目視は行っていない。自動テストと Simulator の書き出しまで)
- iOS 16・17 での並べ替え (並べ替えハンドラが呼ばれること・隙間の予測・確定位置のずれの揃え方。確かめたのは iOS 18.6・26.5)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
