# Live Session: ios-engine-foundation (仕上げ切替)
対象: (1) UIHostingConfiguration の中央配置はみ出し (翻案元 CustomCellRowPlacement の罠) を高さ変化の検証画面で実物確認し、発現時のみ核心を翻案する (2) `.estimated(44)` の推定高さ見直し
開始: 2026-09-03

## 観測点 (事前定義)
- (a) 展開/折りたたみの瞬間に本文が行の上端より上へ飛び出さない
- (b) 初回表示で推定高さより高い行の本文が上下にずれて現れない
- (c) 再利用後に展開状態の行へ戻っても (a) と同じ

## 試行ログ (append-only)

## 決定事項

## エスカレーション・スコープ外の発見
- (ksn-explore 翻案照合より申し送り) cellProvider が `nil` を返しうる — 翻案元の「provider は必ず Cell を返す」不変条件の喪失
- (同) phase-4 セクション導入時に「全セルに下線」規則がセクション境界で二重線になる
- (同) `rowSpacing` / `contentPadding` 指定時の区切り線の見え方 (行直下・パディング分内側)
- (同) 文書乖離: ADR ios/0001 の骨格リストに「Store 経由」が残ったまま ios/ADR-0004 で棄却。design.md Decision 3 (`configurationUpdateHandler` 想定・`separatorConfiguration` 翻案) と実装の食い違い
- 検証画面の追加 → samples/ios/KsCollectionViewSamples/HeightChangeVerificationView.swift (+ HeightChangeRowBody / HeightChangeSelfStateCell / HeightChangeItem / HeightChangeExpansionPath / HeightChangeLayoutChoice / VerificationScreen / VerificationDestinationView 新規、RootMenuView.swift:7-19 に検証項目追加、SampleLaunchView.swift:22,33-37 に起動引数 `--verify-height-change`) → 継続 (ビルド成功、Simulator 表示中)
- 観測 (親 state 経路, Simulator iPhone 17 Pro): list で行 2・行 3 をタップ → 見た目の変化なし (本文も高さも変わらず)。grid へ切替 → 行 2・行 3 のセルが背高になるが本文は未描画 (見出しのみ)。grid で行 1 をタップ → 行 1〜3 の本文が一斉に描画。grid で行 1 を再タップ (折りたたみ) → 本文は消えるがセル高さは背高のまま (空白)。list へ戻す → 行 2・行 3 展開・行 1 折りたたみで正しく表示 → 継続 (可視セル再構成で内容は更新されるが自己サイズが再計測されず、レイアウト切替 (invalidateLayout) で初めて揃う疑い。はみ出しの観測はこの解消後)
- 原因調査 (ワーカー、ログ実測 + A/B) → 仮説「再構成で自己サイズ未再計測」は否定。真因: テンプレートクロージャは `body` 評価の外 (UIKit 側) で実行されるため、そこでしか読まれない親の `@State` は SwiftUI の依存グラフに載らず、状態変化で親 View が無効化されない → `updateUIViewController` が来ず `update(configuration:)` が一度も呼ばれない。A/B: `body` 内で同じ state を 1 行読むだけで正常に展開 (reconfigureVisibleCells → preferredLayoutAttributesFitting → 高さ追従)。症状 2〜5 は溜まった状態が無関係なタイミング (レイアウト切替・別タップ) でまとめて反映される下流現象。grid では 1 タップで追従する非対称あり (内訳未計測) → 停止 (公開 API / ADR 級のため本体未編集。本体は計測後に復元済み)
- 経路 B (テンプレート内 state) → list/grid とも展開・折りたたみで高さ追従、上端はみ出しなし、折りたたみ後の空白なし → 観測点 (a)(b)(c) は経路 B では非発現。証跡: evidence/height-change-before-pathB-template-state-ok.png
- 証跡保存 → evidence/height-change-before-1-list-tap-no-effect.png / -2-grid-tall-but-unpainted.png / -3-grid-tap-paints-all.png (手順 4・5 は未撮影)

## エスカレーション・スコープ外の発見 (追記)
- 【エスカレーション】テンプレート内でだけ読まれる親 state の変更が検知されない (SwiftUI 依存グラフの構造上の制約)。deviation.md「案 B: 同値配列でも親の更新が来たら可視セルを再構成」は「親の更新が来る」前提が成り立たない場合がある。選択肢: (1) 利用者契約 (親 state は body 側でも読む) として ADR 化 (2) 変更検知用の値を DSL で明示的に受け取る公開 API を追加。公開 API / ADR 級のためライブ調整の受け持ち外
- オーナー実操作 (行高変化デモ) → はみ出し**発生**: 展開時に本文が上から降りてくる (KsSettingsView 当時と同一の事象)。ワーカーの静止画観測「非発現」は一瞬の遷移を捉えられていなかったと判断 → 対策必要 (翻案元 CustomCellRowPlacement の核心を移植する方針で継続)
- 新論点 (テンプレート内でだけ読まれる親 state の変更検知) → 簡易起票 kasane/changes/template-parent-state-observation/ (参考先: KsSettingsView のカスタムセル)
- はみ出し対策の翻案 → ios/Sources/KsCollectionView/KsRowContentPlacement.swift 新規 (提案高さをそのまま返し content は自然高のまま上端配置の Layout。実効行高は持ち込まず常に上端揃え) / KsCollectionViewController.swift:261-266 `UIHostingConfiguration { content }` → `UIHostingConfiguration { KsRowContentPlacement { content } }` / KsRowContentPlacementTests.swift 回帰テスト 4 件 → 継続 (A/B: 遷移パスで bounds.h=44.3 / natural.h=141.7 のとき offsetY -48.7 → 0.0、上方向はみ出し 4 回 → 0 回。テスト 64 件通過。証跡 evidence/height-change-after-ab-measurement.md + 録画 2 本。オーナー実操作の確認待ち)
- オーナー実操作 (修正後ビルド) → 上から降りてくる動きは list / grid とも全て解消 → **採用**
- オーナー観察 (grid, 親 state 経路): 行 1 の展開はアニメーションあり、行 2 はなし。テンプレート内 state は中身 (背景含む) もアニメーションするが、親 state は行の高さだけ動き中身は瞬時に切り替わる → 簡易起票済みの根本原因 (親 state の変化が SwiftUI のトランザクションとして届かず、別のきっかけで hosting configuration が差し替わる) の別の現れと判断。template-parent-state-observation の exploration.md に追記
- 推定高さの見直し → ios/Sources/KsCollectionView/KsEstimatedHeight.swift 新規 (未計測は既定 44、計測後は直近 32 件の平均、reset あり) / KsCollectionViewController.swift:459,464 `.estimated(44)` → `.estimated(estimatedHeight.value)` (sectionProvider 内の実行時参照、invalidate 契機は追加なし)、:269-271 実測記録、:110-112 レイアウト種別変更時に reset / KsHostingCell.swift:72-79 preferredLayoutAttributesFitting で自己サイズ結果を通知 / KsEstimatedHeightTests 7 件 → 継続 (オーナー確認待ち)
  - キー別推定は不成立 (compositional layout の estimated は item 定義単位で index path ごとに変えられない) → 全体で単一値。中央値でなく平均を採用 (推定はコンテンツ全体の高さの見積もりに使われるため合計を言い当てるのは平均。大量件数デモ初回 contentSize: 固定 44 = 225,244 / 中央値 = 226,906 / 平均 = 264,301 / 真値 ≈ 300,000)
  - A/B (スクロール制御デモ list, 実測行高 64.33): 初回 contentSize 4705 → 6433 (誤差 -26.9% → 0%)、末尾命令中のレイアウト再計算 27 回 → 3 回、到達位置は同一。header/footer の estimated は 44 据え置き、grid 既定値も据え置き (測定から変える根拠なし)
  - 残る乖離: grid は行高 = 列内最大セル高だが実測はセル単位のため、行高混在 grid では平均でもやや過小 (固定 44 比で誤差は約半分)。証跡 evidence/estimated-height-ab-measurement.md + before/after png。テスト 71 件通過
- オーナー確認 (推定高さ) → 大量件数・スクロール制御とも問題なし → **採用**
- オーナー報告: 検証画面へ遷移直後は行頭タップの開閉が効かず、Picker を一度動かすと機能する → ワーカーに再現・切り分けを依頼 (既定経路「親 state」なら簡易起票済みの根本原因と同一と推定。その場合は検証画面側で state を body でも読む回避策を適用)
- オーナー示唆: 行高変化の検証画面は Android にもあった方がよい → phase-3 agenda に申し送り追記 (Android タスク時に決める)
- 遷移直後タップ無効の切り分け (ワーカー、ログ) → 簡易起票済みの根本原因と同一 (既定経路「親 state」で `expandedIDs` が body で読まれず依存未登録。Picker 操作で body が再評価されて以降動く。body で count を読む print を仕込むと不具合が消えることで裏取り) → 検証画面側の回避策: HeightChangeVerificationView.swift:48-56 に「展開中: N 行」表示を追加し body で `expandedIDs.count` を読む (本体は不変)。template-parent-state-observation/exploration.md:29 に回避策適用済みを追記 → 継続 (オーナー確認待ち: 遷移直後 1 タップ目から開閉)
- オーナー確認 (遷移直後タップ) → 解消 → **採用**。簡易起票に「根本解決後は Sample の回避策を外して再確認」を追記
- オーナー完了指示 → 確定へ (summary.md 作成 → テスト → 独立レビュー)

## 決定事項
- はみ出し対策: 翻案元 CustomCellRowPlacement の核心 (提案高さをそのまま返し content は自然高のまま上端配置) を `KsRowContentPlacement` として翻案。実効行高の概念は持ち込まない
- 推定高さ: 固定 44 をやめ、コレクション全体の実測平均 (直近 32 件) を実行時参照。未計測時の既定は 44 据え置き。キー別推定は compositional layout の構造上不成立
- deviation.md 14 行 (tasks 3.2) の記述は実態に合わせて改訂する (summary で扱う)
- 独立レビュー review-012 → CHANGES_REQUESTED (Major 2 / Minor 4 / Suggestion 5)。Major-1: 証跡の動画 2 本 (4.7MB) は ui-artifacts.md「動画は残さない」に反する → 見た目非影響のため修正 (trash、数値 A/B と静止画で代替)。Major-2: KsRowContentPlacement が水平位置も先頭固定 (`.topLeading`) にしており、幅を明示しない content の水平中央が先頭寄せに変わる (Sample は全て maxWidth: .infinity のため非発現) → 見た目が変わる指摘のためオーナーに戻す。Minor: 行高を content に提案しない帰結 (grid で背の低いセルが行高いっぱいに広がれない) 未記録 / 移動平均でスクロール中に contentSize が揺れうる (未測定) / reset の契機が kind 変更のみでコメント「幅が変わったら捨てる」を満たさない / コメント位置
- review-012 の非視覚指摘の修正 → Major-1: 動画 2 本を trash、各 3 枚の静止画連番 (タップ直前/遷移中/収束後) に差し替え、measurement.md と summary.md の参照を更新 (静止画では修正前後を目視判別できず、裏付けは offsetY 実測値が担う旨を明記) / Minor: KsCollectionViewController.swift:134-138 コンテナ幅変化でも `estimatedHeight.reset()` (既存 guard 内、invalidate 回数不変)、KsEstimatedHeight.swift:35-37 コメント改訂 / :267-271 コメント位置 / deviation.md:14,15 に grid の非拡張と contentSize の揺れを追記 / KsRowContentPlacementTests.swift:5-8 ヘルパーが唯一の入口である旨のコメント → 継続 (テスト 71 件通過、lint 3 本 exit 0、Sample ビルド成功、「末尾へ」到達を再確認)。Major-2 (水平位置) はオーナー判断待ち
- オーナー判断 (Major-2) → 水平方向は従来どおり中央に戻す (縦方向のみ上端固定)。先頭寄せは採らない
- Major-2 修正 → KsRowContentPlacement.swift:70-78 `contentOrigin(in:naturalWidth:)` x = minX + max(0, (width − contentWidth)/2) (自然幅が非有限なら先頭のまま) / :48-54 placeSubviews で自然幅を測って渡す / :3-5,25-32 doc を縦横の契約に改訂。テスト 3 件追加 (74 件通過)、lint 3 本 exit 0。実測: 幅指定なしの短い Text が左端密着 → 中央 (evidence/row-placement-horizontal-{before,after}.png)。縦のはみ出し対策の維持を経路 B list/grid で目視確認 → **採用** (2 周目レビューへ)
- 独立レビュー review-013 → CHANGES_REQUESTED (Major 1 / Minor 1 / Suggestion 4)。前回 Major 2 件は解消。新規 Major: 幅変化 reset が `lastContainerSize` 初期値 `.zero` のため初回レイアウトで必ず発火し実測値を捨てる → 初回 contentSize が実質固定 44 に逆戻り (プローブ A/B: 現行 4889 / `!= .zero` 条件付き 7307)、回転後も戻らない。証跡の数値 (誤差 −26.9% → 0%) は現行コードで再現しない → 修正 + 測り直し。Minor: 水平中央の doc「素の UIHostingConfiguration と同じ」は初版 (topLeading) との比較しかなく未検証。参考: phase-3 agenda の申し送りが doc-structure-lint item-chars 200 を超過 (541 字)
- review-013 Major 修正 → 幅変化の即時 reset を撤去し遅延破棄へ: KsEstimatedHeight.swift:20-21,32-47 `record(height:width:)` で幅と対に保持、幅が変われば次の実測時に前の幅の分を捨てる (`reset()` 削除) / KsCollectionViewController.swift:266-268 `onMeasuredSize` で記録、viewDidLayoutSubviews と layoutKindChanged の reset を撤去 / KsHostingCell.swift `onMeasuredHeight` → `onMeasuredSize`、prepareForReuse で解除。理由: 「初回だけ除外」案は回転後 44 固着が残る。遅延破棄なら幅変化直後は前の幅の平均 (44 より真値に近い) を使い、新しい幅の実測で置き換わる。invalidate 契機は不変。テスト 4 件追加/改訂 (77 件通過)
- 測り直し (現行コード, スクロール制御デモ list): 初回 contentSize 4705 → 6433.33 (誤差 −26.9% → 0%)、末尾命令中の contentSize 変化回数 25 → 1 (前回の「再計算 27 → 3」はプローブ粒度の違い、指標を統一)、到達位置同一。大量件数デモの数値は不変 (平均 51.83 / contentH 264,301)
- review-013 Minor (水平等価性) → 素の UIHostingConfiguration / 初版 / 現行の 3 条件比較。素と現行のスクリーンショットは sha256 一致、初版のみ相違 → doc の表現は維持。evidence/row-placement-horizontal-plain.png + -measurement.md 追加
- Suggestion → 判別不能な静止画を 1 条件 1 枚に削減 (evidence 3.5MB)。lint 3 本 exit 0 → 継続 (3 周目レビューへ)
- 独立レビュー review-014 → **APPROVED** (Minor 1: summary.md のテスト件数ずれ → 訂正 / Suggestion 3 は任意・見送り)。プローブ実測で初回取りこぼし・回転後 44 固着とも非再現、header/footer 側は変更不要と判定
- 完了: summary.md 確定。git commit / push はオーナー側
