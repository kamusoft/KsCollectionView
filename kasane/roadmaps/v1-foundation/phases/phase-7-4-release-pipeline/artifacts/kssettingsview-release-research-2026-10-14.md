# 翻案元 KsSettingsView のリリースの工程 (調査 2026-10-14)

ksn-scout による読み取り専用の調査の要約。agenda の論点「リリースの手順」と、phase-7-1・7-2・7-3 からの申し送り (版と tag の対応・Release の置き場所・`main` の運用) の材料。参考に KsDialogs との違いも載せる。secret は名前だけを書き、値は書かない。

## 1. ADR 3 枚 (3 枚とも accepted。amended-by / superseded-by は無い)

### 0019 lockstep 単一版 (2026-08-21)

- 決定: すべての platform・artifact に同じ semver を付け、monorepo の tag と一致させる。版の宣言は platform ごとに 1 か所にまとめる
- 却下した案:
  - platform ごとの接頭辞付き tag (SwiftPM が接頭辞付きの tag を版として読めない)
  - MAUI だけ独立の版 (利用者が対応する Native の版を読み解く必要が出る)
- 正の帰結: 版の特定と、利用者への説明が単純になる
- 負の帰結: 変更の無い platform にも空のリリースが出る。1 platform のビルドの失敗が、リリース全体を止める
- prerelease は `X.Y.Z-{alpha|beta|rc}.N` の形にする。`-pre` / `-preview` は、Maven の版の比較で正式版より新しいと判定されるので使わない
- SwiftPM の prerelease は `exact:` で案内するという例外が残る
- 現行照合 (2026-09-07): 帰結の「tag 1 本で起動する」は 0020 で崩れていて、乖離ありと判定されている。決定の本体は維持
- 根拠: `../KsSettingsView/kasane/decisions/cross/0019-lockstep-single-version.md`

### 0020 手動起動・tag は最後・版は CI が注入する (2026-08-21)

- 決定:
  - 起動は `workflow_dispatch` で、版を入力する。tag の push では起動しない
  - 公開は、取り消せる操作から先に行う: Maven の upload (保留) → NuGet の push → Maven の release → tag → Release
  - 版の唯一の正は、起動のときに入力した値。`-Pversion=` / `-p:Version=` で注入する。リポジトリ内の宣言は SNAPSHOT / dev のままにし、版を上げる commit を積まない
  - tag は接頭辞なしの `X.Y.Z`。monorepo と配信用リポジトリで同じ値
  - 本番は `main` からだけ起動する。secret は Environment `release` (deployment branch policy = main) にまとめる。dry-run はブランチの制限を免除する
- 却下した案:
  - tag の push で起動する (後段が失敗すると、iOS だけ先に公開された状態が残る)
  - release ブランチ / PR のマージで起動する (tag が先に出る問題が同じ)
  - ファイルを版の正にして tag と照合する (毎回、版を上げる commit が要る)
  - `vX.Y.Z` の表記 (CI・手順書・検証の各所で v の付け外しが要る)
  - develop から起動する (リリース対象の commit が一意に定まらない)
  - 同じ版での再実行を禁止する (片側だけ公開された版が欠番として残る)
  - smoke の後に tag を作る (smoke が失敗しても公開は取り消せず、利用者を守れない)
  - CI が README を書き換えて main に commit する (push の権限と保護の迂回が要る)
- 正の帰結: 失敗しても再実行するだけで済み、後始末が要らない。unlist しかできない NuGet を前に置き、不可逆な操作の後に失敗しうる工程を最小にする
- 負の帰結: リリースのたびに手動の起動が要る。リポジトリのファイルからはリリースの版が読めない。Central Portal の 2 段階の操作を CI から行う必要がある
- 現行照合: 維持。upload と NuGet の push の間に、Central Portal の検証の決着を待つ工程が加わった
- 根拠: `../KsSettingsView/kasane/decisions/cross/0020-release-dispatch-tag-last-version-injection.md`

### 0030 Release のノートは PR 本文から、手順の正は handbook (2026-09-11)

- 前提: develop へ直接 push し、main へは集約の PR だけが入る運用 (同リポジトリの ADR-0028)。そのため、ラベルによる自動の分類が機能しなかった (0.1.0-beta.2 では全件が「その他」に落ちた)
- 決定:
  - ノートは base=main の PR 本文の `## Changes` から組み立てる。行は `- breaking|feature|fix|docs: 説明` の形、利用者向けの変更が無いときは `- none`。節は必須で、欠けていたり、認識できない行があれば止める
  - 範囲の起点は、draft でない公開済みの Release のうち、main の first-parent 上で対象の commit の祖先にあって最も近いものの tag
  - ノートは validate で 1 回だけ組み立て、artifact で publish へ渡す。publish は PR 本文を読み直さない
  - `.github/release.yml` は廃止
  - 手順の正は handbook。スキルは実行のときに handbook を読むだけで、写しを持たない
- 却下した案:
  - ラベルを 6 つ作る (分類できるのが、集約 PR の粒度でしかない)
  - ADR-0028 を改めて、個別の PR の運用にする (代償が大きい)
  - commit からノートを作る (粒度が、利用者向けの変更の単位と合わない)
  - 直近の PR 1 本だけを見る (複数の PR を取りこぼす)
  - main への PR を 1 本に限る (リリース以外で main を触れなくなる)
  - 節を任意にする (書き忘れと「変更が本当に無い」を区別できない)
  - スキルを手順の正にする (オーナーの判断で却下)
- 負の帰結: PR ごとに書く手間が増える。workflow の責務が増える。スキルが handbook の更新に追随しないと、古い手順を実行しうる。書き忘れるとリリースが止まる
- Revisit When: main への取り込みの単位が変わったとき / ADR-0028 が改められたとき / `## Changes` の書き漏れで止まることが繰り返されたとき
- 根拠: `../KsSettingsView/kasane/decisions/cross/0030-release-notes-from-pr-body-and-handbook-as-procedure-source.md`

### 関連: 0029

インストール例から具体の版を外した決定。あわせて、GitHub の prerelease の印を付けずに `--latest` を指定する決まりを持つ (`../KsSettingsView/kasane/decisions/cross/0029-install-examples-without-pinned-version.md`)。

## 2. リリースの workflow (`../KsSettingsView/.github/workflows/release.yml`)

### 起動

- `workflow_dispatch` の入力は、`version` (必須) と `dry-run` (bool、既定 false) の 2 つ
- `concurrency: release`・`cancel-in-progress: false` で 1 本ずつ流す。既定の権限は `contents: read`
- リリース固有の値は env の節にまとめてあり、他のリポジトリへ持っていくときはここを差し替える前提

### ジョブの順序

1. validate: 入力の形、本番なら main であること、monorepo の同名の tag が起動した commit を指すか、配信用リポジトリの tag の検査、ノートの収集
2. 本体の検証 (ios / android / maui) と package-* を並列に走らせる
3. consumer-* を `mode: dry-run` で走らせる。成果物は artifact で渡す
4. publish (`environment: release`、`contents: write` + `id-token: write`、上限 240 分)
5. wait-for-registries
6. smoke-* (`mode: smoke`)

利用者役の確認は、公開の前 (dry-run) と後 (smoke) の 2 回呼んでいる。

### publish の中の順序

1. deploy key を ssh-agent に載せる (ホスト鍵は固定値)
2. 配信用リポジトリへ写しを commit して push する (差分が無ければ飛ばす。tag はまだ付けない)。commit のメッセージは版の文字列
3. 配信用リポジトリの tag を検査し直す
4. Maven を署名付きでビルドし直し、署名を検査し、package の段の成果物と比べてから upload (保留) する
5. deployment ID を artifact に保存する
6. Central の検証の決着を待つ
7. NuGet へ binding 2 本 → facade の順に push する (`--skip-duplicate`)
8. Maven を release し、公開を待つ
9. 配信用リポジトリの tag → monorepo の tag (`GITHUB_SHA`) → `gh release create`

### 版の注入と secret

- 版の注入: Gradle には `-Pversion="${KS_VERSION}"`。tag と配信用リポジトリも、同じ文字列をそのまま使う
- 署名の鍵: Gradle には環境変数 `ORG_GRADLE_PROJECT_signingInMemoryKey` / `...KeyId` / `...KeyPassword` で渡す。中身は secret の `SIGNING_KEY` / `SIGNING_KEY_ID` / `SIGNING_PASSWORD`。パスフレーズも secret で、ファイルには書き出さない
- そのほかの secret: Central Portal は `MAVEN_CENTRAL_USERNAME` / `MAVEN_CENTRAL_PASSWORD`、配信用リポジトリは `SPM_DEPLOY_KEY`。NuGet は Trusted Publishing (OIDC) で、secret は `NUGET_USER` だけ

### GitHub の Release とやり直し

- Release は monorepo にだけ作る。配信用リポジトリには Release が無い (0 件)
- prerelease の印は付けず、`--latest` を指定する。本文は validate が確定したノート。作成済みなら飛ばし、本文は更新しない
- 各 step は冪等にしてあり、やり直しは「Re-run failed jobs」で行う
- 同名の tag が起動した commit を指していれば、再実行として続ける。別の commit を指していれば失敗にする
- 保留中の deployment ID は、artifact で試行をまたいで引き継ぐ。失敗の経路では、保留中の deployment を drop する

## 3. リリースの手順の handbook (`../KsSettingsView/kasane/handbook/cross/release-procedure.md`)

### 初回だけの手動の手順

- develop から main を作る。保護は必須の検査 7 件、`enforce_admins: false`、承認数 0。設定の PUT は部分更新にならず、書かなかった項目は消える
- 書き込みできる deploy key を作る
- Environment `release` を main 限定で作り、secret 7 件を登録する。鍵は標準入力から流し、ファイルは `trash` で消す
- nuget.org に Trusted Publisher Policy を登録する

### 毎回の 5 段 (到達状態で書いてある)

1. 事前の確認: develop の CI が緑・push していない commit が無い・Skill の追従 (docs-refresh) が要るか
2. リリースの PR: develop → main の PR。`## Changes` は英語で書く。merge commit でマージする
3. 起動: `gh workflow run --ref main`
4. 見守り: 約 40 分
5. 公開の後の確認: 3 経路の公開物・Release・`/releases/latest`

人への確認は、版と `## Changes` の文面を 1 回にまとめて行う (2026-09-30 の変更)。

### 明文の決まりが無かったもの

- リリース候補にする節目の基準: 無い。版は人が決める、とだけある
- `main` を `develop` へ取り込み直すか: 規則は無い。squash / rebase でマージすると、conflict を解くために main を develop へ取り込むことになり、前の版の項目が次のノートに重複して載る、という警告がある (KsDialogs の 0.1.0-beta.3 で実際に起きた)
- 管理者による保護の迂回: 手順は無い。CI に迂回の権限を持たせる案は却下している (0020・0029)
  - develop の必須の検査は、管理者には `enforce_admins` が off で効力が無いとして撤去している (`../KsSettingsView/kasane/roadmaps/archive/2026-09-11-package-distribution/phases/phase-13-ci-trigger-slimming/agenda.md:12`)
- secret を検出したときの手順: 無い。検出は ci.yml の lint のジョブが gitleaks (`--redact`) で行う (`../KsSettingsView/.github/workflows/ci.yml`)

## 4. 版と tag の対応

- 本体と配信用リポジトリは、どちらも接頭辞なしの同じ文字列。monorepo の tag は 0.1.0-beta.1〜beta.10、配信用リポジトリ (`KsSettingsView-SPM`) も同じく beta.1〜beta.10 (`git ls-remote` で確認)
- Release は monorepo の 10 件だけで、beta.10 が Latest
- `../KsSettingsView-SPM/` は手元に clone されていない

## 5. 運用で起きた問題と、後から変えた経緯

| 出来事 | 対処 | 出典 |
|---|---|---|
| beta.2 で、Central の検証 (VALIDATING) を待たずに release へ進んで失敗した。失敗は NuGet の push の後に起きた | upload の直後に決着を待つ工程を入れ、NuGet より前に置いた | `../KsSettingsView/kasane/changes/archive/2026-09-07-fix-release-central-validation-wait/exploration.md` |
| README と Skill の版を置き換える仕組みを Skill まで広げた (2026-09-06) | 0029 で仕組みごと撤去して `{version}` 相当にした。`/releases/latest` が prerelease を除いて 404 を返す問題は、印を付けずに `--latest` を指定する形で解決した | `../KsSettingsView/kasane/changes/archive/2026-09-06-skills-install-version-drift/`・0029 |
| 自動生成のノートのラベルによる分類が機能しなかった | 0030 へ移った | 0030 |
| KsDialogs へ翻案したときの副産物の逆輸入 (7 件のうち 3 件を手当て) | NuGet の照会を fail-closed にした。公開待ちの上限 30 分では足りなかった (KsDialogs の初回は Central の同期に約 60 分)。待機スクリプトの自己テストをつないだ | `../KsSettingsView/kasane/changes/archive/2026-09-12-backport-release-workflow-hardening/` |
| 待機の上限の判定を外しても失敗にならず、止まる穴があった | 誤実装を注入して確かめる形で、自己テストの検出力を確かめた | `../KsSettingsView/kasane/changes/archive/2026-09-14-release-selftest-detection-audit/` |

教訓 (inbox。どれもリリースの workflow を足した change で起きた):

- `if [ "$(script)" = match ]` の形では script の終了コードが捨てられる。代入で受ける (`../KsSettingsView/kasane/lessons/inbox/command-substitution-exit-status-discarded-in-condition.md`)
- 増分ビルドで測った試作が、クリーンビルドでの挙動を見逃した (`../KsSettingsView/kasane/lessons/inbox/spike-measured-on-incremental-build-misses-clean-build-behavior.md`)
- ブランチを確かめないまま develop へ直接 push した (`../KsSettingsView/kasane/lessons/inbox/orchestrator-commits-without-verifying-branch.md`)

release.yml と handbook は、2026-09-03 に新設してから 9 回変わっている (`git log`)。

## 6. 参考: KsDialogs との違い (`../KsDialogs/.github/workflows/release.yml`)

- 4 つの形態 (KMP を含む) を出し、端末をつないで走らせるテスト (`android-instrumented`) と、KMP の利用者役の確認が加わる
- KMP の Maven のメタデータが配信用リポジトリの tag の実在を求めるので、配信用リポジトリの tag だけを、NuGet / Maven の取り消せない操作より前に作る (KsDialogs の cross/ADR-0024)
- 再実行してよいかを、印 (`release-eligibility-marker`、`GITHUB_RUN_ATTEMPT`) で判定する。同じ版での新しい起動と、印を持たない再実行は止める。KsSettingsView は、tag と commit の照合だけで再実行を許す
- NuGet に同じ版があるかを、事前に照会する

## 7. リリースの Skill (`../KsSettingsView/.agents/skills/release/SKILL.md`、2026-10-14 に追加で読んだ)

- 実体は `.agents/skills/release/` で、`.claude/skills/release` はそこへのリンク
- 手順の正は handbook (`release-procedure.md`)。起動のたびに先頭から読み、書かれた順とコマンドに従う。Skill は段の順序もコマンドも持たない。手順書と手元の状況が食い違ったら、補わずに止まる
- Skill が自分で持つのは 3 つだけ:
  - `## Changes` の下書きの作り方: 範囲は、作る Pull Request が `main` へ新しく持ち込む commit (`origin/main..origin/develop`) だけ。利用者から見える変化を 1 項目 1 行で書く (書式の正は `.github/pull_request_template.md`)。確定まで本文に書かない
  - 確認は 1 回: 版と `## Changes` の文面を 1 回のメッセージでまとめて確かめる。確定したら以降の承認として扱い、Pull Request の作成とマージ (merge commit)・本番の起動・tag の作成まで止まらずに進める
  - 止まる条件: 検証や実行が失敗したとき (失敗した位置と、手順書の対応する記述を示す)・手順書に無い状況に当たったとき・確定した版や文面のままでは進めないとき。再実行・中止はオーナーが決める
- CI の完了は自分で見張る (background で `gh run watch` / `gh pr checks --watch`)。自分からは起動しない (公開は取り消せないため)
- 最後に完了報告を 1 回出す (段ごとの到達状態・公開物・気になる点)
