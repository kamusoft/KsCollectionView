# 検証: 行の高さ変化 — 遷移直後の 1 タップ目 (list / grid)

観測点は handbook/cross/runtime-behavior-verification.md の観測点表「検証: 行の高さ変化 (iOS 固有)」の
「遷移直後の 1 タップ目から開閉すること」。親 state 経路 (`observedValue(_:)` を宣言した経路) を実タッチで確認した。

- 環境: Simulator iPhone 17 Pro / iOS 26.5、Sample を Debug 構成でインストール
- 実施日: 2026-09-05
- 操作: シミュレータへの実タッチ入力 (座標指定)。各観測点で静止画を保存

## 手順と観測結果

| # | 経路 | 操作 | 観測結果 | 静止画 |
|---|---|---|---|---|
| 1 | list | `--verify-height-change` で起動 (画面が開いた直後) | 行 1〜5 がすべて折りたたみ表示 (「行 N の先頭」のみ) | `height-change-list-1-before.png` |
| 2 | list | 行 1 を 1 回タップ (遷移後の 1 タップ目) | 行 1 が展開し「行 1 本文 1〜4」が表示。以降の行が押し下がる | `height-change-list-2-expanded.png` |
| 3 | list | 行 1 をもう 1 回タップ | 行 1 が折りたたみ、初期表示と同じ高さへ戻る | `height-change-list-3-collapsed.png` |
| 4 | grid | 再起動後、レイアウトを grid へ切り替えた直後 | 2 列で行 1〜5 がすべて折りたたみ表示 | `height-change-grid-1-before.png` |
| 5 | grid | 行 1 を 1 回タップ (grid へ切り替えてからの 1 タップ目) | 行 1 が展開し「行 1 本文 1〜4」が表示。同じ段の行 2 は高さを保ち、次の段が押し下がる | `height-change-grid-2-expanded.png` |
| 6 | grid | 行 1 をもう 1 回タップ | 行 1 が折りたたみ、切り替え直後と同じ配置へ戻る | `height-change-grid-3-collapsed.png` |
| 7 | list | 通常起動 → ルートメニューから「検証: 行の高さ変化 (iOS 固有)」へ遷移し、その 1 タップ目 | 行 1 が展開 (画面遷移を挟む経路でも 1 タップ目から効く) | `height-change-navigation-list-expanded.png` |

## 判定

list と grid のどちらも遷移直後の 1 タップ目で展開し、次のタップで折りたたむ。追従に差は無く、
別起票の材料になる非対称は観測されなかった。

本文が行の上端より上へ出る症状も、展開・折りたたみのどちらの静止画でも観測されていない。
展開途中のアニメーションの見え方は静止画の射程外であり、ここでは判定していない。
