# Deviation: android-scrollbar-parity

- 決定事項「位置と長さは `LazyGridState.scrollIndicatorState` の値をそのまま使う」: exploration では値をそのまま使う → 実装では位置 (`scrollOffset`) だけを補正する。上側の `contentPadding` の領域に前の行が見えている間、公式の値は先頭の行番号を見えている最初の行から、ずれを余白の境目にかかる項目から取るため 1 行分小さく出る (末尾で下端に届かず、送る途中で 1 行ごとに逆戻りする)。その食い違いの分だけ、見えている行どうしの実際の距離で補う (`ksAlignedScrollOffset`)。長さ (`contentSize`) は公式の値のままで、行の高さの記録・推定 (論点 3 の c) は作らない。余白が無いときは公式の値そのもの。理由: review-001 の Major (余白のある画面で端に届かない)。オーケストレーターの判断で決定の範囲内として扱い、基準機確認の後にオーナーへ報告し、了承を得た (2026-09-24)
