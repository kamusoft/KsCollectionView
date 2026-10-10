## ADDED Requirements

### Requirement: README の節の並び

ルートの `README.md` と `README_ja.md` は、次の 9 つの節を、この順で持たなければならない (SHALL): 概要と特徴・スクリーンショット・対応プラットフォーム・インストール・最小コード例・Skill への導線・リポジトリ構成・貢献・ライセンス。2 枚は、同じ見出しの深さの並びを持ち、互いを指す。

開発者向けの手順 (ビルドのしかた・テストの流し方) を載せてはならない。

**Side Effects**: なし

#### Scenario: 2 枚が同じ節を同じ順で持つ
- **GIVEN** ルートの README の 2 枚
- **WHEN** 見出しを順に並べる
- **THEN** どちらも 9 つの節をこの順で持ち、見出しの深さの並びが一致する

#### Scenario: 準備中の案内が無い
- **GIVEN** 書き直した README
- **WHEN** 節の一覧を見る
- **THEN** 「準備中」だけを伝える節が無い

### Requirement: 対応プラットフォームの案内

README は、対応プラットフォームを表 1 枚で案内しなければならない (SHALL)。iOS は、最低の OS の版と、要る Xcode の版を書く。Android は、最低の OS の版と、利用者のビルドに求める下限を書き、ライブラリのビルドに使った道具の版を、それとは分けて書く。

表の値は、ビルドの設定の値と一致する。

**Side Effects**: なし

#### Scenario: iOS の値がマニフェストと一致する
- **GIVEN** `ios/Package.swift` が宣言する、対象の最も古い iOS と、要求するツールの版
- **WHEN** README の表の iOS の行を見る
- **THEN** 最低の OS の版がマニフェストと同じで、Xcode は 27 以上と書かれている

#### Scenario: Android の値がビルドの設定と一致する
- **GIVEN** 本体のモジュールのビルドの設定が決める、対象の最も古い Android
- **WHEN** README の表の Android の行を見る
- **THEN** 最低の OS の版が、ビルドの設定と同じである

#### Scenario: 利用者に求める下限と、ライブラリが使った版が分かれている
- **GIVEN** README の Android の案内
- **WHEN** 利用者が、自分のビルドに何が要るかを読み取る
- **THEN** 利用者に求める下限が、ライブラリのビルドに使った道具の版と取り違えずに読める

### Requirement: インストール例

README は、SwiftPM と Gradle のインストール例を持たなければならない (SHALL)。例の値 (Package URL・package の名前・product の名前・Maven の座標) は、利用者役が配布物を取るときに使う値と同じにする。版の位置には `{version}` を置き、具体の版を書かない。

例のそばに、`{version}` を置き換えること・置き換えないと依存の解決に失敗すること・最新の版の確かめ先を書く。

配布物を公開するまでの間、README は、インストールの節の冒頭に、まだ公開していないことを書く。

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

#### Scenario: まだ公開していないことが分かる
- **GIVEN** 配布物を公開する前の README
- **WHEN** インストールの節の冒頭を読む
- **THEN** 配布物をまだ公開していないことが書かれている

### Requirement: 最小コード例

README は、iOS と Android の最小コード例を 1 つずつ持たなければならない (SHALL)。各コード例は、そのプラットフォームの利用者役の画面のファイルの全体と、同じ内容である。

**Side Effects**: なし

#### Scenario: コード例が利用者役のファイルと同じである
- **GIVEN** 利用者役の画面のファイル (iOS と Android に 1 つずつ)
- **WHEN** README の 2 枚の、同じプラットフォームのコード例と比べる
- **THEN** 4 か所のすべてで、ファイルの全体と一致する

### Requirement: スクリーンショット

README は、スクリーンショットの節に、iOS と Android の画面を 3 つずつ (リスト・グリッド・グループ化) 載せなければならない (SHALL)。画像は本リポジトリの `assets/` に置き、README から相対パスで参照する。

画像に、外から取得した画像と、個人を特定する情報を写してはならない。

**Side Effects**: なし

#### Scenario: 6 枚の画像が表示される
- **GIVEN** README の 2 枚
- **WHEN** スクリーンショットの節の画像の参照をたどる
- **THEN** 6 枚の画像が、どれも `assets/` に実在する

#### Scenario: 両プラットフォームが同じ 3 つの画面を見せる
- **GIVEN** 6 枚の画像
- **WHEN** プラットフォームごとに並べる
- **THEN** iOS と Android が、同じ 3 つの画面を見せている

#### Scenario: 写ってはいけないものが無い
- **GIVEN** 6 枚の画像
- **WHEN** 1 枚ずつ見る
- **THEN** 外から取得した画像と、個人を特定する情報が写っていない

### Requirement: Skill への導線・貢献・ライセンスの案内

README は、各プラットフォームの `SKILL.md` と、Skill の索引へのリンクを持たなければならない (SHALL)。英語版は `skills/en/` の下と `skills/README.md` を、日本語版は `skills/ja/` の下と `skills/README_ja.md` を指す。

貢献の節は、不具合の報告・提案・質問を Issue で受け、外部からの Pull Request を受けないことを書き、貢献の案内を指す。ライセンスの節は、本ライブラリのライセンスを書いて `LICENSE` を指し、本ライブラリが依存するライブラリのライセンスを案内する。

**Side Effects**: なし

#### Scenario: 導線の先が実在する
- **GIVEN** README の 2 枚
- **WHEN** Skill への導線のリンクをたどる
- **THEN** どのリンクの先も実在し、英語版は英語の Skill を、日本語版は日本語の Skill を指している

#### Scenario: 貢献とライセンスの導線が保たれている
- **GIVEN** 書き直した README の 2 枚
- **WHEN** 貢献とライセンスの節を見る
- **THEN** 貢献の案内と `LICENSE` へのリンクがある
