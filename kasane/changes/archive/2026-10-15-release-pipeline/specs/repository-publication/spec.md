## ADDED Requirements

### Requirement: 配信用リポジトリ

SwiftPM の配信用リポジトリ `kamusoft/KsCollectionView-SPM` は、公開のリポジトリとしてなければならない (SHALL)。次の設定を持つ。

- Issue の機能を無効にし、Pull Request を作れる人を共同作業者に限る (本リポジトリと同じく、貢献は本リポジトリの Issue で受ける — cross/ADR-0011)
- ルートの README が、配信用の写しであることと、使い方・不具合の報告先が本リポジトリであることを示す
- 書き込みは、リリースの workflow が使う書き込み用の deploy key と、管理者だけができる
- Release を作らない (cross/ADR-0024)

**Side Effects**: なし

#### Scenario: 配信用リポジトリから本リポジトリへ案内される
- **GIVEN** 利用者が配信用リポジトリのページを開いた
- **WHEN** README を読む
- **THEN** 配信用の写しであることと、使い方と不具合の報告先が本リポジトリであることが分かる

#### Scenario: Issue を作れない
- **GIVEN** 共同作業者でない利用者が、配信用リポジトリを開いた
- **WHEN** Issue を作ろうとする
- **THEN** Issue の機能が無く、作れない

#### Scenario: 共同作業者でない人は Pull Request を作れない
- **GIVEN** 共同作業者でない利用者が、配信用リポジトリの fork を持っている
- **WHEN** 配信用リポジトリ宛ての Pull Request を作ろうとする
- **THEN** 作れない

### Requirement: リリース用の環境

本リポジトリは、リリース用の Environment `release` を持たなければならない (SHALL)。この Environment は、`main` から起動した run だけが使え、リリースの secret (署名の鍵・鍵の ID・パスフレーズ・Central Portal の認証の情報 2 つ・配信用リポジトリの書き込み用の鍵) を持つ。secret の値は、オーナーが登録する。

**Side Effects**: なし

#### Scenario: main 以外の run は環境を使えない
- **GIVEN** `develop` から起動した run のジョブが、Environment `release` を指定した
- **WHEN** そのジョブが始まる
- **THEN** ジョブは環境の保護に止められ、secret を受け取らない

#### Scenario: 必要な secret がそろっている
- **GIVEN** Environment `release` がある
- **WHEN** secret の名前の一覧を読む
- **THEN** リリースの workflow が使う 6 つの名前がすべてある
