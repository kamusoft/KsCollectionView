## MODIFIED Requirements

### Requirement: ブランチの保護

`main` と `develop` には、次の保護の設定が入っていなければならない (SHALL)。

- `main`: Pull Request を必須にする (承認の数は求めない)。`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` の 5 つを必須の検査にし、GitHub Actions が出したものに限る。強制 push と削除を禁じる
- `develop`: 強制 push と削除を禁じる。必須の検査は持たず、直接の push を受ける
- どちらの保護も、管理者には強制しない。管理者は保護を迂回できる

`consumer-ios / verify`・`consumer-android / verify` の 2 つは、`develop` から `main` 宛ての Pull Request で、その名前の検査が報告されたことを確かめてから、必須の検査に足さなければならない。足すときに、ほかの保護の値を変えてはならない。

本変更の内容は、その Pull Request で `main` に入れなければならない。マージは merge commit で行う。

**Side Effects**:
- GitHub のブランチの保護の設定 (`main`): 更新 (必須の検査を 3 つから 5 つにする)
- GitHub 上の Pull Request (`develop` から `main`): 作成、マージ (`main` に merge commit が加わる)
- 変更の証跡 (`evidence/`): 作成 (実行した内容と、設定の読み直しの結果)

#### Scenario: 報告された名前を確かめてから足す
- **GIVEN** `develop` から `main` 宛ての Pull Request で、検証 CI が起動した
- **WHEN** 報告された検査の名前を読む
- **THEN** `consumer-ios / verify`・`consumer-android / verify` があり、その後に 2 つを必須の検査に足す

#### Scenario: main の保護に必須の検査が 5 つ入っている
- **GIVEN** `main` の保護を更新した
- **WHEN** 保護の設定を読み直す
- **THEN** 必須の検査が 5 つで、名前が `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` であり、Pull Request が必須で承認の数は 0、強制 push と削除が禁じられていて、管理者には強制しない設定である

#### Scenario: develop の保護は変わらない
- **GIVEN** `main` の保護を更新した
- **WHEN** `develop` の保護の設定を読み直す
- **THEN** 強制 push と削除が禁じられていて、必須の検査は無く、管理者には強制しない設定のままである

#### Scenario: main には 5 つの検査を通った develop が入る
- **GIVEN** `develop` から `main` 宛ての Pull Request がある。`main` の保護は、5 つを必須の検査にしている
- **WHEN** 5 つの必須の検査が成功で終わる
- **THEN** その Pull Request を merge commit で `main` にマージでき、`main` に本変更の内容が入る
