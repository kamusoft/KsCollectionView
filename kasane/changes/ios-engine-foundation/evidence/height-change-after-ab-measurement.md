# 中央配置はみ出し対策の A/B 実測

対象: 経路 B (テンプレート内 state) の list / grid で行を展開・折りたたみ。
機種: iPhone 17 Pro Simulator (iOS 26.5)。

同一ビルドに一時計測を入れ、`--no-top-align` の有無だけで配置規則を切り替えて比較した
(計測コードは測定後に撤去済み)。記録した値は、展開の遷移パスにおける
行の高さ (`bounds.h`) / content の自然高 (`natural.h`) / content の配置オフセット (`offsetY`)。

`offsetY` が負の値は、content が行の上端より上へはみ出していることを意味する。

## 修正前 (ホスト View 既定の中央配置)

```
bounds.h=44.333  natural.h=141.667  offsetY=-48.667   (list, 展開)
bounds.h=44.333  natural.h=141.667  offsetY=-48.667   (list, 展開 2 パス目)
bounds.h=44.333  natural.h=141.667  offsetY=-48.667   (grid, 展開)
bounds.h=44.333  natural.h=141.667  offsetY=-48.667   (grid, 展開 2 パス目)
```

行の高さが content のサイズ変化に 1 レイアウトパス遅れて追いつく間、
content は上方向へ 48.667pt はみ出す。これが「本文が一度上へ飛び出してから降りてくる」動きになる。

## 修正後 (KsRowContentPlacement による上端固定)

```
bounds.h=44.333  natural.h=141.667  offsetY=0.0       (list, 展開)
bounds.h=44.333  natural.h=141.667  offsetY=0.0       (list, 展開 2 パス目)
bounds.h=44.333  natural.h=141.667  offsetY=0.0       (grid, 展開)
bounds.h=44.333  natural.h=141.667  offsetY=0.0       (grid, 展開 2 パス目)
```

同一の遷移パス (行 44.333 / content 141.667) で、上方向のはみ出しが 0 になる。
`offsetY` が負になった回数は 修正前 4 / 修正後 0。

## 静止画 (遷移中のフレーム)

経路 B / list で行 2 を展開した瞬間のフレームを 1 条件 1 枚。

- 修正前: `height-change-after-ab-before-centered.png`
- 修正後: `height-change-after-ab-after-topaligned.png`

**この静止画だけでは修正前後を判別できない。** どちらも本文が薄く重なった同じ見え方になり、
上方向のはみ出しは 60fps の撮影では 1 フレームにも定着しなかった。修正の裏付けは上の `offsetY` の実測値
(-48.667 → 0.0、負になった回数 4 → 0) が担い、静止画は遷移が起きている区間そのものの記録として置く。
