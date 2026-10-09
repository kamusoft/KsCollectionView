# レビュー結果: package-distribution (002 回目)

**日付**: 2026-10-09
**判定**: APPROVED

## サマリー

修正サイクル 1 回目の後の再レビューで、対象は tasks.md のグループ 1〜8 (グループ 9 は未実施で対象外)。直した 4 件 (写しを作る道具が git の管理情報の実体を消し得る点・依存の宣言・テストの名前・コメント) は、どれも直っている。Critical・Major は無い。

写しを作る道具について、優先度の低い Minor を 1 件だけ残す。行き先の作業コピーが、オブジェクトの借用先 (alternates) を行き先の中に置いている場合は、今も成功を報告したまま commit を読めなくする。通常の clone では起きない構成なので、本変更の完了の条件にはしない。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always) — 修正で足した・直したコメント (写しの道具の冒頭と `check_git_directories`、バージョンカタログ、本体と利用者役のビルドファイル)
- `kasane/handbook/cross/verification-ci.md` — `scripts/ci/` のテストを変えた
- `kasane/handbook/cross/public-identifiers.md` — バージョンカタログと本体のビルドファイルを変えた
- `kasane/handbook/cross/test-execution.md` — テストの結果の報告
- 決定: core/ADR-0012・android/ADR-0008・cross/ADR-0013・0014 (accepted)。cross/ADR-0015・0016 は proposed なので、判定の根拠にしていない
- `kasane/lessons/code-review.md`: L-001 (直前のサイクルで直したコードの計測値の再現) が該当する。POM の依存の範囲を自分で作り直して読んだ (下の表)。L-002 は対象の機能が無い。「指摘しないこと」は空

ロードしたスキル: ksn-review / kotlin-impl-skill

## 確認した観点

自分で流したもの (2026-10-09):

| 流したもの | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 261 件 / 失敗 0 件 / スキップ 0 件 (前回の 259 件に、管理情報の配置のテスト 2 件が増えた) |
| `python3 scripts/ci/check-workflows.py` | workflow 5 本、違反は無い |
| `scripts/local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py` | どれも違反なし (コメントの規約は検査対象 502 ファイル・禁止 0 件) |
| `./gradlew --offline :kscollectionview:generatePomFileForMavenPublication` (発行はしない。POM の生成だけ) | 成功。compile は runtime・ui・foundation-layout・coil-compose 3.5.0・`androidx.annotation:annotation` 1.9.1・kotlin-stdlib 2.4.10 の 6 つ、runtime は 6 つ、BOM は import。`evidence/android-publishing.md` の「修正サイクル 1」の表と一致した |
| 写しを作る道具を、リポジトリの外の使い捨ての作業コピー 4 種へ実行 (下) | 3 種は期待どおり。1 種が指摘 1 |

写しを作る道具に渡した作業コピー (どれも origin は配信用リポジトリの URL。ネットワークは使っていない):

| 行き先の構成 | 結果 |
|---|---|
| `.git` が、行き先の中の実体を指すシンボリックリンク | 終了コード 1 で拒否。tag を読める |
| 行き先が追加の作業ツリー (worktree) で、共通の管理情報が行き先の中のディレクトリにある | 終了コード 1 で拒否。tag を読める |
| 行き先が追加の作業ツリーで、共通の管理情報が行き先の外にある | 終了コード 0。直下は `.git` と写しの 5 点。tag を読める |
| オブジェクトの借用先 (alternates) が行き先の中のディレクトリを指す | 終了コード 0 で「写しを作った」と出るが、その後 `git log` が `bad object HEAD` で失敗する (指摘 1) |

流していないもの: テスト 4 系統 (iOS 本体・iOS Sample・Android 本体・Android Sample)、確認のスクリプト 2 本の実物のビルド、手元への発行。パッケージの制約に従い、件数と結果は指揮側の報告と証跡を読んだ。利用者役の compile のクラスパスに届く `androidx.annotation` の版 (1.9.1) と AAR のハッシュの比較は、証跡の記録だけで、再現していない。

修正した 4 件:

- 管理情報の実体 (相方レビューの Major): `scripts/distribution/sync-spm-snapshot.py:193` の確認が、作業ツリーごとの管理情報と共通の管理情報の両方の場所を読み、消す対象と同じ並び (直下の `.git` 以外のディレクトリ。シンボリックリンクは除く) と実体のパスで突き合わせている。消す前に拒否し、行き先は変わらない。回帰のテストは、拒否の後に中身・HEAD・tag が変わらず、commit した内容を取り出せることまで見ている。管理情報が行き先の外にある作業コピーを受け付けるテストもある
- 依存の宣言 (review-001.md の指摘 1): `androidx.annotation` を版 1.9.1 で `api` に足し、`ui-graphics`・`ui-unit` は足していない。deviation.md の行と一致する。兄弟ライブラリの宣言 (`../KsSettingsView/android/kssettingsview/build.gradle.kts:214`) も同じ形だった。runtime の範囲へ動いた依存は無い
- テストの名前 (同 指摘 2): 確認のスクリプトのテスト 2 本 (48 件・47 件) は、すべて日本語の名前になった
- コメント (同 指摘 3): `verification/android/app/build.gradle.kts:79` は「本体のバージョンカタログに無いので、版をここに書く」という事実だけになった

仕様充足:

- 足場 (proposal.md・design.md・specs/) は commit 192a10b から変わっていない
- tasks.md の diff はチェックの付け替えだけ。グループ 9 は未チェックのまま
- deviation.md は乖離 1 行。記録の無い差は見つからなかった

設計品質:

- 修正で足したコメントは単独で読める。コードのコメントに、レビューの番号や修正サイクルへの参照は無い
- 成果物 (証跡・草稿・deviation.md) にローカル絶対パスは無い
- Gradle Kotlin DSL: 足した依存はバージョンカタログの別名で参照し、版を書く場所は 1 箇所である

## 指摘事項

### [🟡 Minor] オブジェクトの借用先 (alternates) が行き先の中にある作業コピーでは、成功を報告したまま commit を読めなくする (優先度: 低)

**該当箇所**: `scripts/distribution/sync-spm-snapshot.py:201`

**問題点**: 足した確認が見るのは、作業ツリーごとの管理情報と共通の管理情報の場所の 2 つである。git は、オブジェクトを別のディレクトリから借りる設定 (`objects/info/alternates`) を持つ。その借用先が行き先の中の、`.git` 以外のディレクトリにあると、確認を通って借用先が消える。使い捨ての作業コピーで試すと、道具は終了コード 0 で「写しを作った」と出し、その後の `git log` は `bad object HEAD` で失敗した。直した Major と同じ種類の壊れ方である。

ただし、この構成は、作業ツリーの中にオブジェクトの置き場を自分で作って借用先に指定しないとできない。配信用リポジトリを普通に clone した作業コピーでは起きない。壊れても、配信用リポジトリから取り直せる。そのため優先度は低く、判定には響かせていない。

**推奨修正**: 次のどちらかでよい。本変更の完了の条件にはしない。

- 借用先も確認に足す: 行き先の git のオブジェクトの借用先 (`objects/info/alternates` の各行) を読み、消す対象の中にあれば拒否する
- 受け付けない構成として書く: 道具の冒頭の説明と、配布物の形の文書の草稿に、借用先を行き先の中に置いた作業コピーは対象外と 1 行足す

## アクションプラン

1. 指摘 1 は任意。直すなら借用先の確認と回帰のテストを 1 件足す。見送るなら、そのままでよい
2. 次の段 (verify) へ進める。グループ 9 (公開リポジトリでの確認と保護の更新) は、このレビューの対象に入っていない
