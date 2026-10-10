# Verify 001: user-docs

- 日付: 2026-10-10
- 対象: commit していない作業ツリーの今の状態 (`develop` の `a064aca` に、本変更の未 commit の差分と、追跡していない新しいファイルが載った状態)。別の変更 `android-sample-status-bar-contrast` は見ていない
- 突き合わせた契約: デルタスペック 5 枚 (`specs/user-skills/spec.md`・`specs/user-readme/spec.md`・`specs/user-docs-consistency/spec.md`・`specs/user-docs-refresh/spec.md`・`specs/consumer-verification/spec.md`)
- 判定: **VALID (後で確かめるもの 2 件を残す)**

## 判定の要約

| 区分 | 件数 |
|---|---:|
| Scenario の総数 | 103 |
| ✅ 一致 | 101 |
| ⚠️ 合意済みの乖離 (deviation 記録済み) | 0 |
| ⏳ 後で確かめるもの (タスクの完了を待っている) | 2 |
| ❌ 乖離 | 0 |

- 乖離 (実装が spec と違うもの) は無い。虚偽のチェック・足場の逆流・テストの失敗も無い
- 後で確かめるもの 2 件は、未完了のタスク (9.4・9.5 と 12.5) の完了を待っている。実装が spec と違うのではなく、まだ行えない / 決まっていない段階にある。**この 2 件は、タスクが終わった後に確かめ直す必要がある** (蒸留の前の最後の verify で、✅ になっていることを確かめる)
- Side Effects の逆向きの検査 (Requirement ごとの行) は、すべて列挙に収まっている

## 自分で流した確認

| 確認 | コマンド | 結果 |
|---|---|---|
| スクリプトのテスト | `python3 scripts/ci/run-tests.py` | 実行 504 件 / 失敗 0 件 / スキップ 0 件。終了コード 0 |
| Skill 自身の整合の検査 | `python3 scripts/ci/check-skills.py .` | 違反なし (Skill 4 つ・Markdown 24 枚)。終了コード 0 |
| README の例の検査 | `python3 scripts/ci/check-readme-examples.py .` | 違反なし (一致した最小コード例 4 つ・確かめた依存の宣言の行 12 行)。終了コード 0 |
| 公開の宣言の名前の網羅 | `python3 scripts/docs/check-api-coverage.py` | 漏れ 4 件 (iOS の `buildExpression`・`buildBlock` が、英語版と日本語版に 1 件ずつ)。Android は 0 件。終了コード 1 |
| 変わった源泉の一覧 | `python3 scripts/docs/skills-refresh.py status` | 記録の commit は `a064aca…`。変わった源泉 2 件 (利用者役の画面の 2 つのファイルが「足された」)。公開の宣言の増減は無い。終了コード 0 |
| 片方の言語だけ見出しを足した写し | スクラッチに `skills/` を写し、日本語版の iOS の `references/paging.md` に見出しを 1 つ足して `check-skills.py` を流した (写しは確かめた後に消した) | 違反 1 件 (見出しの深さの並びが、英語版と日本語版で違う)。終了コード 1 |
| 作業ツリーが変わっていないこと | 上の確認の前後の `git status --short` | 一致 |

Simulator・エミュレータ・実機は使っていない。利用者の立場のビルドの確認とテスト 4 系統は流しておらず、証跡 (`evidence/local-completion.md`・`evidence/consumer-screen-source.md`) で確かめた。証跡を取った後に変わったのは `scripts/` と `skills/` の文書だけで、`verification/`・`README.md`・`README_ja.md`・`assets/`・本体のソースは変わっていない (ファイルの更新の時刻で確かめた)。

## 対応表

テストの置き場は `scripts/ci/tests/`。表では、ファイルの名前を次のように縮める。

| 略 | ファイル |
|---|---|
| T-repo | `scripts/ci/tests/test_repository_files.py` |
| T-readme | `scripts/ci/tests/test_check_readme_examples.py` |
| T-skills | `scripts/ci/tests/test_check_skills.py` |
| T-refresh | `scripts/ci/tests/test_skills_refresh.py` |
| T-api | `scripts/ci/tests/test_check_api_coverage.py` |
| T-ios | `scripts/ci/tests/test_verify_consumer_ios.py` |
| T-android | `scripts/ci/tests/test_verify_consumer_android.py` |

状態の記号: ✅ 一致 / ⚠️ deviation 記録済み / ⏳ 後で確かめるもの / ❌ 乖離。

### specs/user-skills/spec.md (19 Scenario: ✅ 18・⏳ 1)

| Requirement / Scenario | 実装 | テスト・証跡 | 状態 |
|---|---|---|---|
| 利用者向け Skill の構成 / 4 つのディレクトリが同じ 6 枚を持つ | `skills/{en,ja}/kscollectionview-{ios,android}/` (どれも `SKILL.md` と `references/` の 5 枚だけ。ファイルの一覧を自分で比べた) | T-skills `test_片方の言語にだけファイルがあると失敗する`、T-repo `test_Skill自身の整合の検査が違反なしで終わる` (Skill 4 つ)、`evidence/skills-cross-check.md` | ✅ |
| 同 / 英語版と日本語版が同じ構成である | 同上 | `scripts/ci/check-skills.py:258` (`check_pair`) を実物に流して違反なし。T-repo 同上 | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| SKILL.md の中身 / 冒頭でライブラリが何かが分かる | 4 枚の `SKILL.md:12` (見出しの直下の段落に、何のライブラリかと、扱うプラットフォームがある) | `evidence/dist-read-*.md` の「冒頭」の節 (4 回とも、分かると報告) | ✅ |
| 同 / できることの表が 5 枚をすべて指す | 4 枚の `SKILL.md` の「What you can do / できること」の表 | 自分でリンクの先を数えた (4 枚とも 5 枚すべてを指す)。リンクの先の実在は `check-skills.py:201` | ✅ |
| 同 / 導入に必要な環境がある | `skills/en/kscollectionview-ios/SKILL.md:55`・`:56` (iOS 16・Xcode 27 以上)。日本語版の同じ場所 | 目で確かめた | ✅ |
| 同 / 最小の動く例が README の例と同じである | 4 枚の `SKILL.md` の「Minimal working example / 最小の動く例」 | 自分でコードブロックを README と比べた (4 枚とも一致)。`evidence/skills-cross-check.md` | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| references の中身 / 割り当てた申し送りがすべて載っている | 両プラットフォームの `references/` の 5 枚 | `evidence/ios-skill-handoffs.md`・`evidence/android-skill-handoffs.md` (design の Decision 2 の表の行ごとに、載せた見出しの一覧)。挙げられた見出しが今の Skill にあることを、見出しの一覧で確かめた | ✅ |
| 同 / 片方のプラットフォームだけの申し送りは、そのプラットフォームにだけ載る | iOS: `references/basics.md`「Read parent state inside a row」・`references/images.md`「Enable the disk cache at launch」。Android には「Enable the disk cache at launch」の節が無く、`skills/en/kscollectionview-android/references/images.md:130` に、Android では準備が要らないことだけがある | 上の 2 枚の証跡と、自分での検索 | ✅ |
| 同 — Side Effects (なし) | 文書だけ。コードブロックの中に、日本語の行とコメントの行は無い (自分で数えて 0 行) | — | ✅ |
| 相手のプラットフォームとの差の書き方 / 動きの差が、その機能の場所に書かれている | 並べ替え: iOS `references/reorder.md:277`・`:281`、Android `references/reorder.md:280`・`:281`。Pull to Refresh の失敗: iOS `references/paging.md:309`、Android `references/paging.md:307` (行は英語版) | 証跡 2 枚の「差を書いた場所」の表。差をまとめた節が無いことは、見出しの一覧で確かめた | ✅ |
| 同 / 相手のプラットフォームのコードが無い | iOS の Skill のコードブロックは `swift` 36・`text` 1、Android は `kotlin` 34・`text` 1 (英日とも) | 自分で数えた。`evidence/skills-cross-check.md` | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| Skill の外への参照 / 相手の Skill は名前だけで触れる | 4 枚の `SKILL.md:12` (相手の Skill の名前がコードの書体で 1 回。リンクは無い) | 自分で検索した。`evidence/skills-cross-check.md` | ✅ |
| 同 / Skill だけで読み切れる | Skill の中の URL は、許可した 4 つ (Package URL・配布元・最新の版の確かめ先・不具合の報告先) だけ。Skill の外への相対のリンクは無い | `check-skills.py:201`・`:223`・`:241` を実物に流して違反なし。`evidence/dist-read-dispositions.md` | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| 公開の宣言の名前の掲載 / 載せないと決めた名前のほかに、漏れが無い | `skills/.manifest.json` の `apiExclusions` は空。道具は今、漏れ 4 件を報告する (iOS の `buildExpression`・`buildBlock` × 2 言語) | `python3 scripts/docs/check-api-coverage.py` (終了コード 1) | ⏳ タスク 9.4 (載せない名前をオーナーに諮って記録に書く) と 9.5 (流し直して 0 件を証跡に書く) の完了を待つ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| Skill の索引 / 索引から導入の手順が分かる | `skills/README.md:14`〜`:45`・`skills/README_ja.md:14`〜`:45` (写しを取る・ディレクトリごとコピーする先・開き直す) | 目で確かめた。`evidence/skills-cross-check.md` の 7.1 | ✅ |
| 同 / 索引が 4 つの Skill をすべて挙げる | `skills/README.md:9`・`:10` (コピー元は `skills/en/`)、`skills/README_ja.md:9`・`:10` (コピー元は `skills/ja/`) | 目で確かめた。見出しの並びの一致は T-repo `test_Skillの索引の2枚の見出しの深さの並びが一致する` | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| 配った先を再現した確認 / 読ませる確認の指摘に、すべて結末が付いている | — (確認の作業) | `evidence/dist-read-dispositions.md` の「番号ごとの結末」。4 つの記録の番号 (49・51・58・53) のすべてに、直・一部・否のどれかが付いていることを、機械的に数えて確かめた。直さないものには理由がある | ✅ |
| 同 / 5 つの課題が、両プラットフォームでビルドできる | — (確認の作業) | `evidence/dist-use.md` の「回ごとの結果」(10 回とも成功)。書かれたファイル 10 個が `evidence/dist-use/` にある | ✅ |
| 同 / 落ちた回には、仕分けが残っている | — (確認の作業) | `evidence/dist-use.md` の「Android の 1 回目の実行について」。落ちたのは、作業用の写しに SDK の場所の設定が無かった 5 回だけで、原因と、その後に行ったこと (設定を足して流し直した) が書かれている (注 1) | ✅ |
| 同 / 確認の作業は、追跡しているファイルを変えない | — (確認の作業) | `evidence/dist-use.md` の「本リポジトリの作業ツリーが変わっていないこと」(前後の `git status --short` が一致。入れ替えたのは作業用の写しの中だけ) | ✅ |
| 同 — Side Effects (一時の作業用のディレクトリ: 作成 / 変更のディレクトリの証跡: 作成) | 残っているのは `evidence/` の下のファイルだけ。作業用の置き場はリポジトリの外 | `evidence/dist-use.md`・`evidence/dist-read-*.md` | ✅ |

### specs/user-readme/spec.md (15 Scenario: ✅ 15)

| Requirement / Scenario | 実装 | テスト・証跡 | 状態 |
|---|---|---|---|
| README の節の並び / 2 枚が同じ節を同じ順で持つ | `README.md:5`〜`:166`・`README_ja.md` の深さ 2 の見出し 9 つ。互いを指す行は `README.md:3`・`README_ja.md:3` | T-repo `test_2枚が9つの節をこの順で持つ`、既存の `ReadmeTest` (見出しの一致・互いを指す) | ✅ |
| 同 / 準備中の案内が無い | 9 つの節だけ (深さ 2 の見出しを、この 9 つに限る) | 同上。開発者向けの手順 (ビルド・テストの流し方) が無いことは、通して読んで確かめた | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| 対応プラットフォームの案内 / iOS の値がマニフェストと一致する | `README.md:31` (iOS 16・Xcode 27 or later)。`ios/Package.swift:1` (`swift-tools-version: 6.4`)・`:8` (`.iOS(.v16)`) | 自分で突き合わせた。`evidence/readme-and-screenshots.md` の 4.1 | ✅ |
| 同 / Android の値がビルドの設定と一致する | `README.md:32` (Android 10 (API 29))。`android/kscollectionview/build.gradle.kts:23` (`minSdk = 29`) | 同上 | ✅ |
| 同 / 利用者に求める下限と、ライブラリが使った版が分かれている | 表の列が「利用する側のビルドに必要なもの」と「ライブラリのビルドに使っているもの」に分かれ、`README.md:34` が違いを説明する | 目で確かめた。値の出どころは `evidence/readme-and-screenshots.md` の 4.1 | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| インストール例 / 例の値が利用者役と同じである | `README.md:48`・`:66` と日本語版の同じ場所。比べる相手は `scripts/ci/verify-consumer-ios.py:141`・`verification/ios/Package.swift.template:33`・`verification/android/app/build.gradle.kts:73` | `scripts/ci/check-readme-examples.py:382` を実物に流して違反なし。T-repo `test_インストール例が利用者役の値と一致する`、T-readme `test_実物の利用者役から比べる相手の値を取れる` | ✅ |
| 同 / 版が書かれていない | 同上 (`exact: "{version}"`・`:{version}`) | 同上。T-readme `test_具体の版が書かれていると失敗しそのファイルが出る` | ✅ |
| 同 / 最新の版の確かめ先が分かる | `README.md:40`・`README_ja.md` のインストールの節の 2 段落目 (Releases の URL) | 同じ検査。T-readme `test_最新の版の確かめ先が無いと失敗しそのファイルが出る` | ✅ |
| 同 / まだ公開していないことが分かる | `README.md:38`・`README_ja.md` のインストールの節の冒頭 | 目で確かめた | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| 最小コード例 / コード例が利用者役のファイルと同じである | `README.md:70`〜、`README_ja.md` の「最小コード例」。相手は `verification/ios/Sources/VerificationApp/ItemListScreen.swift`・`verification/android/app/src/main/kotlin/ItemListScreen.kt` | `check-readme-examples.py:181` を実物に流して、一致した最小コード例 4 つ。T-repo `test_READMEの最小コード例が利用者役の画面と一致する` (4 か所) | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| スクリーンショット / 6 枚の画像が表示される | `README.md:24`・`:25` と日本語版の同じ行。`assets/` の 6 枚 | T-repo `test_スクリーンショットの節が6枚の画像を指し画像が実在する` | ✅ |
| 同 / 両プラットフォームが同じ 3 つの画面を見せる | `assets/{ios,android}-{list,grid,grouping}.png` | 6 枚を自分で開いて見た (リスト・固定 3 列のグリッド・グループ化が、両プラットフォームで同じ画面)。`evidence/readme-and-screenshots.md` の 4.3 | ✅ |
| 同 / 写ってはいけないものが無い | 同上 | 6 枚を自分で開いて見た (写っているのは、Sample の文字・色の四角・時刻 9:41 のステータスバーだけ)。同じ証跡 | ✅ |
| 同 — Side Effects (なし) | 文書と画像だけ | — | ✅ |
| Skill への導線・貢献・ライセンスの案内 / 導線の先が実在する | `README.md:145`〜`:147`・`README_ja.md` の「Skill」の節 | T-repo `test_Skillへの導線が自分の言語のSkillと索引を指し先が実在する` | ✅ |
| 同 / 貢献とライセンスの導線が保たれている | `README.md:164`・`:168` と日本語版の同じ節 (Issue で受ける・外部の Pull Request を受けない・貢献の案内・`LICENSE`・依存するライブラリのライセンスの表) | 既存の `ReadmeTest` (ライセンスと貢献の案内への導線)。依存のライセンスの出どころは `evidence/readme-and-screenshots.md` の 4.2 | ✅ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |

### specs/user-docs-consistency/spec.md (31 Scenario: ✅ 31)

| Requirement / Scenario | 実装 | テスト・証跡 | 状態 |
|---|---|---|---|
| README の最小コード例の検査 / 一致していれば成功する | `scripts/ci/check-readme-examples.py:181` | T-readme `test_一致していれば成功する` | ✅ |
| 同 / README の例だけを変えると失敗する | 同 `:181` | T-readme `test_READMEの例だけを変えると失敗しどのREADMEのどのプラットフォームかが出る` | ✅ |
| 同 / 利用者役のファイルだけを変えると失敗する | 同 | T-readme `test_利用者役のファイルだけを変えると失敗する` | ✅ |
| 同 / 日本語版の README も確かめる | 同 | T-readme `test_日本語版のREADMEも確かめる` | ✅ |
| 同 / 節が見つからないと失敗する | 同 `:156` | T-readme `test_節が見つからないと失敗する` (ほかに、コードブロックが無い・ファイルが無い場合のテストもある) | ✅ |
| 同 / 無いルートでは始めない | 同 `:412` | T-readme `test_無いルートでは始めない` | ✅ |
| 同 — Side Effects (なし) | 読むだけ。確認のスクリプトを読み込んだ跡も残さない | T-readme `test_確認のスクリプトの読み込みが残らない` | ✅ |
| インストール例の検査 / 決めた形なら成功する | `scripts/ci/check-readme-examples.py:382` | T-readme `test_決めた形なら成功する` | ✅ |
| 同 / 具体の版が書かれていると失敗する | 同 `:281`・`:318` | T-readme `test_具体の版が書かれていると失敗しそのファイルが出る` | ✅ |
| 同 / 値が利用者役と違うと失敗する | 同 `:264`・`:281` | T-readme `test_値が利用者役と違うと失敗する` | ✅ |
| 同 / 最新の版の確かめ先が無いと失敗する | 同 `:346` | T-readme `test_最新の版の確かめ先が無いと失敗しそのファイルが出る` | ✅ |
| 同 / 例が無いファイルがあると失敗する | 同 `:346` | T-readme `test_例が無いファイルがあると失敗する` | ✅ |
| 同 / 英語版と日本語版で例の数が違うと失敗する | 同 `:382` | T-readme `test_英語版と日本語版で例の数が違うと失敗する` | ✅ |
| 同 / 無いルートでは始めない | 同 `:412` | T-readme `test_無いルートでは始めない` | ✅ |
| 同 — Side Effects (なし) | 読むだけ | 同上 | ✅ |
| Skill 自身の整合の検査 / 整合していれば成功する | `scripts/ci/check-skills.py:322` | T-skills `test_整合していれば成功する` | ✅ |
| 同 / 片方の言語だけ見出しを変えると失敗する | 同 `:258` | T-skills `test_片方の言語だけ見出しを変えると失敗しその1枚が出る` | ✅ |
| 同 / 片方の言語だけコードを変えると失敗する | 同 `:258` | T-skills `test_片方の言語だけコードを変えると失敗する` | ✅ |
| 同 / 片方の言語にだけファイルがあると失敗する | 同 `:322` | T-skills `test_片方の言語にだけファイルがあると失敗する` | ✅ |
| 同 / frontmatter に決めていない項目があると失敗する | 同 `:162` | T-skills `test_決めていない項目があると失敗する` | ✅ |
| 同 / name がディレクトリの名前と違うと失敗する | 同 `:162` | T-skills `test_nameがディレクトリの名前と違うと失敗する` | ✅ |
| 同 / Skill の外のファイルへのリンクがあると失敗する | 同 `:201` | T-skills `test_Skillの外のファイルへのリンクがあると失敗しそのリンクが出る` | ✅ |
| 同 / リンクの先が無いと失敗する | 同 `:201` | T-skills `test_リンクの先が無いと失敗する` | ✅ |
| 同 / 許可していない URL があると失敗する | 同 `:223` | T-skills `test_許可していないURLがあると失敗しそのURLが出る` | ✅ |
| 同 / 許可した URL と見本の URL は通る | 同 `:223`・`scripts/ci/user-docs-rules.json` | T-skills `test_許可したURLと見本のURLは通る` | ✅ |
| 同 / 内部の言葉があると失敗する | 同 `:241` | T-skills `test_内部の言葉があると失敗しその言葉と場所が出る` | ✅ |
| 同 / skills が無いと失敗する | 同 `:322` | T-skills `test_skillsが無いと失敗する`・`test_Skillが1つも無いと失敗する` | ✅ |
| 同 / 無いルートでは始めない | 同 `:361` | T-skills `test_無いルートでは始めない` | ✅ |
| 同 — Side Effects (なし) | 読むだけ | 自分で流した前後で `git status --short` が一致 | ✅ |
| 検査は検証 CI のスクリプトのテストで毎回流れる / スクリプトのテストが実物を確かめる | T-repo の `UserDocsCheckTest` (3 つの検査を、今のリポジトリのルートに流す) | `python3 scripts/ci/run-tests.py` を自分で流して 504 件・失敗 0 件 | ✅ |
| 同 / 実物が崩れると、スクリプトのテストが失敗する | 同上 | `evidence/checks-and-refresh-tools.md` の 8.2 (一時のツリーで、失敗 1 件)。自分でも、写しに見出しを 1 つ足して `check-skills.py` が終了コード 1 になることを確かめた | ✅ |
| 同 / lint の step が増えていない | `.github/` の下・`scripts/ci/tests/test_workflow_files.py`・`scripts/ci/check-workflows.py` に差分が無い (`git status --short` に現れない) | 既存の `test_workflow_files.py` が変えずに通る。`evidence/checks-and-refresh-tools.md` の 8.3 | ✅ |
| 同 / 源泉だけを変えても、検証 CI は落ちない | T-repo は、源泉と Skill のずれを見ない (`SkillsManifestTest` は記録の形だけ) | `evidence/checks-and-refresh-tools.md` の 8.2。今の実物も裏付ける (`status` が変わった源泉 2 件を出している状態で、スクリプトのテストは成功する) | ✅ |
| 同 / 公開の宣言だけを足しても、検証 CI は落ちない | スクリプトのテストは、網羅の道具を実物に流さない | 同じ証跡。今の実物も裏付ける (網羅の道具が漏れ 4 件・終了コード 1 の状態で、スクリプトのテストは成功する) | ✅ |
| 同 — Side Effects (なし) | テストは一時のディレクトリだけに書く | 自分で流した前後で `git status --short` が一致 | ✅ |

### specs/user-docs-refresh/spec.md (32 Scenario: ✅ 31・⏳ 1)

| Requirement / Scenario | 実装 | テスト・証跡 | 状態 |
|---|---|---|---|
| 追従の記録 / 記録が決めた項目を持つ | `skills/.manifest.json` (`syncedCommit`・`sources`・`apiExclusions`) | T-repo `test_記録が決めた3つの項目を持つ`、T-refresh `test_決めた3つの項目を読む` | ✅ |
| 同 / 概念の文書に、行き先の無いものが無い | `skills/.manifest.json` の `sources` が、`kasane/concepts/` の下の概念の文書 14 枚のすべてを持つ (注 2) | T-repo `test_源泉が掛かる1枚か掛からない理由のどちらかを持つ`・`test_掛かる1枚がSkillに実在する`。自分で流した `status` に「対応の決まっていない源泉」が出ない | ✅ |
| 同 / 最初の記録が、制作の見た commit を指す | 今の `syncedCommit` は、作業を始めたときの HEAD (`a064aca…`)。履歴にはあるが、制作が見た源泉 (書き直した利用者役の画面) を持たない (`status` が変わった源泉 2 件を出す) | `python3 scripts/docs/skills-refresh.py status` | ⏳ タスク 12.5 (commit の後に、記録を制作が見た commit に更新する) の完了を待つ |
| 同 — Side Effects (なし) | 文書だけ | — | ✅ |
| 変わった源泉の一覧 / 変わっていなければ、変わった源泉は無いと出る | `scripts/docs/skills-refresh.py:262`・`:319` | T-refresh `test_変わっていなければ変わった源泉は無いと出て成功する` | ✅ |
| 同 / 変わった源泉と、見直す 1 枚が出る | 同 | T-refresh `test_変わった源泉と見直す1枚が出る` | ✅ |
| 同 / 複数の 1 枚に掛かる源泉は、そのすべてが出る | 同 | T-refresh `test_複数の1枚に掛かる源泉はそのすべてが出る` | ✅ |
| 同 / 公開の宣言を消すと、消えた宣言として出る | 同 `:234` | T-refresh `test_公開の宣言を消すと消えた宣言として出る` | ✅ |
| 同 / 公開の宣言の引数を変えると、前の行と今の行が出る | 同 `:234` | T-refresh `test_公開の宣言の引数を変えると前の行と今の行が出る` | ✅ |
| 同 / 公開の宣言でない変更は、増減に出ない | 同 `:234` | T-refresh `test_公開の宣言でない変更は増減に出ない` | ✅ |
| 同 / commit していない変更も出る | 同 `:181` | T-refresh `test_commitしていない変更も出る` | ✅ |
| 同 / 対象の外の変更は出ない | 同 `:181` | T-refresh `test_対象の外の変更は出ない` | ✅ |
| 同 / 新しい概念の文書は、対応が決まっていないと出る | 同 `:206`・`:215` | T-refresh `test_新しい概念の文書は対応が決まっていないと出る` | ✅ |
| 同 / 名前の変わった源泉は、変わったことが分かる | 同 `:262` | T-refresh `test_名前の変わった源泉は前の名前と今の名前が出る` | ✅ |
| 同 / 差分の本文を出せる | 同 `:307` | T-refresh `test_差分の本文を出せる` | ✅ |
| 同 / 記録の commit が履歴に無いと失敗する | 同 `:380` | T-refresh `test_記録のcommitが履歴に無いと失敗する` (標準出力が空であることも見る) | ✅ |
| 同 / 記録が読めないと失敗する | `scripts/docs/skills_manifest.py:123` | T-refresh `test_記録のファイルが無いと失敗する`・`test_記録が決めた項目を欠いていると失敗する` | ✅ |
| 同 / 何も書き換えない | `scripts/docs/skills-refresh.py:380` | T-refresh `test_何も書き換えない`。自分で実物に流した前後でも `git status --short` が一致 | ✅ |
| 同 — Side Effects (なし) | 読むだけ | 同上 | ✅ |
| 追従の記録の更新 / 今の先頭の commit を記録する | `scripts/docs/skills-refresh.py:388` | T-refresh `test_今の先頭のcommitを記録する` | ✅ |
| 同 / ほかの項目を変えない | `scripts/docs/skills_manifest.py:175` | T-refresh `test_ほかの項目を変えない`・`test_記録のファイルの書き方を保つ` | ✅ |
| 同 / commit していない変更があると書き換えない | `scripts/docs/skills-refresh.py:388` | T-refresh `test_commitしていない変更があると書き換えない` | ✅ |
| 同 / 履歴に無い commit は記録しない | 同 `:159`・`:388` | T-refresh `test_履歴に無いcommitは記録しない` | ✅ |
| 同 / 履歴を変えない | 同 `:388` | T-refresh `test_履歴を変えない` | ✅ |
| 同 — Side Effects (`skills/.manifest.json` の commit の ID: 更新) | 書き換えるのは記録のファイルの ID だけ | T-refresh `test_履歴を変えない` (変わったファイルが記録のファイルだけであることを見る)・`test_ほかの項目を変えない`。実物への `record` は流していない (タスク 12.5) | ✅ |
| 公開の宣言の名前の網羅の報告 / すべての名前が現れていれば、漏れは無いと出る | `scripts/docs/check-api-coverage.py:101` | T-api `test_すべての名前が現れていれば漏れは0件で成功する` | ✅ |
| 同 / 現れない名前が報告される | 同 | T-api `test_現れない名前がプラットフォームと言語と名前で報告される`。実物でも、漏れ 4 件・終了コード 1 を観測した | ✅ |
| 同 / 片方の言語にだけ無い名前も報告される | 同 | T-api `test_片方の言語にだけ無い名前も報告される` | ✅ |
| 同 / 載せないと決めた名前は報告されない | 同 | T-api `test_載せないと決めた名前は報告されない` | ✅ |
| 同 / 載せないと決めた名前の宣言が無くなると、古い項目として出る | 同 | T-api `test_載せないと決めた名前の宣言が無くなると古い項目として出る` | ✅ |
| 同 / 利用者向けでない印の付いた宣言は拾わない | `scripts/docs/public_api.py:437` | T-api `test_利用者向けでない印の付いた宣言は拾わない` | ✅ |
| 同 / 相手のプラットフォームの名前を、漏れに数えない | `scripts/docs/check-api-coverage.py:101` | T-api `test_相手のプラットフォームの名前を漏れに数えない` | ✅ |
| 同 / 宣言を 1 つも拾えないと失敗する | 同 | T-api `test_宣言を1つも拾えないと失敗する` | ✅ |
| 同 / Skill が無いと失敗する | 同 `:71` | T-api `test_Skillが片方の言語に無いと失敗する` | ✅ |
| 同 / 何も書き換えない | 同 | T-api `test_漏れが無いときに何も書き換えない`・`test_漏れがあるときも何も書き換えない` | ✅ |
| 同 — Side Effects (なし) | 読むだけ | 同上。自分で実物に流した前後でも `git status --short` が一致 | ✅ |

### specs/consumer-verification/spec.md (6 Scenario: ✅ 6)

| Requirement / Scenario | 実装 | テスト・証跡 | 状態 |
|---|---|---|---|
| 利用者役の画面のソースの形 / iOS の画面のソースが 1 つのファイルである | `verification/ios/Sources/VerificationApp/ItemListScreen.swift` (置き場にあるのはこの 1 つ。前の 2 つのファイルは消えている) | T-ios `test_利用者役の画面のソースはモデルと画面を持つ1つのファイルである` | ✅ |
| 同 / 画面のソースにコメントが無い | 同上と `verification/android/app/src/main/kotlin/ItemListScreen.kt` | T-ios `test_利用者役の画面のソースはコメントを持たない`、T-android `test_画面のソースはコメントを持たない` | ✅ |
| 同 / Android の画面のソースが package の宣言を持たない | `verification/android/app/src/main/kotlin/ItemListScreen.kt:1` (import から始まる)。入口は `MainActivity.kt:5` の `import ItemListScreen` で呼ぶ | T-android `test_画面のソースはpackageの宣言を持たずimportから始まる`・`test_入口は画面を名前だけのimportで呼ぶ` | ✅ |
| 同 / iOS の確認が成功する | 同上のソース | `evidence/local-completion.md` の 12.2 (Simulator 向け・実機向けとも成功。終了コード 0)、`evidence/consumer-screen-source.md` の 1.4 | ✅ |
| 同 / Android の確認が成功する | 同上のソース | `evidence/local-completion.md` の 12.2 (コード縮小ありの組み立てと、依存の確認が成功。終了コード 0)、`evidence/consumer-screen-source.md` の 1.4 | ✅ |
| 同 / 起動して一覧が表示される | 同上のソースから組み立てた APK | `evidence/consumer-screen-source.md` の 1.5、`evidence/consumer-android-list-launched.png` | ✅ |
| 同 — Side Effects (なし) | 確認のスクリプト・ひな形・ビルドの定義に差分は無い。変わったのは、画面のソースと入口の import だけ | `git diff HEAD --stat -- verification` | ✅ |

## 後で確かめるもの (2 件)

| Scenario | 今の状態 | 待っているタスク | 確かめ方 |
|---|---|---|---|
| user-skills: 公開の宣言の名前の掲載「載せないと決めた名前のほかに、漏れが無い」 | 漏れ 4 件 (iOS の `buildExpression`・`buildBlock` が、英語版と日本語版に 1 件ずつ)。`apiExclusions` は空 | 9.4 (オーナーに諮っている途中)・9.5 | `python3 scripts/docs/check-api-coverage.py` が、漏れ 0 件・終了コード 0 で終わること。Skill に足す形で閉じたときは、2 本の検査とスクリプトのテストも流し直す |
| user-docs-refresh: 追従の記録「最初の記録が、制作の見た commit を指す」 | `syncedCommit` は作業を始めたときの HEAD。履歴にはあるが、制作が見た源泉を持たない | 12.5 (commit の後でないと行えない) | `python3 scripts/docs/skills-refresh.py status` が、変わった源泉が無いことと、公開の宣言の増減が無いことを出すこと。記録の ID が履歴にあること |

どちらも、実装が spec と違うのではない。道具は spec のとおりに動いていて (網羅の道具は漏れを正しく報告し、`status` は足された源泉を正しく出している)、残っているのは、オーナーの決定を記録に書くことと、commit の後の 1 回の操作である。

## 追加の検査

| 検査 | 結果 |
|---|---|
| tasks.md の完了 | 未完了は 9.4・9.5・12.4・12.5 の 4 つ。チェック済みのタスクに、未実装のもの (虚偽のチェック) は見つからない。対応表の ⏳ の 2 件は、未完了のタスク (9.4・9.5 と 12.5) にそのまま対応する。12.4 (オーナーの検収) は、対応する Scenario を持たない |
| 逆流検査 | `git diff HEAD -- kasane/changes/user-docs` で、追跡しているファイルのうち変わっているのは `tasks.md` だけ。差分はチェックの記号だけで、文面は変わっていない (行ごとに突き合わせた)。`proposal.md`・`design.md`・`specs/` の 5 枚は、提案の commit (`a064aca`) のまま |
| 未記録の乖離 | 無い (❌ が無い) |
| Side Effects | 上の対応表の各 Requirement の行のとおり。列挙に収まらない状態変更は見つからない。道具と検査は読むだけで、書き換えるのは `record` の記録の ID だけである |
| 付随修正 | `deviation.md` に `[付随修正]` の行は無い。diff のうち Scenario に直接対応しない変更は、`kasane/config.yaml` のコメント (タスク 7.3)・`drafts/` (タスク 11)・Android の入口の import (タスク 1.2) で、どれも tasks.md にある作業である。記録の無い付随修正は見つからない |
| deviation.md | 蒸留送りの 4 行だけ。spec からの乖離の行は無い |
| UI 変更 | 当たらない (`ui/brief.md` は無い。変えたのは文書・スクリプト・利用者役の最小の画面) |
| テスト | スクリプトのテストは自分で流して 504 件・失敗 0 件。テスト 4 系統 (iOS 本体 567・iOS Sample 48・Android 本体 512・Android Sample 163。失敗 0) は `evidence/local-completion.md` の 12.3 で確かめた (本変更は、本体と Sample のソースを変えていない) |

## 注

1. 「落ちた回には、仕分けが残っている」: 落ちた 5 回の原因は、作業用の写しの環境 (SDK の場所の設定が無い) で、spec の挙げる 3 つの分け方 (Skill の欠け・読み手の書き損じ・ライブラリの側の問題) のどれにも当たらない。証跡は、3 つのどれでもないことと理由、その後に行ったことを書いているので、一致とした。書かれたファイルに届いた失敗 (Skill の中身が原因になり得る失敗) は 0 回である
2. 「概念の文書に、行き先の無いものが無い」: 道具は、`kasane/concepts/` の下の `index.md`・`log.md`・`rules.md` を概念の文書に数えない (`scripts/docs/skills-refresh.py:79`)。目次・更新の履歴・書き方の決まりで、Skill の源泉になる内容を持たないためである。これを除いた 14 枚は、すべて記録にある

## 判定に影響しない気付き

- 使わせる確認 (10 回のビルド) の後に、Skill に手が入っている (確認で挙がった分かりにくいところの手直しと、レビューの指摘の手直し。`references/reorder.md` の 1 行の例など、コードの追加を含む)。spec は、直す作業をこの Requirement の外に置いているので乖離ではない。足したコードは、ビルドでは確かめ直されていない
- `evidence/checks-and-refresh-tools.md` の 8.2 と `evidence/local-completion.md` の 12.1 は、スクリプトのテストが 484 件のときの記録で、今は 504 件である。`deviation.md` の蒸留送りの 1 行目は、件数を `evidence/local-completion.md` から取ると書いているので、蒸留のときは今の件数を取り直す必要がある
- `evidence/dist-read-en-ios.md` は冒頭に「指摘 51 件」と書いているが、表にある番号は 49 個である (`evidence/dist-read-dispositions.md` が自分で書き留めている)。結末は 49 個のすべてに付いている
- 利用者の立場のビルドの確認の Android は、前回のビルドの出力が残った状態で流されている (`evidence/local-completion.md` の 12.2 が自分で書き留めている)。出力の無い状態からの組み立ては、`evidence/consumer-screen-source.md` の 1.4 が確かめている

## 確かめていないこと

- 利用者の立場のビルドの確認とテスト 4 系統を、自分では流していない (Simulator・エミュレータ・実機を使わない制約のため。証跡で確かめた)
- 証跡の画面の写し (`evidence/consumer-android-list-launched.png`) は開いていない。証跡の本文で確かめた
- `references/` の本文の事実の正しさ (ライブラリの動きと合っているか) は見ていない。確かめたのは、spec の Scenario が求める形と、載せた場所である
