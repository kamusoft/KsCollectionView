# セクション / グループ化

sticky ヘッダ付きグループ化と、画面向きで列数が変わる可変グリッド (自社実績機能)。両プラットフォーム。

## 論点

- セクションモデル: 安定セクション ID・header/footer の契約
- sticky ヘッダ: iOS は Compositional Layout の pinned、Android は `stickyHeader` — **グリッドでの sticky 可否が未確定** (`LazyGridScope` に stickyHeader が無い可能性。全幅ヘッダ + 非固定への縮退も検討)
- 画面向き可変グリッド: ポートレイト/ランドスケープでの列数切替の宣言方法と、回転時のスクロール位置維持
- ソート連携の吸収: データ層並べ替え + 差分 move アニメ (iOS diffable / Compose `animateItem`) の確認をこのフェーズで行うか
- グループ変更時の差分更新 (旧実装は Android で full reset だった — 作り直し対象)

### phase-1 からの申し送り (2026-09-01)

- レイアウトは単一コンポーネント + `layout` 値で確定 (core/ADR-0006)。本フェーズの拡張は「セクションごとに layout 値を付与する」形で同じ語彙に乗せる
- 旧語彙の申し送り (core/ADR-0009) — グループ化系: `IsGroupingEnabled` / `GroupHeaderTemplate` / `GroupHeaderHeight` / `IsGroupHeaderSticky` (旧 iOS のみ → 両対応が論点)
- 旧語彙の申し送り (core/ADR-0009) — 余白系: `GroupFirstSpacing` / `GroupLastSpacing` / `BothSidesMargin` / `SpacingType` は contentPadding / spacing の流儀へ簡素化する方向
- ソート連携は DSL 追加なしで確定 (データ層並べ替え + 自動差分 move — core/ADR-0003)。本フェーズでは差分 move アニメの動作確認のみ

### phase-2 からの申し送り (2026-09-03)

- list の区切り線は「先頭行の上端 + 全セルの下端」に全幅で描く規則 (ios-engine-foundation deviation.md)。セクションが入ると前セクション末尾の下線と次セクション先頭の上線が二重になるため、セクション境界での規則を決める
- 区切り線はセル bounds の底辺に描かれ、幅はセル幅 (`contentPadding` の分だけ内側に寄る)。`rowSpacing > 0` の list では線が行間の中央ではなく各行の直下に出る。セクション単位の余白・装飾を設計する際にこの見え方を含めて決める

### phase-3 からの申し送り (2026-09-05)

- 区切り線は両プラットフォームとも content の前面に描く (core/ADR-0010 accepted)。Android は項目単位の `drawWithContent`、iOS はセルのサブビューで、いずれも「行間に区切り線用の item / decoration を挿入する」形ではない。セクション境界の装飾はこの前提 (項目単位の描画) の上で設計する
- Android の `LazyVerticalGrid` は `stickyHeader` を持つ (Foundation 1.8 以上、android/ADR-0001)。論点「グリッドでの sticky 可否が未確定」の Android 側はこれで解ける

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
