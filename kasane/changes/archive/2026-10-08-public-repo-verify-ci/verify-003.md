# Verify 003: public-repo-verify-ci (verify-002 の乖離 1 件への対応の再検証)

- 日付: 2026-10-08
- 対象: `verify-002.md` (INVALID。❌ 1 件) の乖離への対応。`deviation.md` の末尾に足された行が、その ❌ を合意済みの差分として覆っているかを確かめ、55 Scenario と Side Effects の 16 行の最終の区分を出した
- 前回の検証: `verify-002.md`
- 検証の範囲: 今回自分で突き合わせたのは、❌ だった 1 つの Scenario と、verify-002 の後に変わったファイル。ほかの 54 Scenario と Side Effects の 16 行は、下の「引き継ぎの前提」を確かめたうえで、**verify-002 の結果を引き継いだ**
- 対象にしていないもの: `drafts/` の中身 (verify-002 と同じく、置き場があることだけを見た)。GitHub の今の状態の読み直し (今回は流してよいコマンドの外なので、行っていない)

## 判定

**VALID** (❌ 0 件)

| 区分 | verify-002 | 今回 |
|---|---:|---:|
| Scenario の総数 | 55 | 55 (verification-ci 39 / repository-publication 16) |
| ✅ 一致 | 48 | 48 (verification-ci 33 / repository-publication 15) |
| ⚠️ deviation により変更 | 6 | 7 (verification-ci の「iOS の検証」6 / repository-publication の「Issue のフォームの必須項目」1) |
| ❌ 欠落・乖離 | 1 | 0 |
| Side Effects の行 | 16 (✅ 16) | 16 (✅ 16。引き継ぎ) |

- 虚偽のチェック: なし / 逆流: なし / 未記録の乖離: なし / テスト: 111 件成功 (今回流した)
- 変わったのは 1 件だけ: 「Issue のフォームの必須項目 / 3 本のフォームだけが選べる」が ❌ から ⚠️ になった。実装は変わっていない

## 再検証した Scenario

| Requirement / Scenario | 実装 | テスト・証跡 | deviation | 状態 |
|---|---|---|---|---|
| Issue のフォームの必須項目 / 3 本のフォームだけが選べる (本文の「フォームを使わない空の Issue は作れてはならない」を含む) | `.github/ISSUE_TEMPLATE/` の 3 本と `config.yml:1` (`blank_issues_enabled: false`)。verify-002 の時点から変わっていない | `scripts/ci/tests/test_repository_files.py:121`・`:149`。証跡は `evidence/publication-log.md:213`・`:216` (管理する側の画面に、3 本のほかに空の Issue の行が印つきで出る) | `deviation.md:8` | ⚠️ deviation 記録済み |

### deviation の行と、乖離・証跡・実装の突き合わせ

| 見た点 | deviation.md:8 の記述 | 突き合わせた相手 | 合っているか |
|---|---|---|---|
| 対象の Requirement と Scenario | 「Issue のフォームの必須項目 (Scenario「3 本のフォームだけが選べる」)」 | verify-002 の ❌ の Scenario と同じ | ○ |
| spec の記述 | 「フォームを使わない空の Issue は作れてはならない」「空の Issue は選べない」 | `specs/repository-publication/spec.md:107` (本文)・`:123` (THEN)。文面が一致 | ○ |
| 実際の挙動 | 管理する側の画面にだけ、空の Issue を作る行 (`Blank issue`・`Maintainers only` の印つき) が出る | `evidence/publication-log.md:213` の観察と同じ | ○ (「だけ」の部分は下の注) |
| 実装の状態 | 空の Issue を作れなくする設定は design のとおりに入っている | `config.yml:1` と、それを守るテスト | ○ |
| 理由 | GitHub の仕様で、設定では消せない。貢献の受け口には影響しない | verify-002 の見立て (実装では直せない。deviation として合意) と同じ向き | ○ |
| 合意の主体と日付 | オーナーが合意した (2026-10-08) | 行の中に書かれている。コンテキストパッケージの申告とも合う | ○ |
| 乖離の範囲を覆っているか | Scenario の THEN の「空の Issue は選べない」と、本文の「作れてはならない」の両方を引いている | verify-002 が ❌ にした範囲 (THEN と本文) と同じ | ○ |

注:

- deviation の行の「管理する側 (オーナーと共同作業者) の画面にだけ」「管理する側を除いて、空の Issue は作れない」のうち、実際に見たのはオーナーの画面 1 つだけである。共同作業者の画面と、管理する側でない人の画面は誰も見ていない。行そのものが「管理する側でない人の画面は見ていない」と書いているので、記録として偽りは無い。合意済みの差分として数えるが、裏付けは弱い (下の一覧の 2)
- 行の形は、規約の乖離の行 (「→ 指示により <実際>」) ではなく「→ 実際は <実際>」になっている。オーナーの指示で実装を変えた乖離ではなく、実装では直せない差をオーナーが受け入れた乖離なので、文面としては実情に合っている。Requirement の名前・spec の記述・実際・理由・日付はそろっていて、判定には数えない

## 引き継ぎの前提 (verify-002 の後に何が変わったか)

| 確かめたこと | 結果 |
|---|---|
| 手元の先端 | `abf4ade`。verify-002 が対象にした先端と同じ |
| 作業ツリーの差分 (`git status`・`git diff HEAD --stat`) | この change のディレクトリの下の 6 ファイルだけ (`deviation.md`・`drafts/` の 3 つ・`evidence/publication-log.md`・`tasks.md`)。追跡していないファイルは `verify-002.md` だけ |
| ソース・workflow・スクリプト・テスト | 差分なし。`kasane/` の外に、verify-002 より後に変わったファイルは無い |
| 足場 (`proposal.md`・`design.md`・`specs/`) | 差分なし。触れた commit は提案の commit (`a76c380`) だけ。逆流なし |
| verify-002 より後に変わったファイル (更新の時刻で見た) | `deviation.md`・`evidence/publication-log.md`・`drafts/branch-and-github-settings.md` の 3 つだけ |
| `tasks.md` | verify-002 の前に変わったままで、41 件すべてにチェックがある (未チェック 0)。差分は 8.1〜8.4 のチェックの印だけ |
| `deviation.md` の差分 | 末尾の 1 行の追加だけ。前からある行 (`:3`〜`:7`) は変わっていない |
| `kasane/` の中の、この change の外 | 差分なし (長命層は変わっていない) |

この前提のもとで、verify-002 の対応表のうち、上の 1 行を除く 54 Scenario と Side Effects の 16 行を、そのまま引き継ぐ (verification-ci の ✅ 33・⚠️ 6、repository-publication の ✅ 15)。行ごとの実装・テスト・実地の対応は `verify-002.md` の対応表を見ること。

## 証跡の訂正 2 箇所が、verify-002 の根拠を崩していないか

| 訂正 (`evidence/publication-log.md`) | 関わる verify-002 の行 | 見たこと | 結論 |
|---|---|---|---|
| 7.1 の表の順 2: remote `origin` を足したのが、作成のコマンドか、オーナーが手元で流したコマンドかは確かめていない、という訂正 | 「履歴をそのまま公開する — Side Effects」(✅)、追加検査の Side Effects (逆向き) | spec の Side Effects は「手元のリポジトリの remote の設定: 作成」(`specs/repository-publication/spec.md:38`) で、どのコマンドが作ったかを定めていない。どちらが足したにせよ、起きた状態変更は remote の作成と URL の形の変更で、列挙に収まる。verify-002 はこの行を、足した主体には依らずに判定している | 崩していない |
| 7.4 の落ちた iOS のテスト: 「原因は調査中」を「調査は止めた。原因は分かっていない。テストは変えていない」に直した訂正 | 「iOS の検証」の 8 行 (⚠️ 6・✅ 2) と、deviation の記述との突き合わせ | verify-002 の iOS の行は、`deviation.md:5`・`:6`、今の workflow の形、実行 1 の事実 (本体のテストの step が失敗し、その後の Sample の step が走った) に依っていて、落ちた原因や調査の状態には依っていない。訂正は実行 1 の事実 (567 件のうち 1 件が失敗) を変えていない。「テストは変えていない」は、ソースに差分が無いことと合う | 崩していない |

同じファイルの残りの差分 (8.1・8.2 の続き、8.3、8.4 の節) は、verify-002 がすでに作業ツリーの内容として読んでいたもの (verify-002 の所見 1) で、今回の訂正ではない。

## 追加検査

| 検査 | 結果 |
|---|---|
| tasks.md の虚偽のチェック | なし (引き継ぎ。tasks.md は verify-002 の後に変わっていない) |
| 逆流 | なし (今回確かめた) |
| 未記録の乖離 | なし。verify-002 の 1 件は `deviation.md:8` に記録された |
| 付随修正 | `deviation.md:3`・`:4` は変わっていない (引き継ぎ) |
| Side Effects (逆向き) | 16 行すべて ✅ (引き継ぎ)。「Issue のフォームの必須項目 — Side Effects」は「なし」のままで、今回の deviation は状態変更を足していない |
| UI | 対象外 |
| テストの実行 | 今回流した: `python3 scripts/ci/run-tests.py` は実行 111 件 / 失敗 0 件 / スキップ 0 件。`python3 scripts/ci/check-workflows.py` は workflow 3 本で違反なし。lint 3 本 (ローカル絶対パス・個人を特定する値・コメントの規約) は終了コード 0。xcodebuild と Gradle は流していない |

## 裏付けが弱い点 (引き継ぐもの)

✅ または ⚠️ に数えたが、THEN そのものを誰も見ていない、または後から読めないもの。1〜10 は verify-002 の一覧と同じで、今回 11・12 を足した。

| # | Scenario・点 | 何が弱いか |
|---:|---|---|
| 1 | 道具の固定と権限 / 時間の上限を超えると落ちる | 上限を超えたジョブが打ち切られて失敗で終わるところは見ていない |
| 2 | Issue のフォームの必須項目 / 3 本のフォームだけが選べる (今回 ⚠️ になった行) と、必須の項目が空だと送れない | 管理する側でない人の画面 (この Requirement が本来向いている相手) を誰も見ていない。deviation の「管理する側を除いて、空の Issue は作れない」は、設定の値と GitHub の仕様からの推定。共同作業者の画面も見ていない。必須の項目のほうは、オーナーの報告だけ |
| 3 | 公開前の確認 / 通らない確認があれば公開しない | 通らない確認が起きなかったので、止まるところは見ていない |
| 4 | 履歴をそのまま公開する / public にする前にオーナーが確かめる | 目視と承認は記録だけで、後から読めない |
| 5 | 起動条件 / 起動しない push は走っている実行に影響しない | 「push の後も走り続けていた」は、25 秒後の 1 回の観察の記録 |
| 6 | 起動条件 / main 宛ての Pull Request では絞り込まない | Pull Request が「更新される」ときは見ていない |
| 7 | lint の検証の異常系 4 件 | 自動のテストが無く、手元の一時のツリーでの実測だけ |
| 8 | iOS・Android の「落ちると落ちる」 | ランナーの上で失敗する実行を見ていない |
| 9 | チェックサムが合わないと落ちる・決めた版の Xcode が無いと落ちる | 落ちる側は、手元と Linux のコンテナでだけ確かめている |
| 10 | 再利用 / 別の workflow から呼べる | 入口のほかの workflow から呼んだ実績は無い |
| 11 | GitHub の今の状態 (設定・保護・実行の一覧・ブランチの先端) | 今回は読み直していない。verify-002 が読み直した値に依っている。verify-002 の後に GitHub の側で設定が変わっていないことは、この検証では確かめていない |
| 12 | remote `origin` を足した主体 | 証跡が「確かめていない」と書いている。判定には関わらない (Side Effects は作成そのものを数える) |

## 判定に数えない所見

1. **`deviation.md` の今回の行・証跡の訂正・tasks のチェック・`verify-002.md` は、まだ commit されていない。** 検証は作業ツリーの内容で行った。蒸留の前に commit する必要がある。
2. **`drafts/` の中身は、今回も読んでいない。** tasks 9.1〜9.3 は、置き場に 4 つの文書があることだけを見ている。蒸留のときに、今回の deviation (管理する側には空の Issue の行が出る) が、GitHub の設定の文書の草稿に写っているかを見るとよい。
3. **今回の deviation は、蒸留で長命層に写す候補である。** Issue のフォームの決まりを概念や文書に書くとき、「空の Issue は作れない」ではなく「管理する側を除いて作れない」と書く必要がある。`deviation.md` に、これに当たる蒸留送りの行は無い (ADR-0013 の行だけ)。蒸留は deviation の行そのものを入力にするので、行の不足ではない。
4. verify-002 の所見 2〜7 (`main` の workflow の時間の上限が暫定の値のまま・公開前の確認が見た commit の範囲・Android SDK の取得の枝・証跡だけに依る確認・検証 CI の緑が保証する範囲・Linux でのテストの件数) は、そのまま残る。

## 検証者の作業の記録

- 書いたファイルはこの `verify-003.md` だけ。ソース・足場・証跡・deviation・長命層は書き換えていない。git の add・commit・push はしていない
- GitHub への読み書きはどちらもしていない
- 流したコマンド: `python3 scripts/ci/run-tests.py`、`python3 scripts/ci/check-workflows.py`、lint 3 本、読み取りだけの `git` (status・diff・log・rev-parse) と、ファイルの更新の時刻の読み取り
