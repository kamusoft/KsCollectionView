# Exploration: library-default-colors-dark-mode

## 課題 / 動機

ライブラリ本体の既定の色の一部が、表示モード (ライト / ダーク) に追随しない、またはダークでだけ両プラットフォームで食い違う。`sample-dark-mode-toggle` で Sample にライト / ダークの切り替えを入れた際、ダークで Sample の配色が暗くなったことで見えるようになった (2026-09-26、オーナー指示で起票)。その change の探索で「ライブラリの既定の色の修正は別の change に切り出す」と決定済み (`kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/exploration.md` の決定事項)。

起票時点で分かっている問題 (コードを読んで確認。実物の見え方はオーナーの目視 = `sample-dark-mode-toggle` の tasks 5.4 の結果をこのメモに追記する):

- **区切り線の既定の色が固定**: 既定は `#D9D9DE` の固定値 (iOS `ios/Sources/KsCollectionView/KsHostingCell.swift:5-10`、Android `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsListSeparator.kt:13`)。ダークでも明るい灰色の線のまま描かれる。core/ADR-0010 で semantic color を却下して固定値にした決定 (プラットフォーム間で同じ実値にするため) で、ダークは考慮されていなかった。ただし 5.4 のオーナーの目視 (2026-09-26) では、ダークで明るい線のまま残る見え方は「問題なし」と判断された — 直すかどうかは探索で決める
- **画像の読み込み中・失敗の色がダークでだけ食い違う** (オーナーの目視で問題ありと確認済み、2026-09-26。Android の読み込み中の色がダークでも明るいまま — `kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/evidence/owner-library-defaults-check.md`): iOS は OS の色 (`ios/Sources/KsCollectionView/KsImage.swift:330` の systemGray5、`:344` の systemGray4) でダークに追随する。Android は固定値 (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:541-543` の読み込み中 `#E0E0E0`・失敗 `#BDBDBD`・印 `#757575`) でライトのまま。ライトの見え方がそろっていても、ダークでは両プラットフォームで違う色になる

参考: 表示モードに追随するもの — iOS のタップの反応 (`.systemFill`)、Android の既定の ripple (MaterialTheme に従う)、両プラットフォームのスクロールインジケータ (Android は `isSystemInDarkTheme()`)。`../KsSettingsView/` は同じ問題を別 change `2026-09-06-fix-default-colors-dark-appearance` で直し、ライブラリが light / dark 2 組の既定色を持つ形にした (`../KsSettingsView/kasane/decisions/core/` の ADR-0030)。

### 探索で確かめた現状 (2026-10-06、コードの実物)

ライブラリ本体が色を決めている箇所の棚卸し。iOS の OS の色の実値は公表値で、このリポジトリでは実測していない。

| 何の色か | iOS | Android | ダークに追随 | 両プラットフォームの実値 |
|---|---|---|---|---|
| 区切り線の既定 | 固定 `#D9D9DE` (`ios/Sources/KsCollectionView/KsHostingCell.swift:5-10`) | 固定 `#D9D9DE` (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsListSeparator.kt:13`) | どちらもしない | ライト・ダークとも同じ (ダークも明るいまま) |
| 画像の読み込み中 | OS の色 systemGray5 (`ios/Sources/KsCollectionView/KsImage.swift:330`。ライト `#E5E5EA` / ダーク `#2C2C2E`) | 固定 `#E0E0E0` (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:541`。描く箇所は `:406` と `:512` の 2 つ) | iOS する / Android しない | ライトでも違う |
| 画像の失敗の下地 | systemGray4 (`KsImage.swift:344`。`#D1D1D6` / `#3A3A3C`) | 固定 `#BDBDBD` (`KsImage.kt:542`) | 同上 | ライトでも違う |
| 画像の失敗の印 | SF Symbols の `photo` を systemGray `#8E8E93` で (`KsImage.swift:346-348`) | 自前の四角と丸を `#757575` で (`KsImage.kt:527-543`) | 同上 | 違う (印の形も違う) |
| タップしたときの色の既定 | `.systemFill` (`KsHostingCell.swift:15`) | material3 の既定の ripple (`KsCollectionView.kt:439-441`) | する (Android はアプリのテーマ次第) | 違う (オーナーの目視で問題なし) |
| 読み込み中のインジケータ・Pull to Refresh | OS 標準 | Material の既定 (テーマの primary) | する (Android はテーマ次第) | 違う (core/ADR-0035 で受け入れ済み) |
| スクロールインジケータ | OS 標準 | 黒 35% / 白 50% を `isSystemInDarkTheme()` で選ぶ (`KsScrollIndicator.kt:48-63`、`KsCollectionView.kt:451`) | する | 設計上同じ |
| 並べ替えの持ち上げの影 | UIKit 標準 | 色の指定なしの影 8dp (`KsReorderLift.kt:119-122`) | Android はしない | 違う (仕組みが別) |

- 起票時の記述の訂正: 画像の既定の色は「ライトの見え方がそろっている」わけではなく、ライトでも両プラットフォームで実値が違う。「同じ実値」の方針を画像に当てるなら、ライトの値も決め直しになる
- 画像の失敗の表示 (Android の下地と印) もダークで明るいまま。オーナーの目視 (2026-09-26) は読み込み中だけで、失敗は見ていない
- iOS: 区切り線の色は `UIColor` のまま線の View の背景色に入る (途中で `CGColor` に固定する箇所は無い)。表示モードの変化を拾う仕掛け (`traitCollectionDidChange` / `registerForTraitChanges`) は本体に無い。既定を表示モードで変わる `UIColor` にすれば追加の仕掛けなしで追随する見込み (未実測)。区切り線のテストは既定の色が同じオブジェクトで渡ること (`===`) を前提にしている (`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:2333-2344`)
- Android: 区切り線の未指定は `null` で表し、コンポジションの中で既定に解決する (`KsCollectionView.kt:431`)。ここを表示モードの分岐に替えれば再コンポーズで追随する
- Android 本体の中で表示モードの判定元が 2 系統ある: スクロールインジケータは `isSystemInDarkTheme()`、ripple・読み込み中のインジケータ・Pull to Refresh はアプリの MaterialTheme (`kasane/concepts/core/styling/collection-layout.md:153` に記載済み)
- Sample の外観の切り替えは、iOS が window の `overrideUserInterfaceStyle`、Android が Configuration の `uiMode` の上書き (`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleAppearanceStore.kt:10-44`)。どちらも trait / `isSystemInDarkTheme()` に届く
- Sample のトークン `separator` はライト `#D9D9DE` (ライブラリの既定と同じ) / ダーク `#2A3752` (紺寄り。Sample の配色のための値)
- 配布の状況: git の tag は 0 件、配布のフェーズ (phase-7-samples-distribution) は pending、maven-publish は未設定。外部の利用者はまだいない
- core/ADR-0035 は「指定しないときはライブラリの固定のグレーで 3 つをそろえる」案を、ライト / ダーク 2 組の値と表示モードを判定する仕組みが要ることを理由に却下している。この change でその仕組みを入れるなら、却下理由の前提が変わる

### 参考にする KsSettingsView のやり方 (2026-10-06 調査、オーナー指示)

`../KsSettingsView/kasane/decisions/core/0030-theme-dark-appearance-library-owned-light-dark-defaults.md` (accepted) と実コードの要点。

- ライブラリがライト / ダーク 2 組の既定の色を自前で持ち、未指定の色だけを描くときに現在の表示モードの側へ解決する。利用者が指定した色には触らない。利用者が渡すのは従来どおりの単色で、ライト / ダークの対を持つ新しい型は足さない
- iOS: 既定の色の定数そのものを、表示モードで変わる `UIColor` (`UIColor { trait in ... }`) にして UIKit に解決を任せる (`../KsSettingsView/ios/Sources/KsSettingsViewUI/Theme.swift:262-320`)
- Android: 未指定を `Color.Unspecified` で表し、1 か所で埋める。Compose の入口は `isSystemInDarkTheme()` で選ぶ (`../KsSettingsView/android/kssettingsview/src/main/kotlin/jp/kamusoft/kssettingsview/ui/KsSettingsViewDefaults.kt:70-71`)。ホストの `MaterialTheme` への自動追随は却下
- ダークの値は iOS のダークのシステムパレットの不透明な近似を、両プラットフォームに同じ値で置く (区切り線はライト `#C8C7CC` / ダーク `#38383A`)。OS の semantic color への置き換えは、ライトの見た目が変わることと半透明の色が Android の描き方と合わないことを理由に却下
- 既定の色をライト / ダークそれぞれの値で固定するテストを両プラットフォームに持つ。目視は承認したモックとスクリーンショットの画素の比較
- 実装でぶつかった点: iOS で `CGColor` を layer に置く箇所だけ表示モードの変化で解決し直す仕掛けが要った。表示モードで変わる `UIColor` は同じインスタンスでしか等しくならないので、固定 RGB と比べていたテストを書き換えた
- 「未配信で外部の利用者がいない」という前提が実際には誤りで、後続の ADR-0031 で扱いを決め直している。このリポジトリでは上の「配布の状況」で確かめた

### タップしたときの色の調査 (2026-10-06、論点 5)

Android の波紋 (material3 の ripple) が渡した色をどう扱うかを、このリポジトリが使う版 (Compose BOM 2026.06.01 → material3 1.4.0 / material-ripple 1.11.4) の AAR のバイトコードと、OS 側の `RippleDrawable` のソースで確かめた。**エミュレータ・実機での見え方は未確認** (数値はすべてソースの読み取り)。

- 渡した色の不透明度は**捨てられ**、押している間の不透明度 (既定 0.10) に**置き換わる** (掛け合わせではない)。material-ripple の `calculateRippleColor` が `color.copy(alpha = …)` を呼ぶ。ライト / ダークや色の明るさによる分岐は無い
- 押している間の表示はすべて OS の `RippleDrawable` が描く。見える濃さは API 29-30 で約 10%、API 31 以降は押し続けている間の中心が約 8.3% (途中の最大 10%)
- したがって「不透明なアクセント色」と「アクセント色の 15%」は Android では同じ見え方になる見込み。次の 3 か所の「不透明度を掛ける」「iOS で使う半透明の色をそのまま渡すと見えなくなる」は、ソース上は成り立たない: `kasane/concepts/core/core-model/collection-interaction.md:76`、`kasane/decisions/android/0003-material3-dependency-for-ripple.md:29` (Consequences)、`kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md:6`
- 本当の違い: iOS は色も濃さも利用者が決める (渡した色をそのまま塗る。不透明な色を渡すとセルの中身が隠れる。出入りにアニメーションは無い)。Android は色みだけ利用者が決め、濃さは Material の標準
- 今の Sample「リスト」は iOS がアクセント色の 15%、Android が約 8〜10% で、数値の上ではそろっていない
- Android で利用者の不透明度どおりに塗る手段: 自前の Indication (波紋なし) なら正確に塗れる。波紋を残す手段 (`createRippleModifierNode` で不透明度を差し替える) は OS の係数が残る (API 29-30 は上限 約 50%、API 31 以降は押し続けている間 約 0.83 倍)。後者の API は androidx の開発中の版で形が変わりつつある (どの版から入るかは不明)
- 色・濃さを固定するテストは Android に無い (Robolectric では波紋が描かれない)。iOS は指定色がそのまま入ることを固定している (`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:364`)
- Sample で色を渡している箇所: `samples/ios/KsCollectionViewSamples/ListDemoView.swift:39` (アクセント色の 15%)、`samples/ios/KsCollectionViewSamples/InteractiveControlVerificationView.swift:41` (検証用の赤)、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ListDemoScreen.kt:60` (アクセント色そのもの)

## 検討した選択肢 (却下案と理由を含む)

### 論点 1: 区切り線の既定の色をダークで切り替えるか

- **切り替える (採用)**: ライトは `#D9D9DE` のまま、ダーク用の値を足す
- **固定のまま (却下)**: ダークでも明るい線のまま (2026-09-26 の目視では「問題なし」)。却下の理由: 画像の既定の色に 2 組の仕組みを入れるのに区切り線だけ固定だと、ライブラリの既定の色の扱いが 2 通りになる。切り替える作業は小さい (iOS は既定の定数、Android は既定を選ぶ 1 か所)。配布前で、既定の見え方が変わって困る利用者がいない

### 論点 2: 画像の読み込み中・失敗の色を両プラットフォームでどうそろえるか

- **両プラットフォームとも同じ値の 2 組をライブラリが持つ (採用)**: iOS は OS の灰色を借りるのをやめて自前の値を持つ。Android はライトの値も変わる。両プラットフォームで同じ定数としてテストに固定でき、区切り線と同じ扱いになる。iOS で OS の「コントラストを上げる」設定に合わせた灰色の変化はなくなる (区切り線は今も固定値で同じ状態)
- **Android にダークの値を足すだけ (却下)**: ライトの見え方は変わらないが、両プラットフォームの値が違うまま残り、値をテストで固定できるのが Android だけになる
- **Android を iOS の値に合わせ、iOS は OS の灰色のまま (却下)**: 見た目はほぼそろうが、値が同じであることをテストで保証できず、iOS だけ別の扱いになる

### 論点 3: Android が表示モードを何で判定するか

iOS は trait で UIKit が解決するため、決めるのは Android だけ。

- **端末の表示モード (`isSystemInDarkTheme()`) (採用)**: スクロールインジケータと同じ判定。KsSettingsView の Compose の入口とも同じ。アプリが Material のテーマを使っていなくても正しく動く (android/ADR-0003 の前提は「material3 を使っているかは問わない」)。Sample の外観の切り替え (Configuration の `uiMode` の上書き) にも追随する
- **アプリの Material テーマの明るさ (却下)**: アプリ内だけでテーマを切り替えるアプリには追随するが、Material のテーマを使わないアプリでは端末がダークでも常にライトと判定される。iOS に対応するものがない
- **端末の表示モード + 利用者が表示モードを渡せる入口 (今回は採らない)**: Android だけの公開 API が 1 つ増える。必要になったら後から足せる

### 論点 4: 既定の色の値の出どころ

- **iOS の標準の灰色の値 (採用)**: KsSettingsView と同じ出どころ。iOS の画像の見え方が今と変わらず、変わるのは Android のライトがわずかにだけ。区切り線のダークは KsSettingsView と同じ値になる。区切り線のコントラスト比 (計算値) は、ライト (白の上の `#D9D9DE`) が約 1.41、ダーク (Sample のダークのセル `#182236` の上の `#38383A`) が約 1.36 で控えめさがそろう。今のまま (`#182236` の上の `#D9D9DE`) は約 11.3
- **Material の灰色 (却下)**: Android の今のライトの値を両プラットフォームで使い、ダークは Material の灰色から選ぶ。iOS の画像の色が変わり、KsSettingsView とも違う値になる
- **Sample のダークの配色に合わせる (却下)**: 区切り線のダークを Sample のトークン `#2A3752` などにする。Sample にはぴったり合うが、紺寄りの値で、灰色基調のアプリでは青みが浮く

### 論点 5 (置き場所): タップしたときの色の意味の違いをどこで扱うか

- **この change で一緒に扱う (採用、オーナー判断)**: 「リスト」の画面で区切り線とタップを同じ目視で確かめられ、提案・レビュー・蒸留が 1 回で済む。2026-09-27 の決定のまま
- **別の change に分ける (却下)**: 決めることが別 (指定しないときの色 / 指定した色の意味) で調べものも残っていたため分ける案を推奨したが、オーナーが一緒に扱うと判断した

### 論点 5 (方向): タップしたときの色の意味をどうするか

- **意味は今のままにし、文書を事実に直して Sample は両プラットフォームに同じ値を渡す (採用)**: 統一の動機だった「同じ値だと Android で見えない」が成り立たない見込み。各プラットフォームの標準の部品を保って濃さの違いを受け入れるのは core/ADR-0035 と同じ考え方。ライブラリのコードを変えない。弱点: 同じ 15% を渡しても濃さは少し違う (iOS 15%、Android 約 8〜10%)。不透明な色を渡すと iOS だけ中身が隠れる
- **両プラットフォームとも渡した色の濃さで塗る — Android を変える (却下)**: 利用者が濃さも決められるが、Android のタップの反応を自前で組み直す。波紋を残すと OS の係数 (約 0.83 倍) が残り、頼る API は形が変わりつつある
- **両プラットフォームとも色みだけ指定、濃さは約 10% — iOS を変える (却下。目視で違いが気になったときの次の候補)**: iOS で濃さを決められなくなり、iOS の 10% は標準の値ではなくライブラリが決めた値になる

### 論点 6: 起票後に見つかったものの扱い

- **Android の並べ替えの持ち上げの影**: この change では直さない。既定の色ではなく持ち上げの見せ方の話で、ダークでの見え方を誰も見ていない。この change のダークの目視のついでに「並べ替え」を見てもらい、気になれば簡易起票する
- **読み込み中のインジケータの既定の色 — core/ADR-0035 のまま (採用)**: core/ADR-0035 が「指定しないときは固定のグレーでそろえる」案を却下した理由 3 つのうち、「ライト / ダーク 2 組の値と表示モードを判定する仕組みが要る」はこの change で成り立たなくなる。残る 2 つ (指定しない一覧の見え方が変わる・色がライブラリ独自になる) は今も成り立つ。インジケータと Pull to Refresh は OS / Material の標準の部品で、アプリのテーマの色に合わせて出るのが自然
- **core/ADR-0035 を改めて、既定を固定のグレー 2 組にする (却下)**: 指定しなくても 3 つがそろい両プラットフォームで同じ値になるが、テーマの色から外れてライブラリ独自の色になる。iOS の Pull to Refresh は標準の部品が色を薄く描くので同じ値にはそろわない。変更がページングの表示にも広がる

## 決定事項

- **前提** (オーナー指示、2026-10-06): KsSettingsView のやり方 (ライブラリがライト / ダーク 2 組の既定の色を持ち、未指定のときだけ表示モードで解決する。利用者が指定した色には触らない) を骨格にする
- **論点 1** (2026-10-06): 区切り線の既定の色は、ライトは `#D9D9DE` のまま、ダークでは暗い色に切り替える (値は論点 4)。利用者が色を指定したときは表示モードで変えない
- **論点 2** (2026-10-06): 画像の読み込み中・失敗の表示の既定の色 (読み込み中・失敗の下地・失敗の印) は、両プラットフォームとも同じ値のライト / ダーク 2 組をライブラリが持つ。iOS は OS の色の参照をやめる。失敗の印の形の違い (iOS は写真のアイコン、Android は四角と丸) は色の話ではないため、この change では扱わない
- **論点 3** (2026-10-06): Android の既定の色は端末の表示モード (`isSystemInDarkTheme()`) でライト / ダークを選ぶ。Compose の中だけでテーマを切り替えるアプリ (端末はライトのままアプリ内でダークにする作り) では既定の色がアプリの見た目とずれるので、区切り線は色を指定し、画像は読み込み中・失敗の表示を差し替えてもらう (スクロールインジケータで受け入れ済みの制限と同じ)。利用者が表示モードを渡せる入口は足さない。(提案の相方レビューで、判定元の言い方を「画面の構成の夜間モード。通常は端末の表示モードに追随し、アプリが画面の構成を上書きしたときはその値。Material の配色だけの切り替えには追随しない」に正した。使う判定は同じ `isSystemInDarkTheme()` で、決定の中身は変わらない)
- **論点 4** (2026-10-06): 値は iOS の標準の灰色から取る。候補は次の表。iOS の値は公表値なので、提案の段階で iOS シミュレータで実測して確かめる。最終の値はモックをオーナーが見て確定する。Sample のダークでは Sample 自身の区切り線のトークン (`#2A3752`) と違う値になり、線が少し無彩色に見える可能性がある (モックで確かめる)

  | 何の色か | ライト | ダーク | 出どころ |
  |---|---|---|---|
  | 区切り線 | `#D9D9DE` (今のまま) | `#38383A` | iOS のダークの区切り線の不透明な値 (KsSettingsView と同じ) |
  | 画像の読み込み中 | `#E5E5EA` | `#2C2C2E` | iOS の systemGray5 |
  | 画像の失敗の下地 | `#D1D1D6` | `#3A3A3C` | iOS の systemGray4 |
  | 画像の失敗の印 | `#8E8E93` | `#8E8E93` | iOS の systemGray |

- **論点 5 の置き場所** (2026-10-06): タップしたときの色の意味の違いは、この change で一緒に扱う
- **論点 5 の方向** (2026-10-06): タップしたときの色の意味は今のままにする (iOS は渡した色をそのまま塗る、Android は標準の波紋に渡す)。ライブラリのコードは変えない。この change で行うのは次の 3 つ
  - 提案の段階で、エミュレータで実測する: Android にアクセント色の 15% と不透明なアクセント色を渡し、押している間の見え方が同じであること。**読みが外れていたら (15% が見えなかったら) この論点を決め直す**
  - Sample「リスト」は両プラットフォームに同じ値を渡す (値は目視で決める。候補はアクセント色の 10〜15%)
  - 公開 API のドキュメントコメント (iOS `.touchFeedback(color:)`、Android `touchFeedbackColor`) に、濃さの決まり方を書く
- **論点 6** (2026-10-06): Android の並べ替えの持ち上げの影はこの change では直さない (ダークの目視のついでに見て、気になれば簡易起票)。読み込み中のインジケータの既定の色は core/ADR-0035 のまま変えない (改訂しない)
- **論点 7** (2026-10-06): 外部の利用者がまだいないため、既定の見え方が変わることの告知や互換の手当てはしない

長命層の追随 (実装の作業ではなく蒸留で行う):

- 蒸留時に反映: `kasane/concepts/core/styling/collection-layout.md`・`kasane/concepts/ios/architecture/collection-engine.md`・`kasane/concepts/android/architecture/compose-wrapper.md` — 区切り線の既定の色を「固定値」と書いている箇所を、ライト / ダーク 2 組に改める。Android の表示モードの判定元の記述に、区切り線と画像の既定の色も端末の表示モードで選ぶことを足す
- 蒸留時に反映: `kasane/concepts/core/core-model/image-loading.md` — 画像の既定の表示の色がライト / ダーク 2 組で、両プラットフォームで同じ値であること
- 蒸留時に反映: `kasane/concepts/core/core-model/collection-interaction.md` の「既知の非対称」— 「不透明度を掛ける」「見えなくなる」を事実 (不透明度は置き換わる) に直し、「統一の方向は未決」を core/ADR-0037 の決定に置き換える
- 蒸留時に反映: android/ADR-0003 の footer に `関連: core/ADR-0037` を足す (本文は変えない)。core/ADR-0010 の frontmatter に `amended-by: 0036` を足し、index の行に「一部改訂: 0036」を書く (core/ADR-0036 の昇格と同時)
- 蒸留時に反映: 利用者への案内の原料として concepts に書く — Android でアプリの中だけでテーマを切り替えるアプリは色を指定する (区切り線) / 表示を差し替える (画像) こと、タップの色は両プラットフォームで近い見え方にしたいとき半透明の色を渡すこと

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

- 作成済み: core/ADR-0037 (proposed) 「タップしたときの色は両プラットフォームで意味をそろえず、濃さの決まり方を各プラットフォームの標準の部品に任せる」。論点 5 の決定。android/ADR-0003 の帰結にあった「統一は後続の変更で扱う」に対する決定で、ADR-0003 の Decision は置き換えない (関連のみ)。前提 (波紋は渡した色の不透明度を使わない) はエミュレータの実測で確かめる
- 作成済み: core/ADR-0036 (proposed) 「ライブラリが値を持つ既定の色はライト / ダーク 2 組の固定値にし、利用者が指定しないときだけ表示モードで選ぶ」。core/ADR-0010 の色の項だけを置き換える amends。論点 1・2・3 の決定をまとめた。core/ADR-0010 が semantic color を却下した理由 (両プラットフォームで同じ実値の比較が成り立たない) は 2 組の固定値でも保たれる。論点 6 で読み込み中のインジケータを対象に入れないと決まり、下書きの「標準の部品に任せている表示は対象にしない」のままで合う

## 未決の論点

探索中 (2026-10-06 開始)。論点の番号は探索の間固定する。

1. (決定済み — 決定事項を参照)
2. (決定済み — 決定事項を参照)
3. (決定済み — 決定事項を参照)
4. (決定済み — 決定事項を参照。最終の値はモックで確定)
5. (決定済み — 決定事項を参照。経緯: `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md` (申し送り) → `kasane/roadmaps/v1-foundation/phases/phase-5-paging-state-machine/history.md` (2026-09-27: タップの色の意味の違いを扱う場所)。エミュレータの実測で前提が崩れたら決め直す)
6. (決定済み — 決定事項を参照)
7. (決定済み — 決定事項を参照)

論点はすべて決定済み。提案の段階へ持ち越す確認は次のとおり (最初の 3 つは提案の段階で確かめた。結果は `evidence/proposal-probes.md`。Android の波紋は読みどおりで、論点 5 の決定はそのまま。区切り線の候補 `#38383A` は iOS 26 までの OS の値で、iOS 27 では OS の値が変わっていると分かった)。

- iOS の標準の灰色の値 (論点 4 の表) を iOS シミュレータで実測して確かめる
- Android の波紋が渡した色の不透明度を使わないこと (core/ADR-0037 の前提) をエミュレータで実測して確かめる。外れていたら論点 5 を決め直す
- iOS の画像の既定の表示は SwiftUI で描いている。表示モードで変わる `UIColor` を SwiftUI の色として使ったときに、表示中の切り替えへ追随することを確かめる
- Android の画像の読み込み中の色は 2 か所で描いている (Composable と描画の段階のノード)。どちらも表示モードの切り替えに追随させる
- モックで確かめる: Sample のダーク (紺寄りの配色) の上で、区切り線の `#38383A` が無彩色に浮いて見えないか
- オーナーの目視の対象: 「リスト」(区切り線の「既定」・タップの反応)、「画像グリッド」(読み込み中)、画像の失敗の表示、「並べ替え」(持ち上げの影。参考) を、両プラットフォーム × ライト / ダークで

## UI 素材 (ui/references/ の一覧と注釈)

なし (チャットに貼られた画像は無い)。見た目の基準は論点 4 の値の表で、提案のモックで確定する。

## 変更級の推奨: M (理由)

M で確定 (オーナー、2026-10-06)。提案は ksn-propose で作る。

- 触る能力: 区切り線の既定の色、画像の読み込み中・失敗の既定の表示、タップしたときの色 (文書・Sample・コメントだけ)。両プラットフォームと両 Sample
- 公開 API: 型・名前・引数の変更は無い。指定しないときの見え方が変わる (ダークの区切り線と画像、Android のライトの画像の灰色がわずかに)
- 可逆性: 高い (定数と既定の選び方の変更)
- UI: あり (色)。モックの承認で値を確定する
- ADR: core/ADR-0036 (core/ADR-0010 の一部改訂)、core/ADR-0037 (どちらも proposed)
- 能力が 3 つにまたがる点は L の基準にも当たるが、どれも定数と既定の選び方の変更で、設計書が要る深さではない
