> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/branch-and-github-settings.md`
> - 追記は 8 個ある。それぞれの見出しに、追記先の節と、足すのか置き換えるのかを書いてある
> - 文書の中のリンクは、追記先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - **保護の更新 (tasks 9.3) と、`main` 宛ての Pull Request (tasks 9.2・9.4) は、この草稿を書いた時点ではまだ行っていない。** 追記先は「値を変えるときは、先にこの表を直す」と定めているが、この草稿の値は、まだ GitHub に入っていない値である。蒸留の前に、グループ 9 の証跡と突き合わせ、実行したコマンド・読み直した値に合わせて直す。草稿の案と違う形で実行したものは、実行したほうに直す
> - 実行の結果が要る箇所は `【公開の実施後に記入】` の印で空けてある。印のある箇所は 6 つある (追記 3 に 1・追記 5 に 1・追記 6 に 3・追記 7 に 1)
> - 追記 5 の payload は、追記先にある今の payload (2026-10-08 に実行して読み直したもの) の、必須の検査の配列に 2 つを足しただけの形である。足した形では、まだ実行していない
> - 追記先は「3 つの検査」と書いている箇所が多い。追記 1〜5 で直す箇所を挙げたが、蒸留のときに、文書の全体で「3 つ」を探して読み直す
> - `timestamp` は、保護の値を読み直して確かめた日にする

---

## 追記 1: 冒頭の段落の直し

「必須の検査の名前を 3 つに固定した理由は」を、次に置き換える。

> 必須の検査の名前を固定した理由は [cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md) にある。`main` 宛ての Pull Request で、配布物を利用者役でビルドして確かめ、必須の検査にした理由は [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) にある。

## 追記 2: 節「ブランチの役割」の表の `main` の行の置き換え

| ブランチ | 先端が表すもの | 入れ方 | 検証 CI |
|---|---|---|---|
| `main` | リリース候補。リポジトリの既定のブランチ | 同じリポジトリの `develop` からの Pull Request だけ | Pull Request で走り、5 つの検査が必須 |

`develop` の行は変えない。`develop` への push で走る検査は、今も 3 つである (利用者の立場のビルドの確認は、`develop` への push では走らない)。

## 追記 3: 節「main 宛ての Pull Request を作ってマージする」の直し

手順の 3 を、次に置き換える。

3. 5 つの必須の検査 (`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`) が成功で終わるのを待ち、マージできる状態を読む: `gh pr view <番号> --json mergeable,mergeStateStatus,isCrossRepository`

手順の下の段落の「変更したパスに関わらず 3 つの検査が走る」を、「変更したパスに関わらず 5 つの検査が走る」に置き換える。その段落の後ろに、次を足す。

> 5 つのうち、利用者の立場のビルドの確認の 2 つ (`consumer-ios / verify`・`consumer-android / verify`) は、`main` 宛ての Pull Request でだけ走る。`develop` の最新の検証 CI が成功していても、この 2 つは Pull Request を作って初めて結果が出る。配布物の形に関わる変更を含むときは、Pull Request を作る前に、手元で同じ確認を流しておく ([検証 CI](verification-ci.md) の「手元で確かめる」)。
>
> この 2 つは、外部の依存の取得 (Nuke・Maven の依存) に頼る。コードの誤りではない理由で止まったときは、実行をやり直す。やり直しても進まないときの手段は、下の管理者による迂回である。

必須の検査が 5 つになった後の最初の Pull Request の記録: 【公開の実施後に記入】 (tasks 9.2・9.4 の証跡から、番号・日付・5 つの検査の結果と所要時間・マージできる状態・マージの方法を書く)

## 追記 4: 節「保護の値」の表の「必須の検査」の行の置き換え

| 項目 | `main` | `develop` |
|---|---|---|
| 必須の検査 | `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`。GitHub Actions が出したものに限る | なし |

ほかの行は変えない。

## 追記 5: 節「入れ方と確かめ方」の小節「main の保護」の直し

payload の `required_status_checks.checks` を、次の 5 つにする。ほかの項目は変えない。PUT は部分の更新にならないので、検査を足すだけのときも、項目をすべて書いた payload を送る。

```bash
gh api -X PUT repos/kamusoft/KsCollectionView/branches/main/protection --input - <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "checks": [
      { "context": "lint", "app_id": 15368 },
      { "context": "ios / verify", "app_id": 15368 },
      { "context": "android / verify", "app_id": 15368 },
      { "context": "consumer-ios / verify", "app_id": 15368 },
      { "context": "consumer-android / verify", "app_id": 15368 }
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
```

確かめ方の表の 1 行目を、次に置き換える。

| 読む項目 | 期待する値 |
|---|---|
| `required_status_checks.checks` | 5 件。`context` が `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify`、`app_id` がどれも 15368 |

「結果 (2026-10-08)」の表の後ろに、次を足す。

結果 (必須の検査を 5 つにした更新): 【公開の実施後に記入】 (tasks 9.3 の証跡から、日付・実行したコマンド・終了コード・更新の前に読んだ値・更新の後に読み直した値を書く。必須の検査のほかの項目が、更新の前後で変わっていないことも書く)

## 追記 6: 節「設定を入れる順」の後ろに、節を 1 つ足す

## 必須の検査を足すとき

`main` の必須の検査を足すときは、検査が実際に報告されるのを見てから、保護に登録する。次の順で行う。GitHub への操作は、1 つずつオーナーの承認を得てから行い、実行したコマンドと読み直しの結果を証跡に残す。

| 順 | 行うこと | この順にする理由 |
|---|---|---|
| 1 | 検査を足した実装を `develop` に push し、検証 CI が成功することを確かめる。足した検査が push で走らない形なら、走らないことも確かめる | `develop` の検証が壊れたまま、`main` 宛ての Pull Request を作らない |
| 2 | `develop` から `main` 宛ての Pull Request を作り、足した検査が報告されることと、名前が決めたとおりであることを確かめる | 検査の名前は、実際に報告されて初めて確かめられる。この時点では、保護はまだ前の検査だけを必須にしているので、名前が違っていても Pull Request は止まらない |
| 3 | `main` の保護の必須の検査を更新し、読み直して確かめる。ほかの保護の値は変えない。`develop` の保護も読み直して、変わっていないことを確かめる | 名前が食い違ったまま登録すると、登録した名前の検査が報告されず、Pull Request をマージできなくなる |
| 4 | 足した検査を含めて、すべての必須の検査が成功した状態で、Pull Request を merge commit でマージする | 足した検査を通った内容だけが `main` に入る |

先に保護へ登録してから Pull Request を作る順にはしない。名前が食い違っていたとき、その Pull Request が止まる。

戻し方: 保護の必須の検査を、前の値で PUT し直す。必須の検査を外しても、検査そのものは走り続ける。

### 実施の結果 (利用者の立場のビルドの確認の 2 つを足したとき)

| 順 | 結果 |
|---|---|
| 1 (`develop` への push) | 【公開の実施後に記入】 (tasks 9.1 の証跡から。3 つの検査だけが走って成功したこと、利用者の立場のビルドの確認が走らなかったこと) |
| 2 (Pull Request で報告された名前) | 【公開の実施後に記入】 (tasks 9.2 の証跡から。5 つの検査の名前と結果) |
| 3・4 (保護の更新とマージ) | 【公開の実施後に記入】 (tasks 9.3・9.4 の証跡から。更新の前後の値は、上の「main の保護」の結果に書く) |

## 追記 7: 節「実施の記録」の直し

表の前の段落を、次に置き換える。

> 2026-10-08 の行の証跡は、`kasane/changes/archive/2026-10-08-public-repo-verify-ci/evidence/publication-log.md` にある。表の「証跡」の列には、その中の節の番号を書く。それより後の行は、証跡のファイルの場所から書く。

表に、次の行を足す。

| 行ったこと | 日付 | 証跡 |
|---|---|---|
| 利用者の立場のビルドの確認の 2 つを、`main` の必須の検査に足した (3 つから 5 つ) | 【公開の実施後に記入】 | `kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/【グループ 9 の証跡のファイル名】` |

## 追記 8: 節「関連」と出典に足す

節「関連」の「[検証 CI](verification-ci.md) — 3 つの検査の中身と、失敗したときの見方」を、次に置き換え、その下に 1 行足す。

- [検証 CI](verification-ci.md) — 5 つの検査の中身と、失敗したときの見方
- [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) — 配布物を利用者役でビルドして確かめ、必須の検査にする決定

出典の行の末尾に、次を足す。

```
/ kasane/changes/archive/【蒸留の日付】-package-distribution/design.md (Decision 8) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/【グループ 9 の証跡のファイル名】 (必須の検査を 5 つにした更新と読み直しの記録)
```
