# セカンドオピニオン: paging-state-machine (spec-001)
**相方**: codex / **label**: so-spec-paging-state-machine / **日付**: 2026-09-27 / **対象**: 提案一式 (kasane/changes/paging-state-machine/ の proposal.md / design.md / specs/ / tasks.md / ui/brief.md / ui/mock/ の案 A・B。依頼時点の版)
---
## 独立提案レビュー

**判定: NEEDS_DISCUSSION**

実装前に、競合時の責任範囲と、Sample で実際に再現できる操作手順を決める必要があります。既存コード、対象 ADR、Sample 規約を静的に照合しました。ビルド・テストは実行していません。

### 指摘事項

**Major — 失敗後の再試行手順が、切り替えの仕様と両立しない**  
**該当箇所:** `kasane/changes/paging-state-machine/specs/samples/spec.md:29`、`kasane/changes/paging-state-machine/specs/samples/spec.md:34`  
**問題点:** 切り替えをオフにすると「その場で再読み込み」します。失敗フッターの「再試行」を押す前に状態と項目が更新され、指定された「オフにして再試行」という Scenario を再現できません。オンにした時点でも取り直しが失敗するため、次ページの失敗だけを観察する手順になっていません。  
**推奨修正:** 切り替え時の自動再読み込みを見直すか、失敗と再試行を確実に観察できる操作・テスト手順を別に定めてください。

**Major — 追加読み込みと取り直しの競合を防ぐ条件が足りない**  
**該当箇所:** `kasane/changes/paging-state-machine/design.md:125`、`kasane/changes/paging-state-machine/specs/samples/spec.md:29`  
**問題点:** 引っ張りを止める条件は VM の状態が「追加読み込み中」の間だけです。一方、この提案は VM が状態更新を遅らせてもよいとしています。また、Sample の切り替えと「再読み込み」は追加読み込み中にも操作できます。古い追加読み込みの結果が取り直し後に届き、新しい一覧へ混ざる経路が残ります。提案が参照する `kasane/decisions/core/0023-pull-to-refresh-and-paging-state.md:34` の帰結も、この条件だけでは保証できません。  
**推奨修正:** 実行中の要求も抑止条件に含めるか、取り直しを開始する VM が古い結果を破棄する契約を明記してください。手動再読み込みと切り替えを含む競合 Scenario を追加してください。

**Major — 0 件時の再試行ボタンの操作保証と重なり方が矛盾する**  
**該当箇所:** `kasane/changes/paging-state-machine/design.md:63`  
**問題点:** 0 件の表示はヘッダー・フッターを避けず、iOS ではそれらの背後にある `backgroundView` に置きます。大きなヘッダーまたはフッターが中央まで届くと、再試行ボタンは覆われます。それでも「ボタンは押せる」とする契約を満たせません。Android は前面に重ねる設計なので、重なった場合の操作対象も異なります。  
**推奨修正:** 重なったときの表示順とタッチの優先順位を決めるか、操作可能な表示はヘッダー・フッターを避けてください。重なる大きさのヘッダーを使う Scenario で確認できるようにしてください。

**Major — 「画面から外れたら取り消す」の検知方法が契約より狭い**  
**該当箇所:** `kasane/changes/paging-state-machine/specs/collection-paging/spec.md:106`、`kasane/changes/paging-state-machine/design.md:96`  
**問題点:** iOS の取り消しは `disconnect()` に結び付けていますが、現行の呼び出しは `kasane` 外の `ios/Sources/KsCollectionView/KsCollectionRepresentable.swift:17` にある dismantle 時だけです。画面が見えなくなっても View が保持される場合、要求の取り消しを保証できません。Android も composition からの離脱を「画面から外れた」と同一視しています。  
**推奨修正:** 契約を View の破棄時に限定するか、表示・非表示を観測して取り消す設計にしてください。保持された画面へ移動して戻る Scenario を定めてください。

**Minor — 項目はあるが可視項目が 0 件の発火規則が未定義**  
**該当箇所:** `kasane/changes/paging-state-machine/specs/collection-paging/spec.md:22`  
**問題点:** ルートヘッダーだけで表示範囲が埋まる場合などは、項目数が 0 件ではなくても「いちばん後ろの可視項目」が存在せず、式を評価できません。  
**推奨修正:** 可視項目が現れるまで判定を保留する等の規則を明記してください。

## 突き合わせ結果

ホスト側の自己レビュー (2 周。core/ADR-0017 との衝突 1 件を検出してオーナー判断で core/ADR-0025 を起票、ほかは問題なし) との突き合わせ。相方の 5 件はいずれもホスト側が拾えていなかったもので、該当箇所と実害の筋道が具体的なため、すべて「相方のみ + 根拠強」として採用した。

| # | 重要度 | 指摘 | 採否 | 反映 |
|---|---|---|---|---|
| 1 | Major | Sample の切り替えを変えるとその場で再読み込みするため、「失敗させる」をオフにしてから「再試行」を押す手順が成り立たない | 採用 | 再読み込みするのは「中身を 0 件にする」を変えたときだけにし、「次の読み込みを失敗させる」は次の取得から効かせる。0 件での失敗の Scenario の手順も直した (specs/samples・design Decision 9・tasks 6.2 / 6.3) |
| 2 | Major | 引っ張りを止める条件が「状態が追加読み込み中」だけで、状態の書き換えを遅らせる VM や、Sample の再読み込み・切り替えでは古いページが混ざる経路が残る | 採用 | 引っ張りを止める条件に「ライブラリが頼んだ次ページ要求の処理の実行中」を足した。処理から戻った後に状態を書き換える書き方の残りの隙間と、VM が自分で始める取り直しとの競合は VM の責任として core/ADR-0023 の帰結を正し、Sample の VM は取り直しを始めたら古い読み込みの結果を捨てる (世代で見分ける)。競合の Scenario を足した (specs/collection-paging・specs/samples・design Decision 7 / 9・core/ADR-0023・tasks 5.x / 6.2 / 6.4 / 6.5・proposal の Non-Goals のガイドの申し送り) |
| 3 | Major | 0 件の表示を iOS はヘッダー / フッターの背面 (`backgroundView`)、Android は前面に置くため、重なったときに再試行を押せず、両プラットフォームで重なり方も違う | 採用 | 0 件の表示は両プラットフォームともルートのヘッダー / フッターより前面に重ね、表示の外のタッチは下へ通す (iOS は `backgroundView` をやめて一覧の上の重ね置きにする)。重なっても押せる Scenario を足した (specs/collection-paging・design Decision 3・brief・tasks 3.3 / 3.5) |
| 4 | Major | 「画面から外れたら取り消す」が、iOS の `disconnect()` (dismantle) と Android の composition 離脱より広い | 採用 | 契約を「一覧が破棄されたら取り消す」に狭め、別の画面へ進んでも一覧が残る間は取り消さない (残るかは各プラットフォームのナビゲーションの仕組みしだい) と書いた。core/ADR-0022 の帰結の言い回しも合わせた (specs/collection-paging・design Decision 5・core/ADR-0022・tasks 2.3 / 2.6) |
| 5 | Minor | 項目はあるが画面に出ている項目が 1 つも無いとき (ヘッダーだけで埋まっている等) の発火の規則が無い | 採用 | 画面に出ている項目が 1 つも無いときは (項目が 0 件の場合を除き) 頼まないと書き、Scenario を足した (specs/collection-paging・design Decision 4・tasks 2.6) |

降格: なし。未解決: なし。依頼時点では案 A・B の mock を対象にしており、その後オーナーの指示で案 C (背景が透けるフローティングのパネル) に作り直したが、5 件の指摘は mock の案によらない。
