## MODIFIED Requirements

### Requirement: 検証 CI の起動条件

検証 CI は、`develop` への push と、`main` 宛ての Pull Request で起動しなければならない (SHALL)。

`develop` への push では、`lint`・`ios / verify`・`android / verify` の 3 つの検査を走らせる。`main` 宛ての Pull Request では、この 3 つに加えて、利用者の立場のビルドの確認 (`consumer-ios / verify`・`consumer-android / verify`) を走らせる。利用者の立場のビルドの確認は、`develop` への push では走らせてはならない。

`develop` への push のうち、`kasane/` 配下・Issue のフォーム・貢献の案内だけを変えたものでは、起動してはならない。`main` 宛ての Pull Request では、変更したパスに関わらず起動しなければならない。

同じブランチ、または同じ Pull Request で新しい実行が始まったとき、走っている古い実行は打ち切られなければならない。起動しない push は、走っている実行に影響してはならない。

**Side Effects**:
- GitHub 上の検証の実行: 作成、同じブランチまたは同じ Pull Request の古い実行の打ち切り

#### Scenario: develop への push で起動する
- **GIVEN** ライブラリのソースを変えた commit がある
- **WHEN** その commit を `develop` に push する
- **THEN** `lint`・`ios / verify`・`android / verify` の 3 つの検査が走り、利用者の立場のビルドの確認は走らない

#### Scenario: 開発の記録だけの push では起動しない
- **GIVEN** `kasane/` 配下のファイルだけを変えた commit がある
- **WHEN** その commit を `develop` に push する
- **THEN** 検証 CI は起動しない

#### Scenario: main 宛ての Pull Request では絞り込まない
- **GIVEN** `develop` から `main` 宛ての Pull Request がある
- **WHEN** その Pull Request が作られる、または更新される
- **THEN** 変更したパスに関わらず、`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` の 5 つの検査が走る

#### Scenario: 起動の対象になる新しい push が古い実行を打ち切る
- **GIVEN** `develop` への push で始まった検証が走っている
- **WHEN** ライブラリのソースを変えた新しい commit を `develop` に push する
- **THEN** 古い実行は打ち切られ、新しい commit に対する実行が走る

#### Scenario: 起動しない push は走っている実行に影響しない
- **GIVEN** `develop` への push で始まった検証が走っている
- **WHEN** `kasane/` 配下のファイルだけを変えた commit を `develop` に push する
- **THEN** 新しい実行は作られず、走っている実行はそのまま続く

## ADDED Requirements

### Requirement: 利用者の立場のビルドの確認の再利用

iOS と Android の利用者の立場のビルドの確認は、入口の workflow 以外の workflow からも、切り替えと版を渡して呼べなければならない (SHALL)。入口は、切り替えを `local` にして、版を渡さずに呼ぶ。入口から呼ばれたとき、検査は `consumer-ios / verify`・`consumer-android / verify` の名前で報告されなければならない。既存の 3 つの検査の名前は変えてはならない。

**Side Effects**: なし

#### Scenario: 検査が決めた名前で報告される
- **GIVEN** `main` 宛ての Pull Request で、検証 CI が起動した
- **WHEN** 検査の結果が報告される
- **THEN** 検査の名前は `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` である

#### Scenario: 別の workflow から切り替えを渡して呼べる
- **GIVEN** 利用者の立場のビルドの確認の workflow がある
- **WHEN** その定義を読む
- **THEN** ほかの workflow から呼ばれる形だけを持ち、切り替え (必須) と版 (任意) を入力として受け取る

#### Scenario: 入口は local で呼ぶ
- **GIVEN** 入口の workflow がある
- **WHEN** 利用者の立場のビルドの確認を呼ぶジョブの定義を読む
- **THEN** Pull Request で起動したときだけ走る条件を持ち、切り替えに `local` を渡し、版を渡していない

### Requirement: 利用者の立場のビルドの確認の道具と権限

利用者の立場のビルドの確認の workflow は、既存の検証の workflow と同じ決まりに従わなければならない (SHALL)。

- ランナーは版を指定した名前で選び、最新を指す名前を使わない
- iOS の確認は、決めた版の Xcode を使う。その版がランナーに無いとき、ビルドを始める前に失敗で終わる
- Android の確認は、決めた版の JDK を使う
- 外部の action は、commit の ID で指定する
- 権限は、リポジトリの内容の読み取りだけにする
- 各ジョブは時間の上限を持つ
- 失敗を見逃す指定を持たない

**Requires**:
- 決めた版の Xcode がランナーにあること

**Side Effects**: なし

#### Scenario: workflow の定義の検査が新しい workflow でも通る
- **GIVEN** 利用者の立場のビルドの確認の workflow を足した
- **WHEN** workflow の定義の検査を流す
- **THEN** 違反が無い

#### Scenario: 決めた版の Xcode が無いと落ちる
- **GIVEN** ランナーに、決めた版の Xcode が無い
- **WHEN** iOS の利用者の立場のビルドの確認が始まる
- **THEN** ビルドを始める前に、失敗で終わる

#### Scenario: 失敗を見逃す指定が無い
- **GIVEN** 利用者の立場のビルドの確認の workflow がある
- **WHEN** その定義を読む
- **THEN** どのジョブにも step にも、失敗を見逃す指定が無い
