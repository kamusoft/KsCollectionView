# Design: release-pipeline

## Context

配布物の形はできている (変更 `package-distribution`)。

- SwiftPM: `scripts/distribution/sync-spm-snapshot.py` が、行き先 1 つを受け取って `ios/` の写し (マニフェスト・`Sources/`・`Tests/`・`LICENSE`・配信用 README) を作る。git は操作しない。行き先は、まだ無いパス・空のディレクトリ・origin が `kamusoft/KsCollectionView-SPM` の作業コピーに限る
- Android: 公開のプラグインは vanniktech `com.vanniktech.maven.publish` 0.37.0 (`android/gradle/libs.versions.toml:54`)。`publishToMavenCentral()` を引数なしで呼び、`signAllPublications()` で署名する (`android/kscollectionview/build.gradle.kts:86-93`)。鍵はプロパティ `signingInMemoryKey`・`signingInMemoryKeyId`・`signingInMemoryKeyPassword`、認証は `mavenCentralUsername`・`mavenCentralPassword` で受け取る。鍵が無ければ署名を飛ばす。版が `-SNAPSHOT` のとき、Maven Central へ送るタスクを失敗させる (`:154-178`)。開発中の版は `0.1.0-SNAPSHOT` で、`-Pversion` で上書きできる (`android/build.gradle.kts:11-17`)
- プラグインのタスクは、保留で送る `publishToMavenCentral`・送って自動で公開する `publishAndReleaseToMavenCentral`・取り下げる `dropMavenCentralDeployment` などで、**保留にした送信を後から公開するだけのタスクは無い** (0.37.0 の jar の文字列から確認)。`publishToMavenCentral` が検証の決着を待つかどうかは、確かめていない
- 利用者役: `scripts/ci/verify-consumer-ios.py`・`verify-consumer-android.py` と、同名の再利用 workflow が、切り替え `local`・`published` と版を受け取る。`local` は自分で写しと発行物を作り、`published` は公開済みのものを取る。外から成果物を受け取る口は無い。README の検査が、iOS の `published` の参照の行を比べる相手にしている
- 検証 CI: 入口 `ci.yml` が `verify-ios.yml`・`verify-android.yml` を呼び、`main` 宛ての Pull Request のときだけ利用者役の 2 本を `local` で呼ぶ。権限は `contents: read`
- workflow の定義の検査 (`scripts/ci/check-workflows.py`) は、すべての workflow に、外部の action の commit の ID での指定・版を指定したランナー・各ジョブの時間の上限・**`contents: read` か `none` だけの権限**を求める。`scripts/ci/tests/test_workflow_files.py` は、`ci.yml` のジョブの数・利用者役の入力が `{mode, version}` だけであること・step の数などを固定している
- 既定のブランチは `main` である。手動で起動する workflow は、既定のブランチに workflow のファイルがあるときだけ起動できる (GitHub の決まり)
- `main` 宛ての Pull Request はこれまでに 2 本 (#1・#2) で、どちらの本文にも変更の節 (`## Changes`) が無い。Pull Request のひな形も無い
- README の「まだ公開していない」の 1 文 (`README.md:38`・`README_ja.md:38`) を見ている検査は無い。変更 `user-docs` の spec が「公開するまでの間」書くと定めている
- 進行中の変更 `user-skill-refresh-skill` は、追従の Skill の実体を `.agents/skills/docs-refresh/` に置き、`.claude/skills/docs-refresh` をそこへの相対のリンクにして、AGENTS.md に 1 行を足す。リリースの手順から追従の「確かめるだけ」を呼ぶかは、phase-7-4 に委ねている

フェーズの決定は `kasane/roadmaps/v1-foundation/phases/phase-7-4-release-pipeline/agenda.md` の決定事項にあり、方向は cross/ADR-0021〜0024 (proposed) にある。兄弟ライブラリ KsSettingsView の工程の実物は、同じフェーズの `artifacts/kssettingsview-release-research-2026-10-14.md` にまとめてある。

## Goals / Non-Goals

**Goals**

- 版を入力して `main` から手動で起動すると、両プラットフォームの配布物が同じ版で公開され、tag と Release ができる
- どこで失敗しても、同じ版の再実行で続けられる
- 公開の前に、工程が実際に公開する成果物を利用者役で確かめる
- リリースの入口になる Skill があり、オーナーの確認は版と文面の 1 回で済む
- 初回の版 `0.1.0-beta.1` を公開し、公開の後の確認まで通す

**Non-Goals** は proposal.md のとおり。

## Decisions

### Decision 1: 版の形と、入力の検査

**採用案:** 版は semver の `X.Y.Z` か、プレリリースの `X.Y.Z-alpha.N`・`X.Y.Z-beta.N`・`X.Y.Z-rc.N` に限る (N は 1 以上)。workflow の最初のジョブが、入力をこの形と照らし、合わなければ何もせずに止まる。tag は版の文字列そのものを、本リポジトリと配信用リポジトリの両方に付ける (cross/ADR-0021)。初回の版は `0.1.0-beta.1`。

**理由:** プレリリースの語を絞るのは、Maven の版の比較で正式版より前に並ぶ語だけを使うため。入力を最初に検査すれば、形の誤りで途中まで進んでから止まることが無い。

**代替案:**
- **A: プラットフォームごとの版** — cross/ADR-0021 で却下 (確かめ先が分かれ、6 つのファイルと許可する URL の一覧を書き直す)
- **B: `v` 付きの tag** — cross/ADR-0021 で却下 (各所で付け外しが要る)

### Decision 2: リリースの workflow の構成

**採用案:** `.github/workflows/release.yml` を足す。起動は `workflow_dispatch` だけで、入力は `version` (必須) と `dry-run` (真偽、既定は偽)。`concurrency` の group を 1 つに固定し、走っている間に起動したものは待たせる (打ち切らない)。ジョブの並び:

```
validate ─┬─ verify-ios (verify-ios.yml を呼ぶ)
          ├─ verify-android (verify-android.yml を呼ぶ)
          ├─ package-ios (写しを作って artifact に置く)
          └─ package-android (署名しない発行物を手元の Maven リポジトリに作って artifact に置く)
                 └─ consumer-ios / consumer-android (mode: artifact)
                        └─ publish (dry-run のときは飛ばす。environment: release)
                               └─ wait-for-registries
                                      └─ smoke-ios / smoke-android (mode: published) ・ check-release
```

- validate: 入力の形 (Decision 1)・本番なら起動したブランチが `main`・両リポジトリの同じ名前の tag の状態 (Decision 4)・リリースノートの組み立て (Decision 6)
- 本番は `main` からだけ起動できる。dry-run はブランチを問わない。dry-run は publish 以降を飛ばし、外へ何も送らない
- 既定の権限は `contents: read`。publish のジョブだけが `contents: write` を持つ (Decision 9)

**理由:** 検証は検証 CI と同じ再利用 workflow を呼ぶので、`main` 宛ての Pull Request で通った検査と同じものが公開の前に流れる (cross/ADR-0014)。公開を 1 つのジョブにまとめると、取り消せる順の step を 1 か所で並べられ、secret を渡す範囲もそのジョブに限れる。

**代替案:**
- **A: tag の push で起動する** — cross/ADR-0022 で却下 (後の工程が失敗すると、iOS だけ先に公開された状態が残る)
- **B: `develop` から起動する** — cross/ADR-0022 で却下 (リリースの対象の commit が 1 つに定まらない)
- **C: 公開を検証 CI の入口 (`ci.yml`) に組み込む** — 却下。`ci.yml` は `develop` への push と `main` 宛ての Pull Request で走り、権限は読み取りだけと決めている。公開の権限と secret を持ち込むと、検証のたびに走る workflow に書き込みの経路ができる

### Decision 3: Maven Central への送信と公開

**採用案:** publish のジョブで、Android の発行物を署名して組み立て直し、`publishToMavenCentral` で保留のまま送る。送信の ID (deployment ID) を控え、Central Portal の Publisher API を直に呼ぶスクリプト (`scripts/release/central-portal.py`) で、検証の決着 (`VALIDATED` か `FAILED`) を待つ。`VALIDATED` なら公開を指示して `PUBLISHED` まで待ち、`FAILED` なら保留を取り下げて止まる。

- 署名して組み立て直した発行物は、`.asc` が揃っていることと、package-android の段の成果物と中身 (署名を除く) が同じであることを確かめてから送る
- 発行物の POM の `scm` に、元になった commit (起動した commit) を書く。公開済みの版がどの commit から作られたかを、後から照合できるようにする (Decision 4)
- 失敗の経路では、公開を指示する前なら保留の送信の取り下げを試みる。run の打ち切りでは後始末が走るとは限らないので、取り下げに頼らず、次の試行が状態を照会して扱う (Decision 4)
- 送信の ID の取り出し方 (プラグインの出力から読むか、API の一覧から探すか) と、`publishToMavenCentral` が検証の決着まで待つかどうかは、実装の最初に、プラグイン 0.37.0 のソースと Central Portal の公式の文書で確かめてから決める (tasks 1.1)

**理由:** 保留で送れば、公開の指示を出す前ならいつでも取り下げられる。workflow が止まったり打ち切られたりしても、失敗の経路で取り下げれば、何も公開されない状態に戻る。プラグインには保留の送信を後から公開するタスクが無いので、そこだけ API を直に呼ぶ。

**代替案:**
- **A: `publishAndReleaseToMavenCentral` で、送信と公開を一度に行う** — 却下。送った後は、検証が通れば workflow の状態に関わらず公開まで進む。送った後で workflow が止まると、Android だけ公開された状態を、取り下げで戻す道が無い
- **B: 発行物の組み立てと送信も、プラグインを使わずに API を直に呼ぶ** — 却下。署名と、送る束 (bundle) の組み立てをプラグインがすでに担っていて (変更 `package-distribution`)、作り直すことになる

### Decision 4: 再実行の形と、状態の引き継ぎ

**採用案:** 各工程は、同じ版でもう一度走らせても同じ結果になる形にする。やり直しは、GitHub Actions の「失敗したジョブの再実行」か、同じ版での新しい起動で行う。

| 工程 | 2 回目に走ったときの動き |
|---|---|
| 両リポジトリの tag の検査 | 同じ名前の tag が無ければ続ける。起動した commit (配信用リポジトリでは、その commit から作った写しの commit) を指していれば、再実行として続ける。別のものを指していれば止まる |
| 公開済みの検査 (validate) | Maven Central にその版が公開済みなら、公開済みの POM の `scm` に書かれた commit と、起動した commit を照らす。同じなら続け、違えば止まる |
| 写しの push | 写しに差分が無ければ commit を作らずに飛ばす |
| Maven Central | その版がすでに公開済みなら、送信と公開を飛ばす。前の試行の送信の控えがあれば、その送信の状態を照会する: 保留中 (`PENDING`・`VALIDATING`・`VALIDATED`) ならそれを使い、`PUBLISHING` なら送り直さずに公開済みを待ち、`FAILED`・見つからない (取り下げ済み) なら新しく送る |
| tag | すでにあり、上の検査を通っていれば作らずに飛ばす |
| Release | すでにあれば作らず、本文も書き換えない |

- 送信の ID の控えは artifact に置き、同じ run の再実行の試行へ引き継ぐ。控えは消さない (artifact を消すには公開のジョブに別の権限が要るため)。控えが古いかどうかは、照会した状態で決める
- 別の run に残った保留の送信 (打ち切られて後始末が走らなかったもの) は、控えが届かないので扱わない。手順の文書に、Central Portal で残った保留の送信を確かめて取り下げる手順を置く
- tag だけの照合では、Maven Central の公開の後・tag の前に失敗し、`main` が進んでから同じ版で起動し直すと、別の commit の iOS と tag が出せてしまう (相方の提案レビューの指摘)。公開済みの POM の commit の照合で、これを止める
- `workflow_dispatch` は commit を指して起動できない。公開の後で失敗した run を、`main` が進んだ後に続けるときは、その run の「失敗したジョブの再実行」を使う (元の commit のまま走る)
- 兄弟ライブラリ KsSettingsView と同じ形 (tag と commit の照合で再実行を許す) にする

**理由:** cross/ADR-0022 の「同じ版で再実行できる」を、工程ごとの形に落とす。取り消せない操作 (Maven Central の公開) の後に失敗しても、残りは再実行で揃う。送信の状態を照会して決めれば、後始末が走らなかった場合や、公開の指示の応答を受け取れなかった場合も、二重に送らずに済む。

**代替案:**
- **A: 再実行してよいかを、run に残す印で判定する (兄弟ライブラリの系列 KsDialogs の形)** — 却下。同じ版の新しい起動と、印を持たない再実行を止められ、より厳しい。しかし印を残して読む仕組みとその検査が増える。オーナーの指示で、KsSettingsView の形に揃える
- **B: 同じ版での再実行を禁止する** — cross/ADR-0022 で却下 (片側だけ公開された版が欠番として残る)
- **C: 失敗の後始末で控えを消し、再実行では控えの有無だけで決める** — 却下。控えを消すには公開のジョブに artifact の書き込みの権限が要る。打ち切りで後始末が走らないと、控えと実際の状態が食い違う

### Decision 5: secret の置き場と渡し方

**採用案:** secret は、Environment `release` に置く。この Environment は、deployment branch policy で `main` だけが使える。publish のジョブだけが Environment を指定し、secret は、使う step の環境変数にだけ渡す。

| secret | 使う step | 渡し方 |
|---|---|---|
| `SIGNING_KEY`・`SIGNING_KEY_ID`・`SIGNING_PASSWORD` | 署名して組み立て直す | `ORG_GRADLE_PROJECT_signingInMemoryKey`・`...KeyId`・`...KeyPassword` |
| `MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD` | 送信・API の呼び出し | `ORG_GRADLE_PROJECT_mavenCentralUsername`・`...Password` と、スクリプトの環境変数 |
| `SPM_DEPLOY_KEY` | 写しの push・配信用リポジトリの tag | ssh-agent に載せる (ファイルに書き出さない) |

- 鍵とパスフレーズは、どれもファイルに書き出さない。dry-run は publish を飛ばすので、secret を使わない
- secret の値は、オーナーが登録する (エージェントは値を扱わない)。初回の登録は、標準入力から流し、使ったファイルは `trash` で消す
- 署名の鍵と Central Portal の認証の情報を、兄弟ライブラリと共通のものにするか、本ライブラリ用に作るかは、オーナーが決める (Open Questions)

**理由:** Environment の branch policy で、`main` 以外から起動した workflow には secret が渡らない。使う step だけに渡せば、ほかの step の出力に値が混ざる経路が減る。

**代替案:**
- **A: リポジトリの secret に置く** — 却下。どのブランチから起動した workflow でも読めるので、`main` 以外からの公開を secret の側で止められない

### Decision 6: リリースノートの組み立て

**採用案:** `.github/pull_request_template.md` を足し、変更の節 `## Changes` の書き方を置く (行は `- breaking|feature|fix|docs: 説明`、利用者向けの変更が無ければ `- none` だけ。説明は英語で、利用者の言葉で書く)。

`scripts/release/build-release-notes.py` が、validate の段で 1 回だけノートを組み立て、artifact に置く。publish はそれを Release の本文に使い、Pull Request の本文を読み直さない。

- 範囲: 前回の Release (draft でない公開済みのもの) の tag のうち、`main` の first-parent で起動した commit の祖先にある最も近いものから、起動した commit までに `main` に入った Pull Request のすべて。前回の Release が無ければ、`main` の最初から
- 検査: 範囲の Pull Request のどれかに変更の節が無い、または読めない行があれば、どの Pull Request のどの行かを示して止まる
- 組み立て: 種類ごとに見出しを分けて並べる。すべてが `- none` なら、利用者向けの変更が無いことを 1 行で書く
- dry-run も、起動したのが `main` のときは収集と検査を行う。`main` 以外からの dry-run では、ノートを組み立てない

初回のリリースでは、範囲に #1・#2 が入る。この 2 本の本文に、変更の節 (`- none`) を書き足す (外向きの操作なので、オーナーの承認を得て `gh pr edit` で行う)。初回の内容は、リリースの Pull Request の変更の節に書く。

**理由:** cross/ADR-0023 の決定を形にする。初回の 2 本は、ひな形ができる前の Pull Request で、リリースの前のリポジトリの準備にあたり、利用者向けの変更は無い。

**代替案:**
- **A: 範囲の起点を、初回だけ設定で与える (#1・#2 を範囲から外す)** — 却下。一度きりの事情のために、起点を与える経路がずっと残る
- **B: 変更の節の無い Pull Request を飛ばす** — 却下。cross/ADR-0023 の「節は必須」と合わず、書き忘れと区別できない

### Decision 7: Release の作り方

**採用案:** publish の最後で、本リポジトリにだけ Release を作る。tag は版の文字列、題も版の文字列、本文は Decision 6 のノート。プレリリースの印は付けず、最新の Release として指定する。同じ名前の Release がすでにあれば作らない (cross/ADR-0024)。

公開の後の確認 (check-release) で、最新の Release を指す URL が今回の版を指すことを確かめる。

**理由:** README と Skill の確かめ先 (本リポジトリの Release の一覧) をそのまま確定にできる。プレリリースの印を付けると、プレリリースの版しか無い間は、どれも最新にならない。

**代替案:**
- **A: プレリリースの版にプレリリースの印を付ける** — cross/ADR-0024 で却下 (最新の Release を指す URL が見つからなくなる)

### Decision 8: 利用者役に、工程の成果物を受け取る切り替えを足す

**採用案:** 利用者役のスクリプトと再利用 workflow に、切り替え `artifact` を足す。workflow は入力 `artifact` (取り込む artifact の名前) を受け取り、取り込んだディレクトリをスクリプトに渡す。

- iOS: 取り込んだ写しのディレクトリを、`local` と同じくパスで参照する。写しは自分で作らない
- Android: 取り込んだ手元の Maven リポジトリだけを取得元にし、入力の版で依存する。発行は自分でしない
- `local` と `published` の参照の形は変えない (README の検査が `published` の行を比べる相手にしている)
- リリースの workflow は、公開の前に `artifact`、公開の後に `published` で呼ぶ。検証 CI は今のまま `local` で呼ぶ

**理由:** 公開の前に確かめたいのは、工程が実際に公開する成果物である。`local` は利用者役が自分で作り直すので、工程の組み立ての誤り (版の注入の漏れ・写しの入れ漏れ) を見逃す。

**代替案:**
- **A: リリースの workflow でも `local` を使う** — 却下。工程が公開するものとは別に作ったものを確かめることになる
- **B: 公開の後の確認だけにする** — 却下。公開の後に誤りが見つかっても取り消せない

### Decision 9: workflow の定義の検査に、公開のジョブの例外を足す

**採用案:** `scripts/ci/check-workflows.py` の権限の決まりを、「`contents: read` か `none` だけ。ただし `release.yml` の publish のジョブだけは `contents: write` を持ってよい」に改める。送信の控えの artifact は消さないので (Decision 4)、`actions: write` は要らない。ほかの決まり (commit の ID での指定・版を指定したランナー・時間の上限) は、`release.yml` にもそのまま掛ける。

あわせて、`scripts/ci/tests/test_workflow_files.py` に `release.yml` の検査を足す: 起動が手動だけであること・入力・`concurrency`・publish だけが Environment を指定すること・publish の step が取り消せる順 (写しの push → 保留の送信 → 決着の待ち → 公開 → 配信用リポジトリの tag → 本リポジトリの tag → Release) に並ぶこと。

**理由:** 書き込みの権限を許す範囲を 1 つのジョブに閉じ、検証 CI に書き込みの権限が入る余地を残さない。公開の順は cross/ADR-0022 の要なので、並べ替えたら落ちるテストで守る。

**代替案:**
- **A: `release.yml` を検査の対象から外す** — 却下。commit の ID での指定・ランナーの版・時間の上限の検査が、いちばん強い権限を持つ workflow に効かなくなる
- **B: すべての workflow に `contents: write` を許す** — 却下。検証 CI に書き込みの権限が入っても気付けない

### Decision 10: 公開を待つ時間の上限

**採用案:** 待つ処理は、上限を持つスクリプトにして、上限に達したら失敗で終える。上限は、検証の決着の待ちが 60 分、公開の指示から `PUBLISHED` までが 120 分、Maven Central の取得先に版が現れるまで (wait-for-registries) が 120 分。各ジョブの時間の上限は、そのジョブの待ちの上限の合計より長く取る。

**理由:** 兄弟ライブラリでは 30 分の上限が足りず、KsDialogs の初回は Central の同期に約 60 分かかった。その倍を取る。上限の判定を外しても止まらない誤りがあった (兄弟ライブラリの自己テストの監査) ので、上限に達したら失敗で終わることをスクリプトのテストで確かめる。

**代替案:**
- **A: 上限を 30 分にする** — 却下。兄弟ライブラリで足りなかった

### Decision 11: リリースの Skill

**採用案:** リリースの入口になる Skill を、`.agents/skills/release/SKILL.md` に置き、`.claude/skills/release` をそこへの相対のリンクにする。AGENTS.md に、リリースは頼まれたときに `release` で行う、の 1 行を足す。置き方は、変更 `user-skill-refresh-skill` の追従の Skill と同じ形にする。

- 手順の正は handbook の `kasane/handbook/cross/release-procedure.md` (蒸留で作る)。Skill は起動のたびにそれを先頭から読み、段の順序もコマンドも持たない
- Skill が自分で持つのは 3 つ: 変更の節の下書きの作り方 (範囲は、その Pull Request が `main` へ新しく持ち込む commit。利用者に見える変化だけを 1 項目 1 行で)、確認の境界 (版と下書きと事前の確認の結果を 1 回で確かめ、確定したら、Pull Request の作成とマージ・本番の起動・tag の作成まで止まらずに進める)、止まる条件 (失敗・手順に無い状況・確定した版や文面で進めないとき)
- 事前の確認: 手元の `develop` が先行していれば push して検証 CI の完了を待ち (兄弟ライブラリと同じ)、遅れている・分かれているときは止まる。`origin/develop` の先端 (対象の commit) の検証 CI が成功していることを確かめる。追従の Skill `docs-refresh` の「確かめるだけ」で、利用者向け Skill の追従が要るかを調べて確認の 1 回に添える。追従そのものはしない (追従はオーナーが頼むもの — cross/ADR-0017 と、それを置き換える提案中の cross/ADR-0020)
- 確定は対象の commit についての承認として扱う。マージは、リリースの Pull Request の先端が対象の commit と同じときだけ行い、確定の後に `develop` が進んでいたら止まる
- CI の完了は Skill が自分で見張る。自分からは起動しない

**理由:** 手順の文書だけでは、メインのセッションが手順にたどり着く保証が無い (変更 `user-skill-refresh-skill` の探索で分かったこと)。手順の正を handbook に置けば、手順を変えても Skill を直さずに済む (兄弟ライブラリの 0030)。

**代替案:**
- **A: handbook だけにし、Skill を置かない** — 却下。名前で呼べず、手順にたどり着く保証が無い
- **B: Skill の中に手順を持たせ、handbook に置かない** — 却下。兄弟ライブラリがオーナーの判断で却下した形で、手順の置き場が 2 つになる余地が残る

### Decision 12: 初回のリリースの進め方

**採用案:** 初回のリリースは、この変更の中で行う (オーナーの決定)。手順の handbook は蒸留で作るので、初回は change の中の草稿 `drafts/release-procedure.md` に従って行い、Skill は使わない。順序:

1. 実装を `develop` に入れ、検証 CI が緑になる
2. 準備の Pull Request (変更の節は `- none`) を `develop` から `main` へ出してマージし、リリースの workflow のファイルを既定のブランチに入れる (手動の起動に要る)
3. `develop` から dry-run を起動し、公開の直前までが通ることを確かめる。`develop` から本番を試し、最初のジョブで止まることも確かめる
4. 配信用リポジトリを作って設定し、Environment と deploy key を作る。オーナーが secret の値を登録する
5. README 2 枚の「まだ公開していない」の 1 文を外し、配信用 README のひな形をルートの README と照らす
6. #1・#2 の本文に変更の節 (`- none`) を書き足し、初回の内容を変更の節に書いたリリースの Pull Request を `develop` から `main` へ出してマージする
7. `main` から dry-run を起動し、ノートの組み立てまで通ることを確かめる
8. オーナーの承認を得て、`main` から版 `0.1.0-beta.1` で本番を起動し、公開の後の確認まで通す

外向きの操作 (配信用リポジトリの作成・GitHub の設定・Pull Request の本文の編集・マージ・本番の起動) は、それぞれの前にオーナーの承認を得る。

**理由:** Maven Central の検証の決着と同期の時間、tag を付けた写しを SwiftPM が解決できること、Release が最新に選ばれることは、本当に公開しないと確かめられない。この変更の中で通せば、見つかった問題をレビューと検証の流れの中で直せる。

**代替案:**
- **A: 初回のリリースを変更の外 (蒸留の後) に置く** — 却下 (オーナーの決定)。最初から正式な手順と Skill で行えるが、初回で見つかった問題を別の変更で直すことになる

### Decision 13: secret の検査の誤検出の扱い

**採用案:** gitleaks や GitHub の push の保護が、secret でない値 (テスト用の値など) を検出したら、まずその値を secret の形に見えない値に書き換える。書き換えられないとき (実物と同じ形が要るテストなど) だけ、その検出の指紋を `.gitleaksignore` に、理由を書いた行と一緒に足す。push の保護に止められたときは、値を書き換えてから push し直す。

**理由:** 除外が増えるほど、本物の secret を見落とす。除外を 1 件ずつ理由つきにすれば、後から見直せる。

**代替案:**
- **A: 検出されたものを、すべて除外に足す** — 却下。除外が増えるほど見落とす
- **B: gitleaks の規則そのものを緩める** — 却下。除外の範囲が、その 1 件より広くなる

## Risks / Trade-offs

- [Central Portal の挙動] 検証の決着と同期の時間、送信の ID の取り方は、実物でしか確かめられない → 実装の最初に公式の文書とプラグインのソースで確かめ (tasks 1.1)、dry-run と初回のリリースで確かめる。初回で失敗したら、直して同じ版で再実行する
- [取り消せない公開の後の失敗] Maven Central の公開の後、配信用リポジトリの tag の前に失敗すると、Android だけが公開された状態が残る → 残りは再実行で揃う (Decision 4)。再実行までの間、iOS の利用者はその版を解決できない
- [secret の管理] 6 つの secret が本リポジトリの Environment に置かれる → `main` だけに渡し、使う step だけに渡す。漏れたときの手順は handbook に置く (B3 の決定)
- [並行する変更] `user-skill-refresh-skill` と、AGENTS.md・Skill の置き場・`kasane/decisions/cross/index.md` が重なる → 置き方はあちらに揃え、AGENTS.md の追記は行を分ける。commit の前に ADR の番号の重なりを確かめる
- [外部の依存] 利用者役の確認は外部の依存の取得に頼る → 止まったら再実行して待つ (管理者も迂回しない)
- [別の run に残った保留の送信] 打ち切られて後始末が走らなかった run の保留の送信は、新しい run からは扱えない → 手順の文書に、Central Portal で確かめて取り下げる手順を置く
- [macOS のランナー] リリースのたびに macOS のジョブが 3 本走る → リリースは手動で起動するので、回数はオーナーが決める

## Migration Plan

- 配信用リポジトリは新しく作る。既存の利用者はいない
- 初回のリリースまでは、README の「まだ公開していない」の 1 文を残し、リリースの Pull Request で外す
- 公開した後に戻す手段は無い (Maven Central は取り消せない)。誤りが見つかったら、直した新しい版を出す

## Open Questions

- 署名の鍵と Central Portal の認証の情報を、兄弟ライブラリと共通のものにするか、本ライブラリ用に作るか (オーナーが決める。tasks の secret の登録の前まで)
- Central Portal の名前空間 `jp.kamusoft` が、本ライブラリの座標の公開に使える状態か (兄弟ライブラリの公開で確認済みと見込むが、本ライブラリでは確かめていない。tasks 1.1 で確かめる)

## ADR 候補

- Decision 1 → cross/ADR-0021 (proposed 済み): すべてのプラットフォームに 1 つの版を付け、本リポジトリと配信用リポジトリに同じ版の文字列の tag を付ける
- Decision 2・3・4 → cross/ADR-0022 (proposed 済み): リリースは版を入力して main から手動で起動し、取り消せる操作から公開して、tag と Release を最後に作る
- Decision 6 → cross/ADR-0023 (proposed 済み): リリースノートは、前回の Release からの main 宛ての Pull Request の本文にある変更の節から組み立てる
- Decision 7 → cross/ADR-0024 (proposed 済み): Release は本リポジトリにだけ作り、プレリリースの印を付けずに、最新の Release として示す
- ほかの Decision は、方向の中の形 (置き場・渡し方・上限の値・検査の例外) なので ADR にしない
