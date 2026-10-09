# 利用者ドキュメント

skills/ と README を制作し、源泉 (kasane/ とコード) に追従させる仕組みを決める。

## 論点

- skills/ 方式の利用者ドキュメントの実制作 (方針は [cross/ADR-0005](../../../../decisions/cross/0005-user-docs-as-agent-skills-and-root-readme.md) で accepted 済み)
- `skills/` を源泉 (`kasane/` とコード) に追従させる仕組み (cross/ADR-0005 が本フェーズに委ねた。翻案元は対応表 `skills/.manifest.json` と、オーナーの依頼で動かす docs-refresh)
- インストール例の版の書き方 (翻案元 `../KsSettingsView/kasane/decisions/cross/` の 0029: 版を書かず `{version}` を置き、最新版は Release の一覧で案内する)

### phase-8 からの申し送り (2026-09-08)

- 利用者ドキュメント (skills/ 方式) に画像ロードの運用を含める。原料は concepts `core/core-model/image-loading.md` の責務境界と「してはいけないこと」。含める項目は次の表

| 項目 | 要点 |
|---|---|
| 先読みに宣言する URL | グリッドにはサムネイル用途の寸法で配信される URL を宣言する |
| iOS のディスクキャッシュ | 起動時に `KsImagePipeline.enableSharedDiskCache()` を一度呼ぶ。delegate を使うアプリは自分でパイプラインを組む |
| iOS の `remove` | 消したソースはローダー付属ビューとキャッシュを共有しなくなる |
| Android のキャッシュ操作 | androidx.startup の初期化が前提。無効化した構成では警告だけで何もしない |

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

### phase-7-2 からの申し送り (2026-10-09、package-distribution)

- インストール例に書く値が決まった。SwiftPM は、Package URL が配信用リポジトリ `KsCollectionView-SPM` で、利用者がマニフェストに書く package の名前も `KsCollectionView-SPM` になる (product の名前は `KsCollectionView`。cross/ADR-0015)。Android は座標 `jp.kamusoft:kscollectionview` の 1 行。値は handbook の `cross/public-identifiers.md` にある
- マニフェストの宣言を Swift 6.4 に上げたので、利用者には Xcode 27 以上が要る。案内に書く
- 利用者が書くのと同じ書き方でビルドできることは、利用者役 (`verification/ios/`・`verification/android/`) が確かめている。README のインストール例と、利用者役のソースを一致させる検査は、まだ無い。このフェーズで扱う

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
