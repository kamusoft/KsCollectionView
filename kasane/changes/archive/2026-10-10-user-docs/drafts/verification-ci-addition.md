> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/verification-ci.md`
> - proposal の「蒸留時に反映」にある、lint が流すテストへ README と Skill の検査が加わったこと・落ちたときの見方を足すための草稿である
> - 追記は 6 個ある。それぞれの見出しに、追記先の節と、足すのか置き換えるのかを書いてある
> - 文書の中のリンクは、追記先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - 中身は、2026-10-10 時点の実物 (`scripts/ci/check-skills.py`・`check-readme-examples.py`・`user-docs-rules.json`・`scripts/ci/tests/test_repository_files.py`) と、手元での確認の記録 (`evidence/checks-and-refresh-tools.md`) から書いた
> - **検証 CI の上では、まだ 1 回も走っていない。** 本変更の作業ツリーは、書いた時点で commit していない。追記 5 の件数 (484 件) と所要時間は、手元の値である。push の後に、ランナーの上の値で確かめ直す
> - 追記 5 の件数は、書いた時点の値である。tasks 9.4・9.5・12 でテストを足した・変えたなら、最後の完了判定の証跡の件数に合わせる
> - リンク先の「利用者向け Skill と README の書き方」「利用者向け Skill の追従」は、同じ変更で新設する文書 (草稿は `user-docs-writing.md`・`user-skill-refresh.md`)。置き先の名前が変わるなら、リンクも直す
> - `timestamp` は、蒸留で置く日にする

---

## 追記 1: frontmatter の直し

`description` の「走らせる範囲 (利用者の立場のビルドの確認を含む 5 つの検査)」の後ろに、README と利用者向け Skill の検査が lint の中で流れることが分かる言葉を足す。

```
description: 検証 CI が走る時点・走らせる範囲 (利用者の立場のビルドの確認を含む 5 つの検査。README と利用者向け Skill の検査は lint のスクリプトのテストの中で流れる)・緑が保証する範囲、失敗したときの見方、手元での確かめ方、既知の制限、検査を足すときの注意
```

`applies-when` の `paths` と `tasks` は変えない (`scripts/ci/**` が、検査のスクリプトと一覧のデータを含んでいる)。README と `skills/` を触る作業で読まれる文書は、「利用者向け Skill と README の書き方」の側である。

## 追記 2: 節「走らせる範囲」の「lint」の表の下に、段落と表を足す

表の `CI script tests` の行は変えない。表の下の「文書の構造の検査は入れていない。」の前に、次を足す。

> `CI script tests` は、スクリプトのロジックのテストのほかに、今のリポジトリの実物を確かめるテストを含む。README と利用者向け Skill (`skills/`) の検査は、step を足さずに、このテストの中から流している。lint の step の数と名前は変わっていない。
>
> | 実物を確かめるテスト (`scripts/ci/tests/test_repository_files.py`) | 確かめること |
> |---|---|
> | README の節の並び | README の 2 枚が、決めた 9 つの節 (深さ 2 の見出し) を、決めた順で持つ。スクリーンショットの節が `assets/` の 6 枚を 1 回ずつ指し、6 枚が実在する。Skill への導線の節のリンクが、自分の言語の 2 つの `SKILL.md` と索引だけで、先が実在する |
> | README の例の検査 (`scripts/ci/check-readme-examples.py`) | README の最小コード例が、利用者役の画面のファイルの全体と同じである。README と各 `SKILL.md` のインストール例の値が、利用者役の使う値と同じで、版の位置が `{version}` であり、最新の版の確かめ先の URL が同じファイルにある |
> | Skill 自身の整合の検査 (`scripts/ci/check-skills.py`) | 英語版と日本語版で、Skill の集合・ファイルの集合・見出しの深さの並び・コードブロックの中身と順番が同じである。`SKILL.md` の frontmatter が決めた 5 項目である。Skill の外へ出るリンクが無い。許可した一覧に無い URL が無い。決めた内部の言葉が無い |
> | 追従の記録 (`skills/.manifest.json`) | 記録が決めた項目を持つ。源泉がどれも、掛かる 1 枚か、掛からない理由のどちらかを持つ。掛かる 1 枚が実在する |
>
> どの検査も、`skills/` と README と利用者役のファイルの中だけで合否が決まる。Skill が源泉 (`kasane/concepts/`・本体のコード) からずれていることは、検査しない ([cross/ADR-0017](../../decisions/cross/0017-user-skill-refresh-on-request-by-commit-diff.md))。そのため、`skills/` も README も利用者役も触らない push は、これらの検査で落ちない。源泉の概念の文書だけを変えた push も、本体に公開の宣言を足しただけの push も、落ちない。
>
> 書き方の決まりは [利用者向け Skill と README の書き方](user-docs-writing.md)、源泉の変更に追従させる流れは [利用者向け Skill の追従](user-skill-refresh.md) にある。

## 追記 3: 節「緑が保証する範囲」の 2 つの表に、行を足す

1 つ目の表 (緑が言えること) の、「lint の step がどれも成功した」の行の下に、次の 2 行を足す。

| 緑が言えること | 言える起動 |
|---|---|
| README の最小コード例が利用者役の画面のファイルと同じで、README と各 `SKILL.md` のインストール例の値が利用者役の使う値と同じである | push と Pull Request |
| 利用者向け Skill の英語版と日本語版が、同じファイル・同じ見出しの深さの並び・同じコードブロックを持ち、Skill の外へのリンク・一覧に無い URL・決めた内部の言葉を持たない | push と Pull Request |

2 つ目の表 (緑では言えないこと) に、次の 5 行を足す。

| 緑では言えないこと (手元の完了条件に残る) | 補足 |
|---|---|
| 利用者向け Skill が、今の源泉 (概念の文書・本体のコード) と合っている | 検査しないと決めてある。オーナーが頼んだときに、追従の道具で確かめる ([利用者向け Skill の追従](user-skill-refresh.md)) |
| 本体の公開の宣言の名前が、Skill にすべて現れている | 検証 CI では流していない。追従のときに `python3 scripts/docs/check-api-coverage.py` で確かめる |
| Skill の `references/` のコード例がコンパイルできる | どの検査もビルドしない。ビルドされるのは、README の最小コード例と同じ内容の、利用者役の画面のファイルだけである (`main` 宛ての Pull Request のとき) |
| 各 `SKILL.md` の最小の動く例が、利用者役の画面のファイルと同じである | 検査が比べるのは README の例だけである。`SKILL.md` の側は、追従の道具が、利用者役の変更を「変わった源泉」として出す |
| 英語版と日本語版の本文が、同じ内容である | 検査が比べるのは、見出しの深さの並びとコードブロックだけである。スクリーンショットが今の画面と合っていることも、検査しない |

## 追記 4: 節「失敗したときの見方」の「lint」の表の下に、小さな表を足す

表の `CI script tests` の行は変えない。表の下に、次を足す。

> `CI script tests` が、README か Skill の検査で落ちたときは、落ちたテストの名前と、違反の文面を見る。テストのクラスは `test_repository_files` の `ReadmeSectionsTest`・`UserDocsCheckTest`・`SkillsManifestTest` である。同じ違反は、検査のスクリプトを手元で直に流すと、「ファイル: 内容」の形で出る。
>
> ```bash
> python3 scripts/ci/check-skills.py .
> python3 scripts/ci/check-readme-examples.py .
> ```
>
> | 違反の文面 (要点。N は番号) | 意味 | すること |
> |---|---|---|
> | 見出しの深さの並びが、英語版と日本語版で違う / N つ目のコードブロックが、英語版と日本語版で違う / コードブロックの数が違う | 片方の言語だけを直した | もう片方の言語の同じ 1 枚に、同じ変更をする |
> | frontmatter に、決めていない項目がある / 項目が無い / frontmatter の N 行目を読み取れない | `SKILL.md` の frontmatter が、決めた 5 項目でない。値を複数行に折り返したときも、読み取れない行として出る | 5 項目だけにし、値を 1 行で書く |
> | Skill の外のファイルへのリンクがある / リンクの先が無い | README・索引・相手の Skill などへのリンクを書いた。または、Skill の中のファイルの名前を変えた | Skill の外へのリンクは消す (相手の Skill は名前だけで触れる)。Skill の中のリンクは、先を直す |
> | 許可した一覧に無い URL がある | 一覧 (`scripts/ci/user-docs-rules.json`) に無い URL を書いた | 見本の URL は `https://example.com/` で始める。操作の対象になる URL を足すときだけ、一覧に足す。知識を委ねる先の URL は、足さずに消す |
> | 内部の言葉がある | ADR の番号・ハーネスの道具の名前・利用者役など、利用者の知らない言葉を書いた | 利用者の言葉に書き直す。一覧から言葉を外して通さない |
> | (最小コード例が) ファイルと違う: N 行目が違う / 行の数が違う | README の例か、利用者役の画面のファイルの、片方だけを変えた | 利用者役の画面のファイルを正として、README の 2 枚に写す。4 つの `SKILL.md` の最小の動く例も、同時に直す (検査は見ない) |
> | 最小コード例の節の見出しが、ちょうど 1 つ無い | README の節の見出しの文面を変えた | 見出しを `Minimal code examples`・`最小コード例` に戻す |
> | Package URL (package の名前・product の名前・Maven の座標) が、利用者役の使う値と違う / 版の位置が `{version}` でない / 最新の版の確かめ先の URL が無い / インストール例の種類と数が違う | 例に具体の版を書いた。または、依存の書き方を変えたのに、例を直していない | 版は `{version}` に戻す。値は [公開識別子と配布座標](public-identifiers.md) に合わせる |
> | 差し込む行が、Package URL と版の指定の形でない / (行) が、ちょうど 1 つ無い | 利用者役のひな形・依存の行・確認のスクリプトの、検査が値を読む行の形を変えた | 検査が読む形 (`scripts/ci/check-readme-examples.py` の冒頭) に合わせるか、検査を同時に直す |
> | (追従の記録) 源泉が、掛かる 1 枚も、掛からない理由も持たない / 掛かる 1 枚が無い | 記録に源泉を足したときに、行き先を書いていない。または、Skill の 1 枚の名前を変えた | 記録 (`skills/.manifest.json`) を直す |
>
> 決まりの中身は、[利用者向け Skill と README の書き方](user-docs-writing.md) にある。

## 追記 5: 節「手元で確かめる」の箇条の直しと、足し

「スクリプトのテストは 15 秒ほどで終わる。2026-10-09 時点で 262 件。」を、次に置き換える。

> - スクリプトのテストは【所要時間を、push の後に確かめた値で書く】で終わる。2026-10-10 時点で 484 件。テスト 4 系統とは別に数える

箇条の最後に、次を足す。

> - README か `skills/` か利用者役の画面のファイルを変えたときは、push の前に、検査の 2 本を直に流す (`python3 scripts/ci/check-skills.py .`・`python3 scripts/ci/check-readme-examples.py .`)。違反が、テストの失敗より読みやすい形で出る。どちらも 1 秒かからず、何も書き換えない

## 追記 6: 節「検査を足すときの注意」の「スクリプトと道具」の表に、行を足す

| 場面 | 守ること |
|---|---|
| README か利用者向け Skill の検査を足す・変える | lint の step を足さない。検査のロジックは `scripts/ci/` のスクリプトに置き、ロジックのテスト (一時のディレクトリのひな形で、正常と異常を流す) と、今のリポジトリの実物に流すテスト (`scripts/ci/tests/test_repository_files.py`) の両方を付ける。合否が `skills/` と README と利用者役のファイルの中だけで決まる検査に限る。源泉とのずれを見る検査は足さない ([cross/ADR-0017](../../decisions/cross/0017-user-skill-refresh-on-request-by-commit-diff.md)) |
| 許可する URL・内部の言葉の一覧 (`scripts/ci/user-docs-rules.json`) を変える | 足し方は [利用者向け Skill と README の書き方](user-docs-writing.md) の「URL と内部の言葉の一覧に足すとき」に従う。役割 `latest-version` の URL は、インストール例の検査が読む。変えるときは、例のある 6 か所 (README の 2 枚と 4 つの `SKILL.md`) を同時に直す |
| 追従の道具 (`scripts/docs/`) を変える | 道具は検証 CI の step では流れないが、テストは `scripts/ci/tests/` にあり、`CI script tests` で流れる。道具が git の履歴を変えない・Skill を書き換えない、という決まりを保つ |

節「関連」に、次の 3 行を足す。

> - [cross/ADR-0017](../../decisions/cross/0017-user-skill-refresh-on-request-by-commit-diff.md) — Skill が源泉からずれていることを、検証 CI で検査しない決定
> - [利用者向け Skill と README の書き方](user-docs-writing.md) — 検査が確かめている決まりの中身
> - [利用者向け Skill の追従](user-skill-refresh.md) — 検証 CI の外で流す、追従の道具

出典の行に、次を足す。

> 【蒸留のときに、archive のパスで書く】変更 `user-docs` の design.md (Decision 5・6) / `evidence/checks-and-refresh-tools.md` (実物に検査を流すテスト・一時のツリーでの 3 つの確かめ・件数)
