## ADDED Requirements

### Requirement: 検証 CI の起動条件

検証 CI は、`develop` への push と、`main` 宛ての Pull Request で起動しなければならない (SHALL)。

`develop` への push のうち、`kasane/` 配下・Issue のフォーム・貢献の案内だけを変えたものでは、起動してはならない。`main` 宛ての Pull Request では、変更したパスに関わらず起動しなければならない。

同じブランチ、または同じ Pull Request で新しい実行が始まったとき、走っている古い実行は打ち切られなければならない。起動しない push は、走っている実行に影響してはならない。

**Side Effects**:
- GitHub 上の検証の実行: 作成、同じブランチまたは同じ Pull Request の古い実行の打ち切り

#### Scenario: develop への push で起動する
- **GIVEN** ライブラリのソースを変えた commit がある
- **WHEN** その commit を `develop` に push する
- **THEN** `lint`・`ios / verify`・`android / verify` の 3 つの検査が走る

#### Scenario: 開発の記録だけの push では起動しない
- **GIVEN** `kasane/` 配下のファイルだけを変えた commit がある
- **WHEN** その commit を `develop` に push する
- **THEN** 検証 CI は起動しない

#### Scenario: main 宛ての Pull Request では絞り込まない
- **GIVEN** `develop` から `main` 宛ての Pull Request がある
- **WHEN** その Pull Request が作られる、または更新される
- **THEN** 変更したパスに関わらず、3 つの検査が走る

#### Scenario: 起動の対象になる新しい push が古い実行を打ち切る
- **GIVEN** `develop` への push で始まった検証が走っている
- **WHEN** ライブラリのソースを変えた新しい commit を `develop` に push する
- **THEN** 古い実行は打ち切られ、新しい commit に対する実行が走る

#### Scenario: 起動しない push は走っている実行に影響しない
- **GIVEN** `develop` への push で始まった検証が走っている
- **WHEN** `kasane/` 配下のファイルだけを変えた commit を `develop` に push する
- **THEN** 新しい実行は作られず、走っている実行はそのまま続く

### Requirement: main 宛ての Pull Request の出どころの制限

`main` 宛ての Pull Request では、出どころが同じリポジトリの `develop` であることを `lint` が確かめなければならない (SHALL)。そうでないとき、`lint` は失敗で終わらなければならない。push で起動したときは、この確認を行わない。

**Requires**:
- Pull Request の出どころが、同じリポジトリのブランチであること
- Pull Request の出どころのブランチが `develop` であること

**Side Effects**: なし

#### Scenario: develop からの Pull Request は通る
- **GIVEN** 同じリポジトリの `develop` から `main` 宛ての Pull Request がある
- **WHEN** `lint` が走る
- **THEN** 出どころの確認は通る

#### Scenario: develop 以外のブランチからの Pull Request は落ちる
- **GIVEN** 同じリポジトリの `develop` 以外のブランチから `main` 宛ての Pull Request がある
- **WHEN** `lint` が走る
- **THEN** `lint` は失敗で終わり、出どころが `develop` でないことが理由として示される

#### Scenario: 別のリポジトリの同じ名前のブランチからの Pull Request は落ちる
- **GIVEN** 別のリポジトリ (fork) の `develop` という名前のブランチから `main` 宛ての Pull Request がある
- **WHEN** `lint` が走る
- **THEN** `lint` は失敗で終わり、出どころが別のリポジトリであることが理由として示される

### Requirement: lint の検証

`lint` は、次の検査を走らせなければならない (SHALL)。どれか 1 つでも違反または失敗があれば、`lint` は失敗で終わらなければならない。

- secret の検査 (gitleaks)。追跡中の内容を走査する
- ローカル絶対パスの検査
- 個人を特定する値の検査
- ソースのコメントの規約の検査
- 検査のスクリプトのテストと、workflow の定義の検査

secret の検査は、走査の対象を取り出せなかったとき、走査の前に失敗で終わらなければならない。

**Requires**:
- secret の検査の走査の対象として、追跡中のファイルがすべて取り出せていること

**Side Effects**:
- GitHub 上の commit の検査の結果 (`lint`): 作成

#### Scenario: 違反が無ければ通る
- **GIVEN** 追跡中の内容に、どの検査の違反も無い
- **WHEN** `lint` が走る
- **THEN** `lint` は成功で終わる

#### Scenario: secret を含む内容で落ちる
- **GIVEN** 追跡中の内容に、secret として検出される値を含むファイルがある
- **WHEN** secret の検査が走る
- **THEN** 検査は失敗で終わる

#### Scenario: ローカル絶対パスを含む内容で落ちる
- **GIVEN** 追跡中の内容に、ローカル環境の絶対パスを含むファイルがある
- **WHEN** ローカル絶対パスの検査が走る
- **THEN** 検査は失敗で終わる

#### Scenario: 個人を特定する値を含む内容で落ちる
- **GIVEN** 検査の範囲のファイルに、個人または端末を特定する値がある
- **WHEN** 個人を特定する値の検査が走る
- **THEN** 検査は失敗で終わる

#### Scenario: コメントの規約に反するソースで落ちる
- **GIVEN** ソースのコメントに、規約が禁じる参照がある
- **WHEN** コメントの規約の検査が走る
- **THEN** 検査は失敗で終わる

#### Scenario: 走査の対象を取り出せないと落ちる
- **GIVEN** 追跡中の内容の取り出しが失敗する、または取り出したファイルの数が追跡中のファイルの数より少ない
- **WHEN** secret の検査が走る
- **THEN** 走査を始める前に失敗で終わる

#### Scenario: 検査のスクリプトのテストが落ちると lint も落ちる
- **GIVEN** 検査のスクリプトのテストに、失敗するものがある
- **WHEN** `lint` が走る
- **THEN** `lint` は失敗で終わる

### Requirement: iOS の検証

`ios / verify` は、iOS 本体のテストを Simulator で全件走らせ、続けて iOS Sample のビルドとユニットテストを走らせなければならない (SHALL)。Sample の UI テストは走らせてはならない。

本体のテストが失敗しても、Sample の検証は走らなければならない。本体と Sample のどちらかが失敗したとき、`ios / verify` は失敗で終わらなければならない。

実行の件数は、その実行で作られた記録から読み、スキップされたテストを除いて数える。本体と Sample のそれぞれについて、実行の件数が 0 のとき、または件数を読み取れないとき、`ios / verify` は失敗で終わらなければならない。実行の件数とスキップの件数は、実行の結果の概要に示されなければならない。

**Side Effects**:
- GitHub 上の commit の検査の結果 (`ios / verify`): 作成

#### Scenario: 全件が通れば成功する
- **GIVEN** 本体のテストと Sample のユニットテストがすべて通る状態である
- **WHEN** `ios / verify` が走る
- **THEN** 成功で終わり、本体と Sample のそれぞれの実行の件数が概要に示される

#### Scenario: 本体のテストが落ちても Sample の検証は走る
- **GIVEN** 本体のテストに失敗するものがある
- **WHEN** `ios / verify` が走る
- **THEN** Sample のビルドとユニットテストも走り、`ios / verify` は失敗で終わる

#### Scenario: Sample がビルドできないと落ちる
- **GIVEN** Sample がビルドできない状態である
- **WHEN** `ios / verify` が走る
- **THEN** `ios / verify` は失敗で終わる

#### Scenario: Sample のユニットテストが落ちると落ちる
- **GIVEN** Sample のユニットテストに失敗するものがある
- **WHEN** `ios / verify` が走る
- **THEN** `ios / verify` は失敗で終わる

#### Scenario: Sample の UI テストは走らない
- **GIVEN** Sample に UI テストがある
- **WHEN** `ios / verify` が走る
- **THEN** 実行されたテストに、UI テストのものは含まれない

#### Scenario: 実行が 0 件なら落ちる
- **GIVEN** テストの実行の記録が、実行 0 件を示している
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、1 件も実行されていないことが理由として示される

#### Scenario: 全件がスキップされていると落ちる
- **GIVEN** テストの実行の記録が、全件のスキップを示している
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、スキップを除くと 1 件も実行されていないことが理由として示される

#### Scenario: 件数を読み取れないと落ちる
- **GIVEN** テストの実行の記録が無い、または記録に件数の集計が無い
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、件数を確かめられなかったことが理由として示される

### Requirement: Android の検証

`android / verify` は、Android 本体のデバッグのユニットテストを全件走らせ、続けて Android Sample のアプリの組み立てと、デバッグのユニットテストを走らせなければならない (SHALL)。Sample の計測用のモジュールは対象にしない。

本体のテストが失敗しても、Sample の検証は走らなければならない。本体と Sample のどちらかが失敗したとき、`android / verify` は失敗で終わらなければならない。

実行の件数は、その実行で作られた結果のファイルだけから読み、スキップされたテストを除いて数える。本体と Sample のそれぞれについて、次のどれかに当たるとき、`android / verify` は失敗で終わらなければならない。

- テストの結果のファイルが無い
- 実行の件数が 0 である
- テストのソースにあるテストのクラスのうち、結果に現れないものがある

実行の件数・スキップの件数・クラスごとの内訳は、実行の結果の概要に示されなければならない。

**Side Effects**:
- GitHub 上の commit の検査の結果 (`android / verify`): 作成

#### Scenario: 全件が通れば成功する
- **GIVEN** 本体のテストと Sample のユニットテストがすべて通る状態である
- **WHEN** `android / verify` が走る
- **THEN** 成功で終わり、本体と Sample のそれぞれの実行の件数が概要に示される

#### Scenario: 本体のテストが落ちても Sample の検証は走る
- **GIVEN** 本体のテストに失敗するものがある
- **WHEN** `android / verify` が走る
- **THEN** Sample の組み立てとユニットテストも走り、`android / verify` は失敗で終わる

#### Scenario: Sample が組み立てられないと落ちる
- **GIVEN** Sample のアプリが組み立てられない状態である
- **WHEN** `android / verify` が走る
- **THEN** `android / verify` は失敗で終わる

#### Scenario: 結果のファイルが無いと落ちる
- **GIVEN** 本体または Sample のどちらかで、テストの結果のファイルが 1 つも無い
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、結果が無かった対象が示される

#### Scenario: 実行が 0 件なら落ちる
- **GIVEN** 本体または Sample のどちらかで、結果のファイルの実行の件数の合計が 0 である
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、0 件だった対象が示される

#### Scenario: 全件がスキップされていると落ちる
- **GIVEN** 本体または Sample のどちらかで、結果のファイルが全件のスキップを示している
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、スキップを除くと 0 件だった対象が示される

#### Scenario: 一部のクラスの結果しか無いと落ちる
- **GIVEN** テストのソースにあるテストのクラスのうち、結果のファイルが無いものがある
- **WHEN** 実行の件数を確かめる
- **THEN** 失敗で終わり、結果に現れなかったクラスが示される

#### Scenario: 前の実行の結果は数えない
- **GIVEN** 結果の置き場に、前の実行で作られた結果のファイルが残っている
- **WHEN** 検証を走らせて、実行の件数を確かめる
- **THEN** その実行で作られた結果だけが数えられる

### Requirement: プラットフォームの検証の再利用

iOS と Android の検証は、入口の workflow 以外の workflow からも、入力を渡さずに同じ内容で呼べなければならない (SHALL)。入口から呼ばれたとき、検査は `ios / verify`・`android / verify` の名前で報告されなければならない。lint の検査は `lint` の名前で報告されなければならない。

**Side Effects**: なし

#### Scenario: 検査が決めた名前で報告される
- **GIVEN** 検証 CI が起動した
- **WHEN** 検査の結果が報告される
- **THEN** 検査の名前は `lint`・`ios / verify`・`android / verify` である

#### Scenario: 別の workflow から呼べる
- **GIVEN** iOS または Android の検証の workflow がある
- **WHEN** 別の workflow が、入力を渡さずにそれを呼ぶ
- **THEN** 入口から呼ばれたときと同じ検証が走る

### Requirement: 道具の固定と権限

検証 CI が使う道具は、版が決まっていなければならない (SHALL)。

- ランナーは版を指定した名前で選び、最新を指す名前を使わない
- iOS の検証は、決めた版の Xcode を使う。その版がランナーに無いとき、テストを始める前に失敗で終わる
- Android の検証は、決めた版の JDK を使う
- 外部の action は、commit の ID で指定する
- secret の検査の道具は、配布物のチェックサムを確かめてから使う。合わないとき、失敗で終わる

検証 CI の権限は、リポジトリの内容の読み取りだけでなければならない。各ジョブは時間の上限を持ち、上限を超えたジョブは失敗で終わらなければならない。

**Requires**:
- 決めた版の Xcode がランナーにあること
- secret の検査の道具の配布物が、決めたチェックサムと合うこと

**Side Effects**: なし

#### Scenario: 決めた版の Xcode が無いと落ちる
- **GIVEN** ランナーに、決めた版の Xcode が無い
- **WHEN** `ios / verify` が走る
- **THEN** テストを始める前に失敗で終わり、その版が無いことが理由として示される

#### Scenario: チェックサムが合わないと落ちる
- **GIVEN** 取得した secret の検査の道具の配布物が、決めたチェックサムと合わない
- **WHEN** `lint` が走る
- **THEN** 道具を使う前に失敗で終わる

#### Scenario: commit の ID で指定していない action があると落ちる
- **GIVEN** workflow の定義に、commit の ID で指定していない外部の action がある
- **WHEN** workflow の定義の検査が走る
- **THEN** 検査は失敗で終わり、その指定の場所が示される

#### Scenario: 最新を指す名前のランナーがあると落ちる
- **GIVEN** workflow の定義に、最新を指す名前でランナーを選ぶジョブがある
- **WHEN** workflow の定義の検査が走る
- **THEN** 検査は失敗で終わり、そのジョブが示される

#### Scenario: 読み取り以外の権限があると落ちる
- **GIVEN** 検証 CI の workflow の定義に、リポジトリの内容の読み取り以外の権限がある
- **WHEN** workflow の定義の検査が走る
- **THEN** 検査は失敗で終わり、その権限の場所が示される

#### Scenario: 時間の上限を超えると落ちる
- **GIVEN** あるジョブが、時間の上限を超えて走り続けている
- **WHEN** 上限に達する
- **THEN** そのジョブは打ち切られ、失敗で終わる
