# core — 概念一覧

全 platform が共有する契約。カテゴリ定義は [../rules.md](../rules.md)。

## core-model/

- [core-model/collection-items.md](core-model/collection-items.md) — KsCollectionView が受け取るプレーンな配列・安定 ID・テンプレートキー・グループの値の契約と、配列差し替え時の再描画とアニメーション (グループをまたぐ差分・端への挿入)、親の状態をテンプレートで読む条件 (iOS / Android 共通)
- [core-model/collection-paging.md](core-model/collection-paging.md) — ページング (5 状態・次ページ要求・しきい値) と Pull to Refresh の公開契約: 発火の条件と待ち方・6 つの表示の置き場と差し替え口・差し替え時の表示範囲の置き方・安全領域・利用者の VM が守る書き方 (iOS / Android 共通)
- [core-model/collection-interaction.md](core-model/collection-interaction.md) — onItemTap / onItemLongTap / touchFeedback の発火規則と KsScrollController の順序保証・位置指定の意味 (iOS / Android 共通)
- [core-model/image-loading.md](core-model/image-loading.md) — prefetchResources による画像の先読み (到達点・表示幅・任意キー・取り消し・共有キャッシュ)、KsImage の表示契約 (許容範囲での引き当て)、KsImageCache のキャッシュ操作の契約と限界 (iOS / Android 共通)

## styling/

- [styling/collection-layout.md](styling/collection-layout.md) — layout 値 (list / grid・列数)・余白と contentPadding・区切り線・ヘッダー/フッター・グループの見出しと固定・安全領域 (重ねる表示を含む)・content 配置・行の高さ変化・スクロールインジケータ (iOS / Android 共通)
