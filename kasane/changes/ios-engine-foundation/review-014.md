# レビュー結果: ios-engine-foundation (014 回目)

**日付**: 2026-09-03
**判定**: APPROVED

## サマリー

前回の Major (幅 `reset()` による推定高さの実測化の無効化) は解消した。`reset()` 自体を持たず、実測値を「測ったときの幅」と対で保持して**違う幅の実測が来た時点で捨てる**遅延破棄に置き換わっており、破棄と記録が同一呼び出しで完結するため、1 件でも実測が入った後は推定値が既定値 44 へ戻る経路が構造的に無くなっている。前回と同じ手法のプローブで、初回表示・回転後・list ⇄ grid 切替のいずれでも推定値が実測に追随し layout へ届くことを確認した。

前回の Minor (水平位置の証跡) も解消。Layout 非適用の 3 条件目が撮られ、非適用と現行の PNG が 1 バイト単位で同一であることを当方でも sha256 で確認した。🔵 のうち `prepareForReuse` と静止画の枚数も対応済み。

残るのは summary.md のテスト件数が実測と食い違う 1 点 (🟡) と、任意の 🔵 3 件のみ。いずれも実装の欠陥ではなく、追加の修正サイクルを回す必要はない。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` を触るため (検証画面・ルートメニューの追加) |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動の不具合修正・完了判定 (本 change が本文を改訂) |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と件数報告 |
| [ローカル開発環境と Sample の実行](../../handbook/cross/local-development-setup.md) | 本体・Sample のビルド |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | 公開 API・配布座標に変更が無いことの確認 |
| ksn-core `references/evidence.md` / `references/ui-artifacts.md` | `evidence/` の媒体とメモを差し替えたため |
| ios/ADR-0001〜0004、core/ADR-0001・0006 | 翻案移植・自前 compositional セクション・薄い Representable ラッパー・レイアウト語彙 |
| lessons inbox `verify-interactive-collection-layout-transitions` (scope: code-review) | 重点観点「layout 切替後の上下スクロール・回転を含む操作後の安定性」 |

ドメインスキル: `swift-ui-impl-skill` (`Layout` の使い方・1 ファイル 1 型・View 分割・モダン API・Concurrency)。`skills.code-review` は ios ドメインに未定義。

## 検証したこと

- **ビルド / テスト**: `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug` → `Executed 77 tests, with 0 failures`。`xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`(同 Simulator) → `Executed 3 tests, with 0 failures`
- **lint**: `comment-policy-lint.py --summary` → 禁止 0 件 (検査対象 73 ファイル) / `identity-lint.py`・`local-path-lint.py` → 検出なし / `doc-structure-lint.py` → `handbook/` `concepts/` に検出なし (検出は `roadmaps/` のみ = 本レビュー範囲外)
- **公開 API 不変**: Sources 側の追加宣言は `KsRowContentPlacement` / `KsEstimatedHeight` の 2 型と `KsHostingCell.onMeasuredSize` で、いずれも internal。`KsPublicAPITests` は無改変で通過
- **一時計測コードの残留なし**: `--fixed-estimate` / `--no-top-align` の分岐はソースに残っていない。`print(` の残りは既存の性能計測ドライバのみ
- **水平位置の証跡**: `evidence/row-placement-horizontal-measurement.md` の「Layout 非適用と現行は PNG が同一」を当方でも検証 — `row-placement-horizontal-plain.png` と `-after.png` の sha256 が一致 (`6ba3856d…`)、`-before.png` のみ異なる。doc コメントが宣言する「素の `UIHostingConfiguration` と同じ見え方」は実測で裏付けられている
- **推定高さの実効性 (プローブ実測)**: 前回と同じ手法で本体パッケージをスクラッチへ複製し、推定値を読むアクセサだけを複製側に足して観測した (リポジトリのコードは触っていない)。100 件・iPhone 17 Pro Simulator。

  | 条件 | 初回/切替後の `contentSize.height` | そのときの推定値 | 実測の行高 |
  |---|---:|---:|---:|
  | 初回表示 (list, 390pt 幅) | 14173.11 | 141.47 | 141.5 |
  | 回転後 (844pt 幅) | 16200.00 | 162.00 | 162.0 |
  | list → 1 列 grid (幅は不変) | 14040.69 | 140.56 | 140.6 |
  | list → 2 列 grid (幅 390 → 195、折り返しで高さが変わる content) | 8855.87 | 183.10 | 168.7 |

  初回表示の見積もりが実測どおりになっており、前回 Major で観測した「44 基準へ逆戻り」は再現しない。回転後も新しい幅の実測で置き換わっている (前回は 44 に固着したままだった)。`evidence/estimated-height-ab-measurement.md` の主張 (初回の見積もり誤差 0%) は現行コードで定性的に再現する
- **推定値が layout へ届く経路**: 自己サイズ計測に伴う invalidate でも section provider は再実行される。上表の「list → 2 列 grid」で、幅変化後に `invalidateLayout` を明示的に呼ばなくても推定値が新しい幅の平均 (183.10) に基づく `contentSize` になっていることがこれを示す。deviation.md の「効くのは次に invalidateLayout が走るとき」は実際より保守的な記述で、実挙動はそれより早く追随する
- **既定値へ戻らないこと**: `KsEstimatedHeight.record(height:width:)` は破棄 (`samples.removeAll()`) と記録 (`append`) を同一呼び出しで行うため、1 件でも実測が入った後は `samples` が空になる瞬間が存在しない。`KsEstimatedHeightTests.swift:71` (`test幅が変わると前の幅の実測値を捨てる`) と `:80` (`test幅が変わっても新しい幅の実測が入るまでは前の幅の平均を使う`) がこの性質を両側から固定している
- **幅のばらつき**: 同一レイアウトパス内で `fractionalWidth` から導かれるセル幅は全セル共通になる。3 列 grid (列間隔 1pt / コンテナ幅 393pt) で可視セルの幅を集めても種類は 1 つ (130.0) だった。回転や分割ビューのリサイズ途中の中間幅で標本が入れ替わる可能性は残るが、上記のとおり既定値へは落ちないため実害は無い (下記 🔵)
- **`prepareForReuse` の解除**: `KsHostingCell.swift:117-118` で `onMeasuredSize = nil` が入り、`applyContent` のコメント (「prepareForReuse で内容と一緒に解除される」) が構造で担保されている。`dequeueConfiguredReusableCell` は `prepareForReuse` → 登録クロージャの順で走るため、再利用セルの計測が記録から漏れることはない
- **header / footer に同種の変更が要らないこと**: `KsHostingSupplementaryView` はホスト View を上下左右のアンカーで境界アイテムの矩形に固定する (`KsHostingSupplementaryView.swift:35-41`) ため、セル側で問題になった「ホスト View 既定の中央配置による上方向のはみ出し」は起きない。`KsRowContentPlacement` で包む必要はない。推定値も `KsEstimatedHeight.defaultValue` (44) 据え置きで、セルの実測平均に header / footer の高さが混ざらない分離になっている (summary.md 記載どおり)
- **ルートメニューの区分**: `VerificationScreen.swift:3` の文言が `検証: 行の高さ変化 (iOS 固有)` で始まり、sample-parity の例外枠が求める「デモとは別物だと分かる表記」を満たす。`Section` の有無は規約の要求ではない

## 前回指摘 (review-013) の解消状況

| # | 前回の指摘 | 状態 | 根拠 |
|---|---|---|---|
| 🟠 1 | 幅の `reset()` が初回レイアウトでも発火し実測値が layout へ届かない | **解消** | `reset()` は型ごと削除され、`viewDidLayoutSubviews` (`KsCollectionViewController.swift:126-134`) にも `update(configuration:)` にも呼び出しが無い。破棄は `record` 内の遅延破棄に置き換わった。プローブで初回 `contentSize` が実測どおり (14173.11 / 推定 141.47) になることを確認 |
| 🟠 1 付随 | A/B を現行コードで測り直す | **解消** | `evidence/estimated-height-ab-measurement.md` が更新され (「末尾命令中に contentSize が変化した回数 25 → 1」等、前回引用の 27 → 3 から変わっている)、summary.md・deviation.md の引用も追随。当方のプローブでも主張が定性的に再現した |
| 🟡 2 | 水平位置の証跡が「Layout 非適用」と比べていない | **解消** | `evidence/row-placement-horizontal-measurement.md` が追加され、測定条件 (一時テンプレートの内容) と 3 条件 (非適用 / 初版 / 現行) が記録された。`row-placement-horizontal-plain.png` が追加され、現行との PNG 一致を sha256 で当方も確認 |
| 🔵 3 | `placeSubviews` の計測を `Layout` の cache に載せられる | **未対応** | `KsRowContentPlacement.swift:30`,`:45` は `cache: inout ()` のまま。任意 (下記 🔵) |
| 🔵 4 | `prepareForReuse` が `onMeasuredHeight` を解除しない | **解消** | `KsHostingCell.swift:117-118` で解除。ハンドラ名も `onMeasuredSize` になり、幅と対で渡す意図が型に出た |
| 🔵 5 | 判別できない静止画 6 枚 | **解消** | 1 条件 1 枚の 2 ファイルに整理され、メモの「静止画 (遷移中のフレーム)」節も追随 |
| 🔵 6 | 検証画面の UI テストが無い | **未対応** | `samples/ios/KsCollectionViewSamplesUITests/` は 3 ファイルのまま (`InteractiveControlUITests` / `PerformanceDriverUITests` / `UITestSupport`)。任意 |
| 🔵 7 | ルートメニューで検証画面が区分として分かれていない | **対応不要と判断** | 項目文言が「検証: 」で始まり sample-parity の例外枠の要求を満たす。`RootMenuView.swift:6-17` の 2 つ目の `ForEach` で構造も分かれている |

## 指摘事項

### [🟡 Minor] summary.md のテスト件数が実測と食い違う

**該当箇所**: summary.md「触ったファイル」節 (テスト件数の記述 3 箇所)

**問題点**: 確定サマリは「テスト: 74 件通過 (着手前 60 + 追加 14)」「新規 `KsRowContentPlacementTests.swift` (4 件) / `KsEstimatedHeightTests.swift` (7 件)」と書いているが、実測は `Executed 77 tests`、内訳は `KsRowContentPlacementTests` 7 件 / `KsEstimatedHeightTests` 10 件 (追加 17 件) である。最終サイクルで足したテスト 3 件分が件数に反映されていない。

[テスト実行規約](../../handbook/cross/test-execution.md)は「テスト結果を報告するときは実行件数を併記する」を検証成立の条件に置いており、件数が実態と違うサマリは蒸留時にそのまま参照される。数値の訂正だけで済む。

**推奨修正**: summary.md の 3 箇所を 77 / 17 / 7 / 10 に直す。実装・テストの変更は不要。

### [🔵 Suggestion] 幅の比較に許容差がなく、幅が揺れ続けると標本窓が 1 件に縮む

**該当箇所**: `ios/Sources/KsCollectionView/KsEstimatedHeight.swift:38-46`

`sampledWidth != width` は厳密比較なので、幅が僅かでも変われば標本を全部捨てる。破棄と記録が同一呼び出しなので**推定値が既定値 44 へ戻ることはなく**、最悪でも「直近 1 件の実測」に縮むだけで、固定 44 より悪くなる場面は無い。実測でも同一パス内のセル幅は 1 種類に揃っており (3 列 grid・列間隔 1pt でも 130.0 のみ)、揺れが定常化する経路は見つからなかった。

残るのは回転・分割ビューのリサイズ**途中**の中間幅で標本窓が繰り返し 1 件に縮む可能性で、これは過渡的であり平均の意味が一時的に薄れるだけ。現状で対応は要らないが、将来 `contentPadding` を連続変化させるデモ (スペーシングと余白) と組み合わせたときに「平均のはずが直近 1 件」になっていないかは、性能・安定性を見るときの観測点として覚えておく価値がある。許容差 (例: 0.5pt) を入れる余地もあるが、入れるなら「どこまでを同じ幅とみなすか」の根拠を実測で持つべきで、今その根拠は無い。

### [🔵 Suggestion] `placeSubviews` の計測を `Layout` の cache に載せられる (前回から継続)

**該当箇所**: `ios/Sources/KsCollectionView/KsRowContentPlacement.swift:30`,`:45`

`sizeThatFits` と `placeSubviews` がそれぞれ `subview.sizeThatFits(...)` を呼ぶ点は変わっていない。`LayoutSubviews` の計測はレイアウトパス内でキャッシュされるため実コストはほぼ増えないが、`makeCache` / `updateCache` に自然高を持たせると「1 回測って両方で使う」意図が型に出る。低優先。

### [🔵 Suggestion] 検証画面の UI テスト (前回から継続)

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/`

`--verify-height-change` に対応するスモーク (行をタップ → `heightChange.expandedCount` が `展開中: 1 行`) は、テンプレート内 state / 親 state の経路が壊れたときの回帰検知になり、回避策を外す後続 change (`template-parent-state-observation`) の再確認にも使える。任意。

## 参考 (レビュー範囲外)

`kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:31` の申し送りが 459 字の 1 箇条書きで、`doc-structure-lint.py` の `item-chars: 200` を超える (前回の 541 字から短くはなった)。roadmaps は本レビューの対象範囲外のため指摘に数えないが、追記した側で拾えるようここに残す。

## アクションプラン

1. **🟡 Minor**: summary.md のテスト件数 3 箇所を実測値 (77 / 追加 17 / 7 / 10) に直す。数値の差し替えのみで、再レビューは不要
2. **🔵 3 件**: いずれも任意。実装の欠陥ではなく、着手するならオーナー判断で後続 change に回してよい

修正サイクルの上限に達しているが、残る指摘に**実装の是正を要するものは無い**。1 の件数訂正はレビューを回さずに反映してよく、2 はオーナー判断で見送っても本 change の完成度に影響しない。
