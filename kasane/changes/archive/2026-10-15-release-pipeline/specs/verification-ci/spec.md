## MODIFIED Requirements

### Requirement: 道具の固定と権限

検証 CI とリリースの workflow が使う道具は、版が決まっていなければならない (SHALL)。

- ランナーは版を指定した名前で選び、最新を指す名前を使わない
- iOS の検証は、決めた版の Xcode を使う。その版がランナーに無いとき、テストを始める前に失敗で終わる
- Android の検証は、決めた版の JDK を使う
- 外部の action は、commit の ID で指定する
- secret の検査の道具は、配布物のチェックサムを確かめてから使う。合わないとき、失敗で終わる

検証 CI とリリースの workflow の権限は、リポジトリの内容の読み取りだけでなければならない。ただし、リリースの workflow の公開のジョブだけは、リポジトリの内容の書き込み (tag と Release を作るため) を持ってよい。各ジョブは時間の上限を持ち、上限を超えたジョブは失敗で終わらなければならない。

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
- **GIVEN** 検証 CI の workflow の定義か、リリースの workflow の公開のジョブ以外のジョブに、リポジトリの内容の読み取り以外の権限がある
- **WHEN** workflow の定義の検査が走る
- **THEN** 検査は失敗で終わり、その権限の場所が示される

#### Scenario: 公開のジョブの書き込みの権限は通る
- **GIVEN** リリースの workflow の公開のジョブが、リポジトリの内容の書き込みだけを読み取りに加えて持つ
- **WHEN** workflow の定義の検査が走る
- **THEN** その権限では検査は失敗しない

#### Scenario: 公開のジョブでも、書き込み以外の権限は落ちる
- **GIVEN** リリースの workflow の公開のジョブが、リポジトリの内容の書き込みのほかに別の権限 (Pull Request の書き込みなど) を持つ
- **WHEN** workflow の定義の検査が走る
- **THEN** 検査は失敗で終わり、その権限の場所が示される

#### Scenario: 時間の上限を超えると落ちる
- **GIVEN** あるジョブが、時間の上限を超えて走り続けている
- **WHEN** 上限に達する
- **THEN** そのジョブは打ち切られ、失敗で終わる

## ADDED Requirements

### Requirement: リリースの workflow の定義の検査

スクリプトのテストは、リリースの workflow の定義が次を満たすことを検査しなければならない (SHALL)。検査は lint の中で毎回走る。

- 起動は手動だけで、入力は版と dry-run の 2 つ
- 同時に 1 本だけ流れ、走っているものを打ち切らない
- secret を置いた環境を指定するのは、公開のジョブだけ
- 公開のジョブの step が、写しの push → 保留の送信 → 決着の待ち → 公開 → 配信用リポジトリの tag → 本リポジトリの tag → Release の順に並ぶ

**Side Effects**: なし

#### Scenario: tag の push での起動を足すと落ちる
- **GIVEN** リリースの workflow の起動の条件に、tag の push を足した
- **WHEN** スクリプトのテストが走る
- **THEN** テストは失敗で終わる

#### Scenario: 公開の step の順を入れ替えると落ちる
- **GIVEN** 公開のジョブで、本リポジトリの tag の step を、Maven Central の公開の step より前に移した
- **WHEN** スクリプトのテストが走る
- **THEN** テストは失敗で終わり、順の食い違いが示される

#### Scenario: 公開以外のジョブに環境を指定すると落ちる
- **GIVEN** 組み立てのジョブに、secret を置いた環境を指定した
- **WHEN** スクリプトのテストが走る
- **THEN** テストは失敗で終わる
