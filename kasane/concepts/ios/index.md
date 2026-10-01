# ios — 概念一覧

iOS 固有の公開 API・エンジンの契約。カテゴリ定義は [../rules.md](../rules.md)。

## architecture/

- [architecture/collection-engine.md](architecture/collection-engine.md) — UICollectionView + diffable + UIHostingConfiguration で項目モデル・グループ・レイアウト・操作の契約を実現する部品の責務境界と、実測で確かめた罠対策
- [architecture/paging-engine.md](architecture/paging-engine.md) — ページングと Pull to Refresh の契約を、判定の部品・重ねる表示の入れ物・安全領域の分だけ下げた UIRefreshControl で実現する部品の責務境界と罠対策
- [architecture/reorder-engine.md](architecture/reorder-engine.md) — 並べ替えの契約を UIKit 標準の並べ替え (差分データソースの並べ替えハンドラ + ドラッグ & ドロップの delegate) として実現する部品の責務境界と、隙間の予測・確定位置のずれ・戻し方・置く絵の影・上端の自動スクロール・読み上げの部品で避けている罠
- [architecture/image-pipeline.md](architecture/image-pipeline.md) — 画像の先読みと KsImage の契約を Nuke の上で実現する部品の責務境界と、索引・引き当て・世代付き識別子で避けている罠
