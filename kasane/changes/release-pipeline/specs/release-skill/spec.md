## ADDED Requirements

### Requirement: Skill の置き場と呼び名

リリースの入口になる Skill は、名前 `release` で、どちらの CLI からも呼べなければならない (SHALL)。実体は 1 つで、もう 1 つの CLI の置き場からは、実体へのリンクで指す。置き方は、利用者向け Skill の追従の Skill (`docs-refresh`) と同じ形にする。AGENTS.md は、リリースを頼まれたときに `release` で行うことを示す。

**Side Effects**: なし

#### Scenario: 実体が 1 つで、リンクで指される
- **GIVEN** リポジトリの Skill の置き場
- **WHEN** `release` の場所を読む
- **THEN** 実体は 1 か所にあり、もう 1 つの CLI の置き場の `release` は、その実体へのリンクである

### Requirement: 頼まれたときだけ動く

リリースの Skill は、オーナーが明示してリリース (またはその試し・失敗した実行の続き) を頼んだときだけ動かなければならない (SHALL)。自分から起動しない。

**Side Effects**: なし

#### Scenario: 頼まれていなければ動かない
- **GIVEN** オーナーがリリースを頼んでいない
- **WHEN** 別の作業 (変更の蒸留など) が終わる
- **THEN** リリースの Skill は動かず、Pull Request も workflow の起動も行われない

### Requirement: 手順の正を読む

リリースの Skill は、起動のたびに手順の文書 (`kasane/handbook/cross/release-procedure.md`) を先頭から読み、書かれた順とコマンドのとおりに進めなければならない (SHALL)。Skill は段の順序もコマンドも持たない。手順の文書に書かれていない状況に当たったら、手順を補わずに止まる。

**Requires**:
- 手順の文書があること

**Side Effects**: なし

#### Scenario: 手順の文書が無いと止まる
- **GIVEN** 手順の文書が無い
- **WHEN** オーナーがリリースを頼む
- **THEN** Skill は、手順の文書が無いことを示して止まり、何も実行しない

#### Scenario: 手順に無い状況では止まる
- **GIVEN** 手順の文書の前提と、手元の状態が違う
- **WHEN** Skill がその段に来る
- **THEN** Skill は、何が違うかと、手順の文書の該当箇所を示して止まる

### Requirement: 事前の確認

リリースの Skill は、確認のメッセージを出す前に、次を確かめなければならない (SHALL)。

- 手元の `develop` と `origin/develop` の関係: 手元が先行していれば push し、その先端の検証 CI の完了を待つ。手元が遅れている、または分かれているときは止まる
- `origin/develop` の先端 (以下「対象の commit」) の検証 CI が成功していること。失敗・未完了のまま (待っても終わらない) なら止まる
- 利用者向け Skill の追従が要るか: 追従の Skill `docs-refresh` の「確かめるだけ」で調べ、結果を確認のメッセージに添える。追従そのものはしない

**Requires**:
- 手元の `develop` が、`origin/develop` と同じか、先行していること
- 対象の commit の検証 CI が成功していること

**Side Effects**:
- 本リポジトリの `develop`: push (手元が先行していたとき)

#### Scenario: 手元が先行していれば push して検証を待つ
- **GIVEN** 手元の `develop` に、push していない commit がある
- **WHEN** 事前の確認が走る
- **THEN** Skill は `develop` を push し、その先端の検証 CI が成功するのを待ってから、確認のメッセージを出す

#### Scenario: 手元が分かれていると止まる
- **GIVEN** 手元の `develop` と `origin/develop` が、互いに相手に無い commit を持つ
- **WHEN** 事前の確認が走る
- **THEN** Skill は push せずに止まり、分かれていることを示す

#### Scenario: 検証 CI が失敗していると止まる
- **GIVEN** 対象の commit の検証 CI が失敗している
- **WHEN** 事前の確認が走る
- **THEN** Skill は確認のメッセージを出さずに止まり、失敗した検査を示す

#### Scenario: 追従は確かめるだけで行わない
- **GIVEN** 前回追従した commit から、利用者向け Skill の源泉が変わっている
- **WHEN** 事前の確認が走る
- **THEN** 確認のメッセージに追従が要ることが書かれ、Skill は利用者向け Skill を書き換えない

### Requirement: 確認は 1 回

リリースの Skill がオーナーに確認するのは、1 回のメッセージだけでなければならない (SHALL)。そのメッセージには、対象の commit・版 (頼まれていなければ候補)・変更の節の下書き・下書きから外した commit とその理由・事前の確認の結果・利用者向け Skill の追従が要るかを並べる。

オーナーが版と文面を確定したら、それを対象の commit についての以降の承認として扱い、リリースの Pull Request の作成とマージ・本番の起動・それに伴う tag の作成まで、段ごとに聞かずに進める。マージは、Pull Request の先端が対象の commit と同じときだけ行う。確定の前に、公開を伴う操作 (Pull Request のマージ・本番の起動・tag の作成) をしない。確定していない下書きを、Pull Request の本文に書き込まない。

**Requires**:
- マージの時点で、リリースの Pull Request の先端が対象の commit と同じであること

**Side Effects**:
- 本リポジトリ: リリースの Pull Request の作成とマージ
- 本リポジトリの GitHub Actions: リリースの workflow の起動

#### Scenario: 確定の前には公開を伴う操作をしない
- **GIVEN** 確認のメッセージを出し、オーナーがまだ答えていない
- **WHEN** Skill の状態を見る
- **THEN** リリースの Pull Request はマージされておらず、本番の起動もされていない

#### Scenario: 確定の後は止まらずに進む
- **GIVEN** オーナーが版と文面を確定した
- **WHEN** Skill が続ける
- **THEN** Pull Request の作成とマージ・本番の起動・公開の後の確認まで、オーナーに段ごとの確認をせずに進め、最後に完了の報告を 1 回出す

#### Scenario: 確定の後に develop が進んだらマージしない
- **GIVEN** オーナーが確定した後、マージの前に `origin/develop` に新しい commit が入り、リリースの Pull Request の先端が対象の commit と違う
- **WHEN** Skill がマージの段に来る
- **THEN** Skill はマージせずに止まり、先端が変わったことを示す

### Requirement: 変更の節の下書き

リリースの Skill は、変更の節の下書きを、これから作るリリースの Pull Request が `main` へ新しく持ち込む commit だけから作らなければならない (SHALL)。利用者から見える変化 (公開 API・配布物・利用者向けの文書) だけを、利用者の言葉で 1 項目 1 行にし、ひな形の書き方に合わせる。載せるものが無ければ `- none` の 1 行にする。

**Side Effects**: なし

#### Scenario: すでに main にある変更は載せない
- **GIVEN** 前回のリリースの後に、別の Pull Request ですでに `main` に入った変更がある
- **WHEN** 下書きを作る
- **THEN** その変更は下書きに載らない

#### Scenario: 内部の作業だけなら none になる
- **GIVEN** 新しく持ち込む commit が、ハーネス・CI・テストの整備だけである
- **WHEN** 下書きを作る
- **THEN** 下書きは `- none` の 1 行になる

### Requirement: 止まる条件

リリースの Skill は、次のときに自動の進行を止め、何が起きたか・手順の文書の該当箇所・選べる対応 (推奨を先頭に) を 1 回のメッセージで示さなければならない (SHALL)。再実行するか、どう再実行するか、中止するかはオーナーが決め、Skill は自分では再実行しない。

- 検証や実行が失敗したとき (失敗した位置を、ジョブと step とログの行で示す)
- 手順の文書に書かれていない状況に当たったとき
- 確定した版や文面のままでは進めないと分かったとき

**Side Effects**: なし

#### Scenario: workflow が失敗したら止まって位置を示す
- **GIVEN** 本番の run が、あるジョブの step で失敗した
- **WHEN** Skill が結果を読む
- **THEN** Skill は再実行せずに止まり、失敗したジョブと step と、手順の文書の対応する記述 (無ければ無いこと) を示す
