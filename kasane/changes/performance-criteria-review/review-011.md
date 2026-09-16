# レビュー結果: performance-criteria-review (011 回目)

**日付**: 2026-09-16
**判定**: APPROVED

## サマリー

review-010 の Major 1 件・Minor 2 件・Suggestion 4 件の処理を再確認した。**Major は解消**である — アンカーのテストが定数の厳密一致をやめ「送って静止してから実測した先頭の項目」を採る形になり、判定も「同じ行にいるか」に変わった。レビュアー側で独立に走らせた 2 機種 (画面サイズと倍率が異なる) の絞り込みなし全件と、**review-010 が決定的に落としていた機種での該当 5 本の再実行**が、いずれも 0 failures で通る。Minor 2 件は世代番号 (`anchorGeneration`) の導入で狙いどおり直っており、Suggestion 4 件のうち 2 件 (境界の幾何テスト・`leadingVisibleID` の余白コメント) が入り、2 件 (9.1 の非接続の対照・`KsImageTests` の別起票と tasks 7.3 の注記) は未着手のまま残る。

差し戻さない理由は、**デルタスペックの Scenario として満たせていないものが無い**ことである。Requirement「配列の内部分割 (iOS)」の全 Scenario に対応するテストがあり、境界の幾何・塊の組み直し・位置の維持・区切り線 / 余白 / ヘッダーの境界・スクロール命令のいずれも緑で、本番経路を通っている。残した指摘は 2 件とも Minor で、(1) は「Scenario が触れていない同時適用の窓」、(2) は「テストが採った読み替えと新しい挙動が deviation に記録されていない」— どちらも契約の不成立ではない。

**修正サイクルの 3 周目 (上限)** であるため、残りの扱いを明記する。**Minor 1 は本体コードの変更を伴うので 9 系 (実機再計測) とは並行できない** — 9.1 は最終ビルドでの計測なので、直すなら 9 系の前、直さないなら deviation に「既知の窓」として記録して後続へ送る、のいずれかを先に決める必要がある。**Minor 2 と Suggestion 3 件は文書だけの作業なので 9 系と並行できる**。

### テスト実行

レビュアー側で独立に実行した。ホストが使った機種 (iPhone 16e / 26.0.1、iPad Air 11-inch (M4) / 26.4.1、iPhone 17 / 26.1) とも、review-010 が使った機種とも重ねていない (全件実行の 2 機種)。verify は起動していない。

| 実行 | 環境 | 結果 |
|---|---|---|
| ライブラリ全件 (絞り込みなし、Debug) | iPhone 17 Pro Max Simulator / iOS 26.0.1 (@3x) | **200 tests / 0 failures** |
| ライブラリ全件 (絞り込みなし、Debug) | iPad mini (A17 Pro) Simulator / iOS 26.5 (@2x) | **200 tests / 0 failures** |
| アンカー・回転・ドラッグの 5 本のみ | iPhone 16e Simulator / iOS 26.0.1 | 5 tests / 0 failures |

3 本目は、review-010 で**決定的に落ちていた機種**での再現確認として絞り込み実行した (完了判定は上の 2 機種の全件実行で採る。cross/test-execution.md「完了判定には絞り込みなしの全件実行を使う」)。対象は `test表示形態の切り替えで塊の件数が変わっても先頭の項目を保つ` / `test列数の指定の変更で…` / `testadaptiveで列数が変わると…` / `test向き別列数では回転しても…` / `testドラッグを始めると控えた位置を捨てる`。

Sample の 2 スキームはレビュアー側では実行していない (ホスト報告を採る)。lint は local-path・identity・comment-policy (禁止 0 件 / 検査対象 218 ファイル) とも違反 0。

`KsImageTests` の間欠失敗は、今回の 2 機種の全件実行でも再現しなかった (review-010 の 4 走行と合わせて 6 走行で 0 回)。

## 照合した規約

| 文書 | 適用のきっかけ | 判定 |
|---|---|---|
| cross/comment-policy.md (always) | 新規コメント (世代番号・ドラッグ時の破棄・`leadingVisibleID` の余白) の追加 | 適合。参照は `ios/ADR-0009` / `ios/ADR-0006` の ID 形式のみで、change 名・Decision 番号・レビュー通番の混入は無い。公開 doc コメントへの内部用語の漏れも無い (触れた宣言はすべて internal) |
| cross/test-execution.md | テストの実行と報告 | 適合。新規の待機 (`waitUntil` / `settleContentSize`) はいずれも実時間 deadline + 10 ms の譲り + 期限超過時に実測値を載せて失敗、の 3 点を満たす。件数は上表のとおり併記 |
| cross/runtime-behavior-verification.md | スクロール・再利用・フレーム間タイミングが絡む修正の完了判定 | **部分**。緩和の効き目を 9 系の実機目視で採ることは deviation に記録済みだが、本サイクルで足した挙動 (ドラッグでの破棄・世代による復元の取り下げ) には同じ記録が無い (Minor 2) |
| cross/scroll-performance-gate.md | 性能の証跡・完了判定 | 該当は 9 系。証跡側の非接続の対照の扱いは未着手 (Suggestion 1) |
| ios/performance-verification.md | iOS エンジンのレイアウト経路に触れる変更 | 適合 (本サイクルでの変更なし) |
| cross/sample-parity.md | `samples/` を触るとき | 本サイクルでは samples に変更なし |
| cross/public-identifiers.md / cross/local-development-setup.md | — | 該当なし |

昇格済みルール (`kasane/lessons/<scope>.md`) は未生成のため `kasane/lessons/inbox/` を参照した。`check-tests-exercise-production-path-before-accepting-green` を新しい 3 本のテスト (アンカー・ドラッグ・境界の幾何) の経路確認に、`tests-created-in-change-are-in-scope-for-fixes` を落ちていたテストの扱いに、`report-device-and-os-with-layout-numeric-tests` と `do-not-run-review-and-verify-on-same-simulator` を機種選定と報告に、`check-sibling-contracts-when-fixing-a-review-finding` を「世代番号が他のアンカー経路に及ぼす影響」の追跡に、`verify-interactive-collection-layout-transitions` を回転・列数変化の扱いに適用した。

ios/ADR-0009 は `proposed` のため判定の根拠には使っていない (照合のみ)。accepted の ios/ADR-0003 (compositional layout で統一)・ios/ADR-0006 (同値配列でも可視セルを作り直す)・ios/ADR-0008 (観測する値) との衝突は本サイクルの差分にも見つからなかった。

## review-010 の指摘 7 件の処理状況

| # | 指摘 | 状態 | 根拠 |
|---|---|---|---|
| 🟠 Major | アンカーのテストが定数の厳密一致で待ち、機種によって決定的に落ちる | **解消** | `KsCollectionEngineTests.swift:1262` に `leadingOffsetAfterScrolling(to:in:)` を新設し、`scrollToItem` → `layoutIfNeeded` → `settleContentSize` の後に**実測した先頭の項目**を返す形にした。判定は `:1283` の `assertLeadingItemSharesRow` で「画面の先頭の項目とアンカーのレイアウト属性の `minY` の差が 1 未満」= 同じ行にいるか、に変わった。`:1241` の共通ヘルパ経由で 2 本、adaptive (`:1144`) と回転 (`:1099`) も同じ形に揃っている。落ちていた機種での再実行と、レビュアーの 2 機種の全件実行がいずれも緑 |
| 🟡 Minor 1 | `restoresAnchorAfterApply` / `pendingAnchor` が「適用の束」の単位で持ち越され、遅延復元が古い位置へ戻しうる | **部分** | `KsCollectionViewController.swift:39` の `anchorGeneration` と `:61` の `anchorGenerationAwaitingApply` で復元を適用に紐づけ、`:632-641` が番号の一致を確かめてから戻す。`:203` の `scrollViewWillBeginDragging` が控えを捨てるので、利用者が動かした後に引き戻される窓は塞がった。**推奨の片方 (番号が変わっていたら捨てる) は入ったが、その場合に残る新しい控えの行き先が決まっていない** (下記 Minor 1) |
| 🟡 Minor 2 | 列数が変わらなかった変化で、他の経路が控えたアンカーまで捨てられる | **解消** | `:816` の `restoreAnchorAfterColumnCountChangeIfNeeded` が `containerTransitionAnchor` を `(columnCount, generation)` の組にし、列数が変わらないときの破棄を `anchorGeneration == transition.generation` の下に置いた。控えが別経路のものへ差し替わっていれば捨てない。専用テストは無いが、`:791` の `captureAnchor` と `:808` の `discardPendingAnchor` が世代を進める唯一の口であることはコードで閉じており、読んで確かめられる |
| 🔵 Suggestion 1 | 塊の境界の幾何を `frame` で固定する | **解消** | `KsCollectionEngineTests.swift:844` に `test塊の境界の直前の行が埋まり直後の項目が行頭に置かれる` を新設。2 列で境界の前後 4 項目の `minX` / `minY` を見て、直前の行が 2 列とも埋まること・次の塊の先頭が新しい行の行頭 (`minX` が 1 列目に一致) に来ることを固定している。Scenario「塊の境界に不完全な行が無い」の THEN の幾何がそのまま載った |
| 🔵 Suggestion 2 | `leadingVisibleID()` の余白の扱いが実構成では発火しない | **解消** | `KsCollectionViewController.swift:770-773` に「`contentInsetAdjustmentBehavior = .never` を立てているためバー由来の値は入らず、ここで狭まるのは `contentInset` を自ら持つ構成だけ」が入り、`.never` との矛盾で読み手が止まらない形になった |
| 🔵 Suggestion 3 | 9.1 の「非接続の対照」は再計測とは別に必要 | **未解消** | `evidence/manual-largeData-ios-2026-09-16-prototype.md` の「限界」は依然「対照は 9.1 の最終ビルドでの再計測で兼ねる」のまま。tasks 9.1 にも対照の項は足されていない。文書だけの作業で 9 系と並行できる |
| 🔵 Suggestion 4 | `KsImageTests` の間欠失敗の別起票と tasks 7.3 の注記 | **未解消** | `kasane/changes/` に該当する簡易起票は無い。tasks 7.3 は `[x]` のままで「実経路の確認は 9 系」の句も無い。どちらも文書だけの作業で 9 系と並行できる |

## 本サイクルで入った差分の評価

### 公開 API

不変。追加・変更した表面 (`anchorGeneration` / `anchorGenerationAwaitingApply` / `containerTransitionAnchor` / `discardPendingAnchor()` / `hasPendingAnchor`) はすべて private または internal で、`KsCollectionViewController` 自体が internal。`@_spi(KsMeasurement)` の表面は `KsItemOffsetLookup.itemOffset(of:in:)` 1 本のまま。`KsPublicAPITests` に変更は無い。

### `scrollViewWillBeginDragging` の override と既存の delegate 転送

**衝突しない。** `collectionView.delegate` の設定は `KsCollectionViewController.swift:257` の 1 箇所だけで、行き先は自分自身。`KsScrollController` は delegate を一切持たず、`KsScrollCommandReceiver` 経由で命令を送るだけのハンドルなので、スクロールのコールバックの取り合いは起きない。ライブラリ内に `UIScrollViewDelegate` の他の実装・転送も無い (`scrollView` を含む宣言はこの override だけ)。`super` を呼ばない判断も妥当で、コメント (`:200-202`) が「`UICollectionViewController` 自身が実装を持たない任意メソッドなので `super` は実体の無い呼び出しになる」と単独で読める形で理由を書いている。

### 世代番号の設計と Decision 12 の整合

**整合する。** Decision 12 が定める経路 (`captureAnchor` → apply → `restorePendingAnchor`、塊の件数が変わるときだけ控える、項目だけの増減・並べ替えでは控えない) は変わっていない。世代番号はその経路の内側で「どの適用が要求した復元か」を識別するだけの追加で、契約の形を変えていない。`restorePendingAnchor()` が使用時に `discardPendingAnchor()` を通して世代を進めるため、「控えは 1 度だけ使う」が 1 箇所で閉じているのも良い。

一方、**ドラッグで控えを捨てる挙動は Decision 12 にも design にも書かれていない新しい挙動**である (下記 Minor 2)。

### 新しいテストが本番経路を通るか

| テスト | 本番経路 | 評価 |
|---|---|---|
| `test表示形態の切り替えで…` / `test列数の指定の変更で…` (`:1181` / `:1198`) | `controller.update(configuration:)` → `apply` の `chunkSizeChanged` 経路 | **通る**。実装が使う `leadingVisibleID()` と同じ幾何 (レイアウト属性と表示範囲の重なり) でアンカーを採っており、テスト側の定義 (`onScreenItemOffsets`) との食い違いは `contentInset` を持たない現構成では生じない。判定が「同じ行」に緩んだ分は、列数が変わると元のアンカーが行頭でなくなるため必要な緩和であり、位置が先頭へ飛べば行が一致せず落ちる (弁別は保たれている) |
| `testドラッグを始めると控えた位置を捨てる` (`:1217`) | `viewWillTransition(to:with:)` は実装のメソッドを直接呼ぶ。`scrollViewWillBeginDragging(_:)` も直接呼ぶ | **部分**。メソッドの中身は本番のものだが、**UIKit が実際にこの delegate を呼ぶことは担保していない**。`viewWillTransition` について deviation に記録されているのと同じ型の限界であり、こちらには記録が無い (Minor 2) |
| `test塊の境界の直前の行が埋まり直後の項目が行頭に置かれる` (`:844`) | 本番の compositional layout が解いたレイアウト属性 | **通る**。`layoutAttributesForItem(at:)` の実測で、`assertChunkStructure` の件数だけの検査が前提にしていた「塊の先頭が行頭に置かれる」を幾何で固定した |

### その他 (確認した観点、指摘なし)

- **足場アーティファクトの書き換え**: `specs/` と `design.md` に本サイクルの変更は無い
- **tasks の虚偽チェック**: 6 系・7 系・8 系の `[x]` はいずれも対応する実装とテストがある。7.8 は「取り下げ」と理由付きで `[ ]` のまま、9 系と 5 系は未着手のまま `[ ]`
- **待機の形**: `waitUntil` (`:3149`) は deadline 2 秒・10 ms の譲り・期限超過で実測値つき失敗。`settleContentSize` (`:2641`) は deadline 5 秒・200 ms の静止判定・期限超過で失敗。`leadingOffsetAfterScrolling` が静止せずに先頭を読む形にはなっていない
- **`anchorGeneration` のオーバーフロー**: `&+=` で包むため未定義動作は無い。一致比較の誤合致は 2^63 回の捕捉を要し、現実的な範囲では起きない
- **`hasPendingAnchor` の露出**: 観測専用の internal 計算プロパティで、値の更新も分岐も足していない。`chunkRebuildCount` / `processedCommandCount` と同じ扱いで、理由コメントも付いている
- **早期 return の分割と ios/ADR-0006**: `:494-508` は同値配列でも可視セルを作り直したうえで、塊の件数が変わるときだけ snapshot 構築へ進む形を保っている。本サイクルでの変更なし
- **境界の区切り線 / 余白 / ヘッダー**: `:419-421` の `indexPath.item == 0 && indexPath.section == 0`、`:731-737` の内側余白、`:740-745` のヘッダー / フッターはいずれも本サイクルで変わっていない

## 指摘事項

### [🟡 Minor] 世代が一致しないときに遅延復元を取り下げるだけで、新しい控えの行き先が無い

**該当箇所**: `ios/Sources/KsCollectionView/KsCollectionViewController.swift:632-645` (適用の束の完了での分岐)、とくに `:638` の `guard anchorGeneration == requestedGeneration else { return }` と `:643` の `else` 側

**問題点**:
遅延復元は「番号が合えば戻す / 合わなければ何もしない」の 2 分岐で、**番号が合わなかったときに `pendingAnchor` へ入っている新しい控えを誰も引き受けない**。次の並びで穴になる。

1. 塊の件数が変わる適用 A が走り、`:622` で `anchorGenerationAwaitingApply = G` を置く
2. A の完了の前に `update(configuration:)` が届き、配列も layout 値も変わる (ただし塊の件数は変わらない。行間・列間・内側余白の差し替えがこれに当たる)。`:143` の `captureAnchor()` で世代が G+1 になり、`pendingAnchor` は新しい控え P2 に差し替わる。配列が変わっているので `:504` の早期 return には入らず、`settleAnchorIfNeeded()` も通らない
3. 束の最後の完了で `anchorGenerationAwaitingApply` は G のまま (2 の適用は `chunkSizeChanged` ではないので上書きしない)。`:638` で G ≠ G+1 となり復元は取り下げられ、`:643` の `else` にも入らないため **P2 は戻されないまま残る**
4. その後、塊と無関係な適用が完了すると `:643` の `restorePendingAnchor()` が P2 を拾い、**その時点の表示位置を 2 の時点の位置へ引き戻す**

つまり review-010 が指摘した「古い控えが後から効く」窓が、幅は狭まったものの完全には閉じていない。利用者のドラッグが挟まれば `:203` で捨てられるので被害はさらに限定されるが、間に入るのが `scrollController` によるプログラム的なスクロールだった場合はドラッグが発生せず、そのスクロールが打ち消される。

修正前の挙動 (束の終わりに常に最新の控えを戻す) では 3 の時点で P2 が戻っていたので、この経路に限れば**本サイクルの修正で新しく生じた穴**である。デルタスペックの Scenario はいずれも同時に届く適用を含まないため**契約違反ではなく、Scenario として満たせていないものは無い**。重要度を Minor に置いたのはこのため。

**推奨修正**:
- `:638` で番号が合わなかったときに、`pendingAnchor` が残っていれば**それを戻す** (新しい控えの方が後に採られており、位置としてはそちらが正しい) か、**明示的に `discardPendingAnchor()` で捨てる**かのどちらかに決め、選んだ理由をコメントに書く。どちらでも穴は閉じるが、前者は「控えた側の期待どおり戻る」、後者は「戻さないが後から効くこともない」で契約が変わるため、どちらを契約にするかを決めること
- **本体コードの変更なので 9 系 (実機再計測) とは並行できない**。9.1 は最終ビルドでの計測であり、後から `KsCollectionViewController` を触ると計測のやり直しになる。直すなら 9 系の前、直さないなら `deviation.md` に「適用が重なったとき、塊と無関係な後続の適用で控えが遅れて効きうる」を既知の窓として記録して後続の change へ送る — 記録の無いまま送ると蒸留のときに契約として読めなくなる

### [🟡 Minor] テストが採った読み替えと、新しく入った挙動が deviation に記録されていない

**該当箇所**: `kasane/changes/performance-criteria-review/deviation.md` (末尾)。関係する実装は `ios/Sources/KsCollectionView/KsCollectionViewController.swift:203-205`、テストは `ios/Tests/KsCollectionViewTests/KsCollectionEngineTests.swift:1283-1300`

**問題点**:
本サイクルで 3 つの読み替え・新挙動が入ったが、`deviation.md` は本サイクルで 1 行も増えていない。

1. **判定の読み替え**: Scenario「adaptive で列数が変わると塊を組み直して位置を保つ」の THEN は「X が表示範囲の先頭に留まる」、Scenario「向き別列数で列数が変わっても不完全な行が無い」の THEN は「表示範囲の先頭にあった項目が先頭に留まる」と書かれている。テストが固定しているのは「**X が画面の先頭の行にいる**」であり、列数が増えると X 自身は行頭ではなくなるため、文字どおりの THEN とは一致しない。列数が変わる以上これが唯一成立しうる読み方だと考えるが、**読み替えである以上は合意済み差分として記録しておかないと、蒸留のときに spec の文言のままで契約として読まれる**
2. **新しい挙動**: 「利用者がドラッグを始めたら控えた位置を捨てる」は design Decision 12 にも spec にも無い。`concepts/core/styling/collection-layout.md` の「切り替え直前に表示範囲の先頭にあった要素をアンカーとして表示範囲内に残す (ios/ADR-0003)」に対する限定 (復元の前にドラッグが始まれば残さない) にあたるので、蒸留で concepts を追随させる手掛かりが要る
3. **検証の限界**: `testドラッグを始めると控えた位置を捨てる` は delegate メソッドを直接呼ぶため、**UIKit が実際にこの delegate を届けることは担保していない**。`viewWillTransition` については「SwiftUI の representable 経由の階層まで届くことはテストでは担保できないため 9 系の目視で確かめる」と deviation に書かれているのに、同じ型の限界であるこちらには記録が無い。cross/runtime-behavior-verification.md が「実行環境で実体が変わる経路はテストの緑で否定しない」と定めている範囲でもある

**推奨修正**:
`deviation.md` に 3 行を足す。(1) は「THEN の『先頭に留まる』を『先頭の行に留まる』と読み替える。理由: 列数が変わると元の先頭の項目は行頭ではなくなるため。spec 本文の追随は蒸留時」、(2) は挙動と理由 (復元と利用者の操作が競合する窓を塞ぐ) を 1 行、(3) は「delegate が UIKit から届くことは 9 系の実機・Simulator の実操作で確かめる」を 1 行。**文書だけの作業なので 9 系と並行できる**。

## 指摘ではない所見

### [🔵 Suggestion] 段階送りを採らなかった理由がどのアーティファクトにも残っていない

review-010 は `advanceToSolvedPosition` (段階送り) の再利用を推していたが、実装は `leadingOffsetAfterScrolling` を新設して一度に送る形を採った。`:1259-1261` のコメントは「定数で決め打ちして待たない」理由を書いているが、**段階送りを採らなかった理由は書かれていない**。「2 列グリッドで段階送りにすると UIKit のレイアウトの再帰検出でプロセスが落ちる」といった種類の知見は、次に同じ形のテストを書く人が必ず踏み直すので、`kasane/lessons/inbox/` に 1 本積むか deviation に 1 行残しておくと安い。あわせて、位置まで送るヘルパが `scrollToDeepPosition` / `advanceToSolvedPosition` / `leadingOffsetAfterScrolling` の 3 本になった (それぞれ浅い位置・行の高さが解けるまで刻む・深い位置を一度に) ので、使い分けを 1 箇所にまとめて書いておくと次の書き手が迷わない。

### [🔵 Suggestion] 9.1 の「非接続の対照」(review-010 の再掲)

`evidence/manual-largeData-ios-2026-09-16-prototype.md` の「限界」は、非接続の対照を「9.1 の最終ビルドでの再計測 (同じ fixture・同じ手順) で兼ねる」と書いたままである。cross/scroll-performance-gate.md が求めているのは計測器を接続せずに同じ操作列を 1 回行う対照なので、Instruments を張った 9.1 の走行そのものは対照にならない。9.1 の項に「接続下の計測 1 回」と「非接続の対照 1 回 (体感と数値が食い違ったときだけ)」を別の走行として書くか、食い違いに当たらないと判断したならその理由を証跡に書く。**9 系の手順の書き足しなので 9 系と並行できる**。

### [🔵 Suggestion] `KsImageTests` の別起票と tasks 7.3 の注記 (review-010 の再掲)

`KsImageTests.test失敗した表示はビューが作り直されると再び取得を試みる` の間欠失敗は、レビュアーの全件走行 6 回 (iPhone 16e / 26.0.1 ×3、iPad Air 11-inch (M4) / 26.4.1 ×1、iPhone 17 Pro Max / 26.0.1 ×1、iPad mini (A17 Pro) / 26.5 ×1) で 1 度も再現していない。本 diff は `KsImage` にも読み込み経路にも触れていないので、簡易起票で別の change に積み、完了報告では「本 diff 外・レビュアー側では再現せず」と明記して全件緑の主張から切り離すのがよい。あわせて tasks 7.3 の行に「実経路の確認は 9 系」の 1 句を足すと、`[x]` と実態 (`viewWillTransition` の到達は未確認) がずれない。**どちらも文書だけの作業で 9 系と並行できる**。

### [🔵 Suggestion] 「別経路の控えを残す」側の専用テスト

`restoreAnchorAfterColumnCountChangeIfNeeded` の世代一致ガード (`:827`) は、回転と layout 値の差し替えが同じレイアウトパスの間に重なったときだけ効く分岐で、決定的なテストを組めなかったという扱いになっている。組み直しの本番経路を通すのが難しいなら、`viewWillTransition` の後に `captureAnchor` を起こす経路 (`update(configuration:)` の layout 値の差し替え) を直接呼んでから `viewDidLayoutSubviews` を踏ませ、`hasPendingAnchor` が残ることだけを見る形なら、`testドラッグを始めると控えた位置を捨てる` と同じ粒度で書ける。本サイクルで足す必要は無いが、世代番号の分岐が 2 か所とも観測されていない状態は次に触る人が壊しやすい。

## アクションプラン

1. **Minor 1 (9 系と並行不可)**: 世代が合わなかったときの新しい控えの行き先を「戻す」か「捨てる」に決める。9 系の前に直すか、直さずに deviation へ「既知の窓」として記録するかを先に決める
2. **Minor 2 (9 系と並行可)**: deviation に 3 行 — 「先頭に留まる」→「先頭の行に留まる」の読み替え、ドラッグでの控えの破棄、delegate の到達がテストでは担保されないこと
3. **Suggestion 3 件 (すべて 9 系と並行可)**: 段階送りを採らなかった理由の記録とヘッダーの使い分け、9.1 の非接続の対照、`KsImageTests` の別起票と tasks 7.3 の注記
4. 9 系 (実機再計測) は 1 の判断が付き次第着手できる
