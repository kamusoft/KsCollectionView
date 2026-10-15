# セカンドオピニオン: release-pipeline (spec-001)
**相方**: codex / **label**: so-spec-release-pipeline-001 / **日付**: 2026-10-14 / **対象**: 提案一式 (kasane/changes/release-pipeline/ の proposal.md・design.md・specs/・tasks.md)
---
実装前に修正が必要です。特に、同じ版の再実行で、異なる commit の配布物が両プラットフォームに出る経路が残っています。静的レビューの指摘は以下のとおりです。

1. **Critical — [specs/release-workflow/spec.md:152](kasane/changes/release-pipeline/specs/release-workflow/spec.md:152)**  
   **問題点:** Maven Central 公開後、両リポジトリの tag 作成前に失敗すると、版と元 commit を照合する情報がありません。その後 `main` が進み、同じ版で新しく起動すると、tag 検査は通り、Android の送信は公開済みとして省略され、iOS と本リポジトリには新しい commit の tag が付き得ます。公開後のビルド確認だけでは、この不一致を検出できません。  
   **推奨修正:** 版・元 commit・配信用 commit・発行物のハッシュを結び付け、公開済みの版でも一致を検査してください。両 tag が無い状態で、異なる commit から再実行した場合の拒否 Scenario を追加してください。

2. **Major — [design.md:94](kasane/changes/release-pipeline/design.md:94)、[specs/release-workflow/spec.md:184](kasane/changes/release-pipeline/specs/release-workflow/spec.md:184)**  
   **問題点:** 失敗時には保留の送信を取り下げ、ID を消す一方、Scenario は「保留で送った後に失敗した試行」の ID を引き継ぐとしています。通常の失敗後には、その前提が成立しません。また、design は打ち切り時にも取り下げられるとしていますが、強制終了では後始末の実行を保証できません。[GitHub の取消仕様](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-cancellation)  
   **推奨修正:** 通常失敗・取消・後始末失敗・公開要求の応答喪失を分け、状態ごとの再開動作を定義してください。次回起動時に実際の deployment 状態を照会し、取り下げ済み ID は再利用せず、公開処理中なら再送しない Scenario が必要です。

3. **Major — [specs/release-workflow/spec.md:114](kasane/changes/release-pipeline/specs/release-workflow/spec.md:114)、[specs/verification-ci/spec.md:51](kasane/changes/release-pipeline/specs/verification-ci/spec.md:51)**  
   **問題点:** 送信 ID を保存した artifact の削除には `actions: write` が必要ですが、公開ジョブは `contents: write` 以外の権限を拒否する契約です。控えの削除を実装すると、権限検査と衝突します。[GitHub の artifact 削除 API](https://docs.github.com/en/rest/actions/artifacts#delete-an-artifact)  
   **推奨修正:** 公開ジョブに限定して `actions: write` を許可するか、artifact は残し、照会結果に基づいて無効な ID を無視する契約へ変更してください。

4. **Major — [tasks.md:62](kasane/changes/release-pipeline/tasks.md:62)**  
   **問題点:** 10.2・10.3 は、新設の `release.yml` を `main` に入れる 10.6 より前に手動起動します。既定ブランチは `main` であり、`workflow_dispatch` は既定ブランチに workflow ファイルが存在する必要があります。この初回手順では、想定する検証まで到達できません。[GitHub の起動条件](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_dispatch)  
   **推奨修正:** workflow を通常の PR 経路で先に `main` に導入する準備段階を設けるか、初回の起動検証を 10.6 の後へ移してください。

5. **Major — [specs/release-workflow/spec.md:99](kasane/changes/release-pipeline/specs/release-workflow/spec.md:99)**  
   **問題点:** spec は「Release を作る」としか定めていません。design:143 と ADR-0024 の「題は版そのもの・プレリリースの印なし・最新として明示指定」が契約と Scenario に落ちていません。初回の最新 URL の確認だけでは、題や印の正しさは判定できません。  
   **推奨修正:** Release の題・tag・draft/prerelease の値・最新指定を Requirement に明記し、作成結果を検査する Scenario を追加してください。

6. **Major — [specs/release-skill/spec.md:46](kasane/changes/release-pipeline/specs/release-skill/spec.md:46)**  
   **問題点:** 「事前の確認の結果」を並べるだけで、agenda:110 が決めた「`develop` の CI が緑」「未 push の commit が無い」の検査と、不成立時の動作が定義されていません。また、文面確定後に `develop` が更新された場合、その追加変更まで承認済みとしてマージできる余地があります。  
   **推奨修正:** CI の対象 SHA・手元と remote の一致・確認対象の commit 範囲を定義してください。確定後に対象 SHA が変わったら停止する Scenario も追加してください。

7. **Minor — [specs/release-workflow/spec.md:66](kasane/changes/release-pipeline/specs/release-workflow/spec.md:66)、[specs/release-workflow/spec.md:109](kasane/changes/release-pipeline/specs/release-workflow/spec.md:109)**  
   **問題点:** Side Effects は artifact と公開先だけで、Android の組み立て・署名付き再組み立てが残すビルド出力を含みません。既存の配布仕様と consumer-verification:130 は、追跡対象外のビルド出力も状態変更として列挙しています。  
   **推奨修正:** 作業用 Maven リポジトリとビルド出力の作成・更新を列挙するか、対応する既存 Requirement の Side Effects を明示参照してください。

8. **Minor — [specs/release-notes/spec.md:31](kasane/changes/release-pipeline/specs/release-notes/spec.md:31)**  
   **問題点:** 空の Changes 節、空の説明、重複した Changes 見出し、HTML コメント、次の節との境界の扱いが未定義です。ひな形の説明を節内に置くと、それ自体が「読めない行」になり得ます。  
   **推奨修正:** 節の抽出規則と許容する空白・コメントを定義し、空節・空説明・重複見出しの受理／拒否 Scenario を追加してください。

9. **Minor — [specs/release-workflow/spec.md:159](kasane/changes/release-pipeline/specs/release-workflow/spec.md:159)**  
   **問題点:** Requires は両リポジトリの tag の一致を要求しますが、範囲外 Scenario は本リポジトリの不一致だけです。配信用 tag が別の写しを指す場合の拒否が検証対象になっていません。  
   **推奨修正:** 本リポジトリの tag は一致し、配信用 tag だけが不一致の場合、最初の検査で公開操作前に停止する Scenario を追加してください。

ビルド・テストの実行、ファイルへの書き込みは行っていません。

## 突き合わせ結果

ホスト側の自己レビュー (2 周、問題なしで通過) は、9 件のどれも挙げていなかった。9 件とも相方のみの指摘で、該当箇所と実害の筋書きが具体的なので、すべて採用した。確定 0 / 採用 9 / 降格 0 / 未解決 0。

| # | 重要度 | 採否 | 判定の根拠と反映 |
|---|---|---|---|
| 1 | Critical | 採用 | tag だけの照合では、Maven Central の公開の後・tag の前に失敗し、`main` が進んでから同じ版で起動し直すと、別の commit の iOS と tag が出せる。発行物の POM に元の commit を書き、公開済みの版は元の commit が起動した commit と同じときだけ続ける形にした (spec の公開の順序・同じ版での再実行、design の Decision 3・4、tasks 2.1・2.7、cross/ADR-0022 の Decision の 1 文) |
| 2 | Major | 採用 | 失敗の経路で取り下げて控えを消す一方、控えを引き継ぐ Scenario があり、矛盾していた。打ち切りでは後始末が走るとは限らない。控えの送信の状態を照会して、保留中・公開の処理中・失敗・見つからないで扱いを分けた。別の run に残った保留の送信は扱わず、手順の文書に取り下げ方を置く (spec・design の Decision 4・Risks・tasks 2.3・7.1) |
| 3 | Major | 採用 | 控えの artifact を消すには `actions: write` が要り、公開のジョブの権限の決まりと衝突する。控えは消さずに残し、照会した状態で古さを決める形にした (spec の Side Effects、design の Decision 4・9) |
| 4 | Major | 採用 | 既定のブランチは `main` で (2026-10-14 に API で確認)、手動の起動には既定のブランチに workflow のファイルが要る。準備の Pull Request で先に `main` へ入れる段を足した (design の Decision 12、tasks 10.2、proposal) |
| 5 | Major | 採用 | Release の題・draft・プレリリースの印・最新の指定が、契約になっていなかった。公開の順序の Requirement に書き、属性を読む Scenario を足した |
| 6 | Major | 採用 | agenda の決定の事前の確認 (`develop` の検証 CI・push していない commit) が spec に無く、確定の後に `develop` が進むと追加の変更までマージできた。事前の確認の Requirement を足し、確定を対象の commit への承認にして、先端が変わったらマージせずに止める形にした (release-skill の spec、design の Decision 11、tasks 6.2) |
| 7 | Minor | 採用 | 利用者役の仕様はビルドの出力を状態変更として数えており、揃っていなかった。ランナーの作業ディレクトリを Side Effects に足した |
| 8 | Minor | 採用 | ひな形の書き方を節の中に置くと、それが読めない行になる。節の範囲・注釈 (HTML のコメント) を除くこと・空の節・空の説明・節が 2 つのときを決め、Scenario を足した |
| 9 | Minor | 採用 | Requires の配信用リポジトリの tag に、範囲外の Scenario が無かった。Scenario を足した |
