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
- 旧語彙の申し送り (core/ADR-0009): `IsGroupingEnabled` / `GroupHeaderTemplate` / `GroupHeaderHeight` / `IsGroupHeaderSticky` (旧 iOS のみ → 両対応が論点)。`GroupFirstSpacing` / `GroupLastSpacing` / `BothSidesMargin` / `SpacingType` は contentPadding / spacing の流儀へ簡素化する方向
- ソート連携は DSL 追加なしで確定 (データ層並べ替え + 自動差分 move — core/ADR-0003)。本フェーズでは差分 move アニメの動作確認のみ

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
