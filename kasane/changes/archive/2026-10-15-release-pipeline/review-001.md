# レビュー結果: release-pipeline (001 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー

tasks 1〜7 の実装 (リリースの workflow・`scripts/release/` の道具 6 本・利用者役の `artifact` の切り替え・権限の例外・Pull Request のひな形・リリースの Skill・草稿 2 枚) は、デルタスペックの Requirement と Scenario を満たしており、Critical・Major は無い。公開の step の順・再実行の分岐 (公開済み・控えの状態ごとの扱い・取り下げの条件)・secret の渡し方は、workflow の条件式まで追って spec と design と deviation に合っていることを確かめた。指摘は、草稿の記述の 1 か所のずれ、iOS の写しが確かめた artifact と別に作り直されて push される点、tasks.md のチェックの付け漏れの Minor 3 件と、本番の前に手元で確かめておくとよいことの Suggestion 1 件である。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テストを実行するとき・テストを追加するとき)
- 検証 CI (`.github/workflows/`・`scripts/ci/` を触るとき) — 「workflow の定義の検査が読める書き方」「検査を足すときの注意」(名前と起動の条件・スクリプトと道具・ジョブと step) を節ごとに照合
- 配布物の形と作り方 (Android の公開の設定 `android/kscollectionview/build.gradle.kts` を触るとき)
- 利用者の立場のビルドの確認 (`scripts/ci/verify-consumer-*.py`・`.github/workflows/verify-consumer-*.yml`・`verification/` を触るとき)
- ブランチの運用と GitHub の設定 (リリースの手順の草稿が触れる `main` の運用の確認のため。草稿の中身の反映は蒸留の対象)

ロードしたスキル: ksn-review、kotlin-impl-skill (android の code-review)

## 確認した観点

**仕様充足**
- release-workflow: 起動 (手動だけ・入力 2 つ・本番は main だけ)、1 本ずつ流れる (`group: release`・`cancel-in-progress: false`)、公開の前の確認 (検証の再利用・package-ios / package-android・artifact を使う利用者役)、公開の順序 (写しの push → 保留の送信 → 決着の待ち → 公開 → 配信用リポジトリの tag → 本リポジトリの tag → Release)、同じ版での再実行の表 (公開済み・控えの PENDING / VALIDATING / VALIDATED / PUBLISHING / PUBLISHED / FAILED / 見つからない)、公開の後の確認、secret の渡し方。step の `if:` を状態ごとに追い、各 Scenario の経路で期待どおりに飛ぶ・止まることを確かめた (取り下げは公開の指示の前の失敗だけ・`wait-published` と `published` では取り下げない・公開済みのときは写しの push より前に POM の commit を照らす)
- release-notes: 範囲 (同じ版の Release を起点にしない)・節の読み方・各異常系・main 以外の dry-run で組み立てない・ノートは validate で 1 回だけ
- consumer-verification: iOS / Android の `artifact` (渡された写しを絶対パスで参照・渡されたリポジトリだけから取得・欠けたら始めない・ほかの切り替えで渡したら止める)、再利用 workflow の入力 `artifact` と取り込み前の検査、検証 CI の呼び方が `local` のまま
- verification-ci: `release.yml` の `publish` だけ `contents: write` を許す例外 (先頭・ほかのジョブ・ほかの権限・`write-all` は落ちる)、リリースの workflow の定義の検査 (tag の push を足す・step の順を入れ替える・ほかのジョブに環境を付けると落ちる)
- release-skill: 置き場 (実体 1 つと相対リンク)・頼まれたときだけ・手順の文書を読む / 無ければ止まる・事前の確認・確認は 1 回と先端の一致・下書きの範囲・止まる条件。AGENTS.md の行 (CLAUDE.md は AGENTS.md へのリンクなので両 CLI に届く)
- repository-publication・user-readme は tasks 9・10 の範囲で、今回の対象外
- tasks.md の虚偽チェック: 2〜7 の [x] はすべて実物がある。1.1・1.2 は済んでいるのに未チェック (指摘 3)
- 足場 (proposal・design・specs) は HEAD から変わっていない
- deviation.md の決定 3 行 (送信の決着を待たない・ID はログから読む・公開済みの照会先を 2 段にする) は実装に反映されている。蒸留送りの行は合意済みとして扱った (Upload の step のログの受け方が、handbook の「記録を後の step が読むなら包みをスクリプトにしてテストを付ける」と違う点も、蒸留送りの「`| tee` の決まりに…足すかを決める」の対象として指摘しない)

**テスト**
- `python3 scripts/ci/run-tests.py`: 実行 702 件 / 失敗 0 / スキップ 4 (スキップは `KS_GRADLE_TESTS=1` のときだけ流れる Gradle の実物のテスト。xcodebuild・gradlew はパッケージの制約で流していない)
- `scripts/ci/check-workflows.py`・`actionlint`・`scripts/ci/check-project-skills.py .`: 違反なし。`scripts/comment-policy-lint.py`: 禁止 0 件
- 追加した外部の action の commit の ID (`download-artifact` v8.0.2・`upload-artifact` v7.0.2) を `git ls-remote` で tag と照合し、一致した
- 各スクリプトのテストは、正常と異常の両方・上限で失敗で終わること (`wait_until` は遅い probe でも期限で止まる) を持つ。言い訳コメントでのスキップは無い

**設計品質**
- accepted ADR・handbook の規約との衝突は無い。cross/ADR-0021〜0024 は proposed で、実装はその方向どおり
- 入力は式を本文に埋めずに環境変数で渡している。deploy key は ssh-agent に標準入力から載せ、ホスト鍵は固定値と照らす (`StrictHostKeyChecking=yes`)。secret は使う step の `env` にだけ渡る (テストで step の集合まで固定)
- コメントは単独で読める (作業文書のパス・Decision 番号などの参照は無い)
- Kotlin (`build.gradle.kts`): 元の commit の形の検査は Provider の中で遅延して行い、無いときは `tag` を書かない。送信を止める条件を `buildList` にまとめた形は読みやすく、`-SNAPSHOT` の既存の止め方を壊していない。指摘なし
- エッジケース: 空の配信用リポジトリへの `ls-remote` (tag 無し扱い)・写しに差分が無い再実行・同じ版の Release がある再実行・API の一時的な誤りの扱い (待ちでは続け、認証の誤りではすぐ止まる)・公開の指示の応答を受け取れなかったときの状態の読み直し、を確かめた

## 指摘事項

### 🟡 Minor 草稿の「Wait for validation (上限)」の行が、workflow の後始末の動きと合わない

**該当箇所**: `drafts/release-procedure.md:554` (対応する workflow は `.github/workflows/release.yml:544-550`)
**問題点**: 草稿は、決着の待ちが上限に達したとき「送信は検証中のまま残ることがある / 再実行で、控えの送信の決着をもう一度待つ (送り直さない)」と書く。しかし workflow では、この失敗で `Publish deployment` は飛んでいて、`Extract deployment id` が ID を出しているので、後始末の `Drop pending deployment` が走る。`drop` は最大 10 分決着を待ってから取り下げるので、その間に決着すれば送信は取り下げられ、再実行は控えを「見つからない」と読んで新しく送る。送り直さないのは、後始末の 10 分の間にも決着しなかったときだけである。動き自体は spec (公開の指示の前の失敗では取り下げを試みる) どおりで、草稿の記述だけがずれている。初回のリリースはこの草稿に従うので、オーナーが再実行の結果を読み違える。
**推奨修正**: 行を「後始末が決着を最大 10 分待って取り下げる。取り下げられていれば再実行は新しく送る。後始末も上限に達したときだけ、送信が残り、再実行はその決着を待つ (送り直さない)」の趣旨に直す。

### 🟡 Minor iOS は、利用者役で確かめた artifact ではなく、公開のジョブで作り直した写しを push する

**該当箇所**: `.github/workflows/release.yml:384-395`
**問題点**: `consumer-ios` が確かめるのは `package-ios` が空のディレクトリに作った写し (artifact `spm-snapshot`) だが、`Push SPM snapshot` は、配信用リポジトリの作業コピーに `sync-spm-snapshot.py` をもう一度流して作った写しを push する。作業コピーへの同期は、前の版の中身を消してから写す別の経路を通る。同じ commit と同じ道具なので通常は同じ中身になるが、push する tree と確かめた写しの tree を照らす箇所が無い (`Check tags before tagging` の tree の照合は、配信用リポジトリの tag が既にあるときだけ走る)。design の Decision 8 の「公開の前に確かめたいのは、工程が実際に公開する成果物」に対し、Android は署名の前後の中身を照らしているのに、iOS だけ照合が欠けている。消し残しなどの差は、公開の後の `smoke-ios` まで見つからない。
**推奨修正**: `Push SPM snapshot` で `spm-snapshot` の artifact を取り込み、`git add --all` の後の `git write-tree` と、artifact のディレクトリの tree (`check-release-state.py` の `tree_of_directory` と同じ作り方) が一致することを確かめてから commit・push する (一致しなければ push せずに止まる)。照合はスクリプトに置いてテストを付ける。優先度は低い (同期の経路は `test_sync_spm_snapshot.py` が確かめている)。

### 🟡 Minor tasks 1.1・1.2 が、済んでいるのに未チェックのまま

**該当箇所**: `tasks.md:7-8`
**問題点**: 1.1 の結果は `evidence/research-central-portal.md` と deviation.md の 3 行、1.2 の結果は `evidence/research-github-actions.md` にあり、実装はその結果に沿っている。チェックが無いと、完了判定と蒸留で「外部の挙動を確かめずに実装した」と読める。1.3 (オーナーの確認) は未完で正しい。
**推奨修正**: 1.1・1.2 にチェックを付ける (残す理由があるなら、その理由を tasks.md か deviation.md に書く)。

### 🔵 Suggestion 公開のジョブの前半を、本番の前に手元で 1 度通しておく

**該当箇所**: `.github/workflows/release.yml:397-437` (`Build signed publication`・`Check signed publication`・`Upload to Maven Central`)、`drafts/release-procedure.md:634-635`
**問題点**: dry-run は `publish` を飛ばすので、署名した組み立て直し・別のランナーで作った発行物とのバイトの一致・パスフレーズつきの鍵での署名は、初回の本番 (tasks 10.9) で初めて動く。草稿の「確かめていないこと」に載っていて、失敗しても送る前に止まるので害は小さいが、そのときには写しが配信用リポジトリの `main` に tag なしで入っている。また、送るのは 3 回目の Gradle の起動 (`publishToMavenCentral`) の出力で、照らした `signed-maven` の中身と同じであることは、同じ作業ツリーで成果物が up-to-date であることに依っている。
**推奨修正**: tasks 10.9 の前に、手元で使い捨ての鍵を作り、別々の clone (別のパス) で `package-android` と `Build signed publication` と同じ Gradle のコマンドを流して `check-android-artifacts.py --reference … --signed …` を通す。結果を草稿の「確かめていないこと」に書き足す (使い捨ての鍵とその置き場は `trash` で消す)。

## アクションプラン

1. (Minor) `drafts/release-procedure.md:554` の「Wait for validation (上限)」の行を、後始末の取り下げの動きに合わせて直す — 初回のリリースが従う文書なので先に直す
2. (Minor) `tasks.md` の 1.1・1.2 にチェックを付ける
3. (Minor・低) `Push SPM snapshot` で、push する tree と確かめた artifact の tree を照らす (スクリプトとテストを足す)。今回で直さないなら、deviation.md か簡易起票に残す
4. (Suggestion) 本番の前に、署名した組み立て直しとバイトの一致を手元で 1 度通し、草稿に結果を書く
