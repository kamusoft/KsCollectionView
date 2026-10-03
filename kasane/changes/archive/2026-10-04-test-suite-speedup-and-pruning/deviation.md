# Deviation: test-suite-speedup-and-pruning

- 仕分け表の P3 (Paging / 最初の読み込み中の表示): 決定事項では「消す」→ 指示により残す (UI テストは 11 件)。理由: 表の根拠の本体テスト (`ios/Tests/KsCollectionViewTests/KsPagingDisplayTests.swift:367-389`) は、読み込み中の表示が読み上げの要素として出ることを覆っておらず、コメントで UI テストに委ねると書いている。(2026-10-04)
- 蒸留時に反映: handbook・`kasane/handbook/cross/test-execution.md` — 通常スキームに iOS Sample のユニットテスト (`KsCollectionViewSamplesTests`) が加わったことと、件数の読み方 (ユニットテスト + UI テスト)。実測の内訳 (合計 339 秒)
