# グループ化 (iOS / Android) の手動フリック — 2026-09-26

tasks 5.5 の証跡。Requirement「グループを持つ大量件数での仮想化と滑らかさ」(specs/collection-core/spec.md) の Scenario「グループの多い大量件数」を、[handbook/cross/scroll-performance-gate.md](../../../handbook/cross/scroll-performance-gate.md) の固定の操作列で、基準機 2 台のオーナーの手動フリックで確かめた。iOS は同じ走行の time profile から、塊に割れたグループの見出しの書き換え (方式 3c、ios/ADR-0010) の主スレッド占有率を取り出した。Android の相対計測は [android-performance.md](android-performance.md) (tasks 5.6) にあり、この記録とは取得源も集計対象も別物である (並べて比較しない)。

## 環境

| 項目 | iOS | Android |
|---|---|---|
| 機種 / OS | iPhone 11 (基準機) / iOS 18.7.8 | Pixel 4a (基準機) / Android 13 (API 33)、60 Hz |
| 構成 | Release | benchmark ビルド種別 (release と同じ最適化 + profileable) |
| fixture | Sample「グループ化」(10,000 件・2 列。1,200 件の大きいグループ 3 つ (500 / 500 / 200 件の塊に割れる) と 5〜30 件の小さいグループ多数、見出しは固定)。起動引数 `--screen グループ化` を `devicectl` の `--` の後ろで渡した | 同じ fixture。Intent の追加情報 `ks_start_route=demo/Grouping` で直接開いた |
| 駆動 | オーナーの手動フリック (自動化なし) | 同左 |
| 記録 | Instruments Animation Hitches テンプレートをプロセス名指定で USB 接続 (`xctrace record --template 'Animation Hitches' --attach KsCollectionViewSamples --time-limit 120s`)。記録窓の実長 120.54 秒 | `dumpsys gfxinfo <package> reset` → 合図 → 操作列 → `dumpsys gfxinfo <package> framestats`。記録窓の実長 37.9 秒 (reset から取得までの時刻差)。原因の帰属用に Perfetto (atrace のアプリ区間を含む、120 秒) を reset の直前から並走 |
| 熱状態 | 記録窓の全区間 Nominal (Instruments の thermal state。`is-induced` は No) | 記録していない |
| 数値の取り出し | `xctrace export` で `hitches-summary` / `display-surface-swap` / `time-profile` / `device-thermal-state-intervals` を XML にし、Python で集計 | gfxinfo の集計行。Perfetto は ftrace の print (atrace) を Python で読み、フレームの間隔を数えた |
| 生の記録 | スクラッチにのみ保管。change には置かない | 同左 |

## 操作条件

| 項目 | iOS | Android |
|---|---|---|
| 操作列 | 固定の操作列 (初回: 下向き 10 秒 → 休止 3 秒 → 再訪: 上向き 5 秒 → 連続: 下向き 10 秒)。速度は「いつもの感覚」 | 同左 |
| 開始位置 / 方向 | 先頭から下向き | 先頭から下向き |
| 段階ごとの所要 (記録から) | HID 入力の 1 秒の空白で割って、初回 13.69–19.20 s (5.51 s) → 休止 2.6 s → 再訪 21.84–24.96 s (3.12 s) → 休止 1.9 s → 連続 26.91–33.29 s (6.38 s)。画面が動いた範囲 (surface swap の 1 秒の空白で割る) は 13.73–19.27 s と 21.88–33.33 s で、再訪と連続は画面の動きの上では続いている | 段階の境目は記録から取れない (framestats は最後の 120 フレームしか持たず、Perfetto はリングバッファで記録窓の 19.9 秒より前が上書きされていた)。最後の描画は記録窓の 25.9 秒 |
| 到達範囲 | 取得不能 (trace に可視項目の番号が無い) | 取得不能 |
| 文字サイズ / キャッシュ状態 | 端末の既定 / 記録の手順は Sample を削除してから入れ直して起動する形 (起動スクリプト) | font_scale は記録していない / 記録の手順は削除してから入れ直して起動する形 (起動スクリプト) |
| 記録開始 | 「Starting recording」を確認し、画面が「グループ化」であることをオーナーが確かめてから合図 | reset の後にオーナーへ合図 |

段階を割る区間は、handbook の「HID の 3 秒の空白」で切ると初回・再訪・連続が 1 つのブロックにつながる (段階の間の静止が 3 秒未満だった)。そのため 1 秒の空白で割った。段階と区間の対応は当てであって断定ではない。

## オーナーの体感 (合否の主語。数値を見る前に聞き取り)

| 端末 | 体感 |
|---|---|
| iPhone 11 | 引っかかりなし |
| Pixel 4a | 引っかかりなし |
| Pixel 4a の「検証: 行の高さ変化 (Android 固有)」画面 (list / grid、行の展開・折りたたみとスクロール。記録なしの体感のみ) | 引っかかりなし |

- 段階ごと (初回 / 再訪 / 連続) の分けた申告は無く、全体として「引っかかりなし」の申告である
- 画像の出方 (別の観測点): この画面は画像を持たないため対象外

## 数値 (証跡。合否ではない)

### iOS (iPhone 11、Instruments)

| 指標 (取得源・単位) | 値 |
|---|---|
| hitch 件数 (`hitches-summary`) | 121 (High 23 / Moderate 74 / Low 24)。すべて入力区間 (13.69–33.29 s) の中 |
| hitch time ratio (ms/s) | 20.3 (記録窓 120.54 秒) / **125.0 (入力区間 19.60 秒)**。参考スケール: WWDC20「Eliminate animation hitches with XCTest」の推奨値は 5 ms/s 未満が Good、10 ms/s 以上が Critical (合否には読み替えない) |
| 段階ごとの hitch | 初回 32 件 (High 1)・99.8 ms/s / 再訪 **0 件**・0.0 ms/s / 連続 89 件 (High 22)・297.9 ms/s |
| hitch time ratio の推移 (10 秒ごと、ms/s) | 0.0 / 55.0 / 13.3 / 176.7 / 以降 0.0 |
| hitch の長さ | 中央値 16.67 ms、p90 33.34 ms、最長 33.36 ms (1 フレーム分 95 件・2 フレーム分 26 件) |
| hitch の種類 | Commit to Render latency 106、Expensive Commit(s) 14、Pre-Commit(s) latency 1 |
| 描画 (surface swaps / 秒、60 Hz) | 初回 54.1 (1 秒ごとの中央値 54、最小 52) / 再訪 53.5 (中央値 54、最小 54) / 連続 48.1 (中央値 49.5、最小 39) |
| 主スレッドの稼働率 (time profile の主スレッド標本 / 実時間) | 初回 50.5% / 再訪 38.7% / 連続 63.6% / 入力区間 41.5% |

time profile (inclusive、主スレッド標本比。入れ子の項目は重複して数えるため合計は 100% にならない):

| 帰属 | 初回 | 再訪 | 連続 | 入力区間 |
|---|---:|---:|---:|---:|
| `CA::Transaction::commit` | 78.8% | 68.6% | 88.8% | 82.0% |
| `_updateVisibleCellsNow:` | 45.4% | 26.0% | 58.5% | 48.8% |
| セルの生成 `_createPreparedCellForItemAtIndexPath:` | 42.8% | 40.1% | 49.5% | 45.7% |
| 見出しの生成 `_createPreparedSupplementaryViewForElementOfKind:` | 0.4% | 1.2% | 3.6% | 2.1% |
| hosting の計測 `preferredLayoutAttributesFitting` | 24.0% | 20.6% | 28.0% | 25.4% |
| hosting の描画 `ViewRendererHost.render` | 17.3% | 20.6% | 15.3% | 16.7% |
| プリフェッチ | 16.4% | 22.6% | 7.5% | 13.0% |
| `_UICollectionLayoutSectionEstimatedSolver _solveWithParameters:` | 4.06% | 0.25% | 1.53% | 2.20% |

#### 見出しの書き換え (方式 3c) の主スレッド占有率

`KsCompositionalLayout` の上書き (`layoutAttributesForElements(in:)` と `layoutAttributesForSupplementaryView(ofKind:at:)`) の標本を、上書きの中から呼んだ compositional layout 自身の計算 (super の `-[UICollectionViewCompositionalLayout layoutAttributesForElementsInRect:]` と `-[_UICollectionCompositionalLayoutSolver layoutAttributesForSupplementaryViewOfKind:…]`) と、それ以外 (= 見出しの属性の複製と位置・横位置と幅・透明度の書き換え。`pinnedGroupHeaderAttributes(from:pinning:)`・`lastRowBottom(endingWith:section:)`、書き換えの材料を返す `makeLayout()` の closure を含む) に分けた。

| 区間 | 主スレッド標本 | 上書き全体 (super を含む) | うち super | **うち書き換え** | 書き換えの実時間比 |
|---|---:|---:|---:|---:|---:|
| 初回 (5.51 s) | 2,785 ms | 2.48% | 1.83% | **0.65%** | 0.33% |
| 再訪 (3.12 s) | 1,207 ms | 4.31% | 3.23% | **1.08%** | 0.42% |
| 連続 (6.38 s) | 4,058 ms | 2.29% | 1.60% | **0.69%** | 0.44% |
| 入力区間 (19.60 s) | 8,138 ms | 2.64% | 1.92% | **0.72%** | 0.30% |

- 書き換えは入力区間の主スレッドの 0.72% (59 ms / 8,138 ms) で、どの段階でも 1% 前後に収まる。費用の主役はセルの生成 (45.7%) と hosting の計測・描画である
- `owningSection`・`unadjustedGroupHeaderAttributes`・`pinnedGroupHeaderTop` は標本に独立したフレームとして現れなかった (Release で呼び出し元に畳まれた可能性がある。畳まれた分は上の「書き換え」に含まれる)
- hitch の多い連続の区間でも書き換えは 0.69% で、そこで出た hitch を書き換えに帰属できない

### Android (Pixel 4a、gfxinfo)

| 指標 (取得源・単位) | 値 |
|---|---|
| 描画フレーム数 (gfxinfo、37.9 秒の窓) | 833 |
| janky frames (gfxinfo) | 19 (2.28%)。legacy の定義では 67 (8.04%) |
| 期限超過 (Frame deadline missed) | 19 (legacy 15) |
| フレーム時間 P50 / P90 / P95 / P99 (gfxinfo、ms) | 16 / 20 / 24 / 40 |
| ヒストグラムの山 | 17 ms = 214 と 9〜16 ms の帯 (各 46〜76)。25 ms を超えるフレームは 27、最大は 57 ms の区分に 1 |
| Missed Vsync / Slow UI thread / Slow bitmap uploads / Slow issue draw | 1 / 18 / 0 / 1 |
| High input latency | 786 |
| GPU のフレーム時間 P50 / P90 / P99 (gfxinfo、ms) | 6 / 10 / 10 |

- gfxinfo の集計行の抜粋 (log-sanitize 済み):

```
Total frames rendered: 833
Janky frames: 19 (2.28%)
Janky frames (legacy): 67 (8.04%)
50th percentile: 16ms
90th percentile: 20ms
95th percentile: 24ms
99th percentile: 40ms
Number Missed Vsync: 1
Number High input latency: 786
Number Slow UI thread: 18
Number Slow bitmap uploads: 0
Number Slow issue draw commands: 1
Number Frame deadline missed: 19
```

- この版の gfxinfo のフレーム時間は予定の vsync からの経過で、期限は予定の vsync から 20.5 ms (framestats の `FrameDeadline − IntendedVsync`)。P90 20 ms は期限の内側にある。期限を越えたフレームが janky / deadline missed の 19 件である
- Perfetto (帰属用) は記録窓の 19.9〜25.9 秒 (連続の段階の終わり約 6 秒) だけが残っていた。この 6 秒では、主スレッドの `Choreographer#doFrame` は 296 回すべて vsync ごとに始まり (抜けなし)、RenderThread の `DrawFrames` は 283 回のうち 8 回が 2 vsync 空いた (1 フレームの抜け)。`DrawFrames` の長さは P50 1.88 / P99 4.17 ms。主スレッドのアプリ区間は開始と終了の対応が崩れている箇所があり、フレームごとの帰属には使っていない

## 判定

- **体感の合否: 合格 (オーナー、両基準機とも「引っかかりなし」)**。Pixel 4a の「検証: 行の高さ変化」画面も「引っかかりなし」(記録なし)
- **数値との一致 (iOS): 食い違いあり。** 体感は引っかかりなしだが、入力区間の hitch time ratio は 125.0 ms/s で、参考スケール (WWDC20) の Critical (10 ms/s 以上) の側にある。High の hitch は 23 件で、うち 22 件が連続の段階に集まっている。hitch は最長でも 2 フレーム分 (33.4 ms) で、再訪の段階は 0 件だった
- **数値との一致 (Android): 数値の良し悪しを言う尺度が無い** (handbook: Android のフレーム時間には公式の出所を持つ参考スケールが無い)。期限超過は 19 件 (描画 833 フレームの 2.28%)
- 見出しの書き換え (方式 3c) は入力区間の主スレッドの 0.72% で、hitch の帰属先にはならない
- **前回との比較可否: 比較対象なし。** 「グループ化」fixture の手動フリックの記録はこれが初回である。他の fixture の記録とは比較しない (handbook: fixture を変えた計測は過去の結果と比較しない)
- 再試行: 体感が迷いなく合格のため、計測器を外した対照は行っていない (handbook の再試行条件)
- tasks 5.5 の完了: **合格 (2026-09-26、指揮側で判定)** — handbook の再試行条件は「体感が迷いなく合格で数値だけが悪い」形を、対照を採らずに食い違いを証跡に書き、体感の合否を採る扱いとしている。これに従い体感の合格を採った。iOS の数値の食い違い (hitch の主因はセルの生成 45.7% と hosting の計測 25.4%、見出しの書き換えは 0.72%) は上の記録のとおり

## 限界

- **段階の所要が指定と揃っていない。** iOS は初回 5.51 s (指定 10 秒)・休止 2.6 s (指定 3 秒)・再訪 3.12 s (指定 5 秒)・連続 6.38 s (指定 10 秒)。段階は飛ばしていない。Android は段階の所要を記録から取れない
- 到達範囲・到達件数は両端末とも取得不能。末尾まで達したかは聞き取っていない
- 体感はオーナー 1 人・1 試行で、段階ごとの申告ではない。計測器を外した対照は行っていない
- Android は Perfetto を並走させた (アプリの atrace 区間を含む)。計測器の負荷が gfxinfo の値に乗っている可能性がある。Perfetto はリングバッファで記録窓の前半が上書きされ、残ったのは連続の段階の終わり約 6 秒だけである。gfxinfo の framestats も最後の 120 フレームしか持たないため、期限超過が段階のどこで出たかは分からない
- Android の熱状態と文字サイズは記録していない
- キャッシュ状態は起動スクリプトの形 (削除して入れ直す) から書いた。記録の直前にそのスクリプトを走らせたかは、この証跡の作成者は確かめていない
- iOS の不一致率 (Debug 構成の別走行) は採っていない (tasks 5.5 の指定に含まれない)
- time profile の占有率は inclusive で、書き換えと super の切り分けは「上書きの最も内側のフレームの直下が super のメソッドか」で行った。Release で畳まれた関数の自己時間は上書きのフレームに付くため、書き換えの側に数えている
