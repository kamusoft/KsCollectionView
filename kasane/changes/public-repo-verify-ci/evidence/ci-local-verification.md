# 手元の確認 (workflow と公開の前の確認)

tasks のグループ 4・5 で確かめたことの記録。日付はすべて 2026-10-08。生の記録の全文は手元保管で、ここには件数と結果だけを書く。

環境: Xcode 27.0、作業専用に作った Simulator (iPhone 17・iOS 27.0。確認の後に削除した)、JDK 21、Android SDK Platform 36。

## 4.1 iOS Sample をユニットテストだけに絞る

スキームとテストプランは変えていない。通常の検証のスキーム `KsCollectionViewSamples` に `-only-testing:KsCollectionViewSamplesTests` を付けて流した (`samples/ios/` で実行。workflow の step と同じコマンド)。

| 確かめたこと | 結果 |
|---|---|
| `xcodebuild test` の終了コード | 0 (`** TEST SUCCEEDED **`) |
| 走ったテストのまとまり (`.xctest`) | `KsCollectionViewSamplesTests.xctest` の 1 つだけ |
| 始まったテストの件数 (`Test Case ... started` の行) | 37 |
| そのうち UI テストのターゲットのもの | 0 |
| 件数の集計の行 | 出る: `Executed 37 tests, with 0 failures (0 unexpected)` |
| 件数の検査 (`scripts/ci/check-ios-test-count.py`) | 通る。集計 37 / スキップ 0 / 実行 37 |

UI テストのターゲットとアプリは、スキームのビルドの対象なのでビルドはされる (記録にビルドの行がある)。絞り込みなしで流すと 48 件 (ユニットテスト 37 + UI テスト 11) なので、差の 11 件が UI テストである (5.4)。

件数の検査のスクリプトは、`xcodebuild test` の実物の記録を、本体と Sample のどちらも正しく読めた。入れ子のまとまりのうち、いちばん外側の集計の行だけを数えている。スクリプトの修正は要らなかった。

## 4.5 workflow の定義の検査

| 検査 | 結果 |
|---|---|
| actionlint 1.7.12 (shellcheck による `run` の検査を含む) | 指摘 0 件 |
| `python3 scripts/ci/check-workflows.py` | 違反なし。workflow 3 本 (uses 7 箇所 / runs-on 3 箇所 / permissions 3 箇所) |

actionlint は、ランナーの名前 `xcode-27` を知らない名前として弾いた (actionlint が持つ一覧にまだ無い)。`.github/actionlint.yaml` にこの名前を登録して通した。

外部の action の commit の ID は、タグが指す commit と一致することを `git ls-remote` で確かめた (actions/checkout v7.0.1、actions/setup-java v6.0.0、actions/cache v6.1.0)。

## 5.1 workflow と同じコマンドでの件数

workflow の step と同じコマンドを手元で流した。違いは 3 つ。Simulator は、選ぶスクリプトの結果ではなく作業専用のものを指定した。Android SDK の場所は環境変数で渡した。結果の置き場を空にする操作は、`rm -rf` の代わりにごみ箱へ移すコマンドで行った。

| 系統 | コマンドの終了コード | 件数の検査 | 集計 | スキップ | 実行 | 失敗 |
|---|---:|---|---:|---:|---:|---:|
| iOS 本体 | 0 | 通る | 567 | 0 | 567 | 0 |
| iOS Sample (ユニットテストだけ) | 0 | 通る | 37 | 0 | 37 | 0 |
| Android 本体 | 0 | 通る | 512 | 0 | 512 | 0 |
| Android Sample (アプリの組み立てとユニットテスト) | 0 | 通る | 163 | 0 | 163 | 0 |

Android は、結果のクラスの数とソースのテストのクラスの数が一致した (本体 31 / 31、Sample 21 / 21)。

あわせて確かめたこと:

| 確かめたこと | やり方 | 結果 |
|---|---|---|
| 前の実行の結果は数えない | 結果の置き場に、1000 件を名乗る偽の結果のファイルを置いてから、空にする → テスト → 件数の検査の順で流した | 偽のファイルは数えられず、件数は上の表のとおり。空にする前に検査すると、偽の 1000 件が足されることも確かめた |
| 結果のファイルが無いと落ちる | Android SDK の場所が誤っていてビルドが始まらない状態で、件数の検査まで流した | Gradle は失敗で終わり、件数の検査も「結果のファイルが無い」で失敗した |
| 決めた版の Xcode が無いと落ちる | `Select Xcode` の step の本文をそのまま流した (手元の Xcode は、ランナーと置き場の名前が違う) | 失敗で終わり、その版が無いことが示された |
| 決めた版の Xcode があれば選ぶ | 同じ本文を、置き場だけ模したディレクトリに向けて流した (27.0 の 2 つと、26.4・27.1 を置いた) | 27.0 のうちパッチが新しいほうを選んだ |
| 選んだ Xcode の版が違うと落ちる | `Show toolchain` の step の本文を、決めた版だけ変えて流した | 失敗で終わり、実際の版が示された |
| Android SDK の確認 | `Ensure Android SDK platform` の step の本文をそのまま流した | SDK があれば通り、`ANDROID_HOME` が無ければ失敗で終わる。版 (36) はバージョンカタログから読めた |
| Simulator を選ぶ | `python3 scripts/ci/select-simulator.py` を、実物の一覧に対して流した | iOS 27.0 の iPhone を 1 つ選んだ |

## 5.2 lint の異常系 (一時のツリー)

追跡中のファイルと、これから追跡するファイル (合わせて 1173 ファイル) を、リポジトリの外の一時の場所に取り出し、そこに一時の git リポジトリを作って確かめた。場合ごとに新しいツリーを作り、違反を 1 つだけ置いて commit した。流したのは、`.github/workflows/ci.yml` の step の `run` の本文そのもの (取り出して `bash -e` で実行。環境変数は workflow と同じ名前で渡した)。本リポジトリには commit も違反も作っていない。

手元 (macOS arm64・Python 3.14・git 2.54) と、Linux のコンテナ (`ubuntu:24.04`・x86_64・Python 3.12・git 2.43) の両方で流した。

| 場合 | 流した step | macOS | Linux | 止まり方 |
|---|---|---:|---:|---|
| secret を含む (その場で作った、鍵の形の乱数 2 つ) | Secret scan (gitleaks) | 失敗 (1) | 失敗 (1) | `leaks found: 2` |
| ローカル絶対パスを含む | Local absolute path lint | 失敗 (1) | 失敗 (1) | 違反の報告 |
| 個人を特定する値を含む (`kasane/` の下に、その場で作った UUID) | Identity lint | 失敗 (1) | 失敗 (1) | 違反の報告 |
| コメントの規約に反する (作業文書のパスを指すコメント) | Comment policy lint | 失敗 (1) | 失敗 (1) | 禁止 1 件 |
| 取り出したファイルが追跡中より少ない (取り出しから外す指定を置いた) | Secret scan (gitleaks) | 失敗 (1) | 失敗 (1) | 「走査の対象を取り出せていない (追跡中 1175 に対し 1174)」。走査は始まっていない |
| 取り出しそのものが失敗する (commit の無いリポジトリ) | Secret scan (gitleaks) | 失敗 (128) | 失敗 (2) | 取り出しのパイプで止まる。走査は始まっていない |
| チェックサムが合わない (決めた値を 0 の並びに変えた) | Install gitleaks | 判定できない | 失敗 (1) | チェックサムの照合で止まる。配布物は展開されていない |
| スクリプトのテストに失敗するものがある | CI script tests | 失敗 (1) | 失敗 (1) | `FAILED (failures=1)` |
| workflow の定義の違反 (書き込みの権限・最新を指すランナー・タグで指定した action) | Workflow definition check | 失敗 (1) | 失敗 (1) | 3 件とも場所つきで示された |
| `main` 宛ての Pull Request の出どころが `develop` でない | Pull request head restriction | 失敗 (1) | 失敗 (1) | 理由の表示 |
| `main` 宛ての Pull Request の出どころが別のリポジトリ | Pull request head restriction | 失敗 (1) | 失敗 (1) | 理由の表示 |

「チェックサムが合わない」が macOS で判定できないのは、macOS の `sha256sum` が照合のオプションの一部を受け付けず、チェックサムが正しくても step が失敗するためである。この step は Linux のランナーでだけ走る。Linux では、正しいチェックサムで成功し (`OK`)、誤ったチェックサムで失敗した (`FAILED`)。取得した配布物の SHA-256 は、macOS で別のコマンドで計算しても決めた値と一致した。

取り出しの失敗の終了コードが OS で違うのは、空の入力を受けた `tar` の振る舞いの違いによる。どちらも走査の前に失敗で終わる。

## 5.3 Linux のコンテナでの lint とスクリプトのテスト

5.2 と同じ一時のツリー (違反なし) で、lint のジョブの step を上から順に流した。Linux では、`Install gitleaks` の step が取得した gitleaks (決めた版の linux_x64 の配布物) を使った。macOS では、同じ版 (8.30.1) の手元の gitleaks を使った。

| step | macOS | Linux | 出力の要点 (両方で同じ) |
|---|---:|---:|---|
| Pull request head restriction | 0 | 0 | push での起動のため確かめない |
| Install gitleaks | (対象外) | 0 | チェックサムの照合が `OK` |
| Secret scan (gitleaks) | 0 | 0 | 走査の対象 1173 ファイル (追跡中 1173)。約 10.88 MB を走査して検出なし |
| Local absolute path lint | 0 | 0 | 違反なし |
| Identity lint | 0 | 0 | 違反なし |
| Comment policy lint | 0 | 0 | 禁止 0 件 (検査の対象 494 ファイル) |
| CI script tests | 0 | 0 | 実行 115 件 / 失敗 0 件 / スキップ 0 件 |
| Workflow definition check | 0 | 0 | workflow 3 本、違反なし |

検査の対象の数と結果は、macOS と Linux で一致した。コンテナは、確認の後に止めて、取得したイメージも消した。

## 5.4 テスト 4 系統 (絞り込みなし)

4 系統を順に流した。Android は `--rerun-tasks` を付けた。

| 系統 | 結果 | 実行 | 失敗 | スキップ | 所要 |
|---|---|---:|---:|---:|---:|
| iOS 本体 | 成功 | 567 | 0 | 0 | 159 秒 |
| iOS Sample | 成功 | 48 (ユニットテスト 37 + UI テスト 11) | 0 | 0 | 184 秒 |
| Android 本体 | 成功 | 512 (31 クラス) | 0 | 0 | 33 秒 |
| Android Sample | 成功 | 163 (21 クラス) | 0 | 0 | 14 秒 |

合計は 390 秒 (6 分 30 秒) で、10 分の上限に収まる。件数は、本変更の前の記録 (567・48・512・163) と同じである。iOS Sample の件数に、計測用のドライバは含まれていない。

## 確かめていないこと

- GitHub のランナーの上での実行 (3 本の workflow そのもの)。Xcode の置き場の名前、Simulator の有無、署名なしでの Sample のビルド、Android SDK の有無と取得の手順、キャッシュは、tasks 7.4 の最初の実行で確かめる
- Android SDK Platform が無いときの取得の手順 (`sdkmanager` を呼ぶ側の枝)。手元とコンテナでは流していない
- 各ジョブの時間の上限は暫定の値である (lint 10 分・iOS 40 分・Android 30 分)。tasks 8.3 で実測から決め直す
- gitleaks のチェックサムと、公式のチェックサムの一覧との突き合わせ。取得した配布物の実物とは一致している

## レビュー後の追記 (2026-10-08)

gitleaks のチェックサムを、公式のリリースの記録と突き合わせた (上の「確かめていないこと」の 4 つ目を解消)。

- 読んだもの: gitleaks の公式リポジトリの v8.30.1 のリリースの、配布物ごとの SHA-256 (`gh api repos/gitleaks/gitleaks/releases/tags/v8.30.1` の `assets[].digest`)。配布物そのものは取得していない
- 結果: `gitleaks_8.30.1_linux_x64.tar.gz` の値は、入口の workflow に固定した値 (`551f6fc8…2470eb`) と一致した
- 1 周目のレビューの指摘の修正の後、スクリプトのテストは 115 件から 123 件になった (失敗 0・スキップ 0。macOS で実行)。足した 8 件は、Android のテストのクラスの導き方 5 件と、版を読み取れないランナー名 3 件。修正後の Linux のコンテナでの再実行はしていない
- 2 周目のレビューの指摘の修正の後、スクリプトのテストは 123 件から 128 件になった (失敗 0・スキップ 0。macOS で実行)。足した 5 件は、Android のテストの印の書き方 (ほかの注釈の後ろ・クラスの宣言と同じ行・行頭) の回帰テストで、修正前のスクリプトに掛けると落ちることを確かめてある。実物のソースから導かれるクラスは本体 31・Sample 21 のまま。修正後の Linux のコンテナでの再実行はしていない
- 時間の上限の検査を足した後 (deviation.md の付随修正)、スクリプトのテストは 128 件から 133 件になった (6 件を足し、重なる 1 件を消した。失敗 0・スキップ 0。macOS で実行)。workflow の定義の検査は 3 本で違反なし。Linux のコンテナでの再実行はしていない
