# レビュー結果: public-repo-verify-ci (001 回目)

**日付**: 2026-10-08
**判定**: CHANGES_REQUESTED

## サマリー

対象はグループ 2〜5 (体裁のファイル・検査のスクリプト・workflow・手元の確認)。スクリプトのテストは 115 件すべて通り、lint 3 本・workflow の定義の検査・actionlint も違反なしで、デルタスペックの Requirement / Scenario は現在のリポジトリの内容に対してすべて満たされている。Critical / Major は無い。ただし Android の件数の検査に、テストのクラスの期待の集合が黙って縮む書き方が 1 つ残っており (再現済み)、この検査を置いた目的そのものに関わるので、公開の前に直すことを求める (優先度の高い Minor)。ほかは優先度の低い Minor 2 件。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always) — workflow とスクリプトのコメント・docstring
- `kasane/handbook/cross/test-execution.md` (テストを実行するとき・結果を報告するとき) — 実行件数の確認、iOS / Android の実行手順と workflow のコマンドの一致、Android のクラス単位の突き合わせ
- ksn-core `references/change-scope.md`・`references/delta-spec.md`・`references/paths.md`
- `kasane/lessons/code-review.md` — L-001 (証跡の計測値の再現) は、再現できる範囲で適用した (下記)。L-002 (動きの過程) は対象外 (UI の変更が無い)

ロードしたスキル: ksn-review のみ (code-review / domain / impl に該当するスキルは無い。パッケージの指定どおり)

## 確認した観点

実行して確かめたもの:

- `python3 scripts/ci/run-tests.py`: 実行 115 件 / 失敗 0 件 / スキップ 0 件 (証跡の 5.3 と一致)
- `python3 scripts/ci/check-workflows.py`: workflow 3 本、uses 7 / runs-on 3 / permissions 3、違反なし (証跡の 4.5 と一致)
- `scripts/local-path-lint.py`・`scripts/identity-lint.py`・`scripts/comment-policy-lint.py`: 違反なし (コメントの検査の対象は 494 ファイルで、証跡と一致)
- actionlint: 指摘 0 件
- 外部の action 3 つの commit の ID が、コメントに書いた版のタグの指す commit と一致すること (`git ls-remote` で読み取りのみ。checkout v7.0.1・setup-java v6.0.0・cache v6.1.0)
- `check-workflows.py` に、すり抜けを狙った定義 (引用符つきのキー、並びで書いたランナー、ジョブごとの `write-all` / `read-all`、複数行の文字列の中の偽の `permissions` / `uses`、`with` の下の `uses`) を渡し、違反だけが場所つきで報告されること
- `check-ios-test-count.py` に、外側のまとまりが全件スキップを示す記録を渡し、失敗で終わること
- `check-android-test-count.py` に、クラスの宣言の書き方を変えたソースを渡したときの期待の集合 (→ 指摘 1)

読んで確かめたもの (指摘なし):

- 仕様充足 (verification-ci): 起動の条件 (`develop` への push と `main` 宛ての Pull Request、push だけの `paths-ignore`)、同時実行のまとまりと打ち切り、出どころの確認 (リポジトリとブランチの両方。読み取れないときは失敗)、lint の 5 つの検査と条件・`continue-on-error` の無いこと、gitleaks のチェックサムの照合が展開の前にあること、取り出した数の突き合わせが走査の前にあること、iOS / Android とも本体が落ちても Sample が走る条件、件数の検査がテストの失敗時にも走る条件、Sample の UI テストを外す絞り込み、結果の置き場を空にする順番、Xcode の版が無いときにテストの前で止まること、検査の名前 (`lint`・`ios / verify`・`android / verify`)、入力なしの `workflow_call`、権限が `contents: read` だけであること、全ジョブの時間の上限
- 仕様充足 (repository-publication のうちグループ 2 の範囲): `LICENSE` の文面と名義、README 2 枚の構成の一致と 4 つの内容 (インストールの手順と使い方が無いこと)、貢献の案内 2 枚の構成の一致と 3 つの方針、Issue のフォーム 3 本の必須の項目とラベル、空の Issue を作れなくする設定
- tasks.md の 2.1〜5.4 のチェックに、成果物・テスト・証跡の裏付けがあること。3.1〜3.6 に挙げた正常系・異常系のテストがそれぞれ実在すること
- 足場 (proposal.md・design.md・specs/) は書き換えられていない。tasks.md の差分はチェックの付け替えだけ
- deviation.md は無く、デルタスペックからの無断の逸脱も見当たらない
- 設計品質: スクリプトは Python の標準のライブラリだけで書かれ、macOS のランナーの古い Python でも動く書き方である。値をシェルに直に展開していない (出どころのリポジトリは環境変数で渡す)。`persist-credentials: false`。ビルドの出力をキャッシュしない
- コメント規約: 作業文書のパス・変更の識別子・ローカル通番・履歴の記述・デルタスペックのキーワードは無い。外部参照は ADR の ID だけ
- 証跡: ローカル絶対パスは無い。確かめていないことが明記されている
- cross/ADR-0009〜0013 は proposed なので、判定の根拠にはしていない (衝突も見当たらない)

L-001 について: 証跡の数値のうち、スクリプトのテストの件数・workflow の検査の箇所数・コメントの検査の対象数は再実行して一致を確かめた。テスト 4 系統の件数 (567・37・512・163) と Linux のコンテナでの結果は、パッケージの制約に従って再実行していない (1 周目で、直前のサイクルでの修正も無い)。

## 指摘事項

### [🟡 Minor (優先度: 高)] Android の件数の検査で、注釈と同じ行に書いたテストのクラスが期待の集合から黙って抜ける

**該当箇所**: `scripts/ci/check-android-test-count.py:59-62` (`TOP_LEVEL_DECLARATION`)、`scripts/ci/check-android-test-count.py:133-154` (`test_classes_in_source`)

**関わる仕様**: verification-ci「Android の検証」— 失敗の条件「テストのソースにあるテストのクラスのうち、結果に現れないものがある」、Scenario「一部のクラスの結果しか無いと落ちる」。design.md の Decision 4 (期待の集合が縮んだときに失敗として見えること) と Goals (検査が黙って空振りしない)。

**問題点**: クラスの宣言を、行頭が修飾子または `class` で始まる行としてだけ認識している。次の書き方のクラスは宣言として認識されず、期待の集合に入らない。

```kotlin
@RunWith(RobolectricTestRunner::class) class BTest {
    @Test
    fun b() {}
}
```

再現: 上の `BTest` と、ふつうに書いた `ATest` を同じファイルに置き、結果のファイルは `ATest` の分だけにして検査を流すと、「ソースのテストのクラス 1 / 結果のクラス 1」で成功 (終了コード 0) で終わる。`BTest` は結果に現れていないのに失敗にならない。さらに、認識されなかった宣言の中の `@Test` は、直前に認識したクラスのものとして数えられる (バッククォートで囲んだ名前のクラスや、一覧に無い修飾子 (`enum`・`value`・`annotation` など) で始まる宣言でも同じことが起きる)。

現在のリポジトリには、この書き方のテストのクラスは無い (本体 31 / 31、Sample 21 / 21 で一致している)。したがって今の内容に対する検査の結果は正しい。しかし design.md が代替案 A を退けた理由 (導き方を誤ると、集合が静かに縮んだまま緑になる) と同じ形の穴が、ソースからクラスを導く側に残っている。docstring は「行頭から始まるクラスの宣言」と書いているが、該当するクラスが出たときに失敗も警告もしないので、書いた人は気付けない。テストにもこの形の場合が無い。

**推奨修正**: 次のどちらか、または両方。

- 宣言の前に同じ行の注釈が付く形を認識する。あわせて、認識できない行頭の宣言に出会ったら `current` を引き継がない (直前のクラスに `@Test` を付け替えない)
- 逆向きの突き合わせを足す: 結果に現れているのに、ソースから導いた集合に無いクラスがあれば失敗にする。導き方の取りこぼしが、取りこぼした時点で失敗として見えるようになる (今は 31 / 31・21 / 21 で一致しているので、足しても今の内容は通る)

どちらの場合も、注釈と同じ行の宣言の場合をテストに足す。

### [🟡 Minor] 入口の workflow の冒頭のコメントが、起動しないファイルを「lint にもテストにも入力されない」と説明しているが、事実と違う

**該当箇所**: `.github/workflows/ci.yml:7-10`

**関わる仕様**: verification-ci「検証 CI の起動条件」(挙動そのものは仕様どおり。問題はコメントの説明だけ)

**問題点**: コメントは、`paths-ignore` に挙げたファイルを「ビルド・テスト・lint のどれにも入力されないファイル」と書いている。実際には次のとおり入力になっている。

- `kasane/` 配下は、個人を特定する値の検査とローカル絶対パスの検査の対象である
- `.github/ISSUE_TEMPLATE/` と貢献の案内 2 枚は、lint が流すスクリプトのテスト (`scripts/ci/tests/test_repository_files.py`) が読む

そのため、たとえば Issue のフォームの必須の項目だけを壊した push は、`develop` では検査されず、`main` 宛ての Pull Request で初めて落ちる。これは仕様が決めた挙動で、design.md の Risks にも書いてある。しかしコメントだけを読んだ人は「検査に関係しないから外してある」と受け取り、外してよい根拠を取り違える。

**推奨修正**: コメントを事実に合わせる。たとえば「これらだけを変えた push では起動しない。lint とスクリプトのテストはこれらも読むので、違反は次に起動した回か `main` 宛ての Pull Request で見つかる」。

### [🟡 Minor] gitleaks の配布物のチェックサムを、公式のチェックサムの一覧と突き合わせていない

**該当箇所**: `.github/workflows/ci.yml:59-60`、`evidence/ci-local-verification.md:119`

**関わる仕様**: verification-ci「道具の固定と権限」— secret の検査の道具は、配布物のチェックサムを確かめてから使う

**問題点**: 固定した SHA-256 は、取得した配布物の実物から計算した値と一致することだけが確かめてある (証跡の「確かめていないこと」に明記されている)。この値が配布元の公表している値と同じであることは確かめていない。workflow の仕組みは仕様どおりに動くが、固定した値そのものの出どころが、1 度の取得の結果だけになっている。

**推奨修正**: 公開の前に、gitleaks 8.30.1 のリリースに付いているチェックサムの一覧の `linux_x64` の値と突き合わせ、結果を証跡に 1 行足す。レビューでは、ファイルの取得を伴うので確かめていない。

## アクションプラン

1. `scripts/ci/check-android-test-count.py` のクラスの導き方を直し (注釈と同じ行の宣言の認識、または結果とソースの逆向きの突き合わせ)、その場合のテストを足す。`python3 scripts/ci/run-tests.py` を通す
2. `.github/workflows/ci.yml` の冒頭のコメントを事実に合わせる
3. gitleaks のチェックサムを公式の一覧と突き合わせ、証跡に書く (公開の前まで)

1 を直せば、残りは優先度の低い Minor だけになる。
