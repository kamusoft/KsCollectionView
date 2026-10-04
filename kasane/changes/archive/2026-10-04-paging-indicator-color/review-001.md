# レビュー結果: paging-indicator-color (001 回目)

**日付**: 2026-10-04
**判定**: NEEDS_DISCUSSION

## サマリー

実装はデルタスペックの全 Scenario を満たし、記録済みの乖離 (iOS の Pull to Refresh は色みが指定どおりで濃さは標準と同じ) の範囲に収まっている。4 系統のテストは全件成功し、iOS の Pull to Refresh の証跡の値は、現行のコードを専用シミュレータで実際に引っ張って撮り直して再現した。Critical / Major は無い。ただし iOS・ライトの Pull to Refresh のコントラスト比 約 2.1 が `ui/brief.md` の「視認性の基準」(3 以上) に届かず、`deviation.md` にも合意済み妥協にも記録が無い (brief 自身が「未合意」と書いている)。標準の部品の濃さの上限によるもので実装では直せないため、オーナーの判断が要る。

## テストの実行結果 (tasks 4.2 を兼ねる)

4 系統を絞り込みなしで 1 回ずつ順に流した。iOS は作業専用に新しく作ったシミュレータ (iPhone 17・iOS 27.0) を使い、終わってから削除した。Android は JDK 21、`ANDROID_HOME` を環境変数で渡した (`android/local.properties` は作っていない)。

| 系統 | 実行件数 | 失敗 | 壁時計 |
|---|---|---|---|
| iOS ライブラリ | 545 | 0 | 159 秒 |
| iOS Sample | 48 (ユニットテスト 37・UI テスト 11。計測ドライバは含まない) | 0 | 174 秒 |
| Android ライブラリ | 488 (29 クラス) | 0 | 19 秒 |
| Android Sample | 163 (21 クラス) | 0 | 13 秒 |
| 合計 | 1,244 | 0 | 365 秒 (6 分 5 秒。目安の 10 分以内) |

- iOS ライブラリの 545 件のうち `KsLoadingIndicatorColorTests` は 14 件、公開 API のテストの追加が 1 件 (変更前 530 件)
- Android ライブラリの 488 件のうち `KsLoadingIndicatorColorTest` は 13 件、公開 API のテストの追加が 1 件 (変更前 474 件)
- Android の件数は `build/test-results/testDebugUnitTest/TEST-*.xml` の集計

## 証跡の再現 (lessons/code-review.md [L-001])

iOS の Pull to Refresh の色は、ライブラリのテストが部品に渡した色 (補正後の値) しか見ていないため、描いた画素を自前で撮り直した。

- 手順: 専用シミュレータ (iPhone 17・iOS 27.0) に現行の作業ツリーからビルドした Sample を入れ、「ページング」を開き (取得の遅延 12 秒)、一覧の先頭を実際の指の操作 (下向きのスワイプ) で引っ張って取り直し中にし、0.4 秒おきに 3 枚撮って、インジケータの範囲で下地から最も離れた画素を読んだ
- 結果: ダークは 3 枚とも `#565F73` (下地 `#0D1321`)、ライトは 3 枚とも `#A8A9AF` (下地 `#F2F2F7`)。`deviation.md` と `ui/verification/ios-paging-pull-to-refresh-{dark,light}.png` の値と一致する (保存済みの 2 枚も同じ方法で読み、同じ値だった)
- コントラスト比を計算し直すと、ダーク 約 2.9、ライト 約 2.1 で、brief の記述と一致する
- あわせて、最初の読み込み中 (ダーク) の最も濃い線は `#717C92` で、brief の「指定した色の 8 割前後」と整合する。端末の表示モードをダークからライトへ切り替えると、起動したままの画面でインジケータの色がライトの値に変わった
- 撮った画像は判定に使っただけで、`evidence/` には保存していない

再現していないもの: Android の画素 (ライブラリのテストが描いた画素を直接見ているため)、iOS 18.6・26.0 での Pull to Refresh の画素 (証跡と同じ iOS 27.0 だけで撮った)。

## 照合した規約

- handbook/cross/comment-policy (always)
- handbook/cross/test-execution (テストの実行・追加・結果の報告)
- handbook/cross/sample-parity (`samples/` の変更)
- handbook/cross/sample-debug-controls (`samples/` の変更)
- handbook/cross/runtime-behavior-verification (OS の描き方に依存する分岐の検証の扱い)
- lessons/code-review.md [L-001] (証跡の値の再現)・[L-002] (動きの過程 — この変更は色だけで、位置・動きを変える箇所が無いため録画はしていない)
- 決定: core/ADR-0035 (proposed。方向の理由として読んだ)・core/ADR-0023・core/ADR-0024・core/ADR-0033・core/ADR-0002・cross/ADR-0007・cross/ADR-0008

ロードしたスキル: ksn-review・ksn-verify・kotlin-impl-skill (iOS 側は config に code-review のスキルの定義なし)

## 確認した観点

- 仕様充足: 全 Scenario の実装とテスト (対応表は `verify-001.md`)。指摘は下の 1 件
- tasks.md の虚偽チェック: なし。1.1〜3.2 のチェックは実装と一致。4.1・4.2 は未チェックのまま (4.2 はこのレビューで実行した)
- 足場の書き換え: proposal・specs は実装のファイルより前の更新時刻で、実装中に書き換えた形跡は無い (どれも未コミットのため git の履歴では確かめられない)
- 無断の逸脱: iOS の Pull to Refresh の補正は `deviation.md` に記録済み。Scenario に対応しない diff は内部の整理 (既定の表示の型の統合 — proposal の What Changes にある) だけ
- 付随修正: `deviation.md` に `[付随修正]` の行は無く、diff にも該当する変更は無い
- テストの質: Android は描いた画素で判定し、指定した色が出ることと既定の色が出ないことの両方を見ている。iOS は標準の部品に付いた色を読み、差し替えた表示・指定を外した表示は「色を指定しない一覧」を基準に比べている。待機は条件ベースで、期限を超えると実測値を出して失敗する形 (既存の補助を使用)
- 既存の決定との整合: Kotlin の引数は末尾 (`content` の前) に足してあり、既存の引数の順番は変わらない。iOS は並べ替えのドラッグ中に構成を控える既存の経路に乗り、色だけを先に当てる経路は無い (core/ADR-0033)。Pull to Refresh は標準の部品のまま (core/ADR-0023)
- コメント規約: 公開の doc コメント (Swift の `loadingIndicatorColor(_:)`、Kotlin の `@param loadingIndicatorColor` と `KsPaging` の KDoc) に内部用語は無い。検査 (`scripts/comment-policy-lint.py --advisory`) は禁止 0 件・要確認 7 件で、要確認はどれもこの変更より前からある行
- Sample: 両プラットフォームとも同じ名前のトークン (`SampleTheme.secondaryText`) を 1 行足しただけで、一覧に渡す配置の入力・操作のパネル・失敗 / 終端 / 空の表示は変えていない
- オーバーエンジニアリング: なし。iOS の補正は関数 1 つで、表示モードで変わる色・不透明度・sRGB の外の色の扱いにそれぞれテストがある
- Kotlin (kotlin-impl-skill): null の扱い (`?:` で material3 の既定へ)・公開 API の KDoc・不変性に問題なし
- セキュリティ・入力検証: 該当なし

## 指摘事項

### [NEEDS_DISCUSSION] iOS・ライトの Pull to Refresh のコントラスト比が「視認性の基準」に届かず、合意の記録が無い

**該当箇所**: `ui/brief.md` (「デザイントークン参照」の視認性の基準・「合意済み妥協」・「照合結果」の 3 項目め) / `deviation.md` の 2 行め / `ui/verification/ios-paging-pull-to-refresh-light.png`

**問題点**: samples の Scenario「3 つの表示が同じ色でそろう」で出す Pull to Refresh のインジケータは、iOS・ライトで最も濃い部分が `#A8A9AF`、下地 `#F2F2F7` に対してコントラスト比 約 2.1 になる (自前の撮影で再現)。brief の「視認性の基準」は 4 つの組み合わせすべてで 3 以上としており、`deviation.md` と「合意済み妥協」が受け入れているのは iOS・ダークの約 2.9 だけである。brief の「照合結果」も「ライトの値の扱いは未合意」と書いている。原因はダークと同じ (標準の引っ張りの部品が最大で約 57% の不透明度でしか描かない) で、Requirement「読み込み中の表示の色」の記録済みの乖離 (濃さは標準と同じ) を採る限り、実装では直せない。

**選択肢**:
1. iOS・ライトの約 2.1 も受け入れ、`deviation.md` と brief の「合意済み妥協」に記録する。ライトはダークより基準から遠い (2.1 と 2.9) ので、ダークの合意がそのまま及ぶとは言えず、明示の合意が要る
2. iOS の Pull to Refresh の描き方を見直す (ライブラリが自前のくるくるを描く案)。`deviation.md` の 1 行めで却下済みで、core/ADR-0023 と食い違う
3. Sample のライトで指定する色を変える。テキスト副を使うと決めた brief・承認 mock と、両プラットフォームで同じトークンを参照する決まり (handbook/cross/sample-parity) の変更になる

tasks 4.1 のオーナーの最終承認の中で 1 を合意して記録するのが、いちばん変更が少ない。

### [🟡 Minor] iOS の Pull to Refresh の補正は、対応 OS のうち iOS 16・17 で確かめられていない

**該当箇所**: `ios/Sources/KsCollectionView/KsRefreshControl.swift:42` / `ios/Package.swift:8`

**問題点**: 補正 (成分ごとの平方根) は、標準の部品が渡した色を 2 回掛けて描くことを前提にしている。この描き方は OS の文書に無く、確かめたのは iOS 18.6・27.0 (26.0 は同じ構成) で、パッケージの対応 OS は iOS 16 からである。2 回掛けない版では、指定より明るい色で出る。`deviation.md` の蒸留送りの行に「iOS 16・17 は未確認」とあり認識済みなので、判定には数えない。このレビューの環境にも iOS 16・17 のシミュレータが無く、確かめられなかった。

**推奨修正**: この change では不要。蒸留で concepts に未確認の範囲を書くときに、確かめる機会 (該当の版のシミュレータか実機が手に入ったとき) を残す。

### [🔵 Suggestion] 表示モードで変わる色を指定したとき、部品の色が更新のたびに入れ直される可能性がある

**該当箇所**: `ios/Sources/KsCollectionView/KsRefreshControl.swift:27` / `ios/Sources/KsCollectionView/KsCollectionView.swift:312`

**問題点**: `indicatorColor` は前の値と等しければ何もしないが、`UIColor(color)` は更新のたびに新しく作られる。表示モードで変わる色どうしが等しいと判定されるかは確かめていない。等しくならない場合、一覧の更新のたびに `tintColor` を入れ直すことになる。自前の撮影 (Sample は表示モードで変わる色を指定している) では、取り直し中のインジケータに乱れは見えず、実害は確認していない。

**推奨修正**: 対応は任意。気になる場合は、表示モードで変わる色を指定して更新を繰り返したときに `tintColor` の設定が何回走るかを 1 件のテストで確かめる。

## アクションプラン

1. iOS・ライトの Pull to Refresh のコントラスト比 約 2.1 の扱いをオーナーに諮る (tasks 4.1 の最終承認とあわせて)。受け入れるなら `deviation.md` と brief の「合意済み妥協」に記録する
2. tasks 4.2 は、このレビューの実行結果 (1,244 件・失敗 0・365 秒) で完了にできる
3. Minor・Suggestion は対応不要 (蒸留時の concepts の記述で iOS 16・17 の未確認を残す)
