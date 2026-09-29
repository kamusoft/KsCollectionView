# ios — 概念一覧

iOS 固有の公開 API・エンジンの契約。カテゴリ定義は [../rules.md](../rules.md)。

## architecture/

- [architecture/collection-engine.md](architecture/collection-engine.md) — UICollectionView + diffable + UIHostingConfiguration で項目モデル・グループ・レイアウト・操作の契約を実現する部品の責務境界と、実測で確かめた罠対策
- [architecture/paging-engine.md](architecture/paging-engine.md) — ページングと Pull to Refresh の契約を、判定の部品・重ねる表示の入れ物・安全領域の分だけ下げた UIRefreshControl で実現する部品の責務境界と罠対策
- [architecture/image-pipeline.md](architecture/image-pipeline.md) — 画像の先読みと KsImage の契約を Nuke の上で実現する部品の責務境界と、索引・引き当て・世代付き識別子で避けている罠
