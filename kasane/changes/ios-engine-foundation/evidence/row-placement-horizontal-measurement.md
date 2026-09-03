# 水平位置の実測 (KsRowContentPlacement)

機種: iPhone 17 Pro Simulator (iOS 26.5)。経路 B / list。

## 測定条件

`HeightChangeRowBody` を一時的に**幅を明示しない短い `Text`** へ差し替えて撮影した
(リポジトリ上の同ファイルは `行 N の先頭` を `.frame(maxWidth: .infinity)` 付きで描くため、
そのままでは幅いっぱいに広がり水平位置の差が出ない)。差し替えた内容:

```swift
Text("行 \(item.id)")
    .font(.headline)
    .padding(.vertical, SampleTheme.rowVerticalPadding)
    .background(SampleTheme.cell)
```

同一ビルドに一時フラグを入れ、配置規則だけを切り替えて 3 条件を比較した
(一時コードと一時テンプレートは測定後に撤去済み)。

## 3 条件の結果

| 条件 | 短い `Text` の水平位置 | 証跡 |
|---|---|---|
| Layout 非適用 (素の `UIHostingConfiguration`) | 中央 | `row-placement-horizontal-plain.png` |
| `KsRowContentPlacement` 初版 (先頭固定) | 先頭 (画面左端に密着) | `row-placement-horizontal-before.png` |
| `KsRowContentPlacement` 現行 (余白を等分) | 中央 | `row-placement-horizontal-after.png` |

Layout 非適用と現行の 2 枚は **PNG が 1 バイト単位で同一** (sha256 が一致) であり、
現行の配置は Layout が無かったときと画素レベルで同じ見え方になる。
初版だけが異なる。

これにより `KsRowContentPlacement` の doc コメントが宣言する
「素の `UIHostingConfiguration` と同じ見え方を保つ」は実測で裏付けられている。
