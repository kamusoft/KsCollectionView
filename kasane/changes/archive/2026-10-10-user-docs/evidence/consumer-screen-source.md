# 証跡: 利用者役の画面のソース (tasks グループ 1)

2026-10-10 に手元で確かめた結果。パスはリポジトリのルートからの相対で書く。

## 1.1〜1.3 書き直した形

| プラットフォーム | 新しいファイル | 消したファイル |
|---|---|---|
| iOS | `verification/ios/Sources/VerificationApp/ItemListScreen.swift` (モデル `Item` と画面 `ItemListScreen`。24 行) | `VerificationItem.swift`・`VerificationListScreen.swift` |
| Android | `verification/android/app/src/main/kotlin/ItemListScreen.kt` (モデル `Item` と画面 `ItemListScreen`。31 行。package の宣言なし) | `jp/kamusoft/kscollectionview/verification/android/VerificationListScreen.kt` |

- 両方のファイルに、コメントは 1 行も無い。iOS のファイルに `public` は無い
- Android の入口 (`MainActivity.kt`) は、package を変えずに、`import ItemListScreen` の 1 行を足して呼ぶ
- 例の中身 (100 行の文字の一覧を 1 つ表示する) は、前と同じである。Android は Material に依存しない書き方 (`BasicText`) のままである
- 確認のスクリプト・ひな形・ビルドの定義は変えていない
- スクリプトのテストのうち、前の画面のファイルの名前を書いていたのは `scripts/ci/tests/test_verify_consumer_ios.py` の 2 行 (偽の `xcodebuild` に出させるエラーの文面) だけで、新しい名前に直した。確認のスクリプトの説明と、ひな形・ビルドの定義のコメントには、前の名前は無かった

Scenario に対応するテスト (実物のファイルを見る):

| Scenario | テスト |
|---|---|
| iOS の画面のソースが 1 つのファイルである | `test_verify_consumer_ios.py` の `test_利用者役の画面のソースはモデルと画面を持つ1つのファイルである` |
| 画面のソースにコメントが無い | 同じファイルの `test_利用者役の画面のソースはコメントを持たない`、`test_verify_consumer_android.py` の `test_画面のソースはコメントを持たない` |
| Android の画面のソースが package の宣言を持たない | `test_verify_consumer_android.py` の `test_画面のソースはpackageの宣言を持たずimportから始まる` (あわせて `test_ソースは画面と入口の2つだけである`・`test_入口は画面を名前だけのimportで呼ぶ`) |

スクリプトのテスト (`python3 scripts/ci/run-tests.py`): 実行 268 件 / 失敗 0 件 / スキップ 0 件 (変更の前は 262 件。足したのは 6 件)。workflow の定義の検査 (`python3 scripts/ci/check-workflows.py`): 違反は無い。

## 1.4 切り替えを `local` にした確認

| 確認 | コマンド | 結果 |
|---|---|---|
| iOS | `python3 scripts/ci/verify-consumer-ios.py --mode local` | 終了コード 0。Simulator 向け (`generic/platform=iOS Simulator`・Release) と実機向け (`generic/platform=iOS`・Release) のどちらも `** BUILD SUCCEEDED **`。所要 27 秒。Xcode 27.0 (Build version 27A266a) |
| Android | `python3 scripts/ci/verify-consumer-android.py --mode local` | 終了コード 0。本体の発行と、利用者役のリリースの組み立て (コード縮小あり。`:app:compileReleaseKotlin` と `:app:minifyReleaseWithR8` が走った) がどちらも `BUILD SUCCESSFUL`。実行時の依存に `jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` が現れた。所要 24 秒 |

iOS の確認は、行き先を機種を決めない形 (generic) にしてビルドするだけなので、Simulator は起動していない。

追跡しているファイルに変更が無いこと: 2 つの確認を流す前と後に、`git status --short --untracked-files=all` の出力と、`git diff` の全体のハッシュを取り、どちらも前後で一致した。作業ツリーの差は、意図して書き直したファイル (下の一覧) だけである。

```
 M scripts/ci/tests/test_verify_consumer_android.py
 M scripts/ci/tests/test_verify_consumer_ios.py
 M verification/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/verification/android/MainActivity.kt
 D verification/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/verification/android/VerificationListScreen.kt
 D verification/ios/Sources/VerificationApp/VerificationItem.swift
 D verification/ios/Sources/VerificationApp/VerificationListScreen.swift
?? verification/android/app/src/main/kotlin/ItemListScreen.kt
?? verification/ios/Sources/VerificationApp/ItemListScreen.swift
```

## 1.5 コード縮小を有効にした Android の利用者役の起動

| 項目 | 値 |
|---|---|
| 入れたもの | 1.4 の確認が組み立てた `verification/android/app/build/outputs/apk/release/app-release.apk`。コード縮小の対応表 (`mapping.txt`) に、新しい画面の名前 (`ItemListScreenKt`) と `Item` があり、前の画面の名前は無い |
| エミュレータ | 作業専用に新しく作った AVD `ksn-user-docs-pixel8` (機種の定義 Pixel 8、Android 16・API 36、Google APIs の arm64 のイメージ、Android Emulator 37.1.11)。空いているポートを指定し、画面を出さずに起動した |
| 操作の宛先 | `adb` は、作業専用のエミュレータのシリアルを毎回指定した。操作の前後に `adb -s <android-serial> emu avd name` が `ksn-user-docs-pixel8` を返すことを確かめた。つながっていた実機 2 台と、既存の AVD には触っていない |

手順と観測:

1. APK を入れた (`Success`)。入れる前、利用者役のパッケージは端末に無かった
2. 端末の記録を消してから、`am start -W` で `MainActivity` を起動した。`Status: ok`・`LaunchState: COLD`・`TotalTime: 293` (ミリ秒)
3. 前面の Activity が利用者役の `MainActivity` であることを `dumpsys activity` で確かめた
4. 画面の要素の一覧 (`uiautomator dump`) に、`Item 0` 〜 `Item 20` の 21 行の文字があった (一覧が表示されている)
5. 画面の写しを取った: `consumer-android-list-launched.png`。`Item 0` から `Item 20` までの行と区切り線が写っている。開いて、個人を特定する要素 (通知・アカウント名など) が写っていないことを確かめた
6. 少し置いてから、プロセスの番号が起動のときと同じであることを確かめた (落ちて起動し直していない)。端末の記録 (1,528 行) に、`FATAL EXCEPTION` の行は 0 行、`AndroidRuntime` のエラーの行も 0 行
7. エミュレータを止め、AVD を削除した。`emulator -list-avds` と AVD の置き場に、作った AVD が残っていないことを確かめた

合否は、4 と 5 (アプリの画面に一覧が表示されていること) で判定した。6 は補助の確認である。

確かめた範囲は、起動して一覧の最初の画面が表示されるところまでである。スクロールは、今回は操作していない。
