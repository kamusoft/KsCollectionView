## ADDED Requirements

### Requirement: 公開前の確認

リポジトリは、次の 5 つの確認がすべて通ったときだけ、GitHub に push されなければならない (SHALL)。確認の結果は、証跡として残されなければならない。

- 全 commit の作者とコミッターのメールアドレスが、noreply のものだけである
- 履歴の中身に、個人を特定する値とローカル絶対パスが無い。merge commit だけが持つ内容 (どちらの親とも違う内容) と、最初の commit の内容を含めて確かめる
- 全コミットメッセージに、ローカル絶対パスとメールアドレスが無い
- secret の検査 (gitleaks) で、merge commit を含む全履歴の検出が 0 件である
- 履歴に残る証跡の画像の全件を目で見て、画面内に個人の情報が無い

**Requires**:
- 5 つの確認がすべて通っていること

**Side Effects**:
- 変更の証跡 (`evidence/`): 作成 (確認ごとの、実行した内容・件数・結果。画像そのものは置かない)

#### Scenario: すべて通れば公開に進める
- **GIVEN** 5 つの確認がすべて通り、結果が証跡に残っている
- **WHEN** 公開の手順に進む
- **THEN** GitHub への push を行える

#### Scenario: 通らない確認があれば公開しない
- **GIVEN** 5 つの確認のうち、通らないものが 1 つでもある
- **WHEN** 公開の手順に進もうとする
- **THEN** GitHub への push は行われず、通らなかった確認と見つかった内容がオーナーに示される

### Requirement: 履歴をそのまま公開する

公開のときに push する `main` と `develop` の履歴は、手元のリポジトリの履歴そのままでなければならない (SHALL)。公開のために、履歴を書き換えても、捨ててもならない。

最初の push は非公開の状態で行い、オーナーが中身を確かめてから public に切り替えなければならない。非公開の間に push するのは `main` だけとする。

**Side Effects**:
- GitHub 上のリポジトリ `kamusoft/KsCollectionView`: 作成、公開の範囲を public に更新
- GitHub 上のブランチ `main`・`develop`: 作成
- 手元のリポジトリの remote の設定: 作成
- 手元のブランチ `develop`: 作成

#### Scenario: 公開された履歴が手元と一致する
- **GIVEN** 手元の `main` の先端の commit の ID が分かっている
- **WHEN** 最初の push の後に、GitHub の `main` の先端を読む
- **THEN** 同じ commit の ID である

#### Scenario: public にする前にオーナーが確かめる
- **GIVEN** 非公開の状態で `main` が push されている
- **WHEN** public への切り替えに進む
- **THEN** その前に、オーナーが GitHub の画面で中身を確かめ、切り替えを承認している

### Requirement: ライセンスの表明

リポジトリのルートに、MIT License の全文を収めた `LICENSE` がなければならない (SHALL)。著作権の名義は `kamusoft` でなければならない。

**Side Effects**: なし

#### Scenario: ルートにライセンスがある
- **GIVEN** 公開リポジトリがある
- **WHEN** ルートの `LICENSE` を読む
- **THEN** MIT License の文面で、著作権の名義が `kamusoft` である

### Requirement: 準備中の案内

リポジトリのルートに、英語の `README.md` と日本語の `README_ja.md` がなければならない (SHALL)。2 枚は同じ構成で、次を示さなければならない。

- 何のライブラリか
- 準備中で、公開物がまだ無いこと
- ライセンス
- 貢献の案内への導線

インストールの手順と、使い方の説明は含めない。

**Side Effects**: なし

#### Scenario: 2 枚が同じ構成である
- **GIVEN** `README.md` と `README_ja.md` がある
- **WHEN** 2 枚の見出しの並びを比べる
- **THEN** 見出しの数と順番が一致する

#### Scenario: 準備中であることが分かる
- **GIVEN** 公開リポジトリを初めて見る人がいる
- **WHEN** どちらかの README を読む
- **THEN** 準備中で公開物がまだ無いことと、ライセンスと、貢献の案内の場所が分かる

### Requirement: 貢献方針の表明

貢献の案内が、英語と日本語の 2 枚でなければならない (SHALL)。2 枚は同じ構成で、次を示さなければならない。

- 外部からの Pull Request は受け付けないこと
- 貢献は Issue で受けること
- Issue の本文は英語でも日本語でもよいこと

**Side Effects**: なし

#### Scenario: 方針が両方の言語で読める
- **GIVEN** 貢献の案内の 2 枚がある
- **WHEN** どちらかを読む
- **THEN** 外部からの Pull Request を受け付けないことと、Issue で受けることが分かる

#### Scenario: 2 枚が同じ構成である
- **GIVEN** 貢献の案内の 2 枚がある
- **WHEN** 2 枚の見出しの並びを比べる
- **THEN** 見出しの数と順番が一致する

### Requirement: Issue のフォームの必須項目

Issue は、バグ報告・提案・質問の 3 本のフォームのどれかで作られなければならない (SHALL)。フォームを使わない空の Issue は作れてはならない。各フォームは、次の項目を必須にしなければならない。

| フォーム | 必須の項目 |
|---|---|
| バグ報告 | 版 / プラットフォーム / 再現手順 / 実際の挙動 / 期待した挙動 |
| 提案 | 解決したい課題 / 今どう困っているか / 考えた選択肢 |
| 質問 | 版 / プラットフォーム / 試したこと / 読んだ文書の箇所 |

**Requires**:
- 選んだフォームの必須の項目が、すべて埋まっていること

**Side Effects**: なし

#### Scenario: 3 本のフォームだけが選べる
- **GIVEN** 公開リポジトリがある
- **WHEN** Issue を新しく作る画面を開く
- **THEN** バグ報告・提案・質問の 3 本が選べ、空の Issue は選べない

#### Scenario: 必須の項目が空だと送れない
- **GIVEN** バグ報告のフォームで、再現手順が空である
- **WHEN** 送信しようとする
- **THEN** 送信できず、再現手順が必須であることが示される

### Requirement: Pull Request を作れる人の制限

公開リポジトリでは、Pull Request を作れる人が共同作業者に限られていなければならない (SHALL)。

**Side Effects**:
- GitHub のリポジトリの設定 (Pull Request を作れる人): 更新
- 変更の証跡 (`evidence/`): 作成 (実行した内容と、設定の読み直しの結果)

#### Scenario: 設定が共同作業者だけになっている
- **GIVEN** 公開リポジトリの設定を入れた
- **WHEN** Pull Request を作れる人の設定を読み直す
- **THEN** 共同作業者だけになっている

### Requirement: ブランチの保護

`main` と `develop` には、次の保護の設定が入っていなければならない (SHALL)。

- `main`: Pull Request を必須にする (承認の数は求めない)。`lint`・`ios / verify`・`android / verify` の 3 つを必須の検査にし、GitHub Actions が出したものに限る。強制 push と削除を禁じる
- `develop`: 強制 push と削除を禁じる。必須の検査は持たず、直接の push を受ける
- どちらの保護も、管理者には強制しない。管理者は保護を迂回できる

本変更の内容は、`develop` から `main` 宛ての最初の Pull Request で `main` に入れなければならない。マージは merge commit で行う。

**Side Effects**:
- GitHub のブランチの保護の設定 (`main`・`develop`): 作成
- GitHub 上の Pull Request (`develop` から `main`): 作成、マージ (`main` に merge commit が加わる)
- 変更の証跡 (`evidence/`): 作成 (実行した内容と、設定の読み直しの結果)

#### Scenario: main の保護に必須の検査が入っている
- **GIVEN** `main` の保護を入れた
- **WHEN** 保護の設定を読み直す
- **THEN** Pull Request が必須で承認の数は 0、必須の検査が 3 つで名前が `lint`・`ios / verify`・`android / verify` であり、強制 push と削除が禁じられていて、管理者には強制しない設定である

#### Scenario: develop は強制 push と削除だけを禁じる
- **GIVEN** `develop` の保護を入れた
- **WHEN** 保護の設定を読み直す
- **THEN** 強制 push と削除が禁じられていて、必須の検査は無く、管理者には強制しない設定である

#### Scenario: main には検査を通った develop が入る
- **GIVEN** `develop` から `main` 宛ての Pull Request がある
- **WHEN** 3 つの必須の検査が成功で終わる
- **THEN** その Pull Request を merge commit で `main` にマージでき、`main` に本変更の内容が入る

### Requirement: 公開リポジトリの機能の設定

公開リポジトリは、次の設定でなければならない (SHALL)。

- 既定のブランチは `main`
- Issues は有効。Wiki・Discussions・Projects は無効
- secret の検査・push の保護・依存の脆弱性の通知は有効
- Issue のフォームが使うラベル (`bug`・`enhancement`・`question`) がある

**Side Effects**:
- GitHub のリポジトリの設定 (機能・検査・通知): 更新
- 変更の証跡 (`evidence/`): 作成 (実行した内容と、設定の読み直しの結果)

#### Scenario: 設定が決めたとおりになっている
- **GIVEN** 公開リポジトリの設定を入れた
- **WHEN** 設定を読み直す
- **THEN** 既定のブランチ・機能の有効と無効・検査と通知・ラベルが、決めたとおりである
