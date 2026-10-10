# 使わせる確認 (タスク 10.3〜10.5)

- 日付: 2026-10-10
- 対象: 英語版の Skill (読ませる確認の指摘を直した後の内容)。`skills/en/kscollectionview-ios/` と `skills/en/kscollectionview-android/`
- 結果: 10 回のうち 10 回がビルドに成功した。落ちた回は無い

## 進め方

1. 回ごとに、空の作業用の置き場 (リポジトリの外) を作り、Skill の 1 ディレクトリだけを写した
2. 新しいエージェントに、置き場の中だけを読んで、課題の画面を 1 ファイルで書かせた。置き場の外を読まない・Web を使わない・このライブラリの事前の知識を使わない・ビルドしない、と指示した。リポジトリのパスと、ほかの文書は渡していない
3. 書かれたファイルを、作業用の写しの利用者役の画面と入れ替えて、確認のスクリプトを `local` で流した
   - iOS: `python3 scripts/ci/verify-consumer-ios.py --mode local`
   - Android: `python3 scripts/ci/verify-consumer-android.py --mode local`
4. 回が終わるたびに、作業用の写しの画面のファイルを元に戻した

作業用の写しは、本リポジトリの今の作業ツリー (追跡しているファイルと、追跡していない新しいファイル) を作業用の置き場に写し、使い捨ての git のリポジトリにしたもの。Android のビルドのために、SDK の場所を書いた設定ファイル (`local.properties`。git の管理の外) を 3 つ、写しに足した。

## 課題と一緒に渡した、利用者役とつなぐための条件

ライブラリの知識ではなく、ビルドの入口とつなぐための条件である。

| プラットフォーム | 渡した条件 |
|---|---|
| iOS | 画面は `ItemListScreen` という SwiftUI の View で、引数を取らないイニシャライザを持つ。1 つのファイルに収める。モジュールは Swift 6 の言語モード・iOS 16 向けで、依存は KsCollectionView の product だけ。データはファイルの中に持つ |
| Android | 画面は引数なしで呼べる `@Composable fun ItemListScreen()`。1 つのファイルに収め、package の宣言を書かない。モジュールの依存は KsCollectionView・Compose Foundation・activity-compose だけで、Material は使えない。minSdk 29・compileSdk 36・Kotlin 2.4・コード縮小あり。データはファイルの中に持つ |

Material を使えないことを渡したのは、利用者役のモジュールが Material に依存していないためである (Skill の `references/` の例は Material 3 で書かれている)。

## 回ごとの結果

書かれたファイルは `dist-use/` に、そのまま保存した。

| 回 | 課題 | 書かれたファイル | 行数 | ビルドの結果 | 仕分け |
|---|---|---|---|---|---|
| iOS 1 | 型でテンプレートを切り替える一覧。行のタップを受け、ボタンで先頭へスクロールする | `dist-use/ios-1-ItemListScreen.swift` | 100 | Simulator 向け・実機向けとも成功 | — |
| iOS 2 | 向きで列の数が変わるグリッド。グループの見出しを固定し、ルートのヘッダーを持つ | `dist-use/ios-2-ItemListScreen.swift` | 108 | Simulator 向け・実機向けとも成功 | — |
| iOS 3 | 続きを読み込む一覧。失敗したときの再試行の表示と、空のときの表示を持ち、Pull to Refresh で取り直す | `dist-use/ios-3-ItemListScreen.swift` | 184 | Simulator 向け・実機向けとも成功 | — |
| iOS 4 | グループをまたいで並べ替えられる一覧。置けない場所の判定と、読み上げの移動操作の文言を持つ | `dist-use/ios-4-ItemListScreen.swift` | 168 | Simulator 向け・実機向けとも成功 | — |
| iOS 5 | 画像のグリッド。先読みを宣言し、URL が変わる画像に任意キーを使う | `dist-use/ios-5-ItemListScreen.swift` | 78 | Simulator 向け・実機向けとも成功 | — |
| Android 1 | iOS 1 と同じ | `dist-use/android-1-ItemListScreen.kt` | 163 | コード縮小ありの組み立てと依存の確認が成功 | — |
| Android 2 | iOS 2 と同じ | `dist-use/android-2-ItemListScreen.kt` | 147 | 同上 | — |
| Android 3 | iOS 3 と同じ | `dist-use/android-3-ItemListScreen.kt` | 327 | 同上 | — |
| Android 4 | iOS 4 と同じ | `dist-use/android-4-ItemListScreen.kt` | 275 | 同上 | — |
| Android 5 | iOS 5 と同じ | `dist-use/android-5-ItemListScreen.kt` | 137 | 同上 | — |

### Android の 1 回目の実行について (Skill とも書き損じとも関係の無い失敗)

Android の 5 回は、最初の実行では 5 回とも、画面のファイルをコンパイルする前の「本体の発行」で止まった (SDK の場所が見つからない)。作業用の写しに `local.properties` が無かったためで、書かれたファイルの中身には届いていない。写しに設定ファイルを足して流し直し、5 回とも成功した。Skill の欠けでも書き損じでもないので、やり直しの回数には数えていない。

## 確かめられたこと・確かめていないこと

- 確かめたのは、書かれた画面が利用者役と同じ形でビルドできることまで。**起動して動きを見てはいない** (課題のとおりに動くかは未確認)
- 各回のエージェントは、ビルドの前の環境から、プロジェクトの作業の決まり (コメントを日本語で書く) を受け取っていた。そのため、書かれたファイルのコメントは日本語になっている。ライブラリの知識は、Skill のほかには渡っていない
- 課題が触らない API のコード例の誤りは、この確認では見つからない (design の Risks のとおり)

## 本リポジトリの作業ツリーが変わっていないこと (10.5)

- 10 回を始める前の `git status --short` を保存し、iOS の 5 回・Android の 5 回 (1 回目の実行と流し直し) が終わった後の出力と比べた。差は無い (27 行で一致)
- 利用者役の画面のファイル (`verification/ios/Sources/VerificationApp/ItemListScreen.swift`・`verification/android/app/src/main/kotlin/ItemListScreen.kt`) は、本リポジトリでは入れ替えていない。入れ替えたのは作業用の写しの中だけである

## 書いたエージェントが挙げた、Skill の分かりにくいところ

ビルドは通ったが、推測が要ったと報告されたこと。直すかどうかの結末を付ける。

| 挙げた回 | 内容 | 結末 |
|---|---|---|
| iOS 1〜5 | 行・テンプレート・タップ・見出し・先読み・`canMove` / `canDrop` のクロージャの、Swift 6 の言語モードでの隔離 (`@MainActor` か・`@Sendable` か) が書かれていない。「メインスレッドで呼ばれる」は実行時の話で、型の宣言が分からない | 直す (宣言の実物を確かめて、各 1 枚の該当の場所に短く書く)。直した: iOS `SKILL.md` の「この Skill が使う言葉」の後ろに 1 段落 (イニシャライザと modifier はメインアクターに隔離・渡すクロージャは `@MainActor` も `@Sendable` も付かない・`@MainActor` と宣言されているのは `onLoadMore`・`retry`・`onMove` の 3 つ)、`references/basics.md`「Handle taps and long taps」の保証の 1 つ目、`references/reorder.md`「Limit what can move and where it can be dropped」の最後の箇条、`references/images.md`「Prefetch the images of items about to appear」の最初の段落。`references/paging.md` と `references/reorder.md` の `onLoadMore`・`retry`・`onMove` は、前から型が書いてあったので変えていない。ヘッダー・グループの見出しは、`SKILL.md` の段落で受けた (`references/layout.md` は変えていない) |
| Android 1・3・4・5 | `references/` の例が import を省いていて、`KsCollectionView` のほかの名前 (`rememberKsScrollController` など) と、`CancellationException`・`getValue` / `setValue` の import が推測になる | 直す (SKILL.md に、名前がどれも package の直下にあることと、モデルの例に要る import を短く書く)。直した: Android `SKILL.md` の「Setup」の package の文 (下位の package が無いこと) と、「Minimal working example」の節の終わりの、例の書き方の段落 (`getValue`・`setValue`・`kotlinx.coroutines.CancellationException`) |
| Android 1・2・3・4・5 | `references/` の例がすべて Material 3 で、Material の無いモジュールでは読み替えが要る。Material の無いモジュールで、既定の読み込み中の表示・タップの波紋・Pull to Refresh の目印が動くかが書かれていない | 直す (実物を確かめて、SKILL.md に 1〜2 文で書く)。例を Foundation だけの形に書き直すことはしない (例の量が倍になる)。直した: Android `SKILL.md` の「Minimal working example」の節の終わりに 1 段落 (例の読み替え方・ライブラリが Material 3 で描く 3 つは依存を足さなくても動くこと・`MaterialTheme` で包まないときの色)。確かめたのは、依存の届き方と既定の配色までで、Material の無いモジュールで起動して見てはいない |
| iOS 2・Android 2 | 課題の「端末の向き」と、Skill の「縦長・横長は部品の大きさで決まる」の関係 | 直さない (Skill は決まりを正しく書いている。課題の文面の側の言い方である) |
| iOS 4・Android 4 | 「あるグループだけ、外からの受け入れを断る」の `canDrop` の書き方が、2 つの例の組み合わせになる | 直す (1 行の例を足す)。直した: 両プラットフォーム `references/reorder.md`「Limit what can move and where it can be dropped」の 1 つ目の箇条に、1 行の例を足した |
| iOS 5 | キーを使った画像が再起動の後にも見つかるのは、ディスクキャッシュを有効にしたときだけ、ということが、キーの節に無い | 直す (キーの節に 1 文で書く)。直した: iOS `references/images.md`「Use a key for images whose URL changes」の最初の段落 |
| iOS 5・Android 5 | 表示中に、同じキーで URL だけが変わった項目を渡したときの見え方 (読み込み直すか) が書かれていない | 実物を確かめて、決まっていれば書く。決まっていなければ書かない。書いた: 両プラットフォーム `references/images.md`「Use a key for images whose URL changes」の約束ごとに 1 箇条。動きはプラットフォームで違う (iOS は読み込み直さず、出ている表示が残る。Android はキーで探し直し、メモリに無ければ読み込み直す)。本体のコードと、iOS は依存している画像ローダーのソースを読んで決めた。実行して見てはおらず、この動きを確かめるテストも無い。その後、指揮側の判断で外した (2026-10-10): 動きがプラットフォームで違い、決定の記録・概念の文書・テストのどれにも定めが無く、iOS は画像ローダーの内部の比べ方に依るため、Skill の約束ごととしては載せない。結末は「書かない (決まりとして定められていない)」 |
| iOS 3・Android 3 | モデルの例に、Pull to Refresh だけのときには要らない部分 (スクロールの命令・自分のコードからの読み込み直し) が入っていて、削ってよい部分の判断が要る | 直す (どの部分が任意かを 1 文で書く)。直した: 両プラットフォーム `references/paging.md`「Write the model that owns the paging state」の、モデルの例の前 |
