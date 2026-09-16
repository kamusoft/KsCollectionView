# Deviation: performance-criteria-review

- Scenario「合計高さの見積もりを損ねない」(collection-layout / tasks 2.4): spec では GIVEN「固定高と可変行高が混在する配列」で THEN「初回表示の誤差 ±5% 以内、末尾までの contentSize 変化 3 回以下」→ 指示により GIVEN を「行の高さが一様な配列 (1 列)」に読み替え、基準値はそのまま。理由: design Decision 2 の基準値 (平均での 0% / 1 回) の出典が一様リストの証跡 (`kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/estimated-height-ab-measurement.md`) で、混在 2 列グリッドは行高 = 列内の最大のため単一の推定値では合計を当てられず、平均 (12.0% / 134 回) でも最頻値 (34.5% / 134 回) でも基準を満たさない (採取環境: iPhone 17 Pro Max Simulator / iOS 26.0、全件を刻んで走査する当時の計測形。校正後の計測形では未再採取)。一様配列の実測は下表 (2026-09-15)。

  再検証の計測は「初回表示の後に末尾へ 1 回で送り、その間の contentSize の変化を数える」形にそろえた (基準値の出典と同じ形。全件を刻んで走査する形では、セルの再利用の過程で行が伸びる現象 — 推定とは独立で平均でも起きる — が混ざり、同じ基準で比べられない)。実際の合計高さは「実測した行の高さ × 件数」の解析値を使う (行 = セルで一様なため。到達後の contentSize は解き終えた範囲までしか反映しないので基準にならない)。変化回数は**合計高さの 0.1% を超える変化だけ**を数える (オーナー判断で校正。件数が多いほど到達直前に合計の 0.03% 未満の引き直しが数回入り、その回数は機種で変わるため)。一様配列 2,000 件・窓 390x844・最頻値での実測:

  | Simulator / OS | 初回表示の誤差 (基準 ±5%) | 0.1% 超の変化回数 (基準 3 回) | 0.1% 以下の変化回数 (参考) |
  |---|---|---|---|
  | iPhone 16e / 26.1 | 0.15% | 2 | 1 |
  | iPhone 17 / 26.1 | 0.10% | 2 | 3 |
  | iPhone 17 Pro / 26.4 | 0.10% | 2 | 3 |
  | iPhone Air / 26.1 | 0.09% | 1 | 2 |
  | iPhone 17 Pro Max / 26.0 | 0.09% | 1 | 3 |

  退行の対照 (推定を固定 44pt にしたとき) は iPhone 17 / 26.1 で誤差 20.96% (初回 87,897 / 実測 72,667)、iPhone 17 Pro Max / 26.0 で 20.95% となり、校正後の基準でも落ちる (2026-09-15)
- Requirement「推定高さと一致するセルの自己サイズ (iOS)」(collection-layout): design Decision 1 は「推定値として返すのも量子化後の値」と書くが、実装は**数えるときだけ量子化し、返すのはその格子に入った直近の実測値そのもの**とした。理由: 格子へ丸めた値は実測と半画素 (倍率 3 で 0.167 pt) までずれ、その大きさの差は**解き直しを起こさないまま「渡した高さのまま行が積まれる」**ため、全行ぶんが合計高さの誤差として積み上がる (実測: 差 0.1 pt で 60 行のとき 6.0 pt ちょうど。倍率 3 で 2,180.0 → 2,186.0、倍率 2 で 2,190.0 → 2,196.0。10,000 件なら 1,000 pt、量子化で起こりうる最悪の差 (半画素 = 倍率 3 で 0.167 pt) なら約 1,670 pt)。実測値をそのまま返せば、同じ高さに測られるセルとの差は浮動小数の最下位桁に収まり、積み上がらない。
  確定した事実 (`ios/Tests/KsCollectionViewTests/KsSelfSizingInvalidationTests.swift`。判定は iPhone 16e / 26.1 と iPhone 17 Pro Max / 26.0 の両方で成立、回数の実測値は iPhone 16e / 26.1):
  - `shouldInvalidateLayout(forPreferredLayoutAttributes:withOriginalAttributes:)` は**自己サイズ 1 回につき 1 回呼ばれる**。override が効くのはレイアウトを `init(sectionProvider:)` で派生させたときだけで、ファクトリ経由で作った実体では効かない。ただしその**戻り値は解き直しの有無と連動しない** (差が大きくても `false` が返る) ため、判定には `invalidateLayout(with:)` の回数と「セルを測った回数」を使う
  - 解き直しの境界は**画面のピクセル格子への丸め (半画素)** にある。60 件・窓 390x844・**倍率 3** で渡す推定高さを変えたときの測定回数は **完全一致 22 回 / 最下位桁だけ違う (`nextUp`) 22 回 / +0.1 pt (半画素未満) 22 回 / +0.2 pt (半画素超) 44 回 / +8 pt 44 回**
  - 許容の内側では解き直しが起きない代わりに、渡した高さのまま行が積まれる (+0.1 pt のとき 60 行で合計が 2,180.0 → 2,186.0 pt。倍率 2 の iPad Pro 11-inch (M5) / 26.4 でも 2,190.0 → 2,196.0 と同じ 6.0 pt)
  - 境界の大きさは**画素に対して相対**である。倍率 2 (1 画素 0.5 pt・半画素 0.25 pt) では +0.2 pt でも解き直しは起きない (iPad Pro 11-inch (M5) / iOS 26.4 で実測。レビュアーの iPad mini (A17 Pro) / iOS 26.4 でも再現)。確定テストの対照は `displayScale` から振る
  これを受けて診断カウンタの一致判定は「差が 1e-9 pt 未満なら一致」とした。境界 (半画素) そのものではなく十分内側に置くのは、境界ぎりぎりの幅を許すと上の積み上がりを一致として見逃すためである。当初の「1 画素未満なら一致」は 0.2 pt の差を一致に数えるので上界にならない。実測: 混在 2 列 2,000 件の不一致率は **0.100** (不一致 950 / 自己サイズ 9,495。2026-09-15、iPhone 16e / 26.1)
- [付随修正] `samples/android/benchmark/src/main/kotlin/.../ImageGridBenchmark.kt` の KDoc: 廃止された絶対基準 (フレーム超過時間の絶対値で評価) を前提にした記述を「計測の成立だけを見る」に書き直し。`measureRoundTrips` の KDoc から件数比の理由づけを除去 (2026-09-15)
- [付随修正] `kasane/handbook/android/performance-verification.md` のメモリ手順: 走査が置換 → 離脱まで続くようになったため、`MemoryUsageMetric` は離脱後の水準として載せ、定常判定はアプリ自身の往復ごとの記録が正であることを明記 (グループ 3 の実装に追随) (2026-09-15)
- [付随修正] 同時生存カウンタは既存の `TemplateInvocationCounter` (debug 限定・ログ出力あり) を共用せず、`measurement` ソースセットに `MeasurementLifetime` を新設。理由: benchmark ビルド種別では既存カウンタが空実装で assert が常に 0 を読む (検査しない緑) ため。design Decision 5 の「debug ソースセット」は measurement ソースセット (debug + benchmark) に読み替え (2026-09-15)
- Scenario「合計高さの見積もりを損ねない」(tasks 2.4) の THEN 後半: spec では「末尾までの contentSize 変化回数は 3 回以下」→ 指示により「合計高さの 0.1% を超える変化の回数が 3 回以下」に校正 (微小な引き直しは数えない)。理由: 基準値 3 回の出典 (`kasane/changes/archive/2026-09-04-ios-engine-foundation/evidence/estimated-height-ab-measurement.md`) は 100 件のリストの実測で、2,000 件では +2〜+137pt (合計 72,900pt の 0.03% 未満) の微小な引き直しが機種により 4〜5 回起きる (iPhone 16e / Air 26.1 = 3、17 Pro Max 26.0 = 4、17 26.1 = 5、17 Pro 26.4 = 5)。この引き直しは推定の決め方に依らず平均でも同数発生し、基準が捕まえたい「見積もりが外れて段階的に伸びる」破綻 (固定 44pt で 25 回・+37%) は校正後も捕まえられる (2026-09-15)
- Requirement「iOS の計測ドライバの構成」(samples): spec では「メモリの自動往復だけを持つ (SHALL)」→ `PerformanceDriverUITests` の画像グリッドの観測駆動 (`test画像グリッドで基準点を切り送って戻す`。image-loading の読み込み計数の観測用で、スクロール性能の駆動ではない) は残す。理由: 退役の対象は tasks 2.6 / design Decision 7 / proposal のとおり「自動フリック 2 本と signpost」であり、この観測駆動は image-loading の証跡取得に使う。spec の文言は蒸留時に「メモリの自動往復と画像読み込みの観測駆動」に追随する (2026-09-15)
- tasks 4.1 の判定 (2026-09-15): design Decision 2 の 4 基準で**不合格** (件数比例 4.1 倍、10,000 件の体感不合格。不一致率 0.032 と合計高さは合格)。Decision 3 に従い最頻値化での実装を停止し、オーナー判断 (A) で「提案を改訂して内部セクション分割を追加、再レビュー後にこの change で実装継続」を採用。改訂には次も含める: iOS メモリ往復ドライバの定常判定つき反復と footprint のログ出力 (Scenario「往復後もメモリが定常化する」に未追随、`evidence/memory-roundtrip-ios-2026-09-15.md`)、Sample の Xcode プロジェクトの Debug 構成への `SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG` 追加 (不一致率の帯のボタンが出ない)、`devicectl device process launch` の引数は `--` の後ろに置く旨の iOS 規約への追記
