# レビュー結果: public-repo-verify-ci (005 回目)

**日付**: 2026-10-08
**判定**: CHANGES_REQUESTED

## サマリー

`ios / verify` を「テストを実行せず、ビルドできることだけを確かめる」形にした変更は、deviation.md の 2026-10-08 の乖離の記述どおりで、workflow・テスト・草稿・証跡のあいだに食い違いは見つからなかった。ビルドの失敗を見逃す経路は無く、変えてはいけないもの (検査の名前・入力なしの `workflow_call`・ランナーと Xcode の版・権限・action の固定・時間の上限) も保たれている。ただし、出力を記録に残すスクリプト (`scripts/ci/run-logged.py`) とそのテストの削除が deviation.md に書かれておらず、design の Decision 3 が挙げる 6 本のうち 1 本が記録の無いまま消えている。コードの直しは要らないが、記録を足してから commit してほしいので、この 1 件を優先度の高い Minor として CHANGES_REQUESTED とする。

## 照合した規約

- ソースコメント規約 (always)
- テスト実行規約 (テストを実行するとき・テスト結果を報告するとき・テストを追加するとき)
- ksn-core の change-scope (足場の凍結・deviation = 合意済みの差分・付随修正の同梱条件)

ロードしたスキル: ksn-review (追加のレビュースキルは無し)
lessons: `kasane/lessons/code-review.md` の L-001 (証跡の計測値を自前で再現する) を適用した。L-002 (動きの過程) は対象外。

## 実行した確認

| 確認 | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 111 件 / 失敗 0 件 / スキップ 0 件 (証跡の 111 件と一致) |
| `python3 scripts/ci/check-workflows.py` | workflow 3 本、違反なし |
| `actionlint` | 指摘なし (終了コード 0) |
| `python3 scripts/local-path-lint.py` / `identity-lint.py` / `comment-policy-lint.py` | どれも違反なし (コメントの検査は対象 494 ファイル・禁止 0 件) |
| 件数の内訳 (133 → 111) | HEAD の 3 本のテストは 9・8・8 件、workflow のテストは 23 → 26 件 (5 件を外し 8 件を足した)。133 − 30 + 8 = 111 で、証跡の内訳と一致 |
| 最初の実行 (ID 37766512044) の読み取り | GitHub から読み取りだけで照らし合わせた。結論は失敗、対象は `e1c3d67`、`lint` 8 秒・`android / verify` 6 分 14 秒・`ios / verify` 13 分 10 秒、本体は 567 件のうち 1 件が失敗 (約 333 秒)、Sample は 37 件。`evidence/publication-log.md` の 7.4 の表と一致 |

`xcodebuild` は、パッケージの制約により流していない。L-001 に当たる計測値 (2 つのビルドの成否・所要時間・壊したときの終了コード 65) は自分では再現していない。代わりに、最初の実行の記録で、通常の検証のスキームのビルドが `KsCollectionViewSamples`・`KsCollectionViewSamplesTests`・`KsCollectionViewSamplesUITests` の 3 つのモジュールをコンパイルしていることを確かめた (証跡の「コンパイルされたモジュール」の記述と合う)。総称の行き先でのビルドがランナーの上で通るかは、証跡が「確かめていないこと」に挙げているとおり、次の push まで分からない。

## 確認した観点

**仕様充足 (基準は deviation.md の 2026-10-08 の乖離)**
- workflow が乖離の記述どおりか: `xcodebuild` の呼び出しは `build-for-testing` の 2 つだけで、Simulator を選ぶ step・件数の検査の step は無い。本体と本体のテスト、Sample のアプリと 2 つのテストのターゲットがビルドの対象になる (スキームの定義で確かめた)。やり残しは無い
- 本体のビルドが落ちても Sample のビルドが走るか: Sample の step の条件は `!cancelled() && steps.library.outcome != 'skipped'`。本体が失敗なら走り、本体まで進まなかった回 (Checkout や Xcode の選択の失敗) では走らない。失敗した step があればジョブは失敗で終わる (最初の実行で、同じ形の条件のもとでジョブが失敗で終わったことを確かめた)
- ビルドの失敗を見逃す経路: `continue-on-error` は無い。2 つの step は `xcodebuild` を 1 つだけ直に呼び、パイプ・`;`・`&&` でつないでいない。`shell:` や `defaults:` の上書きも無い。入口の workflow の `ios` のジョブは `name` と `uses` だけで、条件や失敗の見逃しを持たない
- 変えてはいけないもの: ジョブの名前 `verify` と検査の名前 `ios / verify`、入力なしの `workflow_call`、`runs-on: xcode-27`、`KS_XCODE_VERSION: "27.0"` と版の確認の 2 つの step、`permissions: contents: read`、`actions/checkout` の commit の ID での固定と `persist-credentials: false`、`timeout-minutes: 40` はどれも HEAD のまま
- 消したスクリプトへの参照: workflow・スクリプト・テスト・草稿 4 枚・README に残っていない (残るのは過去のレビューと verify の記録、証跡の中の変える前の記述だけ)。草稿の「検査を足すときの注意」の `run-logged.py` を使う行も、スクリプトに頼らない書き方に直っている
- Android と lint への影響: `verify-android.yml`・`check-workflows.py`・`run-tests.py`・`ci_report.py`・Android のテストに差分は無い。Android の step の名前 `Test library` は Android のもので、消した iOS の step とは別。lint の step の一覧も変わっていない
- 足場の凍結: proposal・design・specs・tasks に差分は無い
- deviation に記録の無い逸脱: 1 件あり (下の指摘)
- 付随修正 2 件: 今回の変更で中身は変わっていない (前回までに確認済み)

**テスト**
- 全テストが成功 (111 件)。スキップ 0
- 新しい iOS の workflow のテスト 8 件が、step の一覧・テストを実行しないこと・総称の行き先・ビルドの対象 (パッケージのテストのターゲットと、Sample のスキームの中身)・Sample の step の条件・失敗の見逃しが無いことを確かめている。言い訳のコメントでの実質のスキップは無い
- テストの届かない範囲: 下の Suggestion 1 件

**設計品質**
- accepted の ADR・handbook の規約への抵触: 無い。cross/ADR-0013 は proposed で、今の実装とは食い違うが、deviation の「蒸留時に反映」の行と草稿の冒頭の注記で扱われている
- オーバーエンジニアリング: 無い。呼ぶ所の無くなったスクリプトを残さず、workflow は前より短い
- コメント: workflow と入口の workflow のコメントは現在形で、単独で読める。作業文書のパスや通番への参照は無い (機械の検査も 0 件)
- 権限・機密: 変化なし

**草稿・証跡と実物の一致**
- `drafts/verification-ci.md`: 走らせる範囲・緑の意味の表・件数の表・失敗したときの見方・手元のコマンド・届かない範囲の表・検査を足すときの注意が、実物の workflow とテストに合っている。スクリプトのテストの件数 (111) も合う
- `drafts/test-execution-addition.md`: 追記 2 と追記 4 が新しい形に合っている
- `evidence/ci-local-verification.md`・`evidence/publication-log.md`: 自分で流せた範囲と、GitHub から読めた範囲で一致。細部の指摘は下の Minor と Suggestion

## 指摘事項

### [🟡 Minor・優先度高] 出力を記録に残すスクリプトの削除が deviation.md に記録されていない

**該当箇所**: `deviation.md:6` / `scripts/ci/run-logged.py` と `scripts/ci/tests/test_run_logged.py` (削除) / `design.md:88` / `tasks.md:23`

**問題点**: deviation.md の乖離の行が取り除くと書いているのは、「使う Simulator を選ぶスクリプト」と「iOS のテストの実行件数を確かめるスクリプト」の 2 本である。実際には、コマンドを流して出力を記録に残すスクリプトと、そのテスト 8 件も消えている。このスクリプトは design の Decision 3 が挙げる 6 本の 1 つで、tasks の 3.6 が作ったものである。関わる挙動は「記録を残す処理に隠れて、流したコマンドの失敗が成功に見えることを防ぐ」で、今の iOS の step は `xcodebuild` を直に呼ぶので、この包みは要らなくなった (Android は元から使っていない)。削除そのものは筋が通っていて、草稿の「検査を足すときの注意」も、記録が要るようになったら包みをスクリプトにしてテストを付ける、という形に直してある。足りないのは記録だけである。記録の無い乖離は合意済みの差分として扱えず、蒸留と verify が design の 6 本と実物の 3 本の差を説明できなくなる。

**推奨修正**: コードは変えない。指揮側が deviation.md の `deviation.md:6` の行 (または別の行) に、出力を記録に残すスクリプトとそのテストも取り除いたことと理由 (呼ぶ所が無くなった。iOS の step は `xcodebuild` を直に呼び、合否は終了コードで決まる) を足す。残すと判断するなら、スクリプトとテストを戻し、草稿の該当の行を元に合わせる。

### [🟡 Minor・優先度低] 草稿の冒頭の注記が、ランナーでの実行は 1 度も無いと書いたままである

**該当箇所**: `drafts/verification-ci.md:6`

**問題点**: 蒸留の担当に向けた注記が「GitHub のランナーの上での実行は、この草稿を書いた時点でまだ 1 度も無い」のままで、今回足した `drafts/verification-ci.md:9` の注記 (最初の実行の後に形が変わった) と、本文の「`develop` での最初の実行で…落ちた」と並ぶと食い違って読める。関わるのは、蒸留のときに、草稿のどこまでがランナーの実測に基づくかの読み取りである。

**推奨修正**: 注記を今の状態に合わせる (最初の実行は 1 度あり、その結果は `evidence/publication-log.md` の 7.4 にある。ビルドだけにした後の形は、ランナーの上でまだ流していない)。

### [🔵 Suggestion] 「テストを実行しない」のテストは、ビルドの後ろに足した実行の指定を見つけられない

**該当箇所**: `scripts/ci/tests/test_workflow_files.py:203`

**問題点**: 確かめているのは、`xcodebuild` の直後の語が `build-for-testing` であることと、`test-without-building`・`swift test` が無いことである。`xcodebuild build-for-testing … test` のように、同じ呼び出しの後ろに実行の指定を足した形は通る。今の workflow にその形は無く、足すには意図した編集が要るので、実害は無い。

**推奨修正**: 余力があれば、2 つの step のコマンドを語の列として突き合わせる (決めた引数だけであること) か、`xcodebuild` の引数に単独の `test` が無いことを足す。見送ってよい。

### [🔵 Suggestion] 最初の実行の記録の、Xcode の置き場の名前

**該当箇所**: `evidence/publication-log.md:96`

**問題点**: 「置き場の名前は `Xcode_27.app`」とある。実行の記録では、Select Xcode が選んだ名前は `Xcode_27.0.0.app` で (`DEVELOPER_DIR` の表示)、ビルドの記録に出る実体の場所が `Xcode_27.app` である。workflow の探し方は `Xcode_27.0*.app` なので、`Xcode_27.app` だけを読むと「この名前では選べないはず」と読める。草稿の `【公開の実施後に記入】` を埋めるときに、版を上げる手順の説明に関わる。

**推奨修正**: 選ばれた名前 (`Xcode_27.0.0.app`) と、実体の場所 (`Xcode_27.app`) の両方を書く。

## アクションプラン

1. (指揮側) deviation.md に、出力を記録に残すスクリプトとそのテストの削除を記録する。コードの変更は要らない
2. (任意) 草稿の冒頭の注記を今の状態に合わせる
3. (任意) 証跡の Xcode の置き場の名前を補う
4. (任意・見送り可) 「テストを実行しない」のテストを、後ろに足した実行の指定も見つけられる形にする

1 が済めば、ほかに APPROVED を妨げるものは無い。
