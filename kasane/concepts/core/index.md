# core — 概念一覧

全 platform が共有する契約。カテゴリ定義は [../rules.md](../rules.md)。

## core-model/

- [core-model/collection-items.md](core-model/collection-items.md) — KsCollectionView が受け取るプレーンな配列・安定 ID・テンプレートキーの契約と、配列差し替え時に何が再描画されるか
- [core-model/collection-interaction.md](core-model/collection-interaction.md) — onItemTap / onItemLongTap / touchFeedback の発火規則と KsScrollController の順序保証

## styling/

- [styling/collection-layout.md](styling/collection-layout.md) — layout 値 (list / grid・列数・向き別列数)・スペーシング・contentPadding・区切り線・ヘッダー/フッター・自己サイズの契約
