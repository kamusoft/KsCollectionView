# Tasks: release-pipeline

外向きの操作 (GitHub の設定・リポジトリの作成・Pull Request の本文の編集とマージ・リリースの起動) は、各タスクの前にオーナーの承認を得る。secret の値はオーナーが登録し、エージェントは値を扱わない。証跡は `evidence/` に置く。

## 1. 外部の挙動を確かめる (実装の最初)

- [x] 1.1 vanniktech 0.37.0 のソースと Central Portal の公式の文書で、次を確かめて記録する: `publishToMavenCentral` が検証の決着を待つか / 自動で公開する設定の既定 / 送信の ID の取り出し方 / Publisher API で状態を照会・公開を指示・取り下げる呼び方と認証 / 公開済みの判定と公開済みの POM の取り方 / Gradle の POM の `scm` に commit を書く API。結果で design の Decision 3 の未決を決め、deviation.md に書く (→ Requirement: 公開の順序 / 同じ版での再実行)
- [x] 1.2 GitHub の公式の文書で、`workflow_dispatch` の入力・`concurrency` の待ち・Environment の deployment branch policy・最新の Release の選ばれ方 (`--latest` とプレリリース) を確かめて記録する (→ Requirement: リリースの起動 / 1 本ずつ流れる / secret の渡し方 / 公開の後の確認)
- [ ] 1.3 オーナーに、署名の鍵と Central Portal の認証の情報を兄弟ライブラリと共通にするか本ライブラリ用に作るかと、名前空間 `jp.kamusoft` で本ライブラリの座標を公開できるかを確かめてもらう (design の Open Questions)

## 2. リリースの道具 (`scripts/release/`)

- [x] 2.1 版の形と、両リポジトリの同じ名前の tag の状態と、公開済みの版の元の commit を検査するスクリプトと、そのテストを足す (形の誤り・起動元・本リポジトリの tag の食い違い・配信用リポジトリの tag の食い違い・別の commit から公開済み・再実行として続ける場合) (→ Requirement: リリースの起動 / 同じ版での再実行)
- [x] 2.2 リリースノートを収集・検査・組み立てるスクリプト `build-release-notes.py` と、そのテストを足す (範囲・初回・節が無い・読めない行・説明が空・空の節・節が 2 つ・注釈を読まない・次の見出しで終わる・none の混在・すべて none・種類ごとのまとまり) (→ Requirement: リリースノートの組み立て / ノートは 1 回だけ組み立てる)
- [x] 2.3 Central Portal の Publisher API を操作するスクリプト `central-portal.py` と、偽の API を相手にしたテストを足す (状態の照会・決着の待ち・公開の指示・取り下げ・公開済みの判定・控えの状態ごとの扱い (保留中・公開の処理中・失敗・見つからない)・上限で失敗) (→ Requirement: 公開の順序 / 同じ版での再実行)
- [x] 2.4 署名して組み立て直した発行物の検査 (署名がそろっていること・組み立ての段と署名を除いて同じ中身であること) のスクリプトと、そのテストを足す (→ Requirement: 公開の順序)
- [x] 2.5 Maven Central の取得先に版が現れるまで待つスクリプトと、上限に達したら失敗で終わることのテストを足す (→ Requirement: 公開の後の確認)
- [x] 2.6 2.1〜2.5 のテストが `python3 scripts/ci/run-tests.py` で流れることを確かめる

- [x] 2.7 Android の発行物の POM の `scm` に、`-P` で渡した元の commit を書く設定と、そのテストを足す (→ Requirement: 公開の順序)

## 3. 利用者役に工程の成果物を受け取る切り替えを足す

- [x] 3.1 `scripts/ci/verify-consumer-ios.py` に切り替え `artifact` を足し、テストを足す (渡された写しの参照・写しが無いときの失敗・知らない切り替え) (→ Requirement: 利用者役の参照の書き方 / iOS の利用者の立場のビルドの確認)
- [x] 3.2 `scripts/ci/verify-consumer-android.py` に切り替え `artifact` を足し、テストを足す (渡されたリポジトリだけからの取得・リポジトリか版が無いときの失敗) (→ Requirement: 利用者役の参照の書き方 / Android の利用者の立場のビルドの確認)
- [x] 3.3 `verify-consumer-ios.yml`・`verify-consumer-android.yml` に入力 `artifact` と取り込みの step を足し、`scripts/ci/tests/test_workflow_files.py` の固定を合わせる。検証 CI の呼び方 (`local`) は変えない (→ Requirement: 利用者役の再利用 workflow が成果物を受け取る)
- [x] 3.4 手元で、`local` と、手元で作った写しと発行物を渡した `artifact` の両方で、iOS と Android の確認が通ることを確かめる (→ Requirement: iOS / Android の利用者の立場のビルドの確認)

## 4. リリースの workflow

- [x] 4.1 `.github/workflows/release.yml` を足す (起動・入力・`concurrency`・ジョブの並び・dry-run で公開を飛ばす・Environment は公開のジョブだけ・secret を使う step だけに渡す・公開の step の順・再実行の形・待ちの上限とジョブの時間の上限・公開の後の確認) (→ Requirement: release-workflow の全 Requirement)
- [x] 4.2 `scripts/ci/check-workflows.py` の権限の決まりに、リリースの workflow の公開のジョブだけ `contents: write` を許す例外を足し、テストを足す (→ Requirement: 道具の固定と権限)
- [x] 4.3 `scripts/ci/tests/test_workflow_files.py` に、リリースの workflow の定義の検査を足す (起動が手動だけ・入力・`concurrency`・環境は公開のジョブだけ・公開の step の順) (→ Requirement: リリースの workflow の定義の検査)

## 5. リリースノートの材料

- [x] 5.1 `.github/pull_request_template.md` を足す (変更の節と書き方) (→ Requirement: Pull Request のひな形)

## 6. リリースの Skill

- [x] 6.1 変更 `user-skill-refresh-skill` が、Skill の置き方 (`.agents/skills/` の実体・`.claude/skills/` からのリンク・AGENTS.md の行) を実装し終えていることを確かめる。終えていなければ、ここで止めてオーナーに報告する
- [x] 6.2 `.agents/skills/release/SKILL.md` と、`.claude/skills/release` のリンクを足し、AGENTS.md に 1 行を足す (手順の文書を読む・事前の確認 (push と検証の待ち・分かれていたら止まる・追従は確かめるだけ)・確認は 1 回・対象の commit と先端の一致を見てマージ・下書きの作り方・止まる条件・自分から起動しない) (→ Requirement: release-skill の全 Requirement)

## 7. 蒸留で handbook に置く文面の草稿 (change の中に書く)

- [x] 7.1 `drafts/release-procedure.md` に、リリースの手順の草稿を書く (毎回の手順・初回だけの手順・失敗したときのやり直し・別の run に残った保留の送信の取り下げ方・リリースの前後に確かめること)。初回のリリースはこの草稿に従う
- [x] 7.2 `drafts/` に、`branch-and-github-settings.md` へ足す文面の草稿を書く (節目の基準を置かない・管理者も迂回しない・`main` を `develop` へ取り込み直さない・secret を検出したときの手順と誤検出の扱い・配信用リポジトリと Environment の設定)

## 8. 手元の完了判定

- [x] 8.1 スクリプトのテストを全件流し、失敗 0 を確かめる
- [x] 8.2 テストの規約に従い、4 系統 (iOS 本体・iOS Sample・Android 本体・Android Sample) を全件流し、失敗 0 を確かめる

## 9. GitHub の準備 (外向き。オーナーの承認を得てから)

- [x] 9.1 配信用リポジトリ `kamusoft/KsCollectionView-SPM` を作り、Issue の機能を無効にし、Pull Request を作れる人を共同作業者に限る。設定を API で読み直して証跡に残す (→ Requirement: 配信用リポジトリ)
- [x] 9.2 オーナーが、配信用リポジトリの書き込み用の deploy key を作って登録する (エージェントは公開鍵の登録の手順を示す)
- [x] 9.3 Environment `release` を作り、deployment branch policy を `main` だけにする。設定を API で読み直して証跡に残す (→ Requirement: リリース用の環境)
- [x] 9.4 オーナーが、Environment `release` に 6 つの secret を登録する。エージェントは名前の一覧を API で読み直し、6 つがそろっていることを確かめる (値は読まない) (→ Requirement: リリース用の環境)

## 10. 通しの確認と初回のリリース

- [x] 10.1 実装を `develop` に入れ、検証 CI が緑になることを確かめる
- [ ] 10.2 準備の Pull Request (変更の節は `- none`) を `develop` から `main` へ出し、必須の検査が通ったらマージする。リリースの workflow のファイルが既定のブランチに入り、手動で起動できるようになる
- [ ] 10.3 `develop` から dry-run を起動し、公開の前の確認まで通り、外へ何も送らないことを確かめる (→ Requirement: 公開の前の確認 / secret の渡し方)
- [ ] 10.4 `develop` から本番の起動を試し、最初のジョブで止まることを確かめる (→ Requirement: リリースの起動)
- [ ] 10.5 README 2 枚の「まだ公開していない」の 1 文を外す。配信用 README のひな形が、ルートの README と食い違っていないかを確かめる (→ Requirement: インストール例)
- [ ] 10.6 #1・#2 の本文に、変更の節 (`- none`) を書き足す (→ Requirement: リリースノートの組み立て)
- [ ] 10.7 リリースの Pull Request を `develop` から `main` へ出し、変更の節 (初回の内容) を書いて、必須の検査が通ったらマージする
- [ ] 10.8 `main` から dry-run を起動し、リリースノートの組み立てまで通ることを確かめる (→ Requirement: リリースノートの組み立て)
- [ ] 10.9 `main` から版 `0.1.0-beta.1` で本番を起動し、公開の後の確認まで通ることを確かめる。step の順・配信用リポジトリと本リポジトリの tag・Release の属性・最新の Release・Maven Central の公開と POM の commit を証跡に残す (→ Requirement: 公開の順序 / 公開の後の確認)
