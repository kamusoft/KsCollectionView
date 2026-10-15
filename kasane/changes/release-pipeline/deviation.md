# Deviation: release-pipeline

## tasks 1.1 の調査で決めた、design の Decision 3 の未決 (調査の結果は evidence/research-central-portal.md)

- Decision 3 (`publishToMavenCentral` が検証の決着を待つか): design では未決 → 待たないと確かめた (自動で公開しない設定では、送った直後に終わる)。決着の待ちは計画どおり `scripts/release/central-portal.py` が受け持つ。workflow は `mavenCentralAutomaticPublishing` を渡さず、渡していないことをリリースの workflow の定義の検査で確かめる。理由: 渡すと送った後に workflow と関わりなく公開まで進み、取り下げの道が消える (2026-10-15)
- Decision 3 (送信の ID の取り出し方): design では未決 → プラグインがビルドのログに出す 1 行 (`Uploaded bundle to Central Portal as USER_MANAGED, deployment id: <ID>`) から読む。読めなければ、送信の控えを残さずにそのジョブを失敗させ、ログに Central Portal で残った保留の送信を確かめて取り下げる手順を指す文を出す (手順は drafts/release-procedure.md)。一覧の API から探す形は採らない。理由: プラグインは ID をファイルに書かない。一覧の API は文書のページに載っておらず (OpenAPI の定義にだけある)、別の run の送信と取り違える余地がある (2026-10-15)
- Decision 4 (公開済みの検査の照会先): design では「Maven Central にその版が公開済みなら」とだけある → validate (secret を持たない) は repo1 の公開済みの POM の有無 (認証が要らない) で判定し、publish (secret を持つ) は送る前に Publisher API の `published` でもう一度判定する。publish で公開済みと分かったのに POM がまだ取れないときは、POM が取れるまで上限つきで待ってから commit を照らす。理由: validate には secret を渡さない (Decision 5)。repo1 への反映は公開の後に遅れることがあり、validate の判定だけでは、公開の直後の再実行で公開済みを見落とす (2026-10-15)

## 蒸留送り (実装の報告から)

- 蒸留時に反映: handbook — cross/consumer-build-check.md に、切り替え `artifact` (iOS は渡された写しを絶対パスで参照し、写しのディレクトリの名前は `KsCollectionView-SPM`。Android は渡されたリポジトリだけから渡した版を取る)・引数 `--snapshot` / `--repository` と、何も始めずに終わる条件・Gradle のプロパティ `ksCollectionViewMode` の値 `artifact`・再利用 workflow の入力 `artifact` と step の並び・artifact の中身の形・手元で `artifact` を流す手順と所要時間を足す
- 蒸留時に反映: handbook — cross/verification-ci.md に、外部の action に actions/download-artifact が加わったことを足す (一覧がある場合)
- 蒸留時に反映: handbook — cross/package-distribution.md (または新設するリリースの手順) に、Gradle のプロパティ `ksCollectionViewSourceCommit` (POM の scm の tag に書く・形の検査・無いときは Maven Central へ送れない)・発行物が同じ入力から同じバイトになる前提・手元で `KS_GRADLE_TESTS=1` を付けてスクリプトのテストを流す手順を足す
- 蒸留時に反映: handbook — cross/verification-ci.md の「手元で確かめる」の件数と所要時間を、実装の後の値に直す
- 蒸留時に反映: handbook — cross/verification-ci.md の構成の表に release.yml と Pull Request のひな形を、権限の節と「workflow の定義の検査が読める書き方」に公開のジョブの例外を、外部の action の一覧に upload-artifact を足し、「検査を足すときの注意」のリリースの workflow がまだ無い旨の行を直す。`| tee` の決まりに、ログをファイルに受けて終了コードを返す形を足すかを決める
- 蒸留時に反映: handbook — リリースの手順に、送信の Gradle のログの受け方・送信の控えの artifact の名前と型での取り込み・配信用リポジトリの既定のブランチが `main` である前提を書く
- 蒸留時に反映: handbook — drafts/release-procedure.md を cross/release-procedure.md に置き (初回で分かったことと所要時間を書き足してから)、cross の index に行を足す (適用のきっかけ: リリースの実施・`.agents/skills/release/`・`release.yml`・`scripts/release/` を触るとき)。散文が 10000 字の目安を超えるので、分けるかを反映のときに決める
- 蒸留時に反映: handbook — drafts/branch-and-github-settings.md の各節を cross/branch-and-github-settings.md に反映する (実施の記録の行は初回の後に埋める)

## 乖離 (オーナーの指示)

- release-skill「事前の確認」: spec では「対象の commit の検証 CI が成功していること。失敗・未完了のまま (待っても終わらない) なら止まる」→ 指示により、対象の commit に検証 CI の記録が無いとき (`develop` への push で検証 CI を起動しないパス (`kasane/**`・`.github/ISSUE_TEMPLATE/**`・`.github/CONTRIBUTING*.md`) だけを変えた commit が先端にあるとき) は、直近で検証 CI が成功した commit から対象の commit までの変更が、検証 CI を起動しないパスだけなら、その成功で代えて進む。それ以外の変更があれば止まる。理由: そのままでは蒸留や証跡の記録の直後のリリースが毎回止まる。代えた差分は lint だけが読むファイルで、リリースの Pull Request の必須の検査で必ず確かめられる (2026-10-15)

## 蒸留送り (修正サイクル 1 の報告から)

- 蒸留時に反映: handbook — cross/verification-ci.md「コマンドの出力を記録に残す」に、`-e` の下でログをファイルに受けて元の終了コードを返す形 (`|| status=$?`) を足す (上の「`| tee` の決まりに…足すかを決める」の行の具体化)
- 蒸留時に反映: handbook — リリースの手順に、`scripts/release/place-spm-snapshot.py` (確かめた写しを置く・2 回の tree の照合) と `scripts/release/check-ci-skipped-changes.py` (事前の確認で検証 CI の成功を代える判定) を書く (草稿には書いてある)
- 蒸留時に反映: handbook — リリースの手順へ移すとき、事前の確認の「run が無い」の読み直しを push した直後に限ると書き (Skill の文面と揃える)、artifact が実行の権限を保たないことの書き方を「失敗したとき」の表と「確かめていないこと」の表で揃える (review-003.md の Suggestion 2 件)
- 蒸留時に反映: handbook — リリースの手順の、GitHub の設定を変えた直後の確かめ方に「直後の読み直しで食い違ったら、少し (20 秒ほど) 待って読み直す」を足す (tasks 9.1 で、変更の直後の読み直しが古い値を返した。evidence/github-spm-repository-001.md)
- [付随修正] .agents/skills/release/SKILL.md・drafts/release-procedure.md: Pull Request の本文の変更の節の後ろに行を足すときは `## ` で始まる見出し (`## Notes` など) を置く (`###` などでは節が終わらない) の 1 文を足し、草稿のリリースの Pull Request の本文の例の末尾に `## Notes` を足した (見出しの水準は review-004 の指摘で明示した)。理由: 準備の Pull Request (tasks 10.2) を出す前に本文をリリースノートの組み立ての読み方で読むと、本文の末尾に付ける署名の行が変更の節の読めない行になり、リリースが validate で止まる形だった。Skill が Pull Request を作るときも同じ形になる (2026-10-15)
- 蒸留時に反映: handbook — cross/user-docs-writing.md の、README に「まだ公開していない」を書く旨の記述 (244 行あたり) を、初回のリリースの後の形 (公開済みとして書く。spec user-readme) に直す (review-004.md の確認で見つかった)
- [付随修正] drafts/release-procedure.md: secret の登録の段を書き直した。何行もある値 (`SIGNING_KEY`・`SPM_DEPLOY_KEY`) は `gh secret set` の問いに貼らずファイルか標準入力から流す (貼ったときに何が起きるかは確かめていない)・`SIGNING_KEY` は一時のファイルに書き出し、流すものそのものの 1 行目で秘密鍵か公開鍵かを見分けてから流す (review-006 の指摘で、正しいコマンドを打ち直すだけの確かめ方から改めた)・値は登録の後に読み直せないので登録の前の確かめが唯一の関門であること。理由: 初回の本番の試行 1 が、署名の段で `Could not read PGP secret key` で止まった。オーナーが確かめると、`gpg --armor --export` で書き出した公開鍵を登録していた (2026-10-15)
- 蒸留時に反映: handbook — リリースの手順の「確かめていないこと」の表を、初回の本番で確かめた結果 (evidence/github-release-run-001.md の試行 2) で書き直し、所要時間 (公開のジョブ約 9 分・決着の待ち約 30 秒・公開の待ち約 6 分 33 秒・取得先の待ち数秒) を書き足す。初回だけ行うことの段に、実施の記録 (2026-10-15) を書く
- 蒸留時に反映: handbook — リリースの手順の secret の登録の段を移すとき、`SIGNING_KEY` の登録を 1 行目が合うときだけ流す形 (`head -1 "$key_file" | grep -q 'BEGIN PGP PRIVATE KEY BLOCK' && gh secret set ... < "$key_file"`) にして、コードの塊をまとめて貼っても確かめで止まるようにし、`trash` した鍵のファイルはオーナーがゴミ箱から消すことを書き足す (review-007.md の Suggestion 2 件)
- 蒸留時に反映: handbook — リリースの手順に鍵の見出しの文字列を書くときは、前後の `-----` を外して書く (`BEGIN PGP PRIVATE KEY BLOCK`)。前後の `-----` 付きで書いた草稿とレビューの記録を、commit の前の secret の検査 (gitleaks の private-key の規則) が鍵として検出した。design の Decision 13 のとおり、除外に足さず書き換えた (2026-10-15)
