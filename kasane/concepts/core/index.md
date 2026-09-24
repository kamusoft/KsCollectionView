# core — 概念一覧

全 platform が共有する契約。カテゴリ定義は [../rules.md](../rules.md)。

## core-model/

- [core-model/collection-items.md](core-model/collection-items.md) — KsCollectionView が受け取るプレーンな配列・安定 ID・テンプレートキーの契約と、配列差し替え時に何が再描画されるか、親の状態をテンプレートで読む条件 (iOS / Android 共通)
- [core-model/collection-interaction.md](core-model/collection-interaction.md) — onItemTap / onItemLongTap / touchFeedback の発火規則と KsScrollController の順序保証・位置指定の意味 (iOS / Android 共通)
- [core-model/image-loading.md](core-model/image-loading.md) — prefetchResources による画像の先読み (到達点・表示幅・任意キー・取り消し・共有キャッシュ)、KsImage の表示契約 (許容範囲での引き当て)、KsImageCache のキャッシュ操作の契約と限界 (iOS / Android 共通)

## styling/

- [styling/collection-layout.md](styling/collection-layout.md) — layout 値 (list / grid・列数・向き別列数)・スペーシング・contentPadding・区切り線・ヘッダー/フッター・content 配置・行の高さ変化の契約 (iOS / Android 共通)
