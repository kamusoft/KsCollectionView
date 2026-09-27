# Exploration: library-default-colors-dark-mode

## 課題 / 動機

ライブラリ本体の既定の色の一部が、表示モード (ライト / ダーク) に追随しない、またはダークでだけ両プラットフォームで食い違う。`sample-dark-mode-toggle` で Sample にライト / ダークの切り替えを入れた際、ダークで Sample の配色が暗くなったことで見えるようになった (2026-09-26、オーナー指示で起票)。その change の探索で「ライブラリの既定の色の修正は別の change に切り出す」と決定済み (`kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/exploration.md` の決定事項)。

起票時点で分かっている問題 (コードを読んで確認。実物の見え方はオーナーの目視 = `sample-dark-mode-toggle` の tasks 5.4 の結果をこのメモに追記する):

- **区切り線の既定の色が固定**: 既定は `#D9D9DE` の固定値 (iOS `ios/Sources/KsCollectionView/KsHostingCell.swift:5-10`、Android `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsListSeparator.kt:13`)。ダークでも明るい灰色の線のまま描かれる。core/ADR-0010 で semantic color を却下して固定値にした決定 (プラットフォーム間で同じ実値にするため) で、ダークは考慮されていなかった。ただし 5.4 のオーナーの目視 (2026-09-26) では、ダークで明るい線のまま残る見え方は「問題なし」と判断された — 直すかどうかは探索で決める
- **画像の読み込み中・失敗の色がダークでだけ食い違う** (オーナーの目視で問題ありと確認済み、2026-09-26。Android の読み込み中の色がダークでも明るいまま — `kasane/changes/archive/2026-09-26-sample-dark-mode-toggle/evidence/owner-library-defaults-check.md`): iOS は OS の色 (`ios/Sources/KsCollectionView/KsImage.swift:330` の systemGray5、`:344` の systemGray4) でダークに追随する。Android は固定値 (`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:541-543` の読み込み中 `#E0E0E0`・失敗 `#BDBDBD`・印 `#757575`) でライトのまま。ライトの見え方がそろっていても、ダークでは両プラットフォームで違う色になる

参考: 表示モードに追随するもの — iOS のタップの反応 (`.systemFill`)、Android の既定の ripple (MaterialTheme に従う)、両プラットフォームのスクロールインジケータ (Android は `isSystemInDarkTheme()`)。`../KsSettingsView/` は同じ問題を別 change `2026-09-06-fix-default-colors-dark-appearance` で直し、ライブラリが light / dark 2 組の既定色を持つ形にした (`../KsSettingsView/kasane/decisions/core/` の ADR-0030)。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問は次のとおり。

- 区切り線の既定をライト / ダーク 2 組の固定値にするか (core/ADR-0010 の一部改訂)。ライブラリが表示モードを何で判定するか (iOS は trait、Android は `isSystemInDarkTheme()` か MaterialTheme か)
- 画像の読み込み中・失敗の色を両プラットフォームでどうそろえるか (iOS を固定 2 組に寄せるか、Android を追随させるか)。core/ADR-0010 と同じ「両プラットフォームで同じ実値」の方針を画像にも当てるか
- `sample-dark-mode-toggle` の 5.4 (オーナーの目視) で見つかる問題の追加
- 公開 API の既定値の変更になるため、利用者への影響 (ダークの既定の見え方が変わる) をどう扱うか
- **タップしたときの色 (`touchFeedbackColor`) の意味の違い** (2026-09-27、phase-5-paging-state-machine の議論でこの change に移すと決定): iOS は渡された色をそのままセル全面に塗り、Android は material3 の ripple が渡された色に自前で不透明度を掛ける (android/ADR-0003 の帰結)。同じ値を渡すと Android ではほとんど見えないため、Sample「リスト」は iOS にアクセント色の 15%、Android にアクセント色そのものを渡して見た目をそろえている (`kasane/changes/archive/2026-09-05-android-wrapper-foundation/deviation.md` 4 件目。sample-parity の統一課題として追跡中)。統一の方向 (iOS が不透明度を掛ける側に寄せる / Android が値をそのまま塗る / 語彙を分ける) を決めて Sample の値の一致を回復する。経緯: `kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md` (申し送り) → `kasane/roadmaps/v1-foundation/phases/phase-5-paging-state-machine/history.md` (2026-09-27: タップの色の意味の違いを扱う場所)

## UI 素材 (ui/references/ の一覧と注釈)

## 変更級の推奨

未判定 (暫定: M 以上。両プラットフォームの公開 API の既定値と core/ADR-0010 の改訂に触れるため)
