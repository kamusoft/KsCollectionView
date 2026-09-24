# ios — 概念一覧

iOS 固有の公開 API・エンジンの契約。カテゴリ定義は [../rules.md](../rules.md)。

## architecture/

- [architecture/collection-engine.md](architecture/collection-engine.md) — UICollectionView + diffable + UIHostingConfiguration による契約の実現方法と、実測で確かめた罠対策 (はみ出し・推定高さの最頻値・配列の内部の塊・表示位置の控え・画像の先読み・区切り線とタッチ feedback の揃え直しの契機)
