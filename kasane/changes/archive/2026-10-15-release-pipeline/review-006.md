# レビュー結果: release-pipeline (006 回目)

**日付**: 2026-10-15
**判定**: CHANGES_REQUESTED

## サマリー

初回の本番の途中で手順の草稿の「5. secret を登録する」に足した文と、deviation のその付随修正の行を見た。秘密鍵と公開鍵の見分け方 (1 行目)・止まり方 (`Could not read PGP secret key`)・何行もある値を標準入力から流すことは、経緯 (evidence/github-release-run-001.md)・同じ段のコマンドの例・release.yml の渡し方と食い違っていない。ただし、足した確かめ方 (`gpg --armor --export-secret-keys <鍵の ID> | head -1`) は、流すのと同じ正しいコマンドを走らせ直すだけで、実際に流す値を確かめていない。今回の取り違え (別のコマンドで書き出した公開鍵を登録した) を確かめ方では見つけられず、確かめたつもりにさせる。再発を防ぐための文の中心なので、優先度の高い Minor として直しを求める。

## 照合した規約

- [ブランチの運用と GitHub の設定](../../handbook/cross/branch-and-github-settings.md) (適用のきっかけ: GitHub のリポジトリの設定を変える / 確かめ直す手順の文面。草稿は蒸留でこの文書の横に入る)
- [ソースコメント規約](../../handbook/cross/comment-policy.md) (always。直しは文面だけでソースのコメントに触れないので、当てはまる箇所は無い)

ロードしたスキル: ksn-review (パッケージの指定どおり。レビューで読むスキルはなし)

## 確認した観点

**経緯との一致**
- `drafts/release-procedure.md:168` の「公開鍵を登録すると、署名の段 (`Build signed publication`) が `Could not read PGP secret key` で止まる」は、evidence/github-release-run-001.md の試行 1 の step の表 (`Build signed publication` が failure) と Gradle の出力 (`signMavenPublication` の `Could not read PGP secret key`) に合う
- 原因の書き方 (`gpg --armor --export` が出す公開鍵、1 行目が `BEGIN PGP PUBLIC KEY BLOCK`) は、証跡の「原因 (オーナーが確かめた)」と、試行 2 の承認の記録 (秘密鍵の 1 行目が `BEGIN PGP PRIVATE KEY BLOCK`) に合う
- 日付の付け方 (「初回の本番の試行 1。2026-10-15」) は、同じ段の `drafts/release-procedure.md:180` の手元の通しの記録と同じ形

**草稿のほかの段との一致**
- 何行もある値として挙げた 2 つ (`SIGNING_KEY`・`SPM_DEPLOY_KEY`) は、コマンドの例 (`drafts/release-procedure.md:171` のパイプ・`:176` のリダイレクト) でどちらも標準入力から流しており、問いを使う 4 つ (`SIGNING_KEY_ID`・`SIGNING_PASSWORD`・`MAVEN_CENTRAL_USERNAME`・`MAVEN_CENTRAL_PASSWORD`) は 1 行の値。文と例が合う
- secret の表 (`drafts/release-procedure.md:74`「署名に使う GPG の秘密鍵 (ASCII armor の形で書き出したもの)」) と、足した文の「秘密鍵 (`--export-secret-keys`)」が合う
- 段の頭の「値は標準入力から流すか、`gh secret set` の問いに貼り付ける」と、直後の「何行もある値は貼り付けず、必ず標準入力から流す」は、1 行の値なら問いでよい、という読みで矛盾しない
- `--body` を使わない・ファイルは `trash` で消す、の既存の文は変わっていない

**release.yml の渡し方との一致**
- `SIGNING_KEY` は `ORG_GRADLE_PROJECT_signingInMemoryKey` として署名の 2 つの step に渡る (`.github/workflows/release.yml:413`・`:438`)。メモリ上の鍵として ASCII armor の秘密鍵を読む形で、「秘密鍵を入れる」と合う
- `SPM_DEPLOY_KEY` は `printf '%s\n' "${SPM_DEPLOY_KEY}" | ssh-add -` で載せる (`.github/workflows/release.yml:394`・`:520`)。ファイルから標準入力で流した値で、試行 1 で `Identity added: (stdin)` になった (証跡)。何行もある値を標準入力から流す、と合う

**deviation の付随修正の行**
- `deviation.md:33` は行の形 (`[付随修正] <箇所>: <何を直したか>。理由: <一言> (日付)`) に合う
- 同梱条件: ① 本務の成果物 (手順の草稿) の中 ② 公開 API・スキーマ・ADR に触れない ③ 1 ファイルの 1 段落 ④ 文面だけで、テストの対象が無い (既存の検査は通る) ⑤ ユーザーの選択を要する分岐が無い。収まっている
- 足場 (proposal・design・specs) は未 commit の変更に含まれていない

**検査**
- `scripts/local-path-lint.py`・`scripts/comment-policy-lint.py`: 終了コード 0

## 指摘事項

### 🟡 Minor (優先度高) 登録の前の確かめ方が、流す値ではなく正しいコマンドの出力を確かめている

**該当箇所**: `kasane/changes/release-pipeline/drafts/release-procedure.md:168`
**問題点**: 「登録の前に `gpg --armor --export-secret-keys <鍵の ID> | head -1` で 1 行目を確かめる」は、コマンドの例 (`:171`) と同じ正しい書き出しをもう一度走らせるだけで、`gh secret set` に実際に流すものを確かめていない。例のとおりのパイプで登録するならこの確かめは要らず、例と違う流し方 (別に書き出したファイル・別のコマンドの出力) をしたときには、確かめが `PRIVATE` を示しても登録したものは公開鍵のまま、ということが起きる。今回の取り違えは、まさに例と違う書き出し (`gpg --armor --export`) の出力を登録した形 (evidence/github-release-run-001.md の「原因」、lessons/inbox/guide-secret-registration-with-one-command.md の経緯) で、足した確かめ方ではこれを見つけられない。オーナーは「確かめた」と思って先へ進むので、取り違えない書き方になっていない。確かめが見つけられるのは、その鍵の ID に秘密鍵が無いとき (出力が空) だけである。
**推奨修正**: 確かめる対象を「流すものそのもの」にする。たとえば「登録する前に、流すものの 1 行目が `BEGIN PGP PRIVATE KEY BLOCK` であることを確かめる。例のパイプで流すときは、`gh secret set …` の代わりに `head -1` に流して確かめてから同じコマンドで登録する。ファイルから流すときは `head -1 <ファイル>` で確かめる。`PUBLIC KEY BLOCK` なら公開鍵なので登録しない」のように、期待する 1 行目と、違ったときにどうするかを同じ文に書く。

### 🔵 Suggestion 問いに貼ったときの結果の書き方の根拠が記録に無い・結果を軽く書いている

**該当箇所**: `kasane/changes/release-pipeline/drafts/release-procedure.md:168`・`kasane/changes/release-pipeline/deviation.md:33`
**問題点**: 「問いは 1 行しか受け取らない」「問いに貼ると最初の 1 行だけが登録される」は、今回の証跡では観測されていない (試行 1 の原因は公開鍵で、貼り付けの記録は無い)。deviation の理由も公開鍵の件だけを挙げており、何行もある値の文が何に基づくか (gh の問いの挙動の知識か、オーナーの操作の観測か) が読めない。また、gh の問いは改行で入力を終えるので、貼った残りの行は gh の終了後に端末からシェルへ入力として渡り、コマンドとして走ってシェルの履歴に鍵の一部が残るおそれがある (このレビューでは実物で確かめていない)。「最初の 1 行だけが登録される」だけでは、失敗が止まるところ (署名の段) で済むように読め、秘密の値が手元に残る害が伝わらない。
**推奨修正**: deviation の行の理由に、何行もある値の文の根拠を一言足す (実物で確かめていないなら「gh の問いの挙動から。今回は観測していない」)。草稿の文は「残りの行がシェルに入り、履歴に残るおそれがある」まで書くか、確かめていない結果を書かずに「貼り付けない」の指示だけにする。

### 🔵 Suggestion 1 段落に詰めすぎていて、取り違えの見分け方が埋もれる

**該当箇所**: `kasane/changes/release-pipeline/drafts/release-procedure.md:168`
**問題点**: 1 段落に、流し方の一般則・何行もある値の扱い・秘密鍵と公開鍵の違い・止まり方・経緯・確かめ方・`--body` を使わない・`trash` の 8 つが続く。オーナーが登録の直前に読み返すとき、見分け方 (1 行目の `PRIVATE` / `PUBLIC`) が段落の中ほどに埋もれる。lessons/inbox の捕捉 (guide-secret-registration-with-one-command.md) も、どちらを入れるかと見分け方を同じ表に置くことを挙げている (まだ昇格していないので規則ではない)。
**推奨修正**: 「入れるもの / 入れてはいけないもの / 1 行目 / 取り違えたときの止まり方」を小さな表にするか、箇条に分ける。あわせて「確かめ方」(`drafts/release-procedure.md:182` 付近) に、値の形は登録の後に読めないので登録の前の確かめが唯一の関門であること、本番の起動の前にオーナーがそれを済ませたかを確かめることを 1 文足すと、名前の一覧だけで本番に進んだ今回の流れも塞げる。

## アクションプラン

1. (Minor・優先度高) 登録の前の確かめ方を、流すものそのものの 1 行目を確かめる形にし、期待する値と違ったときの扱いを書く
2. (Suggestion) deviation の付随修正の理由に、何行もある値の文の根拠を足し、草稿の結果の書き方を直すか指示だけにする
3. (Suggestion) 段落を表か箇条に分け、確かめ方に「登録の前の確かめが唯一の関門」の 1 文を足す
