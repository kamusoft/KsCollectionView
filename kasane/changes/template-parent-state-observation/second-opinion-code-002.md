# セカンドオピニオン: template-parent-state-observation (code-002)
**相方**: codex / **label**: so-code-template-parent-state-observation / **日付**: 2026-09-05 / **対象**: 修正サイクル 1 後の作業ツリーの未コミット変更全体 (ios/Sources/KsCollectionView 3 ファイル・ios/Tests/KsCollectionViewTests 3 ファイル・samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift・deviation.md・evidence/)
---
# レビュー結果: template-parent-state-observation

**日付**: 2026-09-05  
**判定**: **APPROVED**

## サマリー

Critical / Major はありません。観測値と配列が同時に変化する経路は、存続する可視セルをsnapshotの再構成対象へ含める実装と、controller／SwiftUI統合テストの双方で修正されています。list / gridの実操作証跡も保存内容と静止画が一致しています。

ホスト側の本体91件・Sample 3件の全成功、lint違反0件を前提として確認しました。性能計測の見送りとtasks 4.1 / 4.2は合意済みのため指摘していません。

## 照合した規約

- ソースコメント規約（常時）
- Sampleのプラットフォーム間一致（iOS固有検証画面の例外）
- テスト実行規約
- 実行時挙動の検証規約
- iOS性能検証の手順と合格基準（見送りはdeviation記録済み）
- ローカル開発環境とSampleの実行
- ios/ADR-0001、ADR-0004、ADR-0006
- ios/ADR-0008（proposedのため参考所見のみ）
- core/ADR-0002

## 指摘事項

### [🟡 Minor] modifier未指定時のdocコメントが実装より広い挙動を保証している

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionView.swift:133`、`ios/Sources/KsCollectionView/KsCollectionConfiguration.swift:19`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:95`

**問題点**: コメントは、`observedValue`を指定しない場合に「更新／再評価が届くたび、表示中のセルを作り直す」と説明しています。しかし配列が変化する更新では、内容不変の既存セルは再構成されません。この挙動は `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:848`でも明示的に保証されています。

デルタスペックが保証する従来挙動は「配列が同値の場合」に限定されているため、実装ではなくコメントの射程が広すぎます。

**推奨修正**: 3箇所とも「配列が同値の更新が届くたび」「配列が同じままビューが再評価された場合」のように条件を限定してください。

例:

```swift
/// 渡さない場合は、配列が同じまま表示するビューが再評価されるたびに、
/// 表示中のセルの内容を作り直します。
```

## アクションプラン

1. 非ブロッキング修正として、modifier未指定時のコメントを同値配列経路に限定する。
2. その後、現在の実装を次工程へ進めてよい。

**件数**: Critical 0 / Major 0 / Minor 1 / Suggestion 0  
指定に従い、レビュー結果ファイルは作成していません。


## 突き合わせ結果 (ホスト review-002 との照合、2026-09-05)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| Minor: modifier 未指定時の doc コメントが「配列が変わる更新でも作り直す」と読める (KsCollectionView.swift:133 / KsCollectionConfiguration.swift:19 / KsCollectionViewController.swift:95) | Minor 1 (同趣旨、KsCollectionView.swift:133) | **確定 (Minor)** | 双方一致。spec の従来挙動は「配列が同値でも」に限定されており、コメントの射程を同値配列の更新に限定する。オーケストレーターが直接修正し、verify の独立文脈で確認する |

ホスト側のみの Suggestion 2 件は review-002.md のとおり (deviation への一言追記は本サイクルで対応、ADR-0006 Consequences への 1 行は蒸留へ申し送り)。未解決なし。両者 APPROVED。
