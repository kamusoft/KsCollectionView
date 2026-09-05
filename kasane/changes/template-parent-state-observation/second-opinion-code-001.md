# セカンドオピニオン: template-parent-state-observation (code-001)
**相方**: codex / **label**: so-code-template-parent-state-observation / **日付**: 2026-09-05 / **対象**: 作業ツリーの未コミット変更全体 (ios/Sources/KsCollectionView 3 ファイル・ios/Tests/KsCollectionViewTests 3 ファイル・samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift)
---
# レビュー結果: template-parent-state-observation

**日付**: 2026-09-05  
**判定**: **CHANGES_REQUESTED**

## サマリー

同値配列だけが更新される主要経路は実装・テストされていますが、配列と観測値が同時に変わる Scenario では既存セルが古い表示のまま残ります。また、完了済みになっている実行時確認と、必須の iOS 性能検証について証跡が不足しています。

提示された本体 89 tests / 0 failures、Sample 3 tests / 0 failures は前提として受け入れ、指定どおり再実行していません。

## 照合した規約・決定

- ソースコメント規約（always）
- Sample のプラットフォーム間一致（iOS 固有の技術検証画面として例外適用）
- テスト実行規約
- 実行時挙動の検証規約
- iOS 性能検証の手順と合格基準
- ローカル開発環境と Sample の実行（guide）
- ios/ADR-0001、ADR-0004、ADR-0006（accepted）
- ios/ADR-0008（proposed。これ自体を必須判断の根拠にはしていない）
- core/ADR-0002（accepted）

## 指摘事項

### [🟠 Major] 配列と観測値が同時に変わると既存の可視セルが再構成されない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:127`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:367`、`ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:984`

**問題点**: `rebuildsVisibleCellContent` は `rebuildingVisibleCellContentOnEqualItems` として渡され、`items == appliedItems` の早期 return 経路でしか使われません。

例えば観測値を変更すると同時に項目を追加すると、snapshot 計画は追加項目と内容が変わった項目だけを処理します。項目自体が同値の既存セルは再構成されないため、観測値に依存する表示が古いまま残ります。その後は新しい観測値が `self.configuration` に保存済みなので、同じ値で再評価されても修復されません。

これは `specs/collection-core/spec.md:28` の「配列の変化と観測する値の変化が同時に届く」Scenario に反します。現在のテストは最初の更新で追加項目しか確認せず、観測値を元に戻す2回目の更新後に既存セルを確認しているため、不具合を検出できません。

**推奨修正**: 観測値の変化を配列変更経路にも引き渡し、削除・reload 対象を除いた既存の可視識別子をsnapshotの再構成対象へ加えるか、snapshot完了後に最新構成で可視セルを再構成してください。併せて、項目追加と観測値変更を同時に行った最初の更新直後に、既存セルの内容が更新されたことを確認する回帰テストを追加してください。

概念的には次の対象集合になります。

```swift
reconfigureTargets =
    plan.reconfigure
    + (observedValueChanged ? survivingVisibleIdentifiers : [])
    - reloadTargets
```

### [🟠 Major] list / grid の実操作確認を完了済みとする証跡がない

**該当箇所**: `kasane/changes/template-parent-state-observation/tasks.md:15`、`kasane/changes/template-parent-state-observation/evidence/transaction-spike.md:3`

**問題点**: task 3.2 は、画面遷移直後の1タップ目から、list / grid の両方で展開・折りたたみが動き、両者に追従差がないことを確認済みにしています。

しかし保存されている証跡は、親 state 経路の行1を1回タップしたトランザクションspikeだけです。gridへの切り替え、折りたたみ、list / grid間の差の確認は記録されていません。提示されたホスト側結果もSampleのビルドと画面起動までであり、実操作の完了を裏付けません。これは実行時挙動の検証規約が要求する「修正後の同一手順による解消確認とchange配下の証跡」を満たしていません。

**推奨修正**: 新規遷移直後から実タッチで、list / gridそれぞれについて最初のタップによる展開と次のタップによる折りたたみを確認してください。行の状態・高さなど判断可能な観測値と、両経路に差がないという判定をsanitize済みの証跡として保存してください。未実施ならtask 3.2を未完了へ戻してください。

### [🟠 Major] snapshot／セル再構成経路の変更に必須の性能検証がない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:359`、`kasane/handbook/ios/performance-verification.md:17`、`kasane/changes/template-parent-state-observation/tasks.md:23`

**問題点**: 今回は可視セルの内容再構成とsnapshot適用の分岐を変更しており、性能検証規約の適用範囲に明確に該当します。同規約は、描画・再利用・レイアウト経路に触れる変更について、hitch time ratioとメモリ定常化の両方を必須としています。

現在のtasksには性能検証項目がなく、`evidence/` にもトランザクションspike以外の計測結果がありません。通常テストの成功だけではこの完了条件を代替できません。

**推奨修正**: Major 1の修正後に固定10,000件fixtureで、実機のhitch time ratioを独立3試行、Simulatorのメモリ定常化を独立2実行で計測し、環境・各値・判定を保存してください。iPhone 11相当を使用できず高速な代替機を使う場合は、基準機相当の保証にならないことを証跡に明記してください。

## アクションプラン

1. 配列変更と観測値変更の同時更新でも、既存の可視セルを再構成する。
2. 最初の同時更新直後を検証するengine／SwiftUI統合回帰テストを追加する。
3. list / grid両方の展開・折りたたみを実タッチで確認し、証跡を保存する。
4. 修正後の最終コードでiOS性能検証を実施する。
5. 全テストを再実行し、件数まで再確認する。

**件数**: Critical 0 / Major 3 / Minor 0 / Suggestion 0  
指定に従い、レビュー結果ファイルは作成していません。


## 突き合わせ結果 (ホスト review-001 との照合、2026-09-05)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| Major 1: 配列と観測値が同時に変わると既存の可視セルが再構成されない | 指摘なし | **採用 (Major)** | `ios/Sources/KsCollectionView/KsCollectionViewController.swift:127` / `:367` で観測値の変化が同値配列の早期 return 経路にしか渡っていないことをオーケストレーターが確認。Requirement「配列が同値であっても」は配列が変わる更新も含む |
| Major 2: list / grid の実操作確認 (tasks 3.2) の証跡がない | 指摘なし | **採用 (Minor 相当)** | handbook/cross/runtime-behavior-verification.md が change 配下の証跡を要求。実装ワーカーの目視報告のみで証跡が無かった |
| Major 3: snapshot / セル再構成経路の変更に性能検証がない | Suggestion 5 (適用外と判断した根拠を残す) | **確定 (オーナー判断へ)** | 双方一致。実機 + Instruments を要するため計測の要否はオーナーに諮り、修正サイクルでは適用外の根拠を deviation に残す |

ホスト側のみの指摘 (Minor 1〜3 / Suggestion 4) は review-001.md のとおり処理する。未解決 (両者矛盾) なし。
