# コード再レビュー: ios-engine-foundation

## メタデータ

- 日付: 2026-09-02
- 対象: 上限後の局所追加検証に対する例外最終再レビュー
- 判定: **CHANGES_REQUESTED**

## サマリー

`review-003.md` #2 のセル内 interactive control Scenario は解消した。Sample の専用画面を起動した XCUITest が `accessibilityActivate()` ではなく Button 中央への実座標 tap を行い、Button action 1 回・item tap 0 回を同時に確認している。さらに、実装は実タッチの hit view から interactive 要素を判定し、collection view の highlight と item selection を抑止する経路を備える。押下中静止画は取得できていないが、座標 press / drag 中に赤い feedback が未観測であること、ならびに `shouldHighlightItemAt` から feedback overlay 表示までのコード経路を合わせると、この Scenario の SHALL NOT を支持する証拠として十分である。

一方、必須性能 Requirement は意図どおり未完了のままであり、承認条件を満たさない。

重要度別件数: **Critical 0 / Major 1 / Minor 0 / Suggestion 0**

## 前回指摘の追跡

| 出典 | 状態 | 確認結果 |
|---|---|---|
| `review-003.md` #1 性能受け入れ | **未解消** | tasks 8.1〜8.3 と iPhone 11 実機の実測値が未完了 |
| `review-003.md` #2 セル内 SwiftUI Button 競合 | **解消** | Sample XCUITest の実座標 tap で Button action 1 回・item tap 0 回を確認し、interactive hit 判定から highlight / feedback / item selection を抑止する実装経路とも整合 |

降格済み指摘は再評価対象としていない。

## Findings

### 🔴 Major

#### 1. 必須の性能受け入れ条件が未検証

- **場所**: `kasane/changes/ios-engine-foundation/specs/collection-core/spec.md:66`、`kasane/changes/ios-engine-foundation/tasks.md:49`
- **問題**: 10,000 件の可変行高混在グリッドについて、iPhone 11 実機での 3 回の hitch time ratio とメモリ定常化が未検証である。tasks 8.1〜8.3 は未チェックで、`kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md:5` および結果表も未実施・未計測のままである。
- **推奨修正**: 規定の iPhone 11 実機と Release 構成で Instruments / Xcode Memory Report の計測を行い、サニタイズ済み結果と判定を `evidence/` に保存して tasks 8.1〜8.3 を完了する。

### 🟡 Minor

なし。

### 🔵 Suggestion

なし。

## interactive control Scenario の評価

判定: **解消**

### 実座標 tap の外部観測

- `samples/ios/KsCollectionViewSamples/SampleLaunchView.swift:4` は `--verify-interactive-control` を専用画面へ接続する。
- `samples/ios/KsCollectionViewSamplesUITests/InteractiveControlUITests.swift:12` は、実 SwiftUI Button の中央座標へ `tap()` している。これは `accessibilityActivate()` による action の直接起動ではない。
- 同テストは tap 後に Button action count が 1、item tap count が 0 であることを同時に検証する。`evidence/interactive-control-after-tap.png` も同じ値と、tap 完了後に赤い全セル feedback が表示されていない画面を示す。

以上から、「セル内 Button をタップすると Button action だけが実行され、item tap は発火しない」という Scenario の利用者観測は実タッチ経路で成立している。

### interactive hit 判定と feedback overlay のコード経路

1. `ios/Sources/KsCollectionView/KsHostingCell.swift:93` の `hitTest(_:with:)` が実イベントの hit view を `updateInteractionTarget(_:)` へ渡す。
2. `KsHostingCell.swift:120` は hit view から cell までの祖先をたどり、`UIControl` または button / link / adjustable trait を interactive として `lastHitWasInteractive` に記録する。
3. `ios/Sources/KsCollectionView/KsCollectionViewController.swift:478` の `shouldHighlightItemAt` は、その値が true の場合に false を返す。
4. feedback overlay を表示するのは `didHighlightItemAt` の `setTouchFeedbackVisible(true)` だけであるため、interactive control 上の touch ではこの表示経路へ進まない。`didSelectItemAt` も同じ値を確認して item tap を抑止する。

この経路は XCUITest の Button action 1 回・item tap 0 回という外部観測と整合する。黒箱テストだけでは個々の delegate 分岐の通過を直接計測していないものの、Scenario が要求するのは内部実装の分岐網羅ではなく利用者から見える競合排除であり、結論を覆す不整合はない。

### 押下中画像の証拠限界

`evidence/verification-matrix.md:19` は、座標 press / drag の試行中に赤い全セル feedback を観測しなかった一方、操作 API が完了後の画面しか取得できず、押下中静止画による瞬間の厳密な画像確認は未完了であることを明記している。`interactive-control-after-tap.png` 単独では押下中の非表示を証明できない。

ただし、観測結果は上記の `hitTest` → interactive 判定 → `shouldHighlightItemAt == false` → `didHighlightItemAt` / overlay 表示へ進まないコード経路と一致する。取得不能な瞬間画像だけを追加の承認条件とはせず、現時点の複数層の証拠で「interactive 要素が処理した場合に feedback は発火しない」という SHALL NOT は満たしたと判断する。

## 確認した成果物と結果

この例外再レビューは指定された局所追加成果物の評価であり、新たな build / test は実行していない。

| 確認対象 | 結果 |
|---|---|
| `InteractiveControlVerificationView.swift` / `SampleLaunchView.swift` | 実 SwiftUI Button、独立した Button / item tap カウンタ、赤い feedback、専用起動経路を確認 |
| `InteractiveControlUITests.swift` | Button 中央への実座標 tap と、Button action 1 回・item tap 0 回の assertion を確認 |
| `evidence/interactive-control-after-tap.png` | tap 完了後の Button action 1・item tap 0・赤い全セル feedback 非表示を目視確認 |
| `evidence/verification-matrix.md` | 実座標 tap、press / drag 時の未観測、押下中静止画を取得できない制約が区別して記録されていることを確認 |
| `KsHostingCell.swift` / `KsCollectionViewController.swift` | interactive hit 判定、highlight 抑止、feedback overlay 表示、item selection 抑止の接続を確認 |
| `tasks.md` / `performance-early-measurement.md` | 性能 8.1〜8.3 と実測値が未完了であることを確認 |

## 推奨アクションプラン

1. iPhone 11 実機で性能・メモリ受け入れ判定を完了する。
2. 結果を `evidence/` に保存し、tasks 8.1〜8.3 を完了したうえで最終判定を依頼する。
