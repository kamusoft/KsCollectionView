# レビュー結果: package-distribution (001 回目)

**日付**: 2026-10-09
**判定**: CHANGES_REQUESTED

## サマリー

対象は tasks.md のグループ 1〜8 (グループ 9 は未実施で対象外)。写しを作る道具・Android の公開の設定・利用者役・確認のスクリプト・workflow は、デルタスペックと design の Decision 1〜8 に沿っており、異常系のテストと証跡も揃っている。Critical・Major は無い。

判定を CHANGES_REQUESTED にした理由は 1 件だけである。Android の発行物の Requirement は「公開 API の宣言に現れる型を持つ依存を compile の範囲で宣言する」と書いているが、`Color`・`Dp`・`@DrawableRes` を持つ 3 つの成果物は宣言されておらず、deviation.md にも記録が無い (指摘 1)。実害は見つかっていないが、記録の無い spec との差なので、verify の前に「宣言を足す」か「乖離として記録する」かを決める必要がある。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md` (always)
- `kasane/handbook/cross/verification-ci.md` — workflow と `scripts/ci/` を変えた。「検査を足すときの注意」の 3 節 (名前と起動の条件・スクリプトと道具・ジョブと step) を節ごとに照合した
- `kasane/handbook/cross/public-identifiers.md` — `build.gradle.kts`・`settings.gradle.kts`・`ios/Package.swift` を触った
- `kasane/handbook/cross/test-execution.md` — テストの結果の報告
- `kasane/handbook/cross/branch-and-github-settings.md` — 必須の検査を足す前提の確認 (実施はグループ 9 で対象外)
- 決定: cross/ADR-0003・0010・0013・0014 (accepted)、core/ADR-0012 (accepted)、android/ADR-0008 (accepted)。cross/ADR-0015・0016 は proposed なので、判定の根拠にしていない
- `kasane/lessons/code-review.md`: L-001 (直前のサイクルで直したコードの計測値の再現) は初回なので該当なし。L-002 (動きの過程の観察) は対象の機能が無い。「指摘しないこと」は空

ロードしたスキル: ksn-review / kotlin-impl-skill

## 確認した観点

自分で流したもの (2026-10-09):

| 流したもの | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 259 件 / 失敗 0 件 / スキップ 0 件 |
| `python3 scripts/ci/check-workflows.py` | workflow 5 本、違反は無い |
| `actionlint` | 終了コード 0 |
| `scripts/local-path-lint.py`・`identity-lint.py`・`comment-policy-lint.py` | どれも違反なし (コメントの規約は検査対象 502 ファイル・禁止 0 件) |
| 写しを作る道具を、リポジトリの外の一時の場所へ実行 | 直下は 5 点だけ。`Package.swift` は `ios/Package.swift` と一致。`swift package dump-package` が名前 `KsCollectionView`・ツールの版 6.4.0 を返した |
| 同じ道具に、作ったばかりの写し (git のリポジトリでない) と `verification` を行き先として渡す | どちらも終了コード 1 で拒否。前後で `git status --short` に差なし |

流していないもの: テスト 4 系統 (iOS 本体・iOS Sample・Android 本体・Android Sample) と、確認のスクリプト 2 本の実物のビルド。パッケージの制約 (Simulator・エミュレータを使わない、軽いスクリプトのテストだけ) に従い、件数と結果は証跡 (`evidence/`) の記録を読んだ。Android の利用者役の起動 (tasks 5.7) も証跡の記録だけで、再現していない。

仕様充足:

- デルタスペック 4 枚の Requirement / Scenario のうち、グループ 1〜8 に対応するものを、実装・テスト・証跡と突き合わせた。指摘 1 を除いて一致している
- tasks.md の diff はチェックの付け替えだけで、グループ 1〜8 の各タスクに対応する実装か証跡がある。グループ 9 は未チェックのまま
- 足場 (proposal.md・design.md・specs/) は commit 192a10b から変わっていない
- deviation.md は無い。記録の無い差は指摘 1 の 1 件

テスト:

- 写しの道具: 正常 (無い行き先・空の行き先・前の写しのある作業コピー・追跡していないファイル・git の状態を進めない) と、拒否 (元の欠け・リポジトリの中・リポジトリを含むディレクトリ・作業コピーでない行き先・origin の違い・シンボリックリンク経由) の両方がある。拒否のテストは、行き先の中身が変わっていないことまで見ている
- 確認のスクリプト 2 本: 切り替えごとの参照・`published` で準備を飛ばすこと・引数の範囲の外・準備の失敗でビルドを始めないこと・片方の行き先の失敗・出力をそのまま流すこと・前の回の対応表を数えないこと、をコマンドを差し替えた形で確かめている
- workflow: 入口のジョブの集合を 5 つに直し、既存の 3 つの名前と呼び方の検査は残っている。新しい 2 本の形 (呼ばれる形だけ・入力・ジョブの名前・失敗を見逃す指定が無い・Xcode を選ぶ step がビルドより前) のテストがある
- 言い訳のコメントで実質スキップしているテストは無い

設計品質:

- 検査のロジックは `scripts/ci/` のスクリプトにあり、workflow は呼ぶだけ。`コマンド | tee` は使っていない。空振りの経路 (対応表が無い・依存の一覧に座標が無い・写しにマニフェストが無い) は失敗にしている
- 外部の action は commit の ID で固定され、既存の workflow と同じ ID である。権限は内容の読み取りだけ、時間の上限あり、認証の情報を受け取らない
- 既存の `verify-ios.yml`・`verify-android.yml` に入力を足していない。`main` 宛ての Pull Request にパスの絞り込みを足していない
- 入力の検証: workflow の入力は環境変数を通して渡し、版は文字の種類を絞ってからマニフェストと Gradle の引数に使っている
- 行き先を消す道具の安全側の判定 (実体のパスでの比較・origin の完全一致・git の場所を固定する環境変数の除去) を読み、抜け道は見つからなかった
- 公開識別子: 利用者役の application ID `jp.kamusoft.kscollectionview.verification.android` は規約の形に合う
- Kotlin (利用者役の 2 ファイルと Gradle Kotlin DSL): null 安全・不変性・コメントの観点で問題は無い
- 成果物 (証跡・草稿) にローカル絶対パスは無い

## 指摘事項

### [🟡 Minor] 公開 API に現れる型を持つ 3 つの成果物が、compile の範囲に宣言されていない (記録の無い spec との差)

**該当箇所**: `android/kscollectionview/build.gradle.kts:191`、`specs/package-distribution/spec.md:100`、`evidence/android-publishing.md:141`

**問題点**: Requirement「Android の発行物」は「公開 API の宣言に現れる型を持つ依存」を compile の範囲で宣言すると書いている。証跡の洗い出しでは、公開 API に `Color` (`ui-graphics`)・`Dp` (`ui-unit`)・`@DrawableRes` (`androidx.annotation`) が現れるが、この 3 つは `api` で宣言されておらず、POM にも名前で現れない。`ui` の API の依存として利用者の compile のクラスパスに届くことは証跡で確かめてあり、ビルドが壊れる経路は見つかっていない。ただし、実装者が「直接宣言しない」と判断したことが、ビルドファイルのコメントと証跡と草稿にだけ書かれていて、deviation.md に無い。Requirement の文面どおりに読むと未充足で、verify が Scenario「依存の範囲が公開面と合う」を乖離と判定し得る。

**推奨修正**: 次のどちらかを、verify の前に決める。

- 宣言を足す: 3 つをバージョンカタログに足し、`api` で宣言する。`ui-graphics`・`ui-unit` は Compose の BOM が版を決める。`androidx.annotation` は BOM の外なので版を自分で持つことになり、利用者へ届く版が今の解決の結果 (1.9.1) と変わらないことを POM と利用者役の依存の一覧で確かめる
- 今の形を保つ: オーナーの合意を得て、deviation.md に乖離として記録する (spec では「型を持つ依存を compile の範囲で宣言する」→ 実際は「`ui` が届ける 3 つは個別に宣言しない」。理由は証跡のとおり)

どちらを選ぶかは、依存の宣言の持ち方の判断なので、指揮側がオーナーに諮る。

### [🔵 Suggestion] 確認のスクリプトのテスト 2 本だけ、テストの名前が英語である

**該当箇所**: `scripts/ci/tests/test_verify_consumer_ios.py:205`、`scripts/ci/tests/test_verify_consumer_android.py:167`

**問題点**: `scripts/ci/tests/` の既存のテストと、同じ変更で足した `test_sync_spm_snapshot.py`・`test_workflow_files.py` は、テストの名前を日本語で書いている。確認のスクリプトの 2 本 (計 95 件) だけが英語で、失敗したときの一覧で読み方が揃わない。動作には影響しない。

**推奨修正**: 手を入れる機会があれば、ほかのテストと同じ日本語の名前に揃える。本変更の完了の条件にはしない。

### [🔵 Suggestion] 利用者役の `activity-compose` の版が、Sample の版と手で合わせてある

**該当箇所**: `verification/android/app/build.gradle.kts:81`

**問題点**: コメントは「Sample が使う版と同じ」と書いているが、値は文字列で直に書いてあり (`1.11.0`)、Sample の側 (`samples/android/gradle/sample.versions.toml`) を上げても追随しない。今は一致している。食い違っても利用者役のビルドは通るので、実害は小さい。

**推奨修正**: コメントを「版はここで決める」という事実だけにするか、wrapper の一致を確かめているテスト (`test_the_wrapper_matches_the_library_build`) と同じ形で、一致を確かめるテストを足す。本変更の完了の条件にはしない。

## アクションプラン

1. 指摘 1 について、「宣言を足す」か「乖離として記録する」かをオーナーに諮って決める。宣言を足した場合は、手元への発行と POM の読み直し、Android の 2 系統のテスト、利用者役の確認を流し直す
2. 指摘 2・3 は任意。見送るなら、そのままでよい
3. 次のレビューでは、指摘 1 の結果 (足した宣言と POM、または deviation.md の行) だけを見れば足りる
