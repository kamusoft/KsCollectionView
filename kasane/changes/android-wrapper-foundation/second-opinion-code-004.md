# セカンドオピニオン: android-wrapper-foundation (code-004)
**相方**: codex / **label**: so-code-android-wrapper-foundation-004 / **日付**: 2026-09-05 / **対象**: Android Sample と性能計測 (tasks.md グループ 7・8) — samples/android/ 全体と evidence/ の計測・対応表
---
# レビュー結果: android-wrapper-foundation

**日付**: 2026-09-05  
**判定**: **CHANGES_REQUESTED**

## サマリー

ビルド・単体テストの提示結果は成功として受領しましたが、性能・再利用・テンプレート内状態の主要な証跡に6件の Major があります。特にメモリ比較は、1,000件側でも10,000件分のデータを生成しているため、現在の結果から要求適合を結論できません。

`deviation.md` の区切り線描画順と性能集計方法の2件は合意済みとして指摘していません。

## 照合した規約

- ソースコメント規約（always）
- Sample のプラットフォーム間一致
- テスト実行規約
- 公開識別子と配布座標
- ローカル開発環境と Sample の実行（guide）
- iOS 性能検証の手順と合格基準
- cross/ADR-0003・0004
- android/ADR-0001・0002（いずれも proposed のため拘束的根拠には不使用）
- `kotlin-impl-skill`、`jetpack-compose-impl-skill`

## 指摘事項

### [🟠 Major] メモリ比較の1,000件側も10,000件分の入力データを保持している

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementDestinations.kt:71`、`samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/DemoData.kt:43`、`evidence/performance-measurement.md:124`

**問題点**: `DemoData.largeItems.take(count)` は、先に `largeItems` の10,000要素すべてを生成・保持してから件数分のリストを作ります。したがって1,000件計測でも、元の10,000個の `DemoItem` と文字列は `DemoData` から保持されています。

この構造では、証跡の「+5,220 KB は9,000件分の入力データでほぼ説明できる」という説明は成立しません。両計測で要素オブジェクトは既に10,000件存在し、主に異なるのは `take` で作られる参照リストと表示経路です。また、証跡自身が示す実行間変動7,359 KBは件数間差5,220 KBより大きく、現在の1回比較では差をノイズから分離できません。

**推奨修正**: 件数ごとに正確に1,000件／10,000件を生成し、入力データだけを保持する対照計測を設けて差し引くか、両側で10,000件を意図的に保持して入力コストを固定した比較として再設計してください。後者の場合、現在の5,220 KB差を入力要素へ帰属させず、複数回計測でUI・ライブラリ保持量とノイズを分離してください。

### [🟠 Major] メモリ走査が到達完了を観測せず、失敗状態も成功扱いになる

**該当箇所**: `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:85`、`samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/LargeDataMemoryBenchmark.kt:71`

**問題点**: 各スクロール命令の後に待つのは2フレームだけで、対象IDが可視になったことも、命令処理が完了したことも、全項目を通過したことも確認していません。端末負荷やコマンド処理の遅延により命令が滞留・追い越ししても、そのままメモリを記録できます。これは「完了条件そのものを観測する」というテスト実行規約と、全項目通過を求める性能要件を満たしません。

さらに、10往復で定常化しなかった `notSteady` も `status != "running"` を満たすため、JUnit上は成功します。回帰時に未判定を緑として報告する構造です。

**推奨修正**: 各段階で対象IDの表示完了を条件付きで待ち、訪問ID集合・両端到達・全項目通過を検証してください。`notSteady`、到達失敗、訪問不足は実測値を付けてテストを失敗させてください。

### [🟠 Major] フレーム計測開始前に目的画面の安定を確認していない

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleNavHost.kt:71`、`samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/LargeDataScrollBenchmark.kt:61`

**問題点**: Activityは常にメニューを `startDestination` として起動し、その後 `LaunchedEffect` で計測画面へ遷移します。一方、benchmarkの `setupBlock` は `startActivityAndWait` 後に目的画面固有の要素やナビゲーション完了を待ちません。計測開始時にメニュー、遷移アニメーション、または大量件数画面の初期構成が残っている可能性があります。

Android公式ガイドも、深い画面を測る場合は `setupBlock` で目的画面まで遷移し、安定表示を待ってから `measureBlock` に入る構成を示しています。[Android Developers: Control your app from Macrobenchmark](https://developer.android.com/topic/performance/benchmarking/macrobenchmark-control-app)

**推奨修正**: 起動時指定を直接 `NavHost` の開始先として使うか、`setupBlock` 内で目的画面固有のsemanticsをdeadline付きで待ち、安定後にのみ計測を開始してください。

### [🟠 Major] テンプレート内状態が破棄されるシナリオを検証画面で再現できない

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/HeightChangeVerificationScreen.kt:24`、`samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/SampleDemoScreenTest.kt:76`、`evidence/sample-parity-comparison.md:28`

**問題点**: 検証画面は5行しかなく、保存画像でも展開前後とも全5行が同時に画面内へ載っています。可視範囲と先読み分を超えて項目をCompositionから破棄させる距離がなく、仕様が要求する「画面外へ送り、戻すとテンプレート内の `remember` が初期値へ戻る」を確認できません。

テストも展開直後の表示だけを確認し、画面外へのスクロールと復帰後の初期化を検証していません。

**推奨修正**: 先読み範囲を確実に超える十分な行数へ増やし、実際に対象行を画面外へ送ってから戻し、本文が消えていることを自動テストと実機証跡の両方で確認してください。

### [🟠 Major] 再利用確認タスクが未実施のまま完了扱いになっている

**該当箇所**: `tasks.md:54`、`evidence/template-reuse-measurement.md:3`、`samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/TemplateInvocationCounter.kt:24`

**問題点**: task 8.3は「カウンタ + Layout Inspector」を要求していますが、証跡はLayout Inspectorを使用しなかったと明記しつつ、タスクを完了扱いにしています。この代替は `deviation.md` にもありません。

また、現在のカウンタは累積呼び出し回数だけを増やします。初期表示が遅延生成されることは示せますが、スクロール中に同時に生存するComposition数や、画面外で破棄されたことは測れないため、Layout Inspectorと同じ問いには答えていません。

**推奨修正**: Layout Inspectorを実施するか、`DisposableEffect(item.id)` 等でactive数を増減させ、最大同時生存数と破棄を測れるカウンタへ変更してください。別方式へ正式に置き換えるなら、オーナー合意を得てdeviationへ記録してからタスクを完了扱いにしてください。

### [🟠 Major] SampleのDSLパラメータ差が未合意のまま残っている

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ListDemoScreen.kt:59`、`samples/ios/KsCollectionViewSamples/ListDemoView.swift:38`、`ui/brief.md:43`

**問題点**: iOSは `accent.opacity(0.15)`、Androidは不透明な `accent` をタッチフィードバック色として渡しています。見た目を揃えるためのプラットフォーム適応という説明には合理性がありますが、Sample仕様とhandbookはDSLへ渡す色・パラメータの一致を要求しています。

さらに `ui/brief.md` は、この差を含む3項目について「オーナーの確認を待っている」と明記しています。`deviation.md` に合意記録がない状態で、task 7.3・7.6を完了とすることはできません。

**推奨修正**: 「raw RGBAの一致」と「描画結果の一致」のどちらを優先するかオーナー判断を得てください。現在の実装を採用する場合は合意済み差分としてdeviationへ記録し、briefの確認待ち表記も確定状態へ更新してください。

## アクションプラン

1. メモリfixtureと到達確認・失敗判定を修正し、Pixel 4aで再計測する。
2. benchmark開始前の目的画面安定待ちを追加し、フレーム結果を再取得する。
3. テンプレート内状態の破棄・復帰シナリオを実際に成立させる。
4. active Composition数を測れる証跡を取得するか、Layout Inspectorを実施する。
5. Sample固有差分についてオーナー判断を得て、deviation／brief／tasksを整合させる。

指摘件数: Critical 0 / Major 6 / Minor 0 / Suggestion 0。  
指定どおりレビュー結果ファイルへの書き込みは行っていません。過去メモは検証層を分ける観点の補助にのみ使い、判定根拠は現checkoutで再確認しています。


---
## 突き合わせ結果 (ホスト側 review-004.md との照合、2026-09-05)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| [Major] メモリ比較の 1,000 件側も 10,000 件分の入力データを保持 | Suggestion (定常判定・全項目通過の自己確認なし) — 別論点 | **採用 (Major)** | `DemoData.largeItems.take(count)` の構造が特定され、1,000 件 / 10,000 件の比較が入力データの差を測れていない実害が明確。再計測が要る |
| [Major] メモリ走査が到達完了を観測せず `notSteady` も成功扱い | Suggestion で同趣旨 (ホストはカウンタで全項目通過を独立計数し、実際には通過していることを確認) | **採用 (Minor)** | 実測では通過しているが、テスト構造として完了条件を観測しておらず未判定が緑になる。handbook/cross/test-execution.md の「収束を待つアサーション」に反する |
| [Major] フレーム計測開始前に目的画面の安定を確認していない | 指摘なし (ホストの再計測は証跡の値を再現) | **採用 (Minor)** | 値は再現しているが、`setupBlock` が遷移完了を待たない構造は計測の再現性を下げる。修正は安価 (目的画面の semantics を deadline 付きで待つ) |
| [Major] テンプレート内状態が破棄される Scenario を検証画面で再現できない (5 行) | 指摘なし。文書ワーカー (6.5) が独立に同じ所見 | **採用 (Major)** | spec の Scenario の WHEN が実行不能。この画面は Android 固有でパリティ義務がない (spec) ため行数を増やせる |
| [Major] 再利用確認 (8.3) が Layout Inspector 未実施のまま完了扱い、カウンタは累積のみ | 指摘なし (release 除外と計数はホストが確認) | **採用 (Minor)** | Layout Inspector は GUI 前提で自動化できないため、同時生存数 (最大値と破棄) を測れるカウンタで代替し、tasks 8.3 からの乖離として deviation.md に記録する |
| [Major] Sample の DSL パラメータ差 (`touchFeedbackColor`) が未合意 | Major で同一指摘 | **確定 (Major)** | 双方一致。sample-parity の規約どおり deviation.md に本体側の統一課題として記録し、evidence の「不一致なし」を訂正する |

ホスト側のみの指摘 (Minor 1〜3: 回転で選択状態が初期値へ戻る / 起動経路指定後の回転で back stack が積み増す / モックの副文字色を採らなかった事実の未記録) はホスト側判定のまま修正対象。採用 5 / 確定 1 / 降格 0 / 未解決 0。
