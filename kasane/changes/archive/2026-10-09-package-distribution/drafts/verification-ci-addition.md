> **草稿の扱い (蒸留のときに、この囲みごと消す)**
>
> - 追記先: `kasane/handbook/cross/verification-ci.md`
> - 追記は 11 個ある。それぞれの見出しに、追記先の節と、足すのか置き換えるのかを書いてある
> - 文書の中のリンクは、追記先から見た相対パスで書いてある (この草稿の場所からは辿れない)
> - 中身は、2026-10-09 時点の実物 (`.github/workflows/ci.yml`・`verify-consumer-ios.yml`・`verify-consumer-android.yml`・`scripts/ci/`) と、手元での確認の記録 (`evidence/consumer-ci-workflows.md`・`consumer-ios.md`・`consumer-android.md`・`local-completion.md`) から書いた
> - **公開リポジトリでの確認 (tasks のグループ 9) は、2026-10-09 に行った。** ランナーの上で、新しい 2 本は 1 回ずつ走って成功した。ランナーの上での値が要る箇所 (8 つ。追記 2 に 2・追記 4 に 2・追記 6 に 1・追記 9 に 3) は、グループ 9 の証跡 (`evidence/public-repository-checks.md`) から埋めた。追記 4 と追記 9 のうち、ランナーの記録を読まないと分からない値 (iOS で選ばれた Xcode・`python3` の版・2 つのビルドそれぞれの所要時間、Android で SDK を取得する枝を通ったか・キャッシュの復元と保存) は、証跡の補足の節 (ランナーの記録を読み直した値) から書いた。確かめていないこととして残るのは、保存したキャッシュが次の実行で復元されることと、Android SDK を取得する枝である
> - 追記先は「3 つの検査」と書いている箇所が多い。追記 1〜3 と 5 で直す箇所を挙げたが、蒸留のときに、文書の全体で「3 つ」を探して読み直す
> - 配布物の形の文書 (`package-distribution.md`、この変更で新設する) へのリンクを含む。置き先の名前が変わるなら、リンクも直す
> - `timestamp` は、蒸留で置く日にする

---

## 追記 1: frontmatter と冒頭の段落の直し

`description` を次に置き換える。

```
description: 検証 CI が走る時点・走らせる範囲 (利用者の立場のビルドの確認を含む)・緑が保証する範囲、失敗したときの見方、手元での確かめ方、既知の制限、検査を足すときの注意
```

冒頭の段落の「緑 (3 つの検査がすべて成功で終わった状態)」を、次に置き換える。

> 緑 (その起動で走る検査がすべて成功で終わった状態。`develop` への push では 3 つ、`main` 宛ての Pull Request では 5 つ)

冒頭の 2 つ目の段落の末尾に、次を足す。

> `main` 宛ての Pull Request で、配布物を利用者役でビルドして確かめる理由と範囲は [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) にある。

## 追記 2: 節「走る時点」の表と、その下の段落の置き換え

| 起動 | 走るもの | 変更したパスでの絞り込み |
|---|---|---|
| `develop` への push | `lint`・`ios / verify`・`android / verify` の 3 つ | あり。`kasane/` 配下・Issue のフォーム・貢献の案内だけを変えた push では起動しない |
| `main` 宛ての Pull Request (作成と更新) | 上の 3 つと、`consumer-ios / verify`・`consumer-android / verify` の 5 つ | なし。変更したパスに関わらず走る |

`main` 宛ての Pull Request で絞り込まないのは、5 つが `main` の保護の必須の検査だからである。絞り込むと、必須の検査が走らないまま通る経路ができる。

利用者の立場のビルドの確認 (`consumer-ios / verify`・`consumer-android / verify`) は、`develop` への push では走らない。入口のジョブに、Pull Request で起動したときだけ走る条件を付けてある。push のたびに macOS のランナーを起こさないためである。配布物だけが壊れたことには、`main` 宛ての Pull Request で気付く。push の前に気付きたいときは、手元で流す (下の「手元で確かめる」)。

`develop` への push では、入口の 2 つのジョブ (`consumer-ios`・`consumer-android`) は、条件が成り立たないジョブとして飛ばされる (結果は skipped)。ランナーは起きない (2026-10-09 の `develop` への push の実行で確かめた)。飛ばされたジョブは、検査の一覧には SKIPPED として並ぶ。名前は入口のジョブの名前のままで、` / verify` が付かない。同じ commit の Pull Request の検査の一覧には、push の実行のこの 2 つも並ぶので、`consumer-ios / verify`・`consumer-android / verify` と読み違えない。

`main` 宛ての Pull Request では、5 つの検査が決めた名前で報告される。2026-10-09 の Pull Request 2 番で、`lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` の 5 つが報告され、どれも成功した。変更したパスによる絞り込みは無く、5 つとも走った。

## 追記 3: 節「構成」の直し

表の `.github/workflows/ci.yml` の行を置き換え、その下に 4 行を足す。

| ファイル | 役割 |
|---|---|
| `.github/workflows/ci.yml` | 入口。起動の条件・同時実行・権限を持ち、lint のジョブを自分で持ち、下の 4 本を呼ぶ。利用者の立場のビルドの確認の 2 本は、Pull Request で起動したときだけ、切り替えを `local` にして呼ぶ |
| `.github/workflows/verify-consumer-ios.yml` | iOS の利用者の立場のビルドの確認。他の workflow から呼ばれる形だけを持ち、切り替え (`mode`、必須) と版 (`version`、任意) を入力に取る |
| `.github/workflows/verify-consumer-android.yml` | Android の利用者の立場のビルドの確認。同上 |
| `scripts/distribution/` | SwiftPM の写しを作る道具と、配信用の README の固定文。iOS の確認が呼ぶ |
| `verification/` | 利用者役 (iOS と Android の最小のプロジェクト) |

「検査の名前は … 3 つに固定してある」の段落を、次に置き換える。

> 検査の名前は `lint`・`ios / verify`・`android / verify`・`consumer-ios / verify`・`consumer-android / verify` の 5 つに固定してある ([cross/ADR-0014](../../decisions/cross/0014-ci-reusable-platform-workflows-and-fixed-check-names.md))。再利用 workflow を呼ぶジョブの検査の名前は「呼ぶ側のジョブの名前 / 呼ばれる側のジョブの名前」になるので、入口のジョブの名前 (`consumer-ios`・`consumer-android`) と、呼ばれる側のジョブの名前 (`verify`) の両方を明示してある。`main` の保護がこの 5 つの名前を参照する ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))。

道具の版の段落の末尾に、次を足す。

> 利用者の立場のビルドの確認の 2 本は、既存の検証と同じランナー・Xcode・JDK を使う。Xcode と JDK の版は、既存の workflow と同じ値であることを、スクリプトのテストが確かめる。認証の情報と署名の鍵は受け取らない。

## 追記 4: 節「走らせる範囲」に小節を 2 つ足す (「android / verify」の後ろ)

### consumer-ios / verify

`main` 宛ての Pull Request のときだけ走る。

1. 決めた版の Xcode を選ぶ。無ければ、ビルドを始める前に失敗で終わる
2. 今の `ios/` から、配信用リポジトリのルートに置くのと同じ写しを、一時のディレクトリに作る
3. 利用者役 (`verification/ios/`) を一時のディレクトリに写し、写しをパスで参照するマニフェストを書く
4. 利用者役を、リリースの構成で、Simulator 向け (`generic/platform=iOS Simulator`) にビルドする
5. 同じ利用者役を、実機向け (`generic/platform=iOS`、署名なし) にビルドする

2〜5 は `scripts/ci/verify-consumer-ios.py` が行い、workflow はそれを 1 行で呼ぶ。どれかが失敗すると、後ろを始めずに失敗で終わる。Simulator 向けのビルドが落ちた回では、実機向けのビルドは走らない。

Simulator は選ばず、起動もしない ([cross/ADR-0013](../../decisions/cross/0013-ci-runs-no-simulator-or-device-tests.md))。利用者役は、本体を package `KsCollectionView-SPM` の product `KsCollectionView` として取る。本体のソースを直接は参照しない。

ランナーの上での最初の実行 (2026-10-09、Pull Request 2 番): 成功し、ジョブの所要時間は 1 分 58 秒だった。選ばれた Xcode は 27.0 (Build version 27A266a)、Swift は 6.4、`python3` は 3.14.8 である。step `Verify consumer` は 1 分 43 秒で、Simulator 向けのビルドが約 1 分 5 秒 (Nuke の取得を含む)、実機向けのビルドが約 37 秒だった。

### consumer-android / verify

`main` 宛ての Pull Request のときだけ走る。

1. JDK 21 を入れ、コンパイル対象の Android SDK がランナーに無ければ取得する
2. 今の `android/` の本体を、一時のディレクトリの Maven リポジトリへ発行する
3. 利用者役 (`verification/android/`) のリリースを、コード縮小 (R8) を有効にして組み立てる。本ライブラリは、2 で発行した場所だけから取る
4. コード縮小の対応表 (`mapping.txt`) ができていることを確かめる
5. 実行時の依存の一覧に、座標 `jp.kamusoft:kscollectionview` が指定の版で現れることを確かめる

2〜5 は `scripts/ci/verify-consumer-android.py` が行う。どれかが失敗すると、後ろを始めずに失敗で終わる。

エミュレータは使わず、利用者役を起動しない。利用者役のテストも無い。キャッシュするのは、依存の解決の結果と、wrapper が取得する Gradle だけである。キーは `gradle-consumer-` で始まり、既存の検証のキャッシュと分けてある。ビルドの出力と、既定の手元の Maven リポジトリは、キャッシュしない。

ランナーの上での最初の実行 (2026-10-09、Pull Request 2 番): 成功し、ジョブの所要時間は 3 分 16 秒だった。JDK は 21.0.12.1、`python3` は 3.12.3 である。コンパイル対象の SDK (Android SDK Platform 36) はランナーにあり、取得する枝は通っていない。Gradle のキャッシュは、このキーでの最初の実行なので復元されず (`Cache not found`)、終わりに保存された (`Cache saved`)。本体の発行は 1 分 34 秒、利用者役のリリースの組み立ては 1 分 26 秒で、実行時の依存に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` が現れた。

利用者役と配布物の中身、切り替え (`local`・`published`) の意味は、[配布物の形と利用者の立場の確認](package-distribution.md) にある。

## 追記 5: 節「緑が保証する範囲」の直し

表の前の説明の後ろに、次の段落を足す。

> 緑が言えることは、起動で変わる。`develop` への push の緑は、下の表の「push と Pull Request」の行までを言える。「Pull Request だけ」の行は、`main` 宛ての Pull Request の緑でだけ言える。

表を、次の 2 つに置き換える (左右の列を対応させない 1 つの表だったものを、言えること・言えないことの 2 つの表に分ける)。

緑が言えること:

| 言えること | 言える起動 |
|---|---|
| iOS 本体と、本体のテストのコードがビルドできた | push と Pull Request |
| iOS の Sample のアプリと、Sample のテストのコード (ユニットテスト・UI テスト) がビルドできた | push と Pull Request |
| Android 本体のデバッグのユニットテストが全件通った | push と Pull Request |
| Android の Sample がビルドでき、デバッグのユニットテストが通った | push と Pull Request |
| Android は、実行の件数が本体と Sample のそれぞれで 0 でなく、テストのソースにあるテストのクラスがすべて結果に現れた | push と Pull Request |
| lint の step がどれも成功した (上の「lint」の表) | push と Pull Request |
| 今の `ios/` から作った写しを、利用者と同じ書き方で取る利用者役が、リリースの構成で Simulator 向けにビルドできた | Pull Request だけ |
| 同じ利用者役が、iOS の実機向けに (署名なしで) ビルドできた | Pull Request だけ |
| 今の `android/` から発行した発行物を、座標の 1 行で取る利用者役のリリースが、コード縮小を有効にして組み立てられた | Pull Request だけ |
| その利用者役の実行時の依存に、本ライブラリの座標が指定の版で現れた | Pull Request だけ |

緑では言えないこと (手元の完了条件に残る):

- iOS のテストが通った (本体の全件・Sample のユニットテスト・Sample の UI テストのどれも、CI では走らない)
- 端末をつないで走らせるテストが通った
- 性能検証を通った
- Xcode 27 以外でビルドできる
- Android のリリースのユニットテストが通る (デバッグだけを流している。利用者役のリリースは組み立てるだけで、テストを持たない)
- コード縮小を有効にしたアプリが、起動して動く (組み立てまでを確かめている。起動は手元で 1 回確かめただけで、範囲は [配布物の形と利用者の立場の確認](package-distribution.md) にある)
- 利用者役が触らない API について、配布物の依存の宣言が足りている
- 公開済みの配布物を取得できる (検証 CI は `local` で呼ぶ。公開済みの配布物は取りに行かない)
- `develop` への push の緑では、配布物が正しいこと (上の表の「Pull Request だけ」の 4 行)

「iOS の実機向けにビルドできる」は、前は言えないことの側にあった。`main` 宛ての Pull Request の緑では、利用者役を通る範囲で言えるようになった。実機向けにビルドするのは利用者役と、それが取る本体の写しだけで、本体のテストのコードと Sample は、今も Simulator 向けのビルドだけを確かめている。

## 追記 6: 節「件数の読み方」の末尾に足す

スクリプトのテスト (lint の中) の件数は、利用者の立場のビルドの確認を足した変更で、111 件から 262 件に増えた (2026-10-09、手元)。

| 足したテスト | 件数 |
|---|---:|
| SwiftPM の写しを作る道具 (`test_sync_spm_snapshot.py`) | 31 |
| Android の確認のスクリプト (`test_verify_consumer_android.py`) | 47 |
| iOS の確認のスクリプト (`test_verify_consumer_ios.py`) | 48 |
| workflow のファイル (`test_workflow_files.py` に足した分) | 25 |

確認のスクリプトのテストは、`xcodebuild` と `gradlew` を、呼ばれ方を記録する偽物に差し替えて流す。ビルドも発行も実際には走らない。利用者の立場のビルドの確認は、実行の件数を持たない (ビルドと組み立ての合否だけである)。

スクリプトのテスト (262 件) は、Linux のランナーの上でも通った。2026-10-09 の `develop` への push と、`main` 宛ての Pull Request 2 番の `lint` が成功している (所要は 18 秒と 17 秒)。

## 追記 7: 節「失敗したときの見方」に小節を 2 つ足す (「android / verify」の後ろ)

冒頭の段落 (「まず、どの step が落ちたかを見る。…」) の末尾に、次を足す。

> 利用者の立場のビルドの確認は、落ちた step の記録に、写しを作る道具・`xcodebuild`・Gradle の出力がそのまま出る。成功したときは、実行の結果のページの概要に、切り替えと確かめたものが出る。

### consumer-ios / verify

| 落ちた step | 意味 |
|---|---|
| Select Xcode / Show toolchain | 決めた版の Xcode がランナーに無い、または選んだ Xcode の版が違う。`ios / verify` も同じ理由で落ちているはずである |
| Verify consumer | 写しの作成・利用者役の準備・2 つのビルドのどれかが失敗した。記録の最後の `::error::` の行が、どの段で落ちたかを言う。理由は、その上の出力にある |

`Verify consumer` が落ちたときの切り分け:

| 記録に出るもの | 意味 |
|---|---|
| 写しを作る道具のエラー | 写しを作れなかった。ビルドは始まっていない |
| Simulator 向けのビルドの `error:` の行 | 写しに要るソースが欠けている、依存 (Nuke) を取得できない、利用者役のソースが本体の公開 API と合わなくなった、のどれか |
| 実機向けのビルドの `error:` の行 | 実機向けでだけビルドできない |
| `::error::` が引数の誤りを言う | 入口が渡す値が変わっている (入口は `mode: local` だけを渡す) |

`ios / verify` が成功していて、こちらだけが落ちたときは、本体ではなく配布物の形 (写しに入るファイル・マニフェストがルートで成り立つこと) か、利用者役の側を疑う。Simulator 向けが落ちた回では実機向けは走っていないので、直した後にもう一度見る。

### consumer-android / verify

| 落ちた step | 意味 |
|---|---|
| Ensure Android SDK platform | `android / verify` の同じ名前の step と同じ |
| Verify consumer | 本体の発行・利用者役の組み立て・対応表の確認・依存の確認のどれかが失敗した。記録の最後の `::error::` の行が、どの段で落ちたかを言う |

`Verify consumer` が落ちたときの切り分けは、[配布物の形と利用者の立場の確認](package-distribution.md) の「失敗したときの見方」と同じである。`android / verify` が成功していて、こちらだけが落ちたときは、公開の設定・発行物の依存の宣言・コード縮小を疑う。

コード縮小で不整合が出たときは、利用者役の側に規則を足して通さない。配布物に規則を同梱するかの判断になるので、オーナーに諮る。利用者役の側に規則を書くと、配布物に規則が足りないことが隠れる。

どちらの確認も、外部の依存 (Nuke・Maven の依存) を取得できないと落ちる。コードを変えていないのに落ちたときは、取得の失敗を先に見る。

## 追記 8: 節「手元で確かめる」の直し

「スクリプトのテストは数秒で終わる。2026-10-08 時点で 111 件。」を、次に置き換える。

> スクリプトのテストは 15 秒ほどで終わる。2026-10-09 時点で 262 件。

「iOS の検証と同じコマンド」の説明の後ろ (gitleaks の小節の前) に、次を足す。

利用者の立場のビルドの確認と同じコマンド:

```bash
python3 scripts/ci/verify-consumer-ios.py --mode local
ANDROID_HOME=<Android SDK の場所> python3 scripts/ci/verify-consumer-android.py --mode local
```

workflow は、同じスクリプトを `--mode "${KS_MODE}" --version "${KS_VERSION}"` の形で呼ぶ。入口が渡すのは `local` と空の版で、上のコマンドと同じ動きになる。終了コード 0 が成功である。どちらも Simulator・エミュレータを使わず、git が追跡しているファイルを変えない。

手元の所要時間 (2026-10-09、依存の取得が済んだ状態): iOS は 30 秒ほど、Android は 5〜23 秒ほど。引数・終了コード・必要な環境は [配布物の形と利用者の立場の確認](package-distribution.md) にある。

`develop` への push では、この 2 つは走らない。配布物の形に関わる変更 (`ios/Package.swift`・`ios/Sources/` のファイルの増減・Android の公開の設定と依存の宣言・`scripts/distribution/`・`verification/`) をしたら、push の前に手元で流す。

## 追記 9: 節「既知の制限」の直し

### 「時間の上限」の表に 2 行足す

| ジョブ | 上限 | ランナーでの所要時間 | 決め直す前の暫定の値 |
|---|---:|---|---:|
| `consumer-ios / verify` | 15 分 | 1 分 58 秒 (2026-10-09、1 回) | 15 分 |
| `consumer-android / verify` | 15 分 | 3 分 16 秒 (2026-10-09、1 回) | 15 分 |

2 つの上限は、手元の所要時間しか無い時点で 15 分を暫定の値として置き、2026-10-09 にランナーでの所要時間を見て、15 分のまま変えないと決めた。理由は次のとおりである。値を変えないので、次の `main` 宛ての Pull Request で入れる変更は無い。

- 測れたのは 1 回だけで、どちらも依存のキャッシュが無い状態の最初の実行である。ばらつきはまだ分からない
- 既存の検証の workflow は、実測 2 分 28 秒〜5 分 2 秒に対して上限を 15 分にしている。利用者の立場のビルドの確認の実測はその範囲の中にあり、同じ上限にしておけば、4 つの検証の上限が揃う
- 外部の依存の取得 (Nuke・Maven の依存) に頼るので、取得が遅い日の余裕を残す。上限を詰めて得るものは、止まった実行が早く切れることだけである

### 「workflow の定義の検査が読める書き方」の末尾の表の置き換え

| 検査していないこと | 代わりに守っているもの | 届かない範囲 |
|---|---|---|
| 失敗の見逃しの指定 (`continue-on-error`) が無いこと | スクリプトのテストが、lint の step・iOS の検証の workflow・利用者の立場のビルドの確認の 2 本について確かめる | Android の検証の step は確かめていない |

### 「確かめ方の限界」に足す

- 利用者の立場のビルドの確認が「配布物が壊れていると落ちる」ことは、ランナーの上で失敗する実行を見て確かめたものではない。iOS は、一時のツリーで本体のソースを 1 つ欠いて、確認が終了コード 1 で終わることを手元で確かめた。Android は、発行物の無い取得元を渡して、組み立てが依存を解決できずに失敗することを手元で確かめた
- 切り替え `published` で呼んだときの取得は、1 度も実行していない (公開物がまだ無い)。確かめたのは、参照の書き方と、準備を飛ばして同じビルドを始めることまでである。最初のリリースで確かめる
- `Select Xcode` の step が Xcode を選べる側の枝は、手元では通せない (手元の Xcode は、ランナーと同じ名前では置いていない)。同じ本文の step が、`ios / verify` でランナーの上で通っている。無い版を渡すと `DEVELOPER_DIR` を書く前に失敗で終わることは、step の本文を取り出して手元で確かめた
- ランナーの上で確かめたのは、利用者の立場のビルドの確認の 2 本が、`main` 宛ての Pull Request で 1 回ずつ成功したことである (2026-10-09)。Android の利用者役の組み立ては、Linux のランナー (`ubuntu-24.04`) の上で通った。ランナー `xcode-27` の `python3` は 3.14.8 だった。Android のキャッシュは、保存されるところまでを確かめた。保存したキャッシュが次の実行で復元されることは、確かめていない (復元される実行がまだ無い)。Android SDK を取得する枝も、確かめていない (コンパイル対象の SDK がランナーにあり、取得する枝は通らなかった)

### 「そのほか」に足す

- 利用者の立場のビルドの確認は、外部の依存の取得 (Nuke・Maven の依存) に頼る。必須の検査が、コードの誤りではない理由で止まり得る。止まったときに `main` 宛ての Pull Request を進める手段は、管理者による保護の迂回である ([ブランチの運用と GitHub の設定](branch-and-github-settings.md))
- iOS の確認は、Simulator 向けのビルドが落ちると、実機向けのビルドを流さない。1 回の失敗で、両方の行き先の結果は分からない
- 利用者役が確かめるのは、最小の利用例が触る範囲である。触らない API の依存の宣言の漏れと、コード縮小の後の動きは、検証 CI では分からない

## 追記 10: 節「検査を足すときの注意」の直し

### 「名前と起動の条件」

1 つ目の項目は変えない (名前を変えるとき・必須にする検査を足すときは、保護の側も同時に直す)。3 つ目の項目 (プラットフォームの検証の workflow に、入力を足さない) を、次に置き換える。

- プラットフォームの検証の workflow (`verify-ios.yml`・`verify-android.yml`) に、入力を足さない。リリースの workflow (2026-10-09 時点ではまだ無く、作る予定) が、同じ検証を入力なしで呼ぶ前提である
- 利用者の立場のビルドの確認の workflow の入力は、切り替えと版の 2 つだけにする。リリースの workflow が、同じ workflow を切り替えを変えて呼ぶ前提である。入力の検査は workflow の step に書かず、スクリプトに持たせてある
- 入口の利用者の立場のビルドの確認のジョブから、Pull Request で起動したときだけ走る条件を外さない。外すと、`develop` への push のたびに macOS のランナーを起こす。条件は、呼ばれる側ではなく入口のジョブに付ける
- 必須にする検査を足すときは、先に `main` 宛ての Pull Request で検査が報告されるのを見てから、保護に登録する。手順は [ブランチの運用と GitHub の設定](branch-and-github-settings.md) にある

### 「ジョブと step」に足す

- 利用者の立場のビルドの確認の 2 本の step を足す・名前を変えるときも、スクリプトのテスト (`scripts/ci/tests/test_workflow_files.py`) が持つ step の一覧を直す。iOS は 4 つ、Android は 6 つの step に決めてある
- Xcode の版と JDK の版は、既存の検証の workflow と、利用者の立場のビルドの確認の workflow で、同時に上げる。値がずれると、スクリプトのテストが落ちる。iOS の `Select Xcode` の step と、Android のコンパイル対象の SDK を確かめる step は、既存の workflow と同じ本文であることもテストが確かめるので、直すときは両方を直す
- 確認の step (`Verify consumer`) の後ろに、別のコマンドをつながない。つないだ側の終了コードが step の合否になる。スクリプトのテストが、つないでいないことを確かめる
- 利用者役のビルドの定義 (`verification/android/` の `*.gradle.kts`・wrapper の設定) を変えると、Android の確認のキャッシュのキーが変わる。wrapper を上げるときは、`android/` と `verification/android/` の両方を同じ版にする (スクリプトのテストが、設定が同じであることを確かめる)

## 追記 11: 節「関連」と出典に足す

節「関連」に 2 行足す。

- [cross/ADR-0016](../../decisions/cross/0016-consumer-build-check-on-main-pull-requests.md) — 配布物を利用者役でビルドして確かめる決定
- [配布物の形と利用者の立場の確認](package-distribution.md) — 配布物の中身、利用者役の流し方、失敗したときの見方

出典の行の末尾に、次を足す。

```
/ kasane/changes/archive/【蒸留の日付】-package-distribution/design.md (Decision 6・7) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/consumer-ci-workflows.md (新しい 2 本の形・手元での確認) / kasane/changes/archive/【蒸留の日付】-package-distribution/evidence/【グループ 9 の証跡のファイル名】 (ランナーの上での実行・時間の上限)
```
