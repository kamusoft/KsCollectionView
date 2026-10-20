# 調査: GitHub Actions と Release の挙動 (tasks 1.2)

調べた日: 2026-10-15 / 調べ方: 公式の文書 (docs.github.com・REST API の文書・gh のマニュアル) を読んだ。実物では確かめていない。

| 項目 | 結論 | 根拠 | 自信度 |
|---|---|---|---|
| `workflow_dispatch` の入力 | 型は boolean / choice / number / environment / string。`inputs.<名前>` は boolean を真偽値のまま保ち、`github.event.inputs.<名前>` は文字列 ("true") に変える | workflow-syntax・events-that-trigger-workflows | 高 |
| 入力名のハイフン | workflow_dispatch の節に命名の規則の記述は無い。action の metadata の input_id の規則 (英字か `_` で始まり、英数字・`-`・`_`) から使えると推測 | metadata-syntax | 中 |
| 手動の起動と既定のブランチ | 手動で起動できるのは、workflow のファイルが既定のブランチにあるときだけ。`gh workflow run --ref develop` は develop にある版の定義で走り、`GITHUB_SHA` はその ref の最後の commit | manually-run-a-workflow・gh_workflow_run | 高 (`--ref` の版は中〜高) |
| commit を指した起動 | REST・gh とも、ref は「branch か tag の名前」と定義。SHA を明示に禁止する文言は見つからない | rest/actions/workflows・gh_workflow_run | 中 |
| `concurrency` | 同じ group で走るのは 1 つまで。`cancel-in-progress: false` (既定) なら後のものは pending で待つ。pending は 1 つまでで、新しいものが来ると既存の pending は取り消される | workflow-syntax (concurrency) | 高 |
| Environment の deployment branch policy | 条件に合わない ref (`GITHUB_REF` で照合) からは、その environment を指定したジョブが失敗する。environment の secret は、保護の規則を満たした後でそのジョブにだけ渡る | deployments-and-environments・changelog 2021-02-17 | 高 (ジョブの失敗は changelog が根拠で中〜高) |
| Environment の REST | `PUT /repos/{owner}/{repo}/environments/{name}` の `deployment_branch_policy` に `protected_branches` と `custom_branch_policies` を逆の値で渡す (同じ値は 422、null は全ブランチ可)。ブランチの名前は `custom_branch_policies: true` にしてから `POST .../environments/{name}/deployment-branch-policies` (`name`・`type: branch`) で足す | rest/deployments/environments・branch-policies | 高 |
| reusable workflow と environment | 再利用 workflow を呼ぶジョブには `environment` を付けられない (呼ばれる側のジョブに付ける) | reuse-workflows | 高 |
| reusable workflow と権限 | 呼ばれる側は、呼ぶ側から渡った `GITHUB_TOKEN` の権限を下げられるだけで、上げられない | reusing-workflow-configurations | 高 |
| Release の latest | gh の `--latest` は既定で自動、`--latest=false` で最新にしない。REST の `make_latest` は true / false / legacy で、新しいものは既定で true。draft とプレリリースは latest にできない。`GET /releases/latest` はプレリリースでも draft でもない最新を返す。URL の `/releases/latest` については記述が無い | gh_release_create・rest/releases・linking-to-releases | 高 |
| Release と tag | tag が無いとき gh は既定のブランチの最新から tag を作る。`--target` で branch か完全な SHA を指定できる。`--verify-tag` で tag が無ければ中断する。tag が既にあれば target は使われない | gh_release_create・rest/releases | 高 |
| 同じ tag の Release が既にあるとき | gh・REST とも記述が無い (REST は 422 とだけ) | — | 確かめられなかった |
| artifact (v4) | 中身は変えられず、名前は一意。同じ名前は失敗し、`overwrite: true` なら作り直す。download-artifact は既定で今の run の artifact だけを読む | upload-artifact・download-artifact の README | 高 |
| 再実行と artifact | 失敗したジョブの再実行で前の試行の artifact が読めるか、試行をまたいだ名前の重なりは、公式の記述が無い (コミュニティの事例で `github.run_attempt` を名前に入れる例) | — | 低 (実物で確かめる) |
| 再実行の commit | 再実行は、最初の起動と同じ `GITHUB_SHA`・`GITHUB_REF`・起動者の権限で走る | re-run-workflows-and-jobs | 高 |

## 実装への影響

- 同じ tag の Release が既にあるときは、作る前に `gh release view <版>` で有無を確かめて飛ばす (失敗の挙動に頼らない)
- 送信の控えを試行をまたいで引き継ぐ artifact は、名前に試行の番号を入れて重なりを避け、読むときは同じ run の前の試行の artifact を探す。前の試行の artifact が読めるかは、dry-run と初回のリリースで確かめる
- Release は tag を先に作ってから `--verify-tag` で作り、tag の作り直しを gh に任せない
