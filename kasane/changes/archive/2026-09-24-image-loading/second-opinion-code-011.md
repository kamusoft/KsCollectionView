# セカンドオピニオン: image-loading (code-011)
**相方**: codex / **label**: so-code-image-loading-011 / **日付**: 2026-09-08 / **対象**: 群 1 = iOS 駆動改善と指摘対応 (PerformanceDriverUITests / ImagePrefetchChoice / SampleLaunchView / ImageGridDemoView)、群 2 = 証跡 4 本の更新 (iOS 7.1 改善後 + 対照、Android 到達点 memory の C 反映後、7.4 取り直し、基準機の目視)
---
# レビュー結果: image-loading（11回目）

**日付**: 2026-09-08  
**指摘件数**: Critical 0、Major 1、Minor 2、Suggestion 0

## サマリー

前回指摘の修正自体はすべて確認できました。Android の再計測値と算術、iOS の改善後3試行および大量件数3試行の算術も整合しています。

ただし、iOS の改善後計測について、改善前の trace 解析結果を現在の不合格原因の排除根拠として扱っているように読めます。「`KsImage` は原因ではない」という判断が次の対応方針を左右するため、現状では承認できません。

今回は指定どおりテストを再実行せず、ホスト報告の iOS Sample UI 5/0、iOS 本体154/0、Android本体130/0、Sample 28/0、実機4/0、修正後の `build-for-testing` 成功を前提に静的レビューしました。

## 前回指摘の解消確認

| 前回指摘 | 判定 |
|---|---|
| review-010 Major 1: Android の撤去後再計測 | **解消**。現行値4.6/4.4 ms、メモリ定常値、7.4観測が本文へ移り、旧値は履歴へ分離 |
| review-010 Major 2: 禁止されたタスク番号・証跡パスのコメント | **解消** |
| review-010 Minor 1: クラッシュ解消の断定範囲 | **解消**。Pixel 4aで同一操作20往復・クラッシュ0を記録 |
| review-010 Minor 2: iOS計測窓が伸びる理由の切り分け | **解消**。`KS71`、投入回数、各回所要、画面更新数、限界を記録 |
| review-010 Minor 3: iOS証跡の「次に必要なこと」 | **解消** |
| review-010 Suggestion 1: `--prefetch` 解釈の重複 | **解消**。`ImagePrefetchChoice` に一本化 |
| review-010 Suggestion 2: iOS 7.4の行数帰属 | **解消**。全行数・初出要素・重複構成を分離 |
| 相方 Major 2: 収束待機のタイムアウト | **実装は解消**。`XCTFail`後に`false`を返し、後続処理を停止 |
| 相方 Minor 2: 「規約どおり」という表現 | **解消**。合意済み乖離を含む手順と明記 |

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（always）
- `kasane/handbook/cross/sample-parity.md`
- `kasane/handbook/cross/test-execution.md`
- `kasane/handbook/cross/runtime-behavior-verification.md`
- `kasane/handbook/ios/performance-verification.md`
- `kasane/handbook/android/performance-verification.md`
- `core/ADR-0008`
- `cross/ADR-0004`
- SwiftUI／Swiftレビュー規律

## 指摘事項

### [🟠 Major] 改善前の trace 分析が、改善後の不合格原因の排除根拠として使われている

**該当箇所**: `evidence/image-grid-measurement-ios.md:150`、`:270`、`:285` / `deviation.md:93`、`:96`

**問題点**: 証跡本文は0.00 / 3.94 / 5.54 ms/sを駆動改善後の最終値としていますが、「`KsImage` の準備・縮小・デコード・先読みは1%未満で、hitch時刻に不在」という分析は、`deviation.md:93`では改善前の1.47 / 5.53 / 5.78 ms/sのtraceに帰属しています。

改善後はhitchの時刻・長さ・種別が変わっています。`deviation.md:96`および改善後結果には、新しい試行2・3で`KsImage`経路との時間的重なりを再確認した記録がありません。この状態では、改善後の残存hitchについて「画像ロード実装は原因ではない」とまでは言えません。

**推奨修正**: 改善後の試行2・3のtraceで、hitch時刻と`KsImage`・デコード・プリフェッチ処理の重なりを再確認し、根拠を記録してください。再解析しない場合は、当該結論を「改善前のtraceで確認した範囲」に限定し、改善後の原因は未特定としてください。

### [🟡 Minor] 異なるfixtureの対照から共通要因を排除している

**該当箇所**: `evidence/image-grid-measurement-ios.md:229`、`:241`、`:293`

**問題点**: 画像グリッドと「大量件数」は、セル内容、列数、可変高、ネットワーク有無が異なります。hitch件数が0〜1件対17〜19件と違うことは重要な発見ですが、それだけで駆動や計測窓などの共通要因を排除できません。共通の足場の費用が、画面内容との相互作用で異なる大きさになる可能性があります。

**推奨修正**: 「同じ駆動でもfixtureにより件数が大きく異なった」「共通要因だけでは差を説明できない可能性がある」までに狭めてください。原因排除には、同一fixtureで画像ロード部分だけを切り替えたA/Bか、改善後traceの帰属分析が必要です。

### [🟡 Minor] `waitUntilMarkSettles` の旧説明が現行挙動と矛盾する

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/PerformanceDriverUITests.swift:237`

**問題点**: 行239〜241は、待ち切れなくてもそのまま進むと説明していますが、現行実装は行269で`XCTFail`し、`false`を返して呼び出し元を終了します。直後の新しいdocコメントとは正反対です。

**推奨修正**: 旧説明を削除し、行248以降の現行説明へ統合してください。

## アクションプラン

1. 改善後のiOS traceで`KsImage`経路との重なりを再解析するか、原因排除の記述を未確認へ戻す。
2. 「大量件数」対照から共通要因を排除する記述を、観測できた範囲に限定する。
3. `waitUntilMarkSettles`の旧docコメントを現行挙動に合わせる。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-011.md との照合、2026-09-08)

| 相方の指摘 | ホスト側 | 採否 |
|---|---|---|
| Major: 「`KsImage` は原因ではない」の根拠が改善前の trace 解析で、改善後の試行 2・3 では再確認していない | 指摘なし (APPROVED 寄り: Minor 1 / Suggestion 2) | **採用 (Major)**。改善後の trace (g2 / g3) と対照 (b1〜b3) を読み取り専用で再解析し、結果に応じて証跡と deviation の結論を「改善後にも確認済み」か「改善前の範囲に限定・改善後は未特定」に書き分ける |
| Minor: 異なる fixture の対照から共通要因を排除している | Suggestion 2 (対照の数値が表に無い) と隣接 | **採用 (Minor)**。記述を「同じ駆動でも fixture により件数が大きく異なった。共通要因だけでは差を説明できない可能性がある」に狭め、対照の画面更新回数と `KS71` を表に載せる |
| Minor: `waitUntilMarkSettles` の旧 doc が現行挙動と矛盾 | Minor 1 (同内容 + `ImagePrefetchChoice` の一文) | **確定**。両方とも修正済み |

ホスト側のみ: Suggestion 1 (deviation の古い非対称の記述に解消済みの注記) → 修正済み。集計: 確定 1 / 採用 2 / 降格 0 / 未解決 0。
