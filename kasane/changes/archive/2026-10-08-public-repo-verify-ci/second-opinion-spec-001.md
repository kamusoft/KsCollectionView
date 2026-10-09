# セカンドオピニオン: public-repo-verify-ci (spec-001)
**相方**: codex / **label**: so-spec-public-repo-verify-ci-001 / **日付**: 2026-10-08 / **対象**: kasane/changes/public-repo-verify-ci/ の proposal.md / design.md / specs/ / tasks.md (自己レビュー 2 周の後の版)
---
判定は **修正要求**です。実装前に解消すべき Major が 4 件、Minor が 1 件あります。

1. **Major — 公開前の履歴検査が merge commit を取りこぼす**
   
   該当箇所: `kasane/changes/public-repo-verify-ci/design.md:193`、`kasane/changes/public-repo-verify-ci/tasks.md:44`
   
   標準検査に全履歴の確認を委ねていますが、`scripts/git-gate-lint.py:173` は `--no-merges` でコミットを列挙しています。既存履歴にも merge commit があり、マージ時の競合解消などで初めて加わった内容は検査対象になりません。最初の commit を別途確認するだけでは、公開スペックの「履歴の中身に違反が無い」を保証できません。
   
   **推奨修正:** 公開する `main`・`develop` の先端を固定し、そこから到達する merge commit を含む全コミットの内容を検査する手順を定義してください。merge commit だけで違反を追加したケースも異常系の確認対象に加えてください。

2. **Major — 管理者の迂回を許す設計と、例外のない保護契約が矛盾する**
   
   該当箇所: `kasane/changes/public-repo-verify-ci/design.md:177`、`kasane/changes/public-repo-verify-ci/specs/repository-publication/spec.md:143`
   
   design は管理者に保護を強制しないと明記しています。一方、spec は `main` が PR を経た変更だけを受け、両ブランチで強制 push・削除を禁止すると例外なく要求しています。設計どおりの設定では、この契約を満たせません。管理者は既定で保護の適用対象外になります。[GitHub 公式文書](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
   
   **推奨修正:** 管理者の迂回を受け入れる方針を spec にも明記し、適用対象と例外を Scenario で区別してください。絶対的な禁止を求めるなら、design の設定を変更する必要があります。

3. **Major — 件数検査の合格条件が「全件実行」を確認できない**
   
   該当箇所: `kasane/changes/public-repo-verify-ci/design.md:99`、`kasane/changes/public-repo-verify-ci/specs/verification-ci/spec.md:161`、`kasane/changes/public-repo-verify-ci/tasks.md:19`
   
   Android の判定は、モジュール・タスクごとに結果ファイルが存在し、件数が正数なら通る形です。これでは一部のクラスだけが実行された状態を検出できません。既存の `kasane/handbook/cross/test-execution.md:97` は、クラス単位の内訳と期待クラスの出現確認まで求めています。また、スキップされたテストを実行件数に含めるかも未定義で、全件スキップでも正数として通す実装が成立します。
   
   **推奨修正:** 今回実行された結果を使うこと、期待するクラスの確認方法、スキップと実行件数の区別を定義してください。「一部のクラスの結果だけがある」「全件スキップ」の異常系を spec とスクリプトのテストに追加してください。

4. **Major — 永続状態の変更が Side Effects の上限に収まっていない**
   
   該当箇所: `kasane/changes/public-repo-verify-ci/specs/repository-publication/spec.md:35`・`:147`、`kasane/changes/public-repo-verify-ci/specs/verification-ci/spec.md:11`
   
   次の変更が design・tasks にある一方、対応する契約に宣言されていません。
   
   - 手元の `develop` ブランチの作成（`tasks.md:7`）。
   - 検証用ブランチと PR の作成、PR のクローズ、ブランチの削除（`tasks.md:66`）。現在の宣言は本番用 PR の作成・マージだけです。
   - 設定の読み直し結果などの証跡の作成・更新（`design.md:166`）。証跡の宣言は公開前の確認に限定されています。
   - CI の実行・検査結果の永続記録。これはブランチ保護が読む状態なので、診断ログだけとして除外できません。
   
   **推奨修正:** 各操作の Requirement に変更対象と作成・更新・削除を列挙してください。検証用 PR の操作は独立した Requirement にすると、失敗時の後片付けも含めて契約を閉じられます。文書の存在を定める不変条件については、`Side Effects: なし` のままで問題ありません。

5. **Minor — 除外対象だけの新しい push に対する Scenario が矛盾する**
   
   該当箇所: `kasane/changes/public-repo-verify-ci/specs/verification-ci/spec.md:7`・`:28`
   
   `kasane/` だけの push は CI を起動しない契約ですが、「新しい push が古い実行を打ち切る」Scenario は変更内容を限定せず、新しい実行が走ると要求しています。古い CI の実行中に証跡だけを push すると、両方を同時に満たせません。
   
   **推奨修正:** 打ち切りの Scenario を「CI の起動対象となる新しい push」に限定し、除外対象だけの push では新しい実行を作らず、既存の実行を継続するかどうかを明記してください。

ビルド・テストの実行、ファイルへの書き込みは行っていません。`decisions/`・`handbook/`・`concepts/` を実装ワーカーに直接書き換えさせるタスクは見当たりませんでした。

## 突き合わせ結果

突き合わせの相手は、ホスト側の自己レビュー 2 周 (チェックリストの通過と、`evidence/proposal-checks.md` の突き合わせ)。相方の指摘 5 件はすべて相方だけの指摘で、いずれも該当箇所が特定でき、実害の筋道がある。

| # | 指摘 | 採否 | 反映 |
|---|---|---|---|
| 1 | 公開前の履歴の検査が merge commit を取りこぼす | 採用 (ホスト側の見逃し) | 標準の検査が merge commit を数えないことを確かめた (`scripts/git-gate-lint.py` の commit の列挙)。design の Decision 10・spec「公開前の確認」・tasks 6.2・6.4 に、merge commit だけが持つ内容の検査と、対照での検出の確認を足した。gitleaks は merge commit を含む指定にした |
| 2 | 管理者の迂回を許す設計と、例外のない保護の契約が矛盾する | 採用 | spec「ブランチの保護」を、入っている設定の約束に書き直し、管理者には強制しないことを明記した。Scenario の読み直しにも同じ項目を足した。design の Risks に対応を書いた |
| 3 | 件数の検査が「全件の実行」を確かめられない | 採用 (iOS は一部) | 両プラットフォームで、その実行で作られた記録だけを読むことと、スキップを除いて数えることを spec と design の Decision 4 に足した。Android は、テストのソースから導いたクラスの集合と結果を突き合わせて、現れないクラスがあれば失敗にする。iOS はクラスごとの突き合わせを合否にしない (出力の、文書に無い書式に頼ることになるため)。この差は design の Risks に書いた |
| 4 | 永続する状態の変更が Side Effects に収まっていない | 採用 | CI の各 Requirement に、検査の結果と実行の作成・打ち切りを足した。公開の各 Requirement に、手元の `develop` の作成と、設定の読み直しの証跡を足した。確かめるための Pull Request は作らない方針に変えた (閉じても公開リポジトリに残るため)。異常系はスクリプトのテストで確かめ、最初の Pull Request では確認が走ったことを記録で確かめる |
| 5 | 除外の対象だけの push と、打ち切りの Scenario が矛盾する | 採用 | 打ち切りの Scenario を、起動の対象になる push に限った。起動しない push が走っている実行に影響しないことを Scenario に足し、tasks 8.1・8.2 を対応させた |

確定 0 件 / 採用 5 件 / 降格 0 件 / 未解決 0 件。

指摘 1 は、フェーズの議論でオーナーに示した「履歴の検査 0 件」の裏付けにも同じ穴があったことを意味する。そこで採用と同時に、merge commit 3 つがどちらの親とも違う内容を持つファイル 4 件を取り出して検査し直した。結果は `evidence/proposal-checks.md` に書いた (違反なし)。
