# 証跡: iOS のマニフェストと SwiftPM の写し (tasks 1.1・2.4)

実施日: 2026-10-09。環境: macOS 27.0.1、Xcode 27.0 (27A266a、Swift 6.4)。

生ログの全文は手元保管で、ここには要約行だけを書く。

## 1.1 宣言を Swift 6.4 に上げた状態での iOS のテスト

`ios/Package.swift` の先頭を `// swift-tools-version: 6.4` に変えた後に、絞り込みなしで流した。

Simulator は、この作業のために新しく作った iPhone 17・iOS 27.0 の 1 台 (名前 `ksn-package-distribution-iPhone-17`) を使い、2 系統を流し終えた後に削除した。

| 系統 | コマンド (作業ディレクトリ) | 実行 | 失敗 | スキップ | 所要 (ビルド込み) |
|---|---|---:|---:|---:|---|
| iOS 本体 | `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug -collect-test-diagnostics never` (`ios/`) | 567 | 0 | 0 | 3 分 43 秒 |
| iOS Sample | `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,id=<uuid>' -configuration Debug -collect-test-diagnostics never` (`samples/ios/`) | 48 (ユニットテスト 37 + UI テスト 11) | 0 | 0 | 3 分 32 秒 |

出力の要約行:

```
# iOS 本体
	 Executed 567 tests, with 0 failures (0 unexpected) in 173.498 (173.685) seconds
** TEST SUCCEEDED **

# iOS Sample
Test Suite 'KsCollectionViewSamplesTests.xctest' passed
	 Executed 37 tests, with 0 failures (0 unexpected) in 0.416 (0.430) seconds
Test Suite 'KsCollectionViewSamplesUITests.xctest' passed
	 Executed 11 tests, with 0 failures (0 unexpected) in 171.841 (171.861) seconds
** TEST SUCCEEDED **
```

- 件数は、宣言を上げる前の記録 (`kasane/handbook/cross/verification-ci.md` の「件数の読み方」: 本体 567・Sample 48) と同じである
- スキップ 0 は、出力にテストのスキップの行が無いことで確かめた
- 所要は、新しく作った Simulator の最初の起動と、ビルドの出力がある状態からの差分ビルドを含む

## 2.4 手元で写しを作り、写しをルートとして SwiftPM が解決できること

行き先は、リポジトリの外の一時のディレクトリの下の、まだ無いパス `KsCollectionView-SPM` にした。

```
$ python3 scripts/distribution/sync-spm-snapshot.py <一時のディレクトリ>/KsCollectionView-SPM
写しを作った: <一時のディレクトリ>/KsCollectionView-SPM (Sources 93 ファイル / Tests 45 ファイル)
```

| 確かめたこと | 結果 |
|---|---|
| 行き先の直下 | `LICENSE`・`Package.swift`・`README.md`・`Sources`・`Tests` の 5 つだけ |
| ファイルの数 | 141 (Sources 93 + Tests 45 + 直下の 3)。`git ls-files ios` の 139 から、`ios/Package.swift` の 1 を引いた 138 と一致する |
| 写しの大きさ | 展開した状態で 1748 KB (約 1.7 MB。`du -sk`) |
| マニフェスト | `cmp` で `ios/Package.swift` と一致 |
| 写しをルートにした依存の解決 | `swift package resolve` が成功 (終了コード 0)。Nuke を 13.2.0 に解決した |
| 写しをルートにしたパッケージの読み取り | `swift package describe` が、名前 `KsCollectionView`・Tools version 6.4・対象 iOS 16.0・product `KsCollectionView` を返した |
| 写しをルートにしたビルド (タスクが求める範囲の外の、追加の確認) | 写しの中で `xcodebuild build -scheme KsCollectionView -destination "generic/platform=iOS Simulator" -configuration Release` が成功 (`** BUILD SUCCEEDED **`、16 秒) |

大きさとファイルの数は、依存を解決する前に測った (解決すると、写しの中に `.build/` と `Package.resolved` ができる)。

実物のリポジトリに対して、拒否される行き先も 3 つ流した。どれも終了コード 1 で、追跡しているファイルに変更は無かった (`git status --short` で確認)。

| 行き先 | 出力 |
|---|---|
| 上で作った写し (中身があり、git のリポジトリではない) | `エラー: 行き先に中身があり、配信用リポジトリ (kamusoft/KsCollectionView-SPM) の作業コピーでもない: … (git のリポジトリではない)` |
| `ios/DerivedData` (このリポジトリの中) | `エラー: 行き先がこのリポジトリの中にある: …` |
| `..` (このリポジトリを含むディレクトリ) | `エラー: 行き先がこのリポジトリを含むディレクトリである: …` |

## 道具のテスト (tasks 2.3)

`python3 scripts/ci/run-tests.py` — 実行 139 件 / 失敗 0 件 / スキップ 0 件 (この変更の前は 111 件。足したのは `scripts/ci/tests/test_sync_spm_snapshot.py` の 28 件)。

テストが判定を実際に見ていることは、道具の判定を 1 つずつ無効にして、対応するテストが落ちることで確かめた (作業ツリーのファイルは変えず、テストの実行の中で差し替えた)。

| 無効にした判定 | 落ちたテスト |
|---|---|
| git の場所を固定する環境変数を外す処理 | `test_gitの場所を固定する環境変数があっても行き先そのものを確かめる` |
| リポジトリの中・外側の判定 | `test_このリポジトリの中を行き先にすると拒否する` (5 つの行き先すべて)・`test_このリポジトリを含むディレクトリを行き先にすると拒否する` (2 つとも)・`test_シンボリックリンクでこのリポジトリの中を指す行き先を拒否する`・`test_ファイルシステムのルートは何でも含むと判定する` |
| origin の突き合わせ | `test_originが配信用リポジトリでない作業コピーを拒否する` (5 つの origin すべて) |
| 追跡しているファイルに絞る処理 | `test_追跡していないファイルは写されない`・`test_元が欠けていると何も消さない` (追跡に関わる 2 つの場合) |

### 修正サイクル 1 回目で足した確認 (2026-10-09)

道具に、行き先の git の管理情報が、消す対象 (行き先の直下の `.git` 以外) の中に無いことの確認を足した。`.git` が行き先の中の別のディレクトリを指すファイルになっている作業コピー (`git init --separate-git-dir` で管理情報を行き先の中に置いた形) は、最上位と origin の確認を通ったうえで、管理情報の実体が消されていた。

`python3 scripts/ci/run-tests.py` — 実行 261 件 / 失敗 0 件 / スキップ 0 件 (修正の前は 259 件。足したのは `test_sync_spm_snapshot.py` の 2 件で、このファイルは 30 件になった)。

| 足したテスト | 確かめること |
|---|---|
| `test_gitの管理情報が行き先の中の別のディレクトリにある作業コピーを拒否する` | 終了コード 1 で終わり、行き先の中身 (管理情報の実体を含む)・HEAD・commit の数・tag・ブランチ・origin が変わらず、commit した内容を取り出せる |
| `test_gitの管理情報が行き先の外にある作業コピーは受け付ける` | 管理情報が行き先の外にある作業コピーには写しを作り、git の状態を進めない |

足した確認を無効にして 1 件目を流すと、道具が終了コード 0 で写しを作り、テストが落ちた (作業ツリーのファイルは変えず、テストの実行の中で差し替えた)。

### 修正サイクル 2 回目で足した確認 (2026-10-09)

道具に、行き先の git の管理情報の場所 (管理ディレクトリと、共通の管理ディレクトリ) が、行き先そのものでないことの確認を足した。行き先の直下に `HEAD`・`config`・`objects`・`refs` が並び、`.git` が行き先自身を指すファイル (`gitdir: .`) になっている作業コピー (`core.bare=false`・`core.worktree=.`) は、管理情報の場所がどの子ディレクトリの「中」にも当たらないので、1 回目に足した確認を通って、管理情報の実体が消されていた。

`python3 scripts/ci/run-tests.py` — 実行 262 件 / 失敗 0 件 / スキップ 0 件 (修正の前は 261 件。足したのは `test_sync_spm_snapshot.py` の 1 件で、このファイルは 31 件になった)。

| 足したテスト | 確かめること |
|---|---|
| `test_gitの管理情報の場所が行き先そのものである作業コピーを拒否する` | 終了コード 1 で終わり、行き先の中身 (直下に並ぶ管理情報の実体を含む)・HEAD・commit の数・tag・ブランチ・origin が変わらず、commit した内容を取り出せる |

確認を足す前の道具でこのテストを流すと、道具が終了コード 0 で写しを作り、テストが落ちた。

確かめる範囲は、管理ディレクトリと共通の管理ディレクトリの場所までと決めて、道具の説明と草稿 (`drafts/package-distribution.md`) に書いた。その外の構成には確認を足していない。使い捨ての作業コピーで、次の構成が今も確認を通ることを見た。

| 構成 | 結果 |
|---|---|
| 管理ディレクトリの中の `objects` が、行き先の中の別のディレクトリを指すシンボリックリンク | 終了コード 0 で「写しを作った」と出るが、その後 `git log` が失敗する |

同じ日の、この修正の後の lint と検査: `local-path-lint.py`・`identity-lint.py` は終了コード 0、`comment-policy-lint.py` は禁止 0 件 (検査対象 502 ファイル)、`check-workflows.py` は違反なし (workflow 5 本)。

## 標準の lint と workflow の定義の検査

| コマンド | 結果 |
|---|---|
| `python3 scripts/local-path-lint.py` | 終了コード 0 |
| `python3 scripts/identity-lint.py` | 終了コード 0 |
| `python3 scripts/comment-policy-lint.py` | 禁止 0 件 (検査対象 494 ファイル) |
| `python3 scripts/ci/check-workflows.py` | 違反は無い (workflow 3 本) |

## 確かめていないこと

- Android の 2 系統 (本体・Sample) のテストは、この担当範囲 (iOS のマニフェストと `scripts/`) では流していない
- 本物の配信用リポジトリの作業コピーを行き先にした実行 (配信用リポジトリはまだ無い)。作業コピーを行き先にした形は、道具のテストが使い捨ての git リポジトリで確かめている
- Linux の上での道具のテストの実行 (検証 CI の lint のジョブが流す)。手元は macOS だけである
