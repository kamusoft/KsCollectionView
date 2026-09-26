# レビュー結果: sections-grouping (001 回目)

**日付**: 2026-09-25
**判定**: APPROVED

## サマリー

グループの宣言・見出しの固定 (iOS は方式 3c、Android は `stickyHeader`)・間隔・区切り線・差分のアニメーション・端への挿入・回転での位置・インジケータの行数・Sample 2 画面は、デルタスペックの Requirement / Scenario に沿って両プラットフォームで実装され、Scenario に対応するテストもそろっている。deviation.md の記録 (付随修正 4 件・乖離・オーナー指示) と brief の合意済み妥協 3 件の外に、無断の仕様逸脱は見つからなかった。Critical / Major はない。指摘は、グループの値の取り出し方を差し替えたときの扱いが iOS で文書化されていない点 (Minor) と、改善提案 2 件にとどまる。

## 実行したテスト (レビュアーが再実行)

- iOS ライブラリ (Simulator iPhone 17 Pro Max, Debug): `Executed 336 tests, with 0 failures`。ホストの報告と一致
- Android ライブラリ (`:kscollectionview:testDebugUnitTest --rerun-tasks`): 17 クラス 316 件、失敗 0・エラー 0・スキップ 0 (TEST-*.xml を集計)。ホストの報告と一致。グループ関係の `KsCollectionViewGroupingTest` 42 件・`KsGroupPlanTest` 10 件・`KsCollectionViewSafeAreaTest` 7 件が入っていることを確認
- iOS Release (327 件)・iOS Sample (17 件)・Android Sample (83 件)・各ビルドは、ホストの実行結果を客観的事実として採用し、再実行はしていない
- `scripts/comment-policy-lint.py --advisory`: 禁止 0 件。要確認 3 件はいずれも今回触れていない既存ファイル。`local-path-lint.py` / `identity-lint.py`: 違反なし

## 照合した規約

- ソースコメント規約 (always): 差分のコメントに作業文書・通番・構文キーワードへの参照が無いこと、公開 doc コメント (`KsGroups`・`.groups(by:)`・`KsLayout` / `KsCollectionLayout` の間隔) に内部用語が無いことを確認
- Sample のプラットフォーム間一致 (`samples/**` を触る): 画面の順と文言 (「グループ化」「差分更新」)、データ生成規則 (`GroupingDemoData`・`SampleRandom` の xorshift・`DiffUpdateModel` の各操作・`GroupingDemoEdits`) の両プラットフォームでの一致、画面数の決め打ちのテストの更新
- テスト実行規約 (テストを実行する): 件数の確認・Android の `--rerun-tasks` と XML の集計・iOS の Simulator 実行
- iOS 性能検証の手順 / Android 性能検証の手順 (描画・レイアウト・スクロール経路に触れる): 「グループ化」の計測対象への追加と、比較対象へのインジケータと `animateItem` の付与 (`BaselineGroupingGrid` ほか) を確認。計測そのもの (tasks 5.x) はこのレビューの対象外
- 実行時挙動の検証規約 / スクロール性能の体感ゲート: tasks 5.x の対象で、今回は照合のみ (未実施であることを確認)
- lessons/code-review.md の重点観点 L-001: deviation の数値 (「最大 81dp の帯」) は設計判断の理由として書かれたもので、現行コードの挙動を主張する証跡値ではないため、プローブでの再現は行っていない

## 指摘事項

### 🟡 Minor iOS でグループの値の取り出し方を差し替えても、配列が同じなら組み直されないことが文書化されていない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:159`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:670`、`ios/Sources/KsCollectionView/KsCollectionView.swift:162`
**問題点**: 塊の組み直しを決める `groupingDeclarationChanged` は、グループの宣言の「有無」しか見ない。配列が同値のまま `.groups(by: \.category)` を `.groups(by: \.brand)` に切り替えると、670 行目で早期に return し、古いグループ分けのまま表示が続く (配列が次に変わった時点で直る)。Android も `remember` のキーに `groups.by` を含めないので同じ挙動だが、Android は `KsGroups` の KDoc (`KsGroups.kt:38` の「表示中に差し替えない前提の宣言」) に利用の前提として書いてある。iOS の公開 doc コメントにはその記載がなく、同じ契約がプラットフォームで違って見える。
**推奨修正**: iOS の `groups(by:...)` の 2 つの doc コメントに、Android と同じ前提 (表示中に `by` を差し替えない) を書く。前提にせず切り替えを受け付けるなら、宣言の同一性を比べる手段 (たとえば `by` の KeyPath を `AnyKeyPath` として保持し、等しいかを比べる) を足して `regroupingSections` を立てる。どちらにするかは実装側で選んでよい。

### 🔵 Suggestion グループを宣言しない構成でも、配列の適用のたびに項目の配列をもう 1 本作って保持している

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:707`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:715`
**問題点**: `groupedItems` (重複 ID を除いた項目の配列) は、グループの見出しにグループの中の項目を渡すためだけに使われる。それなのに、グループを宣言しない構成でも、配列が変わる適用のたびに全件ぶん作られ、`appliedGroupedItems` として持ち続けられる。10,000 件の差し替えで O(n) の作成と保持が余分にかかる (グループの値の取り出しは宣言があるときだけなので、影響はこの配列だけ)。
**推奨修正**: 見出しの宣言がある (`configuration.grouping?.header != nil`) ときだけ作って保持し、ないときは空にする。挙動は変わらない。

### 🔵 Suggestion 高さの補間の有無をすべての可視項目がコンポジションの中で読んでいることを、5.6 の計測で観点に含める

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:588`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsAnimatedHeight.kt:86`
**問題点**: `ksAnimateItem` は `tracker.isAnimating` をコンポジションで読む。一覧のどこかで高さの補間が始まるか終わるたびに、すべての可視項目の入れ物 (`KsAnimatedItemBox` / `KsFullSpanBox`) が作り直される。テンプレートの中身までは作り直さない作りで、これ自体は deviation に記録済みの判断 (補間の間は配置のアニメーションを止める) を実現するためのもの。ただ、中身の高さが非同期に変わる一覧 (画像の読み込みなど) では、スクロール中にもこの作り直しが起きうる。
**推奨修正**: コードの変更は不要。tasks 5.6 の「`animateItem` なし / あり」の比較で、高さの変化が起きる fixture (「画像グリッド」など) も観点に入れ、上乗せがないことを証跡で確かめる。

## 所見 (指摘ではない)

- android/ADR-0004 (accepted) は「`animateItem` を重ねない」と決めているが、本実装は項目・見出し・ルートのヘッダー / フッターに `animateItem` を付けている。これは design Decision 13 と android/ADR-0006 (proposed、amends 0004) にもとづく合意済みの変更で、ルートのヘッダー / フッターへの適用範囲の拡大も deviation に記録がある。蒸留では ADR-0006 を accepted にし、0004 との関係を確定させる必要がある
- proposal.md の What Changes は「差分更新」を「60 件」と書いているが、design Decision 14・デルタスペック・tasks 4.4・brief はいずれも 20 件で、実装も 20 件。実装は spec に合っている。足場は凍結されているため、蒸留のときに参照するならこの食い違いに注意する
- core/ADR-0015・0016、ios/ADR-0010 は proposed のままで、実装はこれらの決定どおり。蒸留での確定が残っている

## 確認した観点

- **仕様充足**: 3 能力のデルタスペックの Requirement ごとに、実装とテストの対応を確かめた。たとえば、キーと同じ値のグループ (`groupValueEqualToItemKeyDoesNotCollide`)、離れた同じ値の release の扱い (両プラットフォーム)、見出しの有無による区切り線、塊に割れたグループの固定、固定中の見出しの下への回転の復元と ID スクロール、見出しの内容の更新と観測する値 (iOS)、グループをまたぐ差分、端への挿入 (list / グリッド・グループあり・フッターあり)、インジケータの行数、ルートのヘッダー / フッターの余白。tasks 1.x〜4.x のチェックに虚偽は見つからなかった (3.8 の試作での決定は deviation に記録がある)。足場 (proposal / design / specs) の書き換えもない
- **付随修正**: 4 件 (安全領域の分の押し下げ、iOS の行間・列間の負の値、不正入力のログの category、Sample の `DemoData.largeItem`) は、いずれも同じ能力の中の局所的な修正で、公開 API の形を変えない。テスト (`KsSafeAreaTests`・`testReleaseでは負の間隔を0として表示し警告する`・`KsInvalidInputTests`・Sample のテスト) で担保されている。安全領域の件は、その後のオーナー指示で広がり、実施内容とテストが deviation に記録されている
- **堅牢性**: 空配列 (塊を 1 つ作る / グループ 0)、グループが 1 つのときの移動、release の縮退 (並べ替えない・消さない・警告を 1 度だけ出す)、状態保存に載らないグループの値の検知、見出しのキーと項目のキーの名前空間の分離、補間の数え方の釣り合い (`invokeOnCompletion`)、再利用時の出現フェードの状態の戻し
- **設計品質**: 塊の表 (`KsGroupChunkTable`) と並べ方の表 (`KsGroupPlan`) は、どちらもグループの数に比例する情報だけを持ち、項目の位置との変換はその場で計算する。スクロール命令・先読み窓・インジケータ・位置の保持が同じ表を共有している。公開 doc コメントは利用者向けの説明だけで書かれている
- **Sample の一致**: 乱数の式と種、データ生成、各操作の組み替えの規則、文言 (「グループ n」「1,200 件」の 3 桁区切りの固定) が両プラットフォームで一致している

## アクションプラン

1. (Minor) iOS の `groups(by:)` の doc コメントに、`by` を表示中に差し替えない前提を書く (または差し替えを検知して組み直す)
2. (Suggestion) iOS の `groupedItems` を、見出しの宣言があるときだけ作る
3. (Suggestion) tasks 5.6 の計測で、高さの変化が起きる fixture での `animateItem` の上乗せも観点に入れる
