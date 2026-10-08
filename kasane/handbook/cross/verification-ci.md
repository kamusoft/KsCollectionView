---
kind: guide
applies-when:
  always: false
  paths: [".github/workflows/**", ".github/actionlint.yaml", "scripts/ci/**"]
  tasks: [検証 CI の失敗の調査, 検証 CI への検査の追加・変更, CI の緑を完了の根拠に使う判断]
title: 検証 CI
description: 検証 CI が走る時点・走らせる範囲・緑が保証する範囲、失敗したときの見方、手元での確かめ方、既知の制限、検査を足すときの注意
timestamp: 2026-10-08
---

# 検証 CI

この文書は、GitHub Actions の検証 CI が、いつ・何を走らせ、緑 (3 つの検査がすべて成功で終わった状態) が何を保証するかをまとめる。失敗したときにどこを見るか、手元でどう確かめるか、検査が届かない範囲はどこかも、ここに書く。workflow や `scripts/ci/` を変えるときは、末尾の「検査を足すときの注意」を先に読む。

走らせる範囲と、緑が保証する範囲を決めた理由は [cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md) にある。workflow の構成と、検査の名前を固定した理由は [cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md) にある。

## 走る時点

| 起動 | 走るもの | 変更したパスでの絞り込み |
|---|---|---|
| `develop` への push | `lint`・`ios / verify`・`android / verify` | あり。`kasane/` 配下・Issue のフォーム・貢献の案内だけを変えた push では起動しない |
| `main` 宛ての Pull Request (作成と更新) | 同じ 3 つ | なし。変更したパスに関わらず走る |

`main` 宛ての Pull Request で絞り込まないのは、3 つが `main` の保護の必須の検査だからである。絞り込むと、必須の検査が走らないまま通る経路ができる。

同じブランチ、または同じ Pull Request で新しい実行が始まると、走っている古い実行は打ち切られる。起動しない push は、走っている実行に影響しない。

起動しない push に入った lint の違反は、次に起動した回か、`main` 宛ての Pull Request で見つかる。push した時点で内容は公開されるので、本命は手元の commit 時と push 時の検査である。

### 実地の確認 (2026-10-08)

検証が走っている間に、`develop` へ push を重ねて確かめた。

| 重ねた push | 結果 |
|---|---|
| `kasane/` の下だけを変えた commit | 25 秒後の実行の一覧に新しい実行は無く、走っている実行はそのまま続いた |
| 起動の対象になる commit | 新しい実行が作られ、走っていた実行は打ち切り (`cancelled`) で終わった。新しい実行は 3 つとも成功した |

打ち切りは、すぐには反映されない。新しい実行が作られてから、古い実行のジョブが止まるまでに 50 秒ほどかかった。その間、古い実行は走っている表示のままで、新しい実行は待ちの状態だった。新しい実行のジョブは、古い実行が止まった後に始まった。

打ち切りの前に終わっていたジョブ (この回は `lint`) は成功のまま残り、走っていた 2 つのジョブが打ち切りになった。

## 構成

| ファイル | 役割 |
|---|---|
| `.github/workflows/ci.yml` | 入口。起動の条件・同時実行・権限を持ち、lint のジョブを自分で持ち、下の 2 本を呼ぶ |
| `.github/workflows/verify-ios.yml` | iOS の検証。他の workflow から、入力を渡さずに呼べる |
| `.github/workflows/verify-android.yml` | Android の検証。同上 |
| `scripts/ci/*.py` | 検査のロジック。workflow はこれを呼ぶだけにしてある |
| `scripts/ci/tests/` | スクリプトと、workflow・公開リポジトリの体裁のファイルに対するテスト |
| `.github/actionlint.yaml` | 手元の actionlint の設定 |

検査の名前は `lint`・`ios / verify`・`android / verify` の 3 つに固定してある ([cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md))。`main` の保護がこの名前を参照する ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))。

使う道具は版を固定している。ランナーは `ubuntu-24.04` と `xcode-27`、Xcode は 27.0、JDK は 21、gitleaks は 8.30.1 である。値の正は workflow のファイルで、ここに書いた値は 2026-10-08 時点の写しである。権限は、リポジトリの内容の読み取りだけである。

## 走らせる範囲

### lint

次の step を上から順に走らせ、どれか 1 つでも失敗すれば `lint` が失敗で終わる。

| step | 確かめること |
|---|---|
| Pull request head restriction | `main` 宛ての Pull Request の出どころが、同じリポジトリの `develop` であること。push での起動では確かめない |
| Install gitleaks | gitleaks の配布物を取得し、チェックサムが決めた値と合うこと |
| Secret scan (gitleaks) | 追跡中の内容を取り出した先に、secret として検出される値が無いこと |
| Local absolute path lint | ローカル絶対パスが無いこと |
| Identity lint | 個人・端末を特定する値が無いこと (範囲は `kasane/config.yaml` の `lint.identity.scope`) |
| Comment policy lint | ソースのコメントが規約に反していないこと |
| CI script tests | `scripts/ci/tests/` のテストが全件通ること |
| Workflow definition check | workflow の定義が、道具の固定と権限の決まりを守り、ランナーで走るジョブが時間の上限を持つこと |

文書の構造の検査は入れていない。

### ios / verify

1. 決めた版の Xcode を選ぶ。無ければ、ビルドを始める前に失敗で終わる
2. 本体と、本体のテストのコードをビルドする (`ios/` で `xcodebuild build-for-testing -scheme KsCollectionView`)
3. Sample のアプリと、Sample のテストのコード (ユニットテストと UI テストの両方のターゲット) をビルドする (`samples/ios/` で、通常の検証のスキームに `xcodebuild build-for-testing`)

本体のビルドが落ちても、Sample のビルドは走る。合否は `xcodebuild` の終了コードで決まる。

2026-10-08 のランナーでは、workflow の探し方 (`Xcode_27.0*.app`) に `Xcode_27.0.0.app` が当たって選ばれた。ビルドの記録に出る実体の場所は `Xcode_27.app` である。チームの指定なしで、Sample の Simulator 向けのビルドができた。

**iOS のテストは、CI では 1 件も走らない。** テストのコードがコンパイルできることまでを確かめ、実行はしない。Simulator も選ばず、起動もしない。ビルドの行き先は、特定の端末を指さない総称の指定 (`generic/platform=iOS Simulator`) である。iOS のテストの実行と実行件数の確認は、手元の完了判定 ([テスト実行規約](test-execution.md)) が本命である。

走らせない理由: `develop` での最初の実行で、手元では通る本体のテスト 1 件が、ランナーの Simulator の上で落ちた。CI の上で Simulator を使うテストを続けると、テストの中身と関係の無い不安定さで検査が落ち続けると判断し、やめた。この判断は [cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md) に決定として残してある。Simulator を使うテストを CI に戻すときは、この決定を先に見直す。

CI から外した後に、今のコードで iOS のテストが手元で通ることを確かめた (2026-10-08、絞り込みなし。Xcode 27.0、iPhone 17・iOS 27.0 の Simulator)。本体は実行 567・失敗 0・スキップ 0、Sample は実行 48 (ユニットテスト 37 + UI テスト 11)・失敗 0・スキップ 0 だった。

### android / verify

1. JDK 21 を入れ、コンパイル対象の Android SDK がランナーに無ければ取得する
2. テストの結果の置き場を空にする (前の実行の結果を数えないため)
3. 本体のデバッグのユニットテストを全件流す
4. Sample のアプリを組み立て、デバッグのユニットテストを流す。計測用のモジュールは対象にしない
5. 本体と Sample の実行の件数と、テストのクラスの突き合わせを確かめる

本体のテストが落ちても、Sample の検証は走る。

2026-10-08 のランナー (`ubuntu-24.04`) には、コンパイル対象の Android SDK (Platform 36) があった。そのため、SDK を取得する枝は、ランナーの上で 1 度も通っていない (下の「確かめ方の限界」)。

## 緑が保証する範囲

次の表の左右の列は、それぞれ別の一覧である。同じ行の左と右は対応しない。

| 緑が言えること | 緑では言えないこと (手元の完了条件に残る) |
|---|---|
| iOS 本体と、本体のテストのコードがビルドできた | iOS のテストが通った (本体の全件・Sample のユニットテスト・Sample の UI テストのどれも、CI では走らない) |
| iOS の Sample のアプリと、Sample のテストのコード (ユニットテスト・UI テスト) がビルドできた | 端末をつないで走らせるテストが通った |
| Android 本体のデバッグのユニットテストが全件通った | 性能検証を通った |
| Android の Sample がビルドでき、デバッグのユニットテストが通った | Xcode 27 以外でビルドできる |
| Android は、実行の件数が本体と Sample のそれぞれで 0 でなく、テストのソースにあるテストのクラスがすべて結果に現れた | iOS の実機向けにビルドできる (Simulator 向けのビルドだけを確かめている) |
| lint の step がどれも成功した (上の「lint」の表) | Android のリリースのユニットテストが通る (デバッグだけを流している) |

CI の緑は、手元の完了判定の緑と同じ意味ではない。とくに iOS は、緑でもテストは 1 件も走っていない。完了の判定には、[テスト実行規約](test-execution.md) の 4 系統の全件実行を使う。iOS の 2 系統 (本体・Sample) は、手元で流さなければどこでも走らない。

### 件数の読み方

CI が件数を出すのは Android だけである。iOS はテストを実行しないので、件数が無い。

| 系統 | CI の件数 | 手元の全件実行の件数 |
|---|---:|---:|
| iOS 本体 | なし (ビルドだけ) | 567 |
| iOS Sample | なし (ビルドだけ) | 48 (ユニットテスト 37 + UI テスト 11) |
| Android 本体 | 512 (31 クラス) | 512 |
| Android Sample | 163 (21 クラス) | 163 |

件数は 2026-10-08 時点の実測で、テストの増減で動く。CI の列の Android は、ランナーの上での実行の件数で、手元の件数と一致した。

ランナーの上での実行の件数 (2026-10-08、`develop` への push の 1 回目と 2 回目):

| 系統 | 1 回目 | 2 回目 (iOS をビルドだけにした後) |
|---|---|---|
| Android 本体 | 実行 512・スキップ 0・失敗 0・クラス 31 / 31 | 同じ |
| Android Sample | 実行 163・スキップ 0・失敗 0・クラス 21 / 21 | 同じ |
| iOS 本体 | 567 件のうち 1 件が失敗 (テストを実行していた形) | なし (ビルドだけ。`TEST BUILD SUCCEEDED`) |
| iOS Sample | ユニットテスト 37 件が全件成功 (UI テストは走っていない) | なし (ビルドだけ。`TEST BUILD SUCCEEDED`) |
| スクリプトのテスト (lint の中) | 実行 133・失敗 0・スキップ 0 | 実行 111・失敗 0・スキップ 0 |

1 回目で落ちた iOS 本体の 1 件は、2000 件の走査で同時に生きているセルの数を確かめるテストで、手元 (同じ機種・OS・Xcode) では通っている。公開の後の手元の全件実行でも成功した。所要は手元で 5.0 秒、ランナーでは 150 秒かかって落ちた。落ちた原因は確かめていない。スクリプトのテストの件数は、iOS をビルドだけにした変更で変わった。この変更では、呼ぶ所の無くなったスクリプト 3 本のテスト (計 25 件) と、Simulator でテストを流す前提の workflow のテスト 5 件を取り除き、iOS の workflow の新しい形を確かめる 8 件を足している (133 − 30 + 8 = 111)。

## 失敗したときの見方

まず、どの step が落ちたかを見る。Android は、実行の結果のページの概要に件数の内訳が出て、失敗の理由が注釈として出る。iOS は、落ちた step の記録に `xcodebuild` の出力がそのまま出る。

打ち切られた実行 (新しい push で古い実行が止まったもの) は、失敗ではない。

### lint

| 落ちた step | 意味 | 見るところ・すること |
|---|---|---|
| Pull request head restriction | 出どころが `develop` でない、または別のリポジトリである | Pull Request を `develop` から作り直す |
| Install gitleaks | 配布物を取得できない、またはチェックサムが合わない | 版を上げた直後なら、チェックサムを同時に直したかを見る |
| Secret scan (gitleaks) | 「走査の対象を取り出せていない」なら、取り出したファイルが追跡中より少ない。そうでなければ secret の検出 | 前者は下の「取り出しから外す指定を足すと secret の検査が落ちる」。後者は検出された場所を見る。値はすでに公開されている |
| Local absolute path lint / Identity lint / Comment policy lint | 違反がある | 同じコマンドを手元で流すと、同じ報告が出る |
| CI script tests | スクリプトのテストが落ちた、または 1 件も実行されなかった | `python3 scripts/ci/run-tests.py -v` |
| Workflow definition check | workflow の定義の違反、または読み取れない書き方がある | 「ファイル:行: 内容」の形で示される |

### ios / verify

| 落ちた step | 意味 |
|---|---|
| Select Xcode / Show toolchain | 決めた版の Xcode がランナーに無い、または選んだ Xcode の版が違う。ランナーのイメージが更新された可能性がある |
| Build library and library tests | 本体、または本体のテストのコードがビルドできない。依存の取得の失敗もここに出る |
| Build sample and sample tests | Sample のアプリ、ユニットテストのコード、UI テストのコードのどれかがビルドできない |

`ios / verify` は、テストの失敗では落ちない (テストを実行していない)。落ちるのは、ビルドできないとき、その前の準備 (チェックアウト・Xcode の選択と版の確認) が失敗したとき、時間の上限を超えたときである。ビルドの失敗は、記録の中の `error:` の行を探す。同じコマンドを手元で流すと、ビルドの誤りを切り分けられる (下の「手元で確かめる」)。ランナーに固有の失敗は、手元では再現しないことがある。

Sample のビルドは、本体のビルドが落ちた回でも走る。本体のビルドの step まで進まなかった回 (Xcode を選べなかった回) では走らない。

### android / verify

| 落ちた step | 意味 |
|---|---|
| Ensure Android SDK platform | コンパイル対象の SDK の版を読めない、`ANDROID_HOME` が無い、SDK を取得できない、のどれか |
| Test library / Assemble sample and test sample units | テストの失敗、またはビルドの失敗 |
| Check test count | 結果のファイルが無い・読めない、実行が 0 件、全件がスキップ、テストのクラスを 1 つも導けない、属するクラスを導けない `@Test` がある、結果に現れないテストのクラスがある、のどれか |

`Check test count` が「属するクラスを導けない @Test」や「結果に現れないテストのクラス」で落ちたときは、テストが走っていない場合と、スクリプトがソースを読み違えた場合がある。下の「Android のテストのクラスの導き方」と照らす。

## 手元で確かめる

workflow や `scripts/ci/` を変えたら、push の前に次を流す。

```bash
python3 scripts/ci/run-tests.py
python3 scripts/ci/check-workflows.py
actionlint
```

- スクリプトのテストは数秒で終わる。2026-10-08 時点で 111 件。テスト 4 系統とは別に数える
- actionlint は、リポジトリのルートで流すと `.github/actionlint.yaml` を読む。この設定は、ランナーの名前 `xcode-27` を登録している。actionlint が持つ名前の一覧にこの名前がまだ無く、登録が無いと知らない名前として弾かれる
- actionlint は検証 CI では流していない。手元で流すだけである
- プラットフォームの検証は、workflow の step と同じコマンドを手元で流して確かめられる。iOS の 2 つのビルドは Simulator を使わないので、Simulator を用意しなくてよい

iOS の検証と同じコマンド:

```bash
(cd ios && xcodebuild build-for-testing -scheme KsCollectionView -destination "generic/platform=iOS Simulator" -configuration Debug)
(cd samples/ios && xcodebuild build-for-testing -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination "generic/platform=iOS Simulator" -configuration Debug)
```

成功すると、出力の末尾に `** TEST BUILD SUCCEEDED **` が出る。総称の行き先では、Simulator 向けの 2 つの CPU の種類 (arm64・x86_64) の両方をビルドする。手元の所要時間 (2026-10-08、Xcode 27.0): ビルドの出力が何も無い状態から、本体 14 秒・Sample 18 秒 (依存の取得は、手元のキャッシュが効いた状態)。ランナーの上では、本体 1 分 56 秒・Sample 1 分 53 秒だった (2026-10-08 の 2 回目の実行)。

### gitleaks の step は macOS では流せない

`Install gitleaks` の step は、Linux 向けの配布物を取得し、`sha256sum` で照合する。macOS の `sha256sum` は照合のオプションの一部を受け付けないので、チェックサムが正しくても step が失敗する。この step は、macOS では合否を判定できない。

手元で確かめるときは、次のどちらかにする。

| 確かめたいこと | 代わりの方法 |
|---|---|
| 走査で検出が無いこと | 同じ版の gitleaks を手元に入れ、`Secret scan (gitleaks)` の step の本文を流す |
| チェックサムの照合で止まること | Linux のコンテナ (`ubuntu:24.04`) で、step の本文をそのまま流す |
| 固定した値が正しいこと | 公式のリリースの記録にある配布物の SHA-256 と突き合わせる。取得した配布物から別のコマンド (`shasum -a 256` など) で計算した値とも比べられる |

## 既知の制限

### 時間の上限

各ジョブに時間の上限を置いている。値は、ランナーの上での所要時間から余裕を取って、2026-10-08 に決め直した。値の正は workflow のファイルである。

| ジョブ | 上限 | ランナーでの所要時間 (2026-10-08) | 決め直す前の暫定の値 |
|---|---:|---|---:|
| `lint` | 5 分 | 7〜10 秒 (5 回) | 10 分 |
| `ios / verify` | 15 分 | 2 分 16 秒〜4 分 8 秒 (ビルドだけの形で 3 回) | 40 分 |
| `android / verify` | 15 分 | 3 分 50 秒〜6 分 14 秒 (4 回) | 30 分 |

`ios / verify` は、テストを実行していた形の 1 回目だけ 13 分 10 秒かかった。決め直した値を持つ commit での実行は、3 つとも成功した。

上限を超えたジョブが、実際に打ち切られて失敗で終わるところは見ていない。GitHub Actions の `timeout-minutes` の振る舞いに依る。わざと超えさせる確認は、壊れた commit を公開リポジトリに push することになるので行わない。3 つのジョブが上限を持つことは、workflow の定義の検査が確かめている。

### 取り出しから外す指定を足すと secret の検査が落ちる

secret の検査は、追跡中の内容を `git archive` で取り出した先を走査し、取り出したファイルの数が追跡中のファイルの数より少なければ、走査の前に失敗で終わる。走査の対象が欠けたまま緑になる経路を塞ぐためである。

`.gitattributes` に、取り出しから外す指定 (`export-ignore`) を足すと、取り出したファイルが減って、この検査が落ちる。2026-10-08 時点で、この指定は 1 つも無い。足す必要が出たら、同じ変更の中で secret の検査の取り出し方を直す。

### Android のテストのクラスの導き方

`scripts/ci/check-android-test-count.py` は、テストのソースからテストのクラスを導き、結果に現れないクラスがあれば失敗にする。Kotlin の構文は解析していない。行頭から始まるクラスの宣言と、`@Test`・`@ParameterizedTest` の印を、行ごとに読んでいる。そのため、導けない書き方がある。

黙って通る形 (そのクラスの結果が無くても失敗にならない):

| 形 | 2026-10-08 時点の該当 |
|---|---|
| `@Test`・`@ParameterizedTest` 以外の印 (`@TestFactory` など) だけを持つクラス | 0 件 |
| 印を自分では持たず、親のクラスから受け継いだテストだけを持つクラス | 0 件 |
| クラスの宣言と同じ行の後ろに、`object 名前`・`interface 名前` と読める語があるクラス。行末のコメント (`class ATest { // interface の実装を確かめる`) や、1 行に書いたクラスの中の名前つきの `companion object` が当たる | 0 件 |

3 つ目は、スクリプトの冒頭の説明には書かれていない。レビューで見つかり、直さずに既知の制限として残したものである。テストのクラスの宣言の行の末尾に、コメントを書かない。

失敗に倒れる形 (テストが走っていても `Check test count` が落ちる):

| 形 | 落ち方 |
|---|---|
| クラスの宣言として読めない行頭の行 (行頭の関数・プロパティなど) の後ろにある印。クラスの中身を字下げしない書き方では、クラスの 2 つ目より後ろの印が当たる | 属するクラスを導けない `@Test` |
| クラスの中に入れ子で書いたテストのクラス | 外側のクラスが結果に現れない |
| コメントや文字列の中の `@Test` | テストを持たないクラスが数えられて結果に現れない、または属するクラスを導けない |
| クラスの宣言の行のコメントや文字列にある `class 名前` | 実在しないクラスが結果に現れない |

失敗に倒れる形に当たったら、テストのソースの書き方を直す (中身を字下げする、入れ子にしない)。

確かめる組 (モジュールとタスク) は、workflow が明示して渡している。モジュールを足したら、workflow の `--target` と、結果の置き場を空にする step の両方に足す。足さないと、そのモジュールは数えられない。

### workflow の定義の検査が読める書き方

`scripts/ci/check-workflows.py` は、YAML のうち workflow でふつうに使う形だけを読む。次の書き方は、検査をすり抜ける経路になるので、違反として止まる。

- 複数行にまたがる `{...}` や `[...]`、中身のある `{...}`
- アンカーとエイリアス (`&`・`*`・`<<`)
- 行頭のタブ
- 閉じていない引用符

確かめるのは 4 つだけである。外部の action と再利用 workflow が commit の ID で指定されていること、ランナーの名前が版を持ち `latest` を含まないこと、権限が内容の読み取りだけであること、ランナーの上で step を走らせるジョブ (`runs-on` を持つジョブ) が時間の上限 (`timeout-minutes`) を持つこと。同じリポジトリの中の指定 (`./` で始まる) は対象にしない。

時間の上限は、1 以上の整数で書く。式 (`${{ ... }}`) で書いた上限と、整数として読めない値 (引用符で囲んだ数を含む) は、違反として止まる。値の大小は見ない。再利用 workflow を呼ぶだけのジョブ (`uses` を持つジョブ) は、`timeout-minutes` を書けないので対象にしない。呼ばれる側のジョブが上限を持つ。

次の 1 つは、このスクリプトは検査していない。

| 検査していないこと | 代わりに守っているもの | 届かない範囲 |
|---|---|---|
| 失敗の見逃しの指定 (`continue-on-error`) が無いこと | スクリプトのテストが、lint の step と iOS の検証の workflow について確かめる | Android の検証の step は確かめていない |

### 確かめ方の限界

- lint の 4 つの検査 (secret・ローカル絶対パス・個人を特定する値・コメントの規約) が違反で落ちることは、自動のテストを持たない。違反を 1 つだけ置いた一時のツリーで、workflow と同じコマンドが失敗で終わることを、macOS と Linux のコンテナで実測して確かめた
- iOS の「ビルドできないとジョブが落ちる」と、Android の「テストが落ちるとジョブが落ちる」は、ランナーの上で失敗する実行を見て確かめたものではない。step の失敗がジョブの失敗になるという GitHub の挙動に依る
- iOS は、テストのコードをわざと壊すと、workflow と同じコマンドが失敗の終了コードで終わることを、手元で確かめた。本体のテストのコードと、Sample の UI テストのコードのそれぞれで、終了コード 65 (`** TEST BUILD FAILED **`)
- ランナーの上で失敗を見たのは 1 回目の実行だけである。見たのはテストの失敗で、ビルドの失敗ではない。テストを実行していた形の iOS で、本体のテストの step が失敗した後に Sample の検証が走り、ジョブは失敗で終わった
- iOS の 2 つのビルドは、`xcodebuild` を step から直に呼んでいる。後ろに別のコマンドをつなぐと、つないだ側の終了コードが step の合否になる。スクリプトのテストが、つないでいないことを確かめる
- 異常系は、公開リポジトリに壊れた commit を push したり、確かめるための Pull Request を作ったりして確かめない (閉じても公開リポジトリに残るため)。スクリプトのテストと、一時のツリーで確かめる
- Android SDK がランナーに無いときの取得の手順は、手元でもコンテナでも流していない。ランナーの上でも、SDK (Platform 36) が最初からあったので、取得の枝は通っていない。この枝は今も未確認である
- 時間の上限を超えたジョブが落ちるところは見ていない (上の「時間の上限」)

### そのほか

- ランナー `xcode-27` は public preview で、稼働の保証が無い。正式なラベルが出たら切り替える
- iOS の依存は範囲で指定していて、解決の結果のファイルを追跡していない。新しい版が出ると、コードを変えていないのに CI が落ち得る

## 検査を足すときの注意

### 名前と起動の条件

- 検査の名前 (ジョブの名前) は、`main` の保護の必須の検査が参照している。名前を変えるとき・必須にする検査を足すときは、保護の側も同時に直す
- `main` 宛ての Pull Request に、変更したパスでの絞り込みを足さない
- プラットフォームの検証の workflow に、入力を足さない。リリースの workflow (2026-10-08 時点ではまだ無く、作る予定) が、同じ検証を入力なしで呼ぶ前提である

### スクリプトと道具

- 検査のロジックは workflow に直に書かず、`scripts/ci/` のスクリプトにして、正常と異常の両方のテストを付ける。Python の標準のライブラリだけで書く。テストは `scripts/ci/tests/test_*.py` に置けば、入口が拾う
- 黙って空振りする経路を作らない。実行 0 件・走査の対象が空・期待した結果のファイルが無い、はどれも失敗にする
- 外部の action は commit の ID で指定し、対応する版をコメントに書く。ID がタグの指す commit と一致することを `git ls-remote` で確かめる
- gitleaks の版を上げるときは、チェックサムを同時に直し、公式のリリースの記録と突き合わせる
- コマンドの出力を記録に残すために `コマンド | tee 記録` と書かない。コマンドが失敗しても成功に見える。記録を後の step が読む必要が出たら、コマンドの終了コードをそのまま返す包みをスクリプトにして、テストを付ける

### ジョブと step

- iOS の検証に、Simulator を使うテストを足さない (上の「走らせる範囲」の理由)。足すと決めたときは、実行の件数を確かめる検査 (0 件・読み取れないときは失敗) も同時に足す。テストが 1 件も実行されなくても `xcodebuild` は成功で終わる
- ジョブを足すときは、時間の上限を置く (無ければ workflow の定義の検査が落ちる)。workflow のファイルを足すときは、失敗の見逃しの指定を自分で確かめる (上の「workflow の定義の検査が読める書き方」)
- lint のジョブの step を足す・名前を変えるときは、スクリプトのテスト (`scripts/ci/tests/test_workflow_files.py`) が持つ step の一覧も直す
- iOS の検証の step を足す・名前を変えるときも、スクリプトのテストが持つ step の一覧を直す

## 関連

- [cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md) — 走らせる範囲と、緑が保証する範囲の決定
- [cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md) — workflow の構成と、検査の名前を固定した決定
- [cross/ADR-0010](../../decisions/cross/0010-develop-and-main-branch-roles.md) — 走る時点の元になる、ブランチの役割の決定
- [ブランチの運用と GitHub の設定](branch-and-github-settings.md) — 必須の検査を参照する保護の値
- [テスト実行規約](test-execution.md) — 手元の完了判定と、件数の読み方
- [ソースコメント規約](comment-policy.md) — Comment policy lint が確かめる規約

出典: kasane/changes/archive/2026-10-08-public-repo-verify-ci/design.md (Decision 1〜7) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/deviation.md (iOS の検証をビルドだけにした指示) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/evidence/ci-local-verification.md (手元と Linux のコンテナでの確認) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/evidence/publication-log.md (ランナーの上での実行・実地の確認・時間の上限の決め直し・公開の後の手元での iOS のテストの確認) / kasane/changes/archive/2026-10-08-public-repo-verify-ci/review-003.md (Android のテストのクラスの導き方の、残した制限)
