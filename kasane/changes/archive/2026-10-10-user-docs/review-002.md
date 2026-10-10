# レビュー結果: user-docs (002 回目)

**日付**: 2026-10-10
**判定**: APPROVED

## サマリー

前回 (`review-001.md`) と相方 (`second-opinion-code-001.md`) の指摘のうち、採用したものは、すべて直っている。Skill の文面は実物のコードと突き合わせ、検査の 2 本は作業用の写しで前回の再現の手順を流し直して、どれも違反として止まることを確かめた。
直したことで入った新しい問題は見つからなかった。残るのは、直しに追い付いていない証跡・草稿の記述 (Minor・優先度は低い) と、検査の拾い方の残りの隙間 (Suggestion) である。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always) — 直したスクリプトとテストのコメント
- `kasane/handbook/cross/verification-ci.md` — `scripts/ci/` を触った (検査のロジックはスクリプトに置きテストを付ける・標準のライブラリだけ)
- `kasane/handbook/cross/test-execution.md` — テストを足した・件数の報告
- `kasane/lessons/code-review.md` — L-001 (証跡の数値を自分で再現する)。L-002 は、動きの過程を持つ機能の変更が無いので当たらない

ロードしたスキル: ksn-review、kotlin-impl-skill (今回の直しに Kotlin のコードの変更は無い。Skill の文面の根拠として Kotlin の実物を読むのに使った)

## 確認した観点

自分で流したもの:

- `python3 scripts/ci/run-tests.py`: 実行 504 件 / 失敗 0 件 / スキップ 0 件 (実装側の申告と一致)
- `scripts/ci/check-skills.py .`: 違反なし (Skill 4 つ・Markdown 24 枚)
- `scripts/ci/check-readme-examples.py .`: 違反なし (最小コード例 4 つ・依存の宣言の行 12 行)
- `scripts/docs/check-api-coverage.py`: 漏れ 4 件 (iOS の `buildExpression`・`buildBlock` が英日に 1 件ずつ。渡された状態と一致)
- `scripts/docs/skills-refresh.py status`: 変わった源泉は利用者役の画面の 2 ファイルだけ。公開の宣言の増減は無い
- `scripts/comment-policy-lint.py`: 禁止 0 件
- Simulator・エミュレータ・実機は使っていない。テスト 4 系統と利用者の立場のビルドの確認は流し直していない (前回の後に変わったのは `scripts/` と Skill の文書だけ)

前回の指摘の直り (採用したもの):

| 指摘 | 確かめ方 | 結果 |
|---|---|---|
| (Major) iOS の Skill: 同じキーへの `KsTemplate` の二重の登録 | `skills/{en,ja}/kscollectionview-ios/references/basics.md:313` を `ios/Sources/KsCollectionView/KsTemplateRegistry.swift:9-18` と突き合わせた | 直っている。デバッグでも停止せず、後の登録を採用して警告を残す、と英日とも書いている |
| (Minor) 同じ表: 列数が 0 以下のリリースビルドのログ | `basics.md:307`・`:316` を読み、前文の「この動きと違う 2 つの行」が本当に 2 行だけかを、表の残りの行について実物で確かめた (未登録のテンプレート・重複した ID・グループの値・負の間隔・ページングのしきい値・先読みの幅・空のキーは、どれも `logger.warning` か `KsInvalidInput.report` を通る) | 直っている。前文と表が合っている |
| (Minor) インストール例の検査が、決めた形でない行の具体の版を通す | 作業用の写しで、前回の 4 つ (行末のコメント・Groovy・`api(...)`・複数行の `.package`) と、`.git` を足した URL・`from:` の指定・version catalog の `module = "…"` を足して流した | どれも終了コード 1。対応するテストが 6 件ある (`scripts/ci/tests/test_check_readme_examples.py:425-458`)。ほかのライブラリの行を巻き込まないテストもある |
| (Minor) Skill の検査が HTML のリンクを見ない | 写しで、`<a href>`・`<img src>`・一重の引用符・引用符なし・大文字と空白・タグを複数行に分けた形・字下げした行を流した | どれも違反として止まる。Skill の中へのリンクは通る。テストが 8 件ある (`scripts/ci/tests/test_check_skills.py:380-438`) |
| (Minor) Android の Skill の 3 か所 (自動スクロールの範囲・失敗した画像の試し直し・`KsLayout` のプロパティ) | `reorder.md:270`・`images.md:93`・`layout.md:59` を、`KsReorderController.kt:419`・`KsImageCache.kt:36-52`・`:98-101`・`KsLayout.kt:12-74` と突き合わせた | 3 か所とも実物と合っている。英日で数値と否定の向きが揃っている |
| (Minor→採用) iOS `basics.md:203` の「headers」の語 | 英日を並べて読んだ | 全体のヘッダーとフッター・グループの見出し・ページングの表示を、英日とも分けて書いている |
| (Suggestion) 索引の 2 枚の見出しの並びのテスト | `scripts/ci/tests/test_repository_files.py` の `SkillsIndexTest` | 足されている。見出しが 1 つ以下なら失敗する歯止めもある |
| (相方) `record` が index にだけ残った変更を見逃す | `scripts/docs/skills-refresh.py:194-203`・`:397-402` と、テスト 3 件 (`test_skills_refresh.py:430-462`) を読んだ | 直っている。テストは、作業ツリーと commit の比較が空であることを先に確かめてから `record` の失敗を見ている。対象の外の変更は妨げない |
| (相方) `status --diff` が無くなった源泉の本文を出さない | `skills-refresh.py:288-300`・`:363-373` と、テスト 2 件 (`:311-327`) | 直っている。commit していない削除と、commit した削除の両方を見ている |

降格・未解決とした指摘 (下限の値・Foundation の届き方・計測の値): 採否の理由に誤りは見つからなかった。下限の値と Foundation の件は、検収 (12.4) でオーナーに伝える、という扱いのままでよい。

そのほか:

- 仕様充足・足場の凍結: proposal・design・specs は、作業ツリーの差分に含まれない
- deviation.md: 蒸留送りの 4 行だけ。付随修正の行は無い。今回の直しに、記録の無い仕様の逸脱は見つからなかった
- tasks.md: 未完了は 9.4・9.5・12.4・12.5 で、渡された状態のとおり
- 設計・コードの品質: 足した拾い方は標準のライブラリだけ。`staged_paths` は読むだけの git の呼び出しで、失敗すれば理由を出して止まる。スクリプトの冒頭の説明が、足した動き (決めた形でない行・HTML の書き方・index にだけ残る変更・無くなった源泉の差分) に合わせて直されている。コメントは単独で読める
- 英日の一致: 直した 5 枚 (iOS `basics.md`・Android `reorder.md`・`images.md`・`layout.md`) は、機械の検査 (見出し・コードブロック) が通り、直した段落の地の文を並べて読んで、食い違いは見つからなかった
- ローカル絶対パス: 成果物に無い

## 指摘事項

### [🟡 Minor] 証跡・草稿・deviation.md の記述が、今回の直しに追い付いていない (優先度は低い)

**該当箇所**: `deviation.md:3`、`drafts/user-skill-refresh.md:129`・`:162`、`drafts/verification-ci-addition.md:8`・`:81`・`:91`、`evidence/local-completion.md:13`・`:22`
**問題点**: スクリプトのテストは、直しで 20 件増えて 504 件になった。deviation.md の蒸留送りの行は「本変更の後の件数 (484 件)」と書いたままで、handbook に置く草稿の 2 枚も 484 件のままである。蒸留がこの行のとおりに handbook を直すと、古い件数が入る。
草稿は、直しで増えた動きも載せていない。`drafts/verification-ci-addition.md:81` の「落ちたときの直し方」の表に、新しい違反の文面 (「本ライブラリの … に触れている行が、決めた形 … でない」) が無い。`drafts/user-skill-refresh.md:162` の `record` が止まる条件に、index にだけ残っている変更が無い。
**推奨修正**: 12.1 を流し直すとき (12.4 の後) に、件数を実測に合わせ、草稿の 2 か所に 1 行ずつ足す。deviation.md の行は、記録の主体が件数を直す。草稿は冒頭の囲みが「蒸留のときに確かめ直す」としているので、今すぐでなくてよい。

### [🔵 Suggestion] インストール例の検査: 座標を分けて書いた行は、今も通る

**該当箇所**: `scripts/ci/check-readme-examples.py:318-343`
**問題点**: 決めた形でない行を拾う条件は、行に Package URL か `group:artifact` の字面が含まれることである。写しで試すと、`implementation(group = "jp.kamusoft", name = "kscollectionview", version = "1.0.0")` と、文字列をつないだ `"jp.kamusoft:" + "kscollectionview:1.0.0"` は、決めた形の行の隣に足しても終了コード 0 だった。前回の 4 つの形は塞がれていて、残るのはわざわざ書かなければ現れない形なので、実害は小さい。
**推奨修正**: 急がない。塞がないなら、スクリプトの冒頭の説明に「座標の字面を含まない書き方 (group・name を分けた形) は拾わない」と 1 文を足す。

### [🔵 Suggestion] Skill の検査: `href`・`src` のほかの属性は見ない

**該当箇所**: `scripts/ci/check-skills.py:72-74`
**問題点**: 写しで試すと、`<img srcset="../../../../assets/a.png 2x">` と `<video poster="…">` は違反にならない。逆に、地の文に `href = "the link"` と書くと、リンクとして読まれて「リンクの先が無い」で止まる (コードとして書けば止まらない)。今の 24 枚に当たる行は無い。
**推奨修正**: 急がない。Skill に画像を足すことになったときに、`srcset`・`poster` を足すかを決める。

## アクションプラン

1. (Minor) 12.1 の流し直しのときに、証跡・草稿・deviation.md の件数を 504 件 (その時点の実測) に合わせ、草稿に新しい違反の文面と `record` の条件を足す
2. (Suggestion) 検査の残りの隙間 2 件は、塞ぐか、限界としてスクリプトの冒頭に書くかを、余裕があるときに決める
3. 未完了の 9.4・9.5・12.4・12.5 を予定どおり進める。検収では、前回から持ち越した 2 件 (Android の下限の値が未確認であること・Compose Foundation の届き方) と、iOS のコードが概念の文書 (テンプレートの二重の登録はデバッグで停止) から外れていることの起票を、オーナーに諮る
