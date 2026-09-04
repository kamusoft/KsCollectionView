# レビュー結果: ios-engine-foundation (013 回目)

**日付**: 2026-09-03
**判定**: CHANGES_REQUESTED

## サマリー

前回の Major 2 件はいずれも解消した — 動画 2 本は削除され静止画の連番に置き換わり、水平位置は中央に戻って doc コメント・テスト・目視証跡がそろっている。Minor 4 件も 3 件が解消、1 件が記録による部分解消。

一方、Minor「`reset()` の契機とコメントの食い違い」に対して入れた「コンテナ幅の変化で `reset()`」が**推定高さの実測化そのものを無効化する回帰**を生んでいる。この `reset()` は初回レイアウトでも必ず発火し (`lastContainerSize` の初期値が `.zero`)、その直後の invalidate で走る section provider が既定値 44 に戻ってしまう。実測平均が layout へ届く契機はその後に無いため、初回表示のコンテンツ全体の高さは実質「固定 44」時代へ逆戻りする。`evidence/estimated-height-ab-measurement.md` が示す「初回の見積もり誤差 -26.9% → 0%」は、現行コードでは成立しない。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| [ソースコメント規約](../../handbook/cross/comment-policy.md) | always |
| [Sample のプラットフォーム間一致](../../handbook/cross/sample-parity.md) | `samples/` を触るため (検証画面の追加・ルートメニュー改変) |
| [実行時挙動の検証規約](../../handbook/cross/runtime-behavior-verification.md) | 実行時挙動の不具合修正・完了判定 (本 change が本文を改訂) |
| [テスト実行規約](../../handbook/cross/test-execution.md) | テストの実行と件数報告 |
| [ローカル開発環境と Sample の実行](../../handbook/cross/local-development-setup.md) | 本体・Sample のビルド |
| [公開識別子と配布座標](../../handbook/cross/public-identifiers.md) | 公開 API・配布座標に変更が無いことの確認 |
| ksn-core `references/ui-artifacts.md` / `references/evidence.md` | `evidence/` の媒体とメモを差し替えたため |
| ios/ADR-0001〜0004、core/ADR-0001・0006 | 翻案移植・自前 compositional セクション・薄い Representable ラッパー・レイアウト語彙 |
| lessons inbox `verify-interactive-collection-layout-transitions` (scope: code-review) | 重点観点「layout 切替後の上下スクロール・回転を含む操作後の安定性」 |

ドメインスキル: `swift-ui-impl-skill` (`Layout` の使い方・1 ファイル 1 型・View 分割・モダン API・Concurrency)。`skills.code-review` は ios ドメインに未定義。

## 検証したこと

- **ビルド / テスト**: `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug` → `Executed 74 tests, with 0 failures`。`xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples`(同 Simulator) → `Executed 3 tests, with 0 failures`。summary.md の「74 件通過 (着手前 60 + 追加 14)」と一致する
- **lint**: `comment-policy-lint.py --summary` → 禁止 0 件 (検査対象 73 ファイル) / `identity-lint.py`・`local-path-lint.py` → 検出なし
- **公開 API 不変**: Sources 側の追加宣言は `KsRowContentPlacement` / `KsEstimatedHeight` の 2 型と `KsHostingCell.onMeasuredHeight` で、いずれも internal。`KsPublicAPITests` は無改変で通過
- **動画の不在**: `kasane/` 配下に `.mov` / `.mp4` / `.webm` は 0 件。summary.md・deviation.md・evidence の各メモに「録画」への参照も残っていない
- **水平中央の実装**: `contentOrigin(in:naturalWidth:)` は `finite()` を通すため、自然幅が `.infinity` でも NaN でも「提案幅いっぱい」とみなして `bounds.minX` に落ちる。自然幅が提案幅より広い場合も `max(0, ...)` で先頭に落ちるので左方向へはみ出さない。`bounds.origin` が非ゼロ (grid の 2 列目) でも `bounds.minX` 起点で計算しており、`KsRowContentPlacementTests` の `test原点は行の位置を基準にする` (bounds.x=205 → origin.x=255) が実際に押さえている
- **目視証跡**: `evidence/row-placement-horizontal-before.png` / `-after.png` を開いて、短い `Text` が左端密着から中央へ移っていることを確認した。個人を特定する写り込みは無い
- **invalidate 回数**: `viewDidLayoutSubviews` の `estimatedHeight.reset()` は既存の `guard containerSize != lastContainerSize` の内側にあり、`invalidateLayout()` の呼び出し箇所も回数も増えていない。回転・adaptive の列数変化で invalidate が増える懸念は**該当なし** (コメント「直後の invalidate に相乗りする」は正しい)
- **推定高さの実効性 (下記 Major の根拠)**: 本体パッケージをスクラッチへ複製し、100 件の list を window に載せて初回 `contentSize.height` を観測するプローブを当てた。`viewDidLayoutSubviews` の幅 `reset()` の有無だけを切り替えた A/B は下表のとおり (行の実測高 130.67pt、同一 Simulator・同一テンプレート)。複製側だけを編集しており、リポジトリのコードは触っていない

  | `viewDidLayoutSubviews` の幅 reset | 初回 contentSize.height | そのとき `estimatedHeight.value` |
  |---|---:|---:|
  | 現行コード (無条件) | 4889.33 | 75.29 |
  | reset を外す (前サイクルの実装) | **7306.67** | 72.92 |
  | reset を残し `lastContainerSize != .zero` を条件に足す | **7306.67** | 72.92 |

  現行コードだけ `contentSize` が実測平均ではなく既定値 44 基準に落ちている (推定値 75.29 は保持されているのに layout へ届いていない)。幅変化 (390×844 → 844×390) の後も同様で、`contentSize=4727.33` / 推定値 `85.67` と乖離したままだった

## 前回指摘 (review-012) の解消状況

| # | 前回の指摘 | 状態 | 根拠 |
|---|---|---|---|
| 🟠 1 | 証跡に動画 (.mov) を残している | **解消** | `.mov` 0 件。`evidence/height-change-after-ab-measurement.md` の「録画」節が静止画連番の節に差し替わり、summary.md の記述も追随 |
| 🟠 2 | `KsRowContentPlacement` が水平位置も先頭固定 | **解消** | `KsRowContentPlacement.swift:73-79` で余白を等分。doc コメント (`:3-5`, `:20-25`) が水平位置も契約に含め、テスト 3 件と目視証跡が付いた。summary.md に採用値と根拠を追記済み。ただし証跡の性質に別途 Minor 1 件 (下記) |
| 🟡 3 | content に行の高さを提案しない帰結が未記録 | **解消** | deviation.md の tasks 3.2 の行に「grid で背の低いセルは行高いっぱいに広がらず自然高のまま上端」を明記 |
| 🟡 4 | 移動平均由来の contentSize の揺れが未測定 | **部分解消** | deviation.md に「既知の帰結」として記録され、未測定であることも明示された。推奨した大量件数デモの通しスクロール観測は未実施。記録で追跡可能な状態にはなっているため、これ以上は求めない |
| 🟡 5 | `reset()` の契機とコメントの食い違い | **対応したが回帰** | コード側で解消したが、初回レイアウトでも発火して推定の実測化が効かなくなった (下記 Major) |
| 🟡 6 | コメントが説明対象の行とずれている | **解消** | `KsCollectionViewController.swift:276-277` が `contentConfiguration` 代入の直上へ移動し、`onMeasuredHeight` にも独自の 1 行が付いた |
| 🔵 7 | `Layout` 本体の配線が未検証 | **部分対応** | `KsRowContentPlacementTests.swift:6-9` に「この 2 つが唯一の入口である」ことを明記。提案どおりの代替対応 |
| 🔵 8 | `sizeThatFits` の未使用計測 | **未対応** | 幅・高さとも有限の提案では `natural` が依然未使用。加えて `placeSubviews` 側に計測が 1 回増えた (下記 Suggestion) |
| 🔵 9 | `prepareForReuse` で `onMeasuredHeight` を解除していない | **未対応** | 解除は入らず、代わりに `applyContent` へ「内容を適用したセルの計測だけを数える」というコメントが付いた (下記 Suggestion) |
| 🔵 10 | 検証画面に UI テストが無い | **未対応** | `samples/ios/KsCollectionViewSamplesUITests/` は 2 ファイルのまま |
| 🔵 11 | ルートメニューで検証画面が区分として分かれていない | **未対応** | `RootMenuView.swift:6-17` は `List` 直下に 2 つ目の `ForEach` を並べる形 |

## 指摘事項

### [🟠 Major] 幅の `reset()` が初回レイアウトでも発火し、推定高さの実測値が layout へ届かない

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:137-139` (と `:40` の `lastContainerSize` 初期値)

**問題点**: `lastContainerSize` の初期値は `.zero` なので、初回の `viewDidLayoutSubviews` では必ず `containerSize.width != lastContainerSize.width` が成り立ち、`estimatedHeight.reset()` が走る。ところがこの時点では**最初のレイアウトパスで可視セルの自己サイズ計測が既に終わっており、実測値が溜まっている**。それを捨ててから `invalidateLayout()` するため、直後に再実行される section provider は `KsEstimatedHeight.defaultValue` (44) を読む。

その後に実測値は再び溜まるが、**推定値が layout へ反映される契機は section provider の再実行だけ**であり、`invalidateLayout()` を呼ぶのは (a) layout 値 / contentPadding / supplementary 構造の変化 (`:114-116`)、(b) コンテナサイズの変化 (`:141`) の 2 つしかない。どちらも起きなければ、初回表示のコンテンツ全体の高さは 44 基準のまま固定される。

上記「検証したこと」のプローブ A/B がこれを示す。現行コードの初回 `contentSize.height` は 4889.33 で、`reset()` を外す (= 前サイクルの実装) と 7306.67 になる。`reset()` を残したまま `lastContainerSize != .zero` を条件に足しても 7306.67 に戻るので、原因が初回パスでの `reset()` であることは切り分けられている。

影響は文書にも及ぶ。`evidence/estimated-height-ab-measurement.md` の A/B (初回誤差 -26.9% → 0%、末尾命令中の再計算 27 → 3) と、それを引く summary.md・deviation.md の記述は、**この `reset()` を入れる前のコードで測った値**であり、現行コードでは再現しない。証跡ファイルの更新時刻もこの修正より前にある。

同じ機構により、回転などで幅が変わった後も推定値は 44 に戻ったきり戻らない (プローブ 2 本目: 幅変化後 `contentSize=4727.33` に対し `estimatedHeight.value=85.67`)。前サイクルの実装は「古い幅で測った平均が残る」不正確さを持っていたが、少なくとも 44 よりは真値に近かった。今回の修正は指摘の趣旨に沿う一方で、この点では前より悪くなっている。

**推奨修正**: どちらかを採る。

1. **`reset()` を実際の幅“変化”に限る** — `lastContainerSize != .zero` (または `lastContainerSize.width > 0`) を条件に加え、初回パスでは捨てない。加えて、幅変化後も推定が 44 のままにならないよう、実測が溜まった時点で 1 度だけ section provider を再実行させる契機を用意する (例: `reset()` 後の最初の一定件数の `record` で `invalidateLayout()` を 1 回だけ呼ぶ)。無限ループにしないための収束条件をコメントで明示すること
2. **幅の `reset()` を入れず、review-012 の代替案 (コメント側を実際の契機に合わせる) に戻す** — `KsEstimatedHeight.reset()` の doc コメント (`KsEstimatedHeight.swift:35-37`) から幅の話を外し、「表示形態の切り替えで捨てる」に直す。回転後に別の幅の平均が残る不正確さは deviation.md に既知の帰結として記録する

いずれの場合も、`evidence/estimated-height-ab-measurement.md` の A/B は**現行コードで測り直す**必要がある。数値が変わるなら summary.md・deviation.md の引用も合わせて直す。

### [🟡 Minor] 水平中央の証跡が「この Layout が無かったとき」と比べていない

**該当箇所**: `evidence/row-placement-horizontal-before.png` / `evidence/row-placement-horizontal-after.png`、`ios/Sources/KsCollectionView/KsRowContentPlacement.swift:3-5`,`:20-25`、summary.md「採用値と根拠」

**問題点**: doc コメントは「素の `UIHostingConfiguration` と同じ見え方を保ちます」「この Layout が無かったときと同じ位置に来るようにします」と、**Layout 非適用時との等価性**を契約として宣言している。しかし置かれた 2 枚の証跡が比べているのは「初版 (`.topLeading` 固定)」と「修正後 (中央)」であり、宣言の基準になっている「Layout が無い状態」は撮られていない。review-012 が求めたのは「変更前後の水平位置を実測し、**中央だったと確認できたら**中央維持を採る」であり、この確認が抜けている。

もう 1 点、この 2 枚には測定条件のメモが無い。画像内の文言は「行 1」だが、リポジトリ上の `samples/ios/KsCollectionViewSamples/HeightChangeRowBody.swift:13` は「行 N の先頭」を描き、かつ `:27` で `.frame(maxWidth: .infinity)` を付けている。つまり撮影時に幅を明示しない別テンプレートへ一時的に差し替えているが、それが読み取れるのは画像を開いて文言の食い違いに気づいた場合だけになる。同じ change の他 2 件の A/B には測定条件を書いた `.md` があり、この 1 件だけ summary.md の括弧書き 1 行しか無い。

**推奨修正**: `evidence/row-placement-horizontal-measurement.md` を 1 本足し、(a) 撮影に使った一時テンプレート (幅を明示しない短い `Text`)、(b) 3 条件 — Layout 非適用 / `.topLeading` / 中央 — の水平位置、を記録する。Layout 非適用が中央でなかった場合は、doc コメントの「素の `UIHostingConfiguration` と同じ」という表現を実測に合う書き方へ直す。

### [🔵 Suggestion] `placeSubviews` の計測を `Layout` の cache に載せられる

**該当箇所**: `ios/Sources/KsCollectionView/KsRowContentPlacement.swift:38`,`:50`

`sizeThatFits` と `placeSubviews` がそれぞれ `subview.sizeThatFits(...)` を呼ぶ。通常の経路では両者の提案が一致し、`LayoutSubviews` の計測結果はレイアウトパス内でキャッシュされるため実コストはほぼ増えないと見ているが、`Layout` の `cache` 引数が `()` のまま未使用で、この型が「1 回測って両方で使う」ことを構造では保証していない。`makeCache` / `updateCache` に自然高を持たせると意図が型に出る。低優先。

なお前回の 🔵「`sizeThatFits` が使わない計測を毎回行う」は、幅・高さとも有限の提案 (`resolvedSize` が `natural` を一切参照しない経路) では今も残っている。

### [🔵 Suggestion] `prepareForReuse` が `onMeasuredHeight` を解除しないまま、コメントが解除済みを前提にしている

**該当箇所**: `ios/Sources/KsCollectionView/KsHostingCell.swift:112-120`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:272`,`:278-281`

`applyContent` に付いた「内容を適用したセルの計測だけを推定高さに数えるため、content と対で設定する」というコメントは、`prepareForReuse` でハンドラが外れることを前提にしないと成り立たない。実際には `prepareForReuse` は `contentConfiguration` だけを `nil` にしてハンドラを残すため、セル登録が `itemsByID` の引き当てに失敗して `applyContent` を通らなかったケース (`KsCollectionViewController.swift:242-247` の guard) では、内容が空のセルの計測が前回のハンドラ経由で記録されうる。`record` が 0 以下を弾くので実害は小さいが、コメントが宣言する性質をコードが保証していない状態になっている。`prepareForReuse` に `onMeasuredHeight = nil` を足せば、コメントの主張がそのまま構造で担保される。

### [🔵 Suggestion] 判別できない静止画 6 枚を残す価値が薄い

**該当箇所**: `evidence/height-change-after-ab-before-centered-{01,02,03}.png` / `evidence/height-change-after-ab-after-topaligned-{01,02,03}.png`、`evidence/height-change-after-ab-measurement.md` の「静止画 (遷移の連番)」節

ksn-core `references/ui-artifacts.md` の「動画は残さず静止画の連番で代替する」には形として適合しており、**規約違反ではない**。メモが「この静止画だけでは修正前後を判別できない」と正直に書き、数値 A/B が主証跡だと明示している点も良い。一方で、判別できない画像を 6 枚 (約 1.6MB) 置くことは、その規約が動画を避ける理由 (容量) と同じ方向に働く。`distill.archive-media: delete` の設定では archive 時にどのみち消える。1 条件 1 枚 (遷移中のフレーム) へ絞るか、数値表だけを残す判断もあってよい。低優先。

### [🔵 Suggestion] 検証画面の UI テストとルートメニューの区分 (前回から未対応)

**該当箇所**: `samples/ios/KsCollectionViewSamplesUITests/`、`samples/ios/KsCollectionViewSamples/RootMenuView.swift:6-17`

review-012 の 🔵 2 件がそのまま残っている。`--verify-height-change` に対応する UI テスト (「行をタップ → `heightChange.expandedCount` が `展開中: 1 行`」だけのスモーク) は、テンプレート内 state / 親 state の経路が壊れたときの回帰検知になり、回避策を外す後続 change (`template-parent-state-observation`) の再確認にも使える。ルートメニューの `Section("検証")` は sample-parity の例外枠が求める「明確に区別する」を文言に加えて構造でも満たす。どちらも任意。

## 参考 (レビュー範囲外)

`kasane/roadmaps/v1-foundation/phases/phase-3-android-wrapper-foundation/agenda.md:36` に本 change が追記した申し送りが 541 字の 1 箇条書きになっており、`doc-structure-lint.py` が `item-chars: 200` 超過として検出する (同ファイルの既存 1 件と合わせ 2 件)。roadmaps は本レビューの対象範囲外のため指摘には数えないが、追記した側で拾えるようここに残す。

## アクションプラン

1. **Major**: 幅の `reset()` を初回パスで発火させない (または幅 reset をやめる) 形へ直し、推定の実測値が初回表示の layout に届くことをプローブまたは Sample で確認する
2. **Major の付随**: `evidence/estimated-height-ab-measurement.md` の A/B を現行コードで測り直し、summary.md・deviation.md の引用値を実態に合わせる
3. **Minor**: 水平位置の証跡に測定条件のメモを足し、「Layout 非適用時と同じ」という doc コメントの主張を実測で裏付ける (裏付かないなら表現を直す)
4. 🔵 4 件は任意。`prepareForReuse` の 1 行だけは、既に書いたコメントの主張と実装を一致させる意味があるので優先度がやや高い
