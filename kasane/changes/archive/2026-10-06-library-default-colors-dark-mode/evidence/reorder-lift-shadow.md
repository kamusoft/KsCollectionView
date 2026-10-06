# 並べ替えの持ち上げの影の見え方 (オーナーの目視用)

tasks 4.3 の準備として撮った画像である。影はこの変更で直していない (proposal の Non-Goals)。ダークでの見え方をオーナーが見て、気になれば別の変更として起票するための材料にする。

- 撮った状態: 両 Sample のデモ画面「並べ替え」で、Item 4 を長押しして持ち上げ、少し動かしたところ
- 環境: iOS は iPhone 17 (iOS 27.0) のシミュレータ、Android は Android 16 (API 36) のエミュレータ。どちらも作業専用に作り、撮影後に削除した (2026-10-06)
- 画像: `ios-reorder-lift-light.png`・`ios-reorder-lift-dark.png`・`android-reorder-lift-light.png`・`android-reorder-lift-dark.png`
- 見えたこと: ライトは両プラットフォームとも持ち上げた行の下に影が見える。ダークは影がほとんど見分けられない (行の下が少し暗い帯になる程度)
