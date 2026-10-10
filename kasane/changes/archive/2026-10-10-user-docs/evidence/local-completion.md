# 手元の完了判定 (tasks 12.1〜12.3)

実施日: 2026-10-10。確かめる作業だけを行い、ソース・文書・スクリプト・テスト・足場は変えていない。

- 作業ツリー: `develop` の `a064aca` に、本変更の未 commit の差分が載った状態
- 環境: macOS 27.0.1・Xcode 27.0 (27A266a)・JDK 21・actionlint あり
- `git status --short` は、作業の開始時・12.2 の前後・作業の終了時のすべてで同じ (28 行)

## 12.1 スクリプトのテスト・標準の lint・workflow の定義の検査

| 確認 | コマンド | 結果 | 終了コード |
|---|---|---|---:|
| スクリプトのテスト | `python3 scripts/ci/run-tests.py` | 実行 484 件 / 失敗 0 件 / スキップ 0 件 (18.3 秒) | 0 |
| ローカル絶対パス | `python3 scripts/local-path-lint.py` | 違反 0 件 (出力なし) | 0 |
| 個人を特定する値 | `python3 scripts/identity-lint.py` | 違反 0 件 (出力なし) | 0 |
| コメントの規約 | `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 504 ファイル) | 0 |
| workflow の定義 | `python3 scripts/ci/check-workflows.py` | workflow 5 本 (uses 13 箇所 / runs-on 5 箇所 / permissions 5 箇所)・違反なし | 0 |
| actionlint | `actionlint` (リポジトリのルート) | 出力なし | 0 |
| Skill 自身の整合 | `python3 scripts/ci/check-skills.py .` | 違反なし (Skill 4 つ・Markdown 24 枚) | 0 |
| README の例 | `python3 scripts/ci/check-readme-examples.py .` | 違反なし (一致した最小コード例 4 つ・確かめた依存の宣言の行 12 行) | 0 |

スクリプトのテストは、前の変更の最後 (262 件) から 484 件に増えている。本変更で足したテストの分である。

### 追跡していないファイルが lint の対象に入っているか

本変更の新しいファイルは、まだ git が追跡していない (78 個。`skills/` 27・`assets/` 6・`scripts/docs/` 4・`scripts/ci/` 9・`verification/` 2・`kasane/changes/` 30)。

- 3 本とも、既定の走査が追跡していないファイルを含む。ローカル絶対パスと個人を特定する値の lint は `git grep --untracked` で候補を拾い、コメントの規約の lint は `git ls-files --others --exclude-standard` を足して列挙する (スクリプトの本文で確かめた)
- 追跡していないファイルのうち、ビルド出力の名前のディレクトリ (`build`・`dist` など) の下にあって読み飛ばされるものは 0 個
- 念のため、追跡していないファイルを `--paths` で名指しして流し直した。結果は既定の走査と同じ

| 確認 | 名指しした範囲 | 結果 | 終了コード |
|---|---|---|---:|
| ローカル絶対パス | 追跡していないファイル (別の変更 `android-sample-status-bar-contrast` を除く) と README の 2 枚 | 違反 0 件 | 0 |
| 個人を特定する値 | `skills`・`assets`・`scripts/docs`・`scripts/ci` の新しいファイル・この変更の `drafts`・`evidence`・利用者役の画面の 2 枚・README の 2 枚 | 違反 0 件 | 0 |
| コメントの規約 | 同上 | 禁止 0 件 (検査対象 2 ファイル = 利用者役の画面の `.kt` と `.swift`) | 0 |

- 3 本の `--selftest` は、どれも「全件 OK」・終了コード 0
- コメントの規約の lint が見る拡張子は `.swift`・`.kt` などのソースに限られる。`.py`・`.md`・`.json` は対象外で、`kasane/` の下も常に対象外である。新しいファイルのうち、この lint が実際に見たのは利用者役の画面の 2 枚である

### 公開の宣言の名前の網羅 (今の状態の記録)

`python3 scripts/docs/check-api-coverage.py` は終了コード 1 で、漏れ 4 件を報告した。この 4 件を載せない名前にするかは判断の途中なので、ここでは失敗として扱わず、今の出力を記録する (tasks 9.5 で閉じる)。

```text
iOS: 拾った名前 83 個 (名前を持つ宣言 90 個)・載せないと決めた名前 0 個
  漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): buildBlock — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:11)
  漏れ: iOS / 英語版 (skills/en/kscollectionview-ios): buildExpression — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5)
  漏れ: iOS / 日本語版 (skills/ja/kscollectionview-ios): buildBlock — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:11)
  漏れ: iOS / 日本語版 (skills/ja/kscollectionview-ios): buildExpression — KsTemplateBuilder の関数 (ios/Sources/KsCollectionView/KsTemplateBuilder.swift:5)
Android: 拾った名前 86 個 (名前を持つ宣言 98 個)・載せないと決めた名前 0 個
公開の宣言の名前の網羅: 漏れ 4 件
```

漏れは iOS の `buildExpression`・`buildBlock` の 2 つが英語版と日本語版に 1 件ずつで、見込みどおりである。Android の漏れは 0 件。

## 12.2 利用者の立場のビルドの確認 (`local`)

| プラットフォーム | コマンド | 結果 | 終了コード | 所要 |
|---|---|---|---:|---:|
| iOS | `python3 scripts/ci/verify-consumer-ios.py --mode local` | Simulator 向け (`generic/platform=iOS Simulator`・Release) 成功・実機向け (`generic/platform=iOS`・Release) 成功。`** BUILD SUCCEEDED **` が 2 回 | 0 | 24 秒 |
| Android | `python3 scripts/ci/verify-consumer-android.py --mode local` | 利用者役のリリースの組み立て (コード縮小あり) 成功。`releaseRuntimeClasspath` に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` が指定の版で現れる | 0 | 4 秒 |

- どちらも、利用者役の画面のソースが新しい形 (`ItemListScreen.swift`・`ItemListScreen.kt`) の状態で通った
- 前後で `git status --short` は変わらない (diff なし)
- Android の SDK の場所は、`android/` と `verification/android/` の `local.properties` から取った (環境変数 `ANDROID_HOME` は渡していない)
- Android は、利用者役のビルドの出力が残っている状態で流した。利用者役の側は 49 タスクのうち 46 が up-to-date (`:app:compileReleaseKotlin`・`:app:minifyReleaseWithR8`・`:app:assembleRelease` を含む) で、今のソースに対する前回の出力が有効と Gradle が判定した形である。出力を消して組み立て直すことはしていない
- iOS のビルドで、本体の並行性の警告が 2 か所に出る (`KsCollectionViewController+Reorder.swift:256`・`KsCollectionViewController.swift:1891`)。前の変更で簡易起票した `ios-release-build-concurrency-warnings` (リリースの構成で並行性の警告が 2 か所) に当たると見ている。起票の箇所との突き合わせはしていない。本変更は本体を変えていない

## 12.3 テスト 4 系統 (絞り込みなしの全件)

4 系統を、重ねずに順に流した。

| 系統 | コマンド | 実行 | 失敗 | スキップ | 終了コード | 所要 | 前の変更の最後 |
|---|---|---:|---:|---:|---:|---:|---:|
| iOS 本体 | `ios/` で `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug -collect-test-diagnostics never` | 567 | 0 | 0 | 0 | 191 秒 | 567 |
| iOS Sample | `samples/ios/` で `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,id=<uuid>' -collect-test-diagnostics never` | 48 (ユニット 37 + UI 11) | 0 | 0 | 0 | 181 秒 | 48 (37 + 11) |
| Android 本体 | `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks` | 512 (31 クラス) | 0 | 0 | 0 | 21 秒 | 512 |
| Android Sample | `samples/android/` で `./gradlew :app:testDebugUnitTest --rerun-tasks` | 163 (21 クラス) | 0 | 0 | 0 | 12 秒 | 163 |

- 件数は 4 系統とも前の変更の最後と同じ。本変更はテストの件数に影響していない
- 揺れて落ちたテストは無い。4 系統とも 1 回目の実行の結果で、流し直しはしていない
- 4 系統の所要の合計は 405 秒 (6 分 45 秒) で、10 分の上限に収まる
- iOS の件数は、`xcodebuild` の出力の末尾の `Executed N tests, with M failures` と、`Test Case ... passed` の行数 (本体 567・Sample 48) の両方で確かめた。末尾は `** TEST SUCCEEDED **`
- iOS Sample は通常のスキームで流した。件数に計測ドライバは入っていない (ユニット 37 + UI 11 = 48)
- Android の件数は、`build/test-results/testDebugUnitTest/TEST-*.xml` の `tests`・`failures`・`errors`・`skipped` を合計した。結果のファイルはすべてこの実行で書かれたもの (古いファイル 0)。Gradle は本体 30 タスク・Sample 45 タスクをすべて実行した (up-to-date 0)
- 端末をつないで走らせるテスト (`KsImageDeviceDecodeTest`) は流していない。4 系統に入っておらず、本変更は Android 本体の画像のデコードに触れていない

### 使った Simulator・エミュレータ

| 用途 | 機種 | OS | 用意 |
|---|---|---|---|
| iOS 本体・iOS Sample | iPhone 17 (Simulator) | iOS 27.0 | この作業のために新しく作り、行き先は毎回その UDID で指定した |
| Android 本体・Android Sample | なし (JVM 上の Robolectric) | — | エミュレータも実機も使っていない |

後片付け:

- 作った Simulator は、名前と UDID が自分のものと一致することを確かめてから削除した。Simulator の一覧 (UDID の集合) は作業の前と一致し、起動中の Simulator は 0 のまま
- 既にあった Simulator・つながっている Android の実機 (2 台) は操作していない (`adb` は台数の確認だけに使った)

## 確かめていないこと

- 利用者の立場のビルドの確認の `published` (公開物が無い)
- Android の利用者役を、ビルドの出力が無い状態から組み立て直すこと
- gitleaks の走査 (検証 CI の `lint` の中の step。手元では流していない)
- 端末をつないで走らせるテスト・性能の検証

## レビューの指摘を直した後・載せない名前を記録した後の流し直し (2026-10-10)

上の記録の後に変えたのは、`scripts/ci/`・`scripts/docs/` (レビューの指摘の修正)・Skill の文書 (レビューの指摘の修正)・`skills/.manifest.json` (載せない名前の記録) だけである。本体・Sample・利用者役・README は変えていないので、テスト 4 系統と利用者の立場のビルドの確認は流し直していない。

| 確認 | 結果 | 終了コード |
|---|---|---:|
| `scripts/ci/run-tests.py` | 実行 504 / 失敗 0 / スキップ 0 (レビューの指摘の修正で 20 件増えた) | 0 |
| `scripts/ci/check-skills.py .` | 違反なし (Skill 4 つ・Markdown 24 枚) | 0 |
| `scripts/ci/check-readme-examples.py .` | 違反なし (最小コード例 4 つ・依存の宣言 12 行) | 0 |
| `scripts/docs/check-api-coverage.py` | 漏れ 0 件 (載せないと決めた名前: iOS 2 個・Android 0 個) | 0 |
| `scripts/local-path-lint.py`・`scripts/identity-lint.py`・`scripts/comment-policy-lint.py` | 違反 0 | 0 |
| `scripts/ci/check-workflows.py` | 違反なし | 0 |

オーナーの検収 (12.4) の後に指摘を直したときは、この表をもう一度流し直す。

## オーナーの検収 (12.4。2026-10-10)

- 対象: Skill の 4 部・索引 2 枚・README の 2 枚・スクリーンショット 6 枚
- 結果: 検収 OK (オーナー)。検収の中で決まったことは 2 つ (どちらも `readme-and-screenshots.md` に記録): Android の利用する側の下限から、確かめていない 2 つ (Android Gradle Plugin・Kotlin) を外す / iOS のスクリーンショットの戻るボタンの差は、Android を撮り直すときに揃える
- 下限を外す直しの後に流し直した結果: スクリプトのテスト 504 件・失敗 0 / `check-skills.py`・`check-readme-examples.py` は違反なし / 網羅の道具は漏れ 0 件 (9.5)。その後に変えたのは、証跡と簡易起票の文書だけである
- 検収の後の Skill と README への指摘は無い
