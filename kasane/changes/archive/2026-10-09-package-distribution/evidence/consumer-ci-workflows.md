# 証跡: 検証 CI の workflow (tasks 6.1〜6.4)

実施日: 2026-10-09。環境: macOS 27.0.1、Xcode 27.0 (27A266a)、Python 3.14.8、actionlint 1.7.12 (shellcheck が PATH にある状態)。

ここに書くのは、手元で確かめたことだけである。GitHub のランナーの上では、まだ 1 度も走らせていない (tasks 9 で確かめる)。生ログの全文は手元保管で、ここには判定に要る行だけを書く。

## 6.1 足した workflow

| ファイル | 形 |
|---|---|
| `.github/workflows/verify-consumer-ios.yml` | 起動は `workflow_call` だけ。入力は `mode` (文字列・必須・既定なし) と `version` (文字列・任意・既定は空)。ジョブは `verify` (名前も `verify`) の 1 つ。ランナー `xcode-27`、時間の上限 15 分、権限は `contents: read` だけ |
| `.github/workflows/verify-consumer-android.yml` | 入力・ジョブの名前・権限・時間の上限は同じ。ランナー `ubuntu-24.04` |

step は次のとおり。どの step にも条件 (`if`) と失敗を見逃す指定 (`continue-on-error`) が無いので、前の step が失敗すると、後ろは始まらない。

| workflow | step (上から順) |
|---|---|
| iOS | Checkout → Select Xcode → Show toolchain → Verify consumer |
| Android | Checkout → Setup JDK → Cache Gradle dependencies → Show toolchain → Ensure Android SDK platform → Verify consumer |

既存の検証の workflow と合わせたところ:

| 決まり | iOS | Android |
|---|---|---|
| ランナー | `verify-ios.yml` と同じ `xcode-27` | `verify-android.yml` と同じ `ubuntu-24.04` |
| 道具の版 | Xcode 27.0 (`KS_XCODE_VERSION`)。`Select Xcode` の step は `verify-ios.yml` と 1 字も違わない。`Show toolchain` は、選んだ Xcode の版が違えば失敗で終わる | JDK 21 (temurin)。コンパイル対象の SDK を確かめる step の本文は `verify-android.yml` と 1 字も違わない |
| 外部の action | `actions/checkout` だけ | `actions/checkout`・`actions/setup-java`・`actions/cache` |
| action の指定 | 既存の workflow と同じ commit の ID (対応する版をコメントに書いてある) | 同じ |
| チェックアウト | `persist-credentials: false` | 同じ |

`Verify consumer` の step は、入力を環境変数 (`KS_MODE`・`KS_VERSION`) を通してスクリプトに渡す 1 行だけである。

```
python3 scripts/ci/verify-consumer-ios.py --mode "${KS_MODE}" --version "${KS_VERSION}"
python3 scripts/ci/verify-consumer-android.py --mode "${KS_MODE}" --version "${KS_VERSION}"
```

入力の検査 (知らない切り替え・`published` で版が無い) は、workflow の step には書いていない。スクリプトが何も始めずに終了コード 2 で終わり、step が失敗する。

Android のキャッシュは、依存の解決の結果 (`~/.gradle/caches/modules-2`) と wrapper が取得する Gradle (`~/.gradle/wrapper`) だけである。キーは `gradle-consumer-` で始まり、既存の検証のキャッシュ (`gradle-deps-`) と分けてある。キーには、本体のバージョンカタログ・本体と利用者役の wrapper の設定・本体と利用者役の `*.gradle.kts` が入る。既定の手元の Maven リポジトリとビルドの出力は、キャッシュしない。

## 6.2 入口に足したジョブ

`.github/workflows/ci.yml` に、次の 2 つを足した。既存の 3 つのジョブ (`ios`・`android`・`lint`) の定義は変えていない。起動の条件・同時実行・権限も変えていない。

| ジョブ | 名前 | 条件 | 呼ぶ workflow | 渡す値 |
|---|---|---|---|---|
| `consumer-ios` | `consumer-ios` | `${{ github.event_name == 'pull_request' }}` | `./.github/workflows/verify-consumer-ios.yml` | `mode: local` だけ (版は渡さない) |
| `consumer-android` | `consumer-android` | 同じ | `./.github/workflows/verify-consumer-android.yml` | 同じ |

入口の起動は、`develop` への push と `main` 宛ての Pull Request の 2 つだけなので、この条件で走るのは `main` 宛ての Pull Request のときだけである。

## 6.3 workflow のファイルに対するテスト

`scripts/ci/tests/test_workflow_files.py` を直した。このファイルのテストは 26 件から 51 件になった (25 件を足し、1 件は名前と期待を直した)。

| クラス | 件数 | 確かめること |
|---|---:|---|
| `EntryWorkflowTest` (直した 1 件) | 1 | 入口のジョブの集合が 5 つ (`lint`・`ios`・`android`・`consumer-ios`・`consumer-android`) で、検査の名前がジョブの名前と同じである。前は 3 つを期待していた |
| `EntryWorkflowTest` (足した) | 4 | `lint` に条件が無い / 利用者の立場のビルドの確認の 2 つのジョブが、Pull Request で起動したときだけ走る条件を持ち、キーが `name`・`if`・`uses`・`with` だけである / `with` が `mode: local` だけで、版を渡していない / 呼ぶ側と呼ばれる側のジョブの名前から組み立てた検査の名前が `consumer-ios / verify`・`consumer-android / verify` になる |
| `ConsumerWorkflowTest` (新設) | 10 | 2 本に共通する形。起動が `workflow_call` だけ / 入力が `mode` (必須・既定なし) と `version` (任意・既定は空) だけ / ジョブが `verify` の 1 つ / ランナーが既存の検証と同じ / 失敗を見逃す指定が無い / workflow の定義の検査に違反が無い / スクリプトに切り替えと版を環境変数を通してそのまま渡し、後ろに何もつないでいない / 確認の step が最後にあり、どの step にも条件が無い / スクリプトを呼ぶのが 1 箇所だけ / 認証の情報を受け取らない |
| `ConsumerIosWorkflowTest` (新設) | 6 | step が決めた 4 つだけ / Xcode の版が `verify-ios.yml` と同じ / Xcode を選ぶ step が確認より前にあり、版が無ければ `DEVELOPER_DIR` を書く前に失敗で終わる / Xcode を選ぶ手順が `verify-ios.yml` と同じ / 選んだ Xcode の版を確かめる step が確認より前にある / Simulator を選ばない |
| `ConsumerAndroidWorkflowTest` (新設) | 5 | step が決めた 6 つだけ / JDK の版が `verify-android.yml` と同じ / キャッシュするのが 2 つの場所だけ / キャッシュのキーに利用者役のビルドの定義が入り、頭が `gradle-consumer-` / コンパイル対象の SDK を確かめる手順が `verify-android.yml` と同じ |

既存の 3 つのジョブの検査 (名前がジョブの名前と同じ・`ios` と `android` は `name` と `uses` だけを持つ) は、そのまま残してある。

### テストが形の崩れを拾うことの確認

workflow を 1 箇所ずつ崩して、スクリプトのテストを全件流し、戻した (13 通り。確かめた後、workflow は元の内容に戻っていて、テストは 259 件とも通る)。

| 崩し方 | 落ちたテスト |
|---|---|
| 入口の `consumer-ios` の条件を外す | `test_利用者の立場のビルドの確認はPullRequestで起動したときだけ走る` |
| 入口で版を渡す | `test_利用者の立場のビルドの確認にlocalを渡し版を渡さない` |
| 入口で `published` を渡す | 同上 |
| 入口の `ios` に条件を付ける | `test_2本の検証を入力なしで呼び条件を付けない` (既存) |
| 入口のジョブの名前を変える | `test_ジョブは決めた5つで検査の名前がジョブの名前と同じである`・`test_利用者の立場のビルドの確認の検査の名前が決めたとおりになる` |
| Android の確認の step に失敗を見逃す指定を足す | `test_失敗を見逃す指定が無い` |
| iOS の workflow に別の起動を足す | `test_他のworkflowから呼ばれる形だけを持つ` |
| iOS の切り替えの入力を任意にする | `test_切り替えを必須で版を任意で受け取る` |
| iOS の Xcode の版をずらす | `test_Xcodeの版が既存の検証と同じである` |
| iOS の確認のコマンドの後ろに `|| true` をつなぐ | `test_確認のスクリプトに切り替えと版をそのまま渡す` |
| Android の JDK の版をずらす | `test_JDKの版が既存の検証と同じである` |
| iOS の Xcode を選ぶ step を確認の後ろへ動かす | `test_stepは決めた4つだけである`・`test_決めた版のXcodeが無ければビルドの前に止まる`・`test_確認のstepは最後に条件なしで走る` |
| Android の時間の上限を消す | `test_workflowの定義の検査に違反が無い`。workflow の定義の検査 (`scripts/ci/check-workflows.py`) も、終了コード 1 で「ジョブ verify: 時間の上限 (timeout-minutes) が無い」と報告した |

最後の行は、最初に流したときはどのテストも落ちなかった (時間の上限は、定義の検査だけが確かめていた)。`test_workflowの定義の検査に違反が無い` を足してから流し直した結果を、表に書いている。

## 6.4 手元で流した結果

| 流したもの | 結果 |
|---|---|
| `python3 scripts/ci/run-tests.py` | 実行 259 件 / 失敗 0 件 / スキップ 0 件 (14 秒)。この担当範囲の前は 234 件 |
| `python3 scripts/ci/check-workflows.py` | 確かめた workflow: 5 本 (uses 13 箇所 / runs-on 5 箇所 / permissions 5 箇所)。違反は無い。この担当範囲の前は 3 本 (uses 7 箇所 / runs-on 3 箇所 / permissions 3 箇所) |
| `actionlint` (リポジトリのルートで、引数なし) | 終了コード 0、出力なし。5 本を読んでいる (`-verbose` で確かめた) |
| `python3 scripts/local-path-lint.py` / `python3 scripts/identity-lint.py` / `python3 scripts/comment-policy-lint.py` | どれも終了コード 0 (コメントの規約は、禁止 0 件・検査対象 502 ファイル) |

`scripts/ci/check-workflows.py` は変えていない。新しい 2 本と、入口の `with` を持つジョブを、今のままで読み取れた。

### workflow と同じコマンドを手元で流した結果

`Verify consumer` の step の本文を、入口が渡すのと同じ値 (`KS_MODE=local`、`KS_VERSION` は空の文字列) で、そのまま流した。

| コマンド | 終了コード | 所要 | 判定に要る行 |
|---|---:|---|---|
| `python3 scripts/ci/verify-consumer-ios.py --mode "${KS_MODE}" --version "${KS_VERSION}"` | 0 | 30 秒 | 配布物への参照は `.package(path: "../KsCollectionView-SPM"),`。Simulator 向け・実機向けとも `** BUILD SUCCEEDED **` |
| `ANDROID_HOME=<Android SDK の場所> python3 scripts/ci/verify-consumer-android.py --mode "${KS_MODE}" --version "${KS_VERSION}"` | 0 | 5 秒 | 発行・組み立て・依存の一覧とも `BUILD SUCCESSFUL`。依存の一覧に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` |

空の文字列の版は、渡していないのと同じに扱われた (iOS は版を使わず、Android は本体のバージョンカタログの版を使った)。Android の 5 秒は、Gradle のデーモンが動いていて、ビルドの出力と依存の取得が残っている状態の値である。

範囲の外の入力を、同じ形のコマンドで渡した結果:

| 渡した値 | 終了コード | 出力 |
|---|---:|---|
| iOS、`--mode "published" --version ""` | 2 | `::error::--mode published では --version が必須である (取る版を決められない)` |
| Android、`--mode "smoke" --version ""` | 2 | `::error::--mode は local か published のどちらかにする: 'smoke'` |

これらの実行の後、git が追跡しているファイルに、この担当範囲で変えたもの以外の変更は無い。

### 決めた版の Xcode が無いときの確認

`verify-consumer-ios.yml` の `Select Xcode` の step の本文を取り出し、手元に無い版 (`KS_XCODE_VERSION=99.9`) と、空の一時のファイルを指す `GITHUB_ENV` を渡して bash で流した。

| 結果 | 値 |
|---|---|
| 終了コード | 1 |
| 出力 | `::error::Xcode 99.9 がランナーに無い` に続けて、手元にある Xcode の一覧 |
| `GITHUB_ENV` に書かれた行 | 0 行 (`DEVELOPER_DIR` を書く前に終わっている) |

step が失敗すれば、後ろの step (`Show toolchain`・`Verify consumer`) は始まらない (どの step にも条件が無い)。

## 確かめていないこと

- ランナーの上での実行のすべて。5 つの検査が決めた名前で報告されること、`develop` への push で利用者の立場のビルドの確認が走らない (ジョブが飛ばされる) こと、所要時間 (tasks 9.1・9.2・9.5)
- `Select Xcode` の step が Xcode を選べる側の枝。手元の Xcode は `/Applications/Xcode_<版>.app` の名前で置いていないので、手元ではこの枝を通せない。同じ本文の step が、既存の `ios / verify` でランナーの上で通っている
- ランナー (`xcode-27`) の `python3` の版。スクリプトは Python の標準のライブラリだけを使う。`Show toolchain` の step が、両方の workflow で版を表示する
- ランナー (Linux) の上での、利用者役のリリースの組み立てと、依存を 1 から取得する状態での所要時間
- `published` を渡して呼んだときの取得の実行 (公開物がまだ無い)
- Android のキャッシュが、ランナーの上で復元・保存されること
- 時間の上限 15 分が足りるかどうか (暫定の値。tasks 9.5 で決め直す)
