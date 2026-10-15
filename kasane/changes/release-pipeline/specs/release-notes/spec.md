## ADDED Requirements

### Requirement: Pull Request のひな形

`main` 宛ての Pull Request のひな形は、変更の節 `## Changes` と、その書き方を持たなければならない (SHALL)。書き方は次を示す。

- 節の内容が、その版のリリースノートになること
- 行は `- <種類>: <説明>` の形だけで、種類は `breaking`・`feature`・`fix`・`docs` の 4 つ
- 利用者向けの変更が無いときは、`- none` を 1 行だけ書くこと
- 説明は英語で、利用者の言葉で書き、内部の作業 (ハーネス・CI・テストの整備) を載せないこと
- 節の中に、見出し・地の文・別の書き方の行があると、リリースが公開の前に止まること

書き方は、節の中では注釈 (HTML のコメント) として置き、ノートに載らない形にする。

**Side Effects**: なし

#### Scenario: 新しい Pull Request の本文に書き方がある
- **GIVEN** 本リポジトリで、新しい Pull Request を作る
- **WHEN** 本文の初期値を読む
- **THEN** 変更の節と、行の形・種類・変更が無いときの書き方・言語の決まりが書かれている

### Requirement: リリースノートの組み立て

リリースの workflow の最初のジョブは、次の範囲の Pull Request の本文の変更の節から、リリースノートを組み立てなければならない (SHALL)。

- 範囲: 公開済みの Release (draft でないもの) の tag のうち、`main` の first-parent で起動した commit の祖先にある最も近いものから、起動した commit までに `main` に入った Pull Request のすべて。そういう Release が無ければ、`main` の最初から
- 節の読み方: 節は、`## Changes` の見出しの行の次から、次の `## ` の見出しの行の前 (無ければ本文の終わり) まで。読む前に注釈 (HTML のコメント) を除き、空の行を無視する
- 組み立て: 種類ごとに分けて並べる。すべての Pull Request が `- none` なら、利用者向けの変更が無いことを 1 行で書く

dry-run も、起動したのが `main` のときは組み立てる。`main` 以外から起動した dry-run では組み立てない。

**Requires**:
- 範囲の各 Pull Request の本文に、変更の節が 1 つだけあること
- 注釈と空の行を除いた節に、行が 1 つ以上あること
- 節の各行が `- <種類>: <説明>` の形 (種類は 4 つのどれか、説明は空でない) であるか、節が `- none` の 1 行だけであること

**Side Effects**:
- この run の artifact: 作成 (リリースノート)

#### Scenario: 前回の Release より後の Pull Request だけが入る
- **GIVEN** 前回の Release の tag の後に、`main` に Pull Request が 2 本入った
- **WHEN** リリースノートを組み立てる
- **THEN** 2 本の変更の節の行が入り、前回の Release より前に入った Pull Request の行は入らない

#### Scenario: 初回は main の最初からの Pull Request が入る
- **GIVEN** 公開済みの Release が 1 つも無い
- **WHEN** リリースノートを組み立てる
- **THEN** `main` の最初から起動した commit までに入った、すべての Pull Request が範囲になる

#### Scenario: 変更の節が無いと止まる
- **GIVEN** 範囲の Pull Request の 1 本の本文に、変更の節が無い
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号を示して失敗で終わり、公開に進まない

#### Scenario: 読めない行があると止まる
- **GIVEN** 範囲の Pull Request の変更の節に、`- improvement: ...` のように 4 つの種類にない行がある
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号とその行を示して失敗で終わる

#### Scenario: 注釈は読まない
- **GIVEN** 変更の節に、ひな形の書き方の注釈と、`- fix: ...` の行がある
- **WHEN** リリースノートを組み立てる
- **THEN** 注釈は無視され、`fix` の行だけがノートに入る

#### Scenario: 空の節は止まる
- **GIVEN** 変更の節に、注釈と空の行しか無い
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号を示して失敗で終わる

#### Scenario: 説明の無い行は止まる
- **GIVEN** 変更の節に、`- fix:` だけの行がある
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号とその行を示して失敗で終わる

#### Scenario: 変更の節が 2 つあると止まる
- **GIVEN** 1 本の Pull Request の本文に、`## Changes` の見出しが 2 つある
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号を示して失敗で終わる

#### Scenario: 次の見出しから先は節に入らない
- **GIVEN** 変更の節の後に、別の `## ` の見出しと、その下の地の文がある
- **WHEN** リリースノートを組み立てる
- **THEN** 別の見出しから先は読まれず、節の行だけがノートに入る

#### Scenario: none とほかの行が混ざると止まる
- **GIVEN** 変更の節に、`- none` とほかの行が並んでいる
- **WHEN** リリースノートを組み立てる
- **THEN** 最初のジョブが、その Pull Request の番号を示して失敗で終わる

#### Scenario: すべてが none なら変更が無いことを書く
- **GIVEN** 範囲のすべての Pull Request の変更の節が `- none` である
- **WHEN** リリースノートを組み立てる
- **THEN** ノートは、利用者向けの変更が無いことを示す 1 行になる

#### Scenario: 種類ごとに分かれる
- **GIVEN** 範囲に、`feature` の行と `fix` の行がある
- **WHEN** リリースノートを組み立てる
- **THEN** ノートは種類ごとに分かれ、同じ種類の行が同じまとまりに並ぶ

#### Scenario: main 以外からの dry-run では組み立てない
- **GIVEN** `develop` から、dry-run を真にして起動した
- **WHEN** 最初のジョブが走る
- **THEN** リリースノートを組み立てず、範囲の Pull Request の検査で止まることも無い

### Requirement: ノートは 1 回だけ組み立てる

Release の本文は、その run の最初のジョブが組み立てたリリースノートでなければならない (SHALL)。公開のジョブは、Pull Request の本文を読み直さない。

**Side Effects**: なし

#### Scenario: 組み立ての後に本文を書き換えても Release は変わらない
- **GIVEN** 最初のジョブがリリースノートを組み立てた後に、範囲の Pull Request の本文を書き換えた
- **WHEN** その run が Release を作る
- **THEN** Release の本文は、最初のジョブが組み立てたノートのままである
