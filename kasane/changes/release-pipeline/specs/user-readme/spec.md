## MODIFIED Requirements

### Requirement: インストール例

README は、SwiftPM と Gradle のインストール例を持たなければならない (SHALL)。例の値 (Package URL・package の名前・product の名前・Maven の座標) は、利用者役が配布物を取るときに使う値と同じにする。版の位置には `{version}` を置き、具体の版を書かない。

例のそばに、`{version}` を置き換えること・置き換えないと依存の解決に失敗すること・最新の版の確かめ先を書く。

配布物は公開済みとして書く。まだ公開していないことは書かない。

**Side Effects**: なし

#### Scenario: 例の値が利用者役と同じである
- **GIVEN** 利用者役が、公開済みの配布物を取るときに書く依存の行
- **WHEN** README のインストール例と比べる
- **THEN** 版の位置を除いて、同じである

#### Scenario: 版が書かれていない
- **GIVEN** README のインストール例
- **WHEN** 依存の宣言の行を見る
- **THEN** 版の位置が `{version}` で、具体の版がどこにも無い

#### Scenario: 最新の版の確かめ先が分かる
- **GIVEN** インストール例だけを読んだ利用者
- **WHEN** `{version}` を何に置き換えるかを調べる
- **THEN** 同じ節の中に、最新の版の確かめ先がある

#### Scenario: まだ公開していないとは書かれていない
- **GIVEN** 初回のリリースの後の README
- **WHEN** インストールの節を読む
- **THEN** 配布物をまだ公開していない、とは書かれていない
