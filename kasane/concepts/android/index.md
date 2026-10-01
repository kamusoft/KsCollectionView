# android — 概念一覧

Android 固有の公開 API・ラッパーの契約。カテゴリ定義は [../rules.md](../rules.md)。

## architecture/

- [architecture/compose-wrapper.md](architecture/compose-wrapper.md) — Compose LazyVerticalGrid の薄いラッパーとして項目モデル・グループ・レイアウト・操作の契約を実現する部品の責務境界と、実測で確かめた罠対策
- [architecture/paging-wrapper.md](architecture/paging-wrapper.md) — ページングと Pull to Refresh の契約を、判定の部品・グリッドに重ねる表示・Modifier.pullToRefresh で実現する部品の責務境界と罠対策
- [architecture/reorder-wrapper.md](architecture/reorder-wrapper.md) — 並べ替えの契約を Compose ラッパーの上で自前のドラッグとして実現する部品の責務境界と、ジェスチャ・行き先の決め方・持ち上げの層・pin・自動スクロール・ドラッグ中に届いた配列の保留・読み上げで避けている罠
- [architecture/image-pipeline.md](architecture/image-pipeline.md) — 画像の先読みと KsImage の契約を Coil 3 の上で実現する部品の責務境界と、先読み窓・鍵の付随情報・画面に出る時点の照会し直しで避けている罠
