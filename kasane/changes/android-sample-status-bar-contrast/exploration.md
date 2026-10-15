# Exploration: android-sample-status-bar-contrast

## 課題 / 動機

Android の Sample で、ライトの表示のときに、画面の上端の時刻と電波・電池のアイコンが白で描かれ、明るい背景の上でほとんど見えない。iOS の Sample は黒で描かれ、はっきり見える。

変更 `user-docs` のタスク 4.3 (README のスクリーンショットの撮影) で見つけた (2026-10-10)。撮るときに時刻を固定する設定を外しても、同じ表示だった。ルートの README に載せた Android の 3 枚 (`assets/android-list.png`・`android-grid.png`・`android-grouping.png`) に、この表示のまま写っている。

`user-docs` は Sample を変えないと決めていた (proposal の Non-Goals) ので、オーナーの判断で、画像はそのまま載せ、Sample の表示は本 change で扱うことにした (2026-10-10)。

## 検討した選択肢 (却下案と理由を含む)

## 決定事項

## ADR 候補

## 未決の論点

- 未探索 (簡易起票)
- 原因はどこか (Sample が画面を端まで広げる設定で、上端のアイコンの明暗を指定していない見込み。確かめていない)
- ダークの表示と、実機での見え方 (確かめていない)
- 直した後に、README の Android の 3 枚を撮り直す (撮り方は `user-docs` の証跡 `evidence/readme-and-screenshots.md`。archive 後は `kasane/changes/archive/*-user-docs/evidence/`)
- ライブラリの本体の問題ではないことの確認 (利用者のアプリで同じことが起きないか)
- 撮り直すときに、iOS の 3 枚 (`assets/ios-list.png`・`ios-grid.png`・`ios-grouping.png`) も、メニューからたどって開いた状態で撮り直す。今の iOS の 3 枚は画面を直接開いて撮ったので、戻るボタンが写っておらず、Android の 3 枚 (戻る矢印が写っている) と揃っていない (2026-10-10、`user-docs` の検収でのオーナーの決定: 今回は今の 6 枚のまま進め、Android を撮り直すときに揃える)

## UI 素材

## 変更級の推奨

未判定 (Sample だけの修正で済むなら S)
