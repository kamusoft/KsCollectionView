# レビュー結果: image-loading (005 回目)

**日付**: 2026-09-08
**判定**: CHANGES_REQUESTED

## サマリー

今回の対象 2 群 — 群 1 (Android 到達点メモリのクラッシュ修正) と群 2 (計測のための足場) — は、いずれも設計としては筋が通っており、群 1 は実機で自前に再現確認して修正が効いていることを確かめられた (Pixel 4a / Pixel 6a の 2 機種で新設の実機テスト 3 件が成功)。群 2 も、計数を `sized` / `unsized` に分ける判断が両プラットフォームの `KsImage` の分岐と実際に対応していることをコードで確認でき、判定の土台として成立している。

一方で、レビューの必須手順であるテスト実行で **iOS 本体のテストが Simulator の OS 版によって 5 件失敗する** ことが判明した (iOS 26.0 は 154/0、iOS 26.1 / 26.4 は 154 件中 5 失敗)。この 5 件は本 change が新設したテストで、失敗の中身は「アクセシビリティの要素が 1 つも作られない」という空振りであり、同じクラスの残り 2 件は**その空振りのおかげで無内容に成功している**。テスト失敗は判定を CHANGES_REQUESTED にする単独の理由であるため、2 群自体に Critical / Major が無いこととは切り離して差し戻す。

## 照合した規約

| 文書 | 適用のきっかけ |
|---|---|
| `handbook/cross/comment-policy.md` | always |
| `handbook/cross/test-execution.md` | テストの実行・結果の報告 (本レビューの再実行) |
| `handbook/cross/runtime-behavior-verification.md` | 群 1 = 実行時挙動の不具合修正の完了判定 |
| `handbook/cross/sample-parity.md` | 群 2 が `samples/**` を触る |
| `handbook/android/performance-verification.md` | 群 2 が Android の計測経路 (benchmark) に触れる |
| `handbook/ios/performance-verification.md` | 群 2 が iOS 計測の土俵となるセルに触れる |

参照した決定: `core/ADR-0011` (不正入力の debug / release 挙動)、`core/ADR-0002` (対称性の粒度)、`cross/ADR-0004` (Sample のプラットフォーム間一致)、`android/ADR-0001`。`core/ADR-0012` は `proposed` のため判定の根拠にはしていない。

参照した lessons (inbox): `reviewer-reproduces-evidence-numbers-by-probe` / `check-tests-exercise-production-path-before-accepting-green` / `exercise-device-only-branches-on-real-hardware` / `tests-created-in-change-are-in-scope-for-fixes` / `check-sibling-contracts-when-fixing-a-review-finding` / `do-not-run-review-and-verify-on-same-simulator`。

## 自分で再実行した結果 (プローブを含む)

| 対象 | コマンド | 結果 |
|---|---|---|
| iOS 本体 (iOS 26.0 / iPhone 17 Pro) | `xcodebuild test -scheme KsCollectionView` | **154 件 / 0 失敗** |
| iOS 本体 (iOS 26.1 / iPhone 16e) | 同上 | **154 件 / 5 失敗** |
| iOS 本体 (iOS 26.1 / iPhone 17 Pro) | 該当クラスのみ | 6 件 / 5 失敗 |
| iOS 本体 (iOS 26.4 / iPhone 17 Pro) | 該当クラスのみ | 6 件 / 5 失敗 |
| iOS Sample (iOS 26.1 / iPhone 17) | `xcodebuild test -scheme KsCollectionViewSamples` | 3 件 / 0 失敗 |
| Android 本体 unit | `:kscollectionview:testDebugUnitTest --rerun-tasks` | 129 件 / 0 失敗 (9 クラス) |
| Android Sample unit | `:app:testDebugUnitTest --rerun-tasks` | 24 件 / 0 失敗 (5 クラス、うち `ImageLoadingSlotCounterTest` 3 件) |
| Android 実機 (Pixel 4a / Android 13) | `:kscollectionview:connectedDebugAndroidTest` | 3 件 / 0 失敗 |
| Android 実機 (Pixel 6a / Android 16) | 同上 | **3 件 / 0 失敗** (基準機以外でも成立することを追加確認) |
| release / benchmark / benchmark モジュール | `:app:assembleRelease` `:app:assembleBenchmark` `:benchmark:assembleBenchmark --rerun-tasks` | 成功 |
| 計数機構の配布構成への非包含 | 3 構成の APK の dex を走査 | debug のみ `CountedLoadingSlot` / `ImageLoadingSlotTag` を含み、release / benchmark は空実装のみ (deviation の記述と一致) |
| 標準 lint | `comment-policy-lint.py --advisory` / `local-path-lint.py` / `identity-lint.py` | 禁止 0 件・検出 0 件 (要確認 14 件はすべて既存ファイル) |

`allowHardware(false)` がキャッシュ鍵を変えないという deviation の主張は、実機テスト `preparedImageFitsInsideFrame` が「先読みが寸法なしの素の鍵へ載せた元寸を `prepare` が引き当てる」ところまで通っていることで、自分の手でも再現できた。

## 指摘事項

### [🟠 Major] iOS 本体テストが Simulator の OS 版で 5 件失敗し、既定表示のアクセシビリティ契約が検証されていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsImageAccessibilityTests.swift:50` / `:58` / `:67` / `:81`

**問題点**:
iOS 26.1 と 26.4 の Simulator で、次の 5 件が失敗する (iOS 26.0 では 6 件とも成功)。

```
:50 XCTAssertEqual failed: ("[]") is not equal to ("["この画像の説明"]") - 失敗の表示で説明が失われました
:58 XCTAssertEqual failed: ("[]") is not equal to ("["この画像の説明"]") - 読み込み中の表示で説明が失われました
:67 XCTAssertEqual failed: ("[]") is not equal to ("["この画像の説明"]") - 失敗の状態で説明が失われました
:81 XCTAssertFalse failed - 読み込み中の既定表示に読み上げの要素がありません
:81 XCTAssertFalse failed - 失敗の既定表示に読み上げの要素がありません
```

失敗の中身は「特定の値が違う」ではなく **`isAccessibilityElement` の要素が木の中に 1 つも無い**である。すなわち `show(_:)` の作り (画面に載せない `UIWindow` + `UIHostingController` を同期でレイアウトするだけ) では、この OS 版の SwiftUI がアクセシビリティ要素を実体化しない。

これが単なる「テストが落ちる」以上に重いのは、同じクラスの残り 2 件 (`test失敗の既定表示は読み上げる名前を作らない` / `test読み込み中の既定表示は読み上げる名前を作らない`) が **`labels == []` を期待している**ため、木が空でも成功してしまう点である。26.1 以降では、この 2 件は**空振りしたまま緑**になっている。deviation 47 / 51 でオーナー判断として決めたアクセシビリティの契約 (説明を状態に関わらず保つ / 既定表示を画像として読み上げる) は、26.1 以降の環境では 1 件も検証層に載っていない。

このファイルは本 change (commit 8336212) で新設されたものであり、lessons `tests-created-in-change-are-in-scope-for-fixes` により本 change の担当範囲に入る。また `handbook/cross/test-execution.md` は「絞り込みなしの全件実行を完了判定に使う」「実行件数を併記する」と定めるが、**どの Simulator の OS 版で通ったかは書かれていない**ため、報告された「154 / 0」は現在の既定の Simulator では再現しない。

**推奨修正**:
1. まず「テストの足場の問題」か「製品の退行」かを切り分ける。`window` を実際に前面化して 1 回ランループを回す・`UIAccessibility` の要素要求を明示的に発火させるなど、OS 版に依らずアクセシビリティ木が実体化する形へ `show(_:)` を直す (製品側の退行であれば話は別で、その場合は NEEDS_DISCUSSION 相当)。
2. 空振りしても緑になる 2 件 (`labels == []` を期待する側) に、**木が実体化していること自体の事前条件**を足す (例: 説明を付けた比較用の表示が 1 件だけ拾えることを先に確かめる)。これが無い限り、同じ空振りが次も緑で通る。
3. `handbook/cross/test-execution.md` の iOS 手順、または完了報告の件数表記に、**検証した Simulator の OS 版**を残す。

### [🟡 Minor] Android の計数機構が debug 常時有効のため、検証画面の観測点「読み込み中の既定の表示」が本体既定を通らなくなる

**該当箇所**: `samples/android/app/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageGridCell.kt:40`、`samples/android/app/build.gradle.kts:85`

**問題点**:
`ImageGridCell` はデモ画面 (`ImageGridDemoScreen.kt:53`)・計測画面 (`MeasurementDestinations.kt:243,274`) に加えて**検証画面**「検証: 画像の挙動」(`ImageBehaviorVerificationScreen.kt:99`) も共有している。計数の実体は `debug` ソースセット固定で常時有効なため、debug では検証画面の読み込み中も Sample 側の複製 (`CountedLoadingSlot`) に置き換わる。

`handbook/cross/runtime-behavior-verification.md` の観測点表は「検証: 画像の挙動」に**「読み込み中の既定の表示」**を挙げており、この観測点は本体既定 (`KsImageDefaultLoading`) を見るためのものである。既定色は Sample 側へ写してあるため (deviation 68) 静止画では見分けが付かず、**本体既定を通っていない画面の静止画が「既定表示を確認した」証跡として通ってしまう**。deviation 67 はこの帰結を「デモ画面」について記録しているが、検証画面と観測点への波及は記録が無い。

iOS 側は起動引数 (`--count-image-loading-slots`) による実行時 opt-in なので、この問題は数えることを明示的に要求した実行にしか起きない。

**推奨修正**: Android も実行時 opt-in (起動 intent の extra、または計測経路に限定した差し込み) に寄せて、既定では本体の表示を通す。それが重いなら、少なくとも「debug ではこの観測点が本体既定を観測できない」ことを deviation または `evidence/image-behavior-observation.md` に明記し、既定表示の証跡は counterDisabled が入る構成で撮ることを手順に残す。

### [🟡 Minor] 計数の読み出しがログ 1 本しかなく、取りこぼしが「経由していない」側 (偽の合格) に倒れる

**該当箇所**: `samples/android/app/src/counterEnabled/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageLoadingSlotCounter.kt:79-85`、`samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:51-58`

**問題点**:
判定規則は doc に書かれているとおり「ある要素の `sized` が 0 件であること」である。読み出し経路は Android が `Log.i`、iOS が `Logger.info` の 1 本しかなく、どちらも**明示的に間引かず 1 回ごとに出す**設計である。ログが落ちれば `sized` は実際より小さく見え、**取りこぼしはそのまま「経由していない」= 合格の側に倒れる**。10,000 件グリッドの cold なフリングでは読み込み中の出現が数百〜数千件に達しうるため、既存の観測 (`evidence/image-behavior-observation.md` の 15〜120 件規模) より落ちやすい条件になる。

Android には `snapshot()` / `tally()` があるが画面にも印にも出ていないため、実機での突き合わせに使えない。これは deviation 69 が benchmark について塞いだ「未判定が緑になる穴」と同じ類型が、計数側に残っている状態である。

**推奨修正**: 既存の `MeasurementTarget.StatusDescription` と同じ形で、計数の結果 (対象要素の `sized` / `unsized`) を画面の印に出してログと突き合わせる。それが重いなら、証跡に logcat の欠落統計 (`logcat -S` 等) と、`sized=` の連番に飛びが無いことの確認を残す。

### [🔵 Suggestion] ベンチマークの生存確認が計測ブロックの内側で走り、「計測値は不変」の裏付けが無い

**該当箇所**: `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/LargeDataScrollBenchmark.kt:131` (呼び出し元は同 `:81` と `ImageGridBenchmark.kt:92`)

**問題点**: `UiDevice.hasObject` はアクセシビリティのダンプを伴い、`measureRepeated` の計測ブロック内で実行される。フリック後の無 jank な区間が計測窓に加わるため、frameOverrun の分位点は下がる方向に動きうる。deviation 69 は「アサーション追加のみで計測値は不変」と書いているが、その根拠は示されていない。穴を塞ぐ判断そのものは妥当なので、Suggestion に留める。

**推奨修正**: 同じ土俵で確認の有無を A/B した 1 組を証跡に残して「不変」を裏付けるか、deviation の記述を「影響は未検証」に改める。

### [🔵 Suggestion] ソースセットの内容を説明するコメントが、新しく置いた計数を含んでいない

**該当箇所**: `samples/android/app/build.gradle.kts:74`

**問題点**: `counterEnabled` / `counterDisabled` を「テンプレート呼び出しカウンタの実体と空実装」と説明しているが、このソースセットには読み込み中スロットの計数 (`ImageLoadingSlotCounter.kt`) も入った。`handbook/cross/comment-policy.md` の「そのファイルだけを読んでいる人にとって意味が通る」を満たすには、列挙を実態に合わせる必要がある。

**推奨修正**: 「テンプレート呼び出しと読み込み中スロットの計数の実体と空実装」のように、置かれているものを言い切る形へ直す。

### [🔵 Suggestion] iOS の計数の分類にテストが無く、Android との担保の強さが非対称

**該当箇所**: `samples/ios/KsCollectionViewSamples/ImageLoadingSlotCounter.swift:42-59`

**問題点**: Android は `ImageLoadingSlotCounterTest` が本番セル (`ImageGridCell`) を描く経路で `sized` が入ることまで押さえているのに対し、iOS 側は分類 (`sized` / `unsized`) に一切のテストが無い。iOS Sample にユニットテストのターゲットが無いことは deviation 40 / 52 に記録済みなので違反ではないが、判定の土台になる分類がコード読解だけで支えられている点は残る。

なお、iOS の分類が正しく働くこと自体はレビューで確認した — `KsImage.body` が `GeometryReader` の実サイズで `.frame(width:height:)` を掛けてから読み込み中を描くため、枠未確定の分岐は 0×0、確定後の分岐は実寸で計数側に届く。

**推奨修正**: 既存の UI テストターゲットに、起動引数を付けた 1 本 (画像グリッドを開いて `sized` の行が出ること) を足すか、この非対称を deviation に明記する。

## 確認して問題が無かった観点

- **群 1 の修正の完結性**: `toBitmap` を呼ぶ箇所はライブラリ全体で `KsImageRequestFactory.kt:139` の 1 箇所のみ。`downscale` は「枠より小さい (`NotNeeded`)」を先に判定してから読み出し可否を見るため、不要に `Unreadable` へ落ちない。`Unreadable` の残差 (利用者が同じ取得元を自分で寸法なしに要求した場合) は、表示要求が `memoryCacheKey(displayKey)` で素の鍵に書かないことから、記述どおりライブラリの先読みだけでは到達しない
- **iOS に同型の問題が無いという結論** (deviation 61): `KsImageRequestFactory.swift:69-74` は `ImageProcessors.Resize.process` が nil を返したときに `cachedImage: nil` へ落ちる形になっており、Android に新設した `Unreadable` と同じ安全側の分岐が既にある。枠より小さい場合に元寸をそのまま使う挙動 (`upscale: false`) も Android の `NotNeeded` と一致しており、`check-sibling-contracts-when-fixing-a-review-finding` が警戒する「片方だけ直して非対称を作る」形にはなっていない
- **実機テストの移植性**: `KsImageDeviceDecodeTest` は `Bitmap.Config.HARDWARE` が実際に選ばれることを前提にするが、Android 13 (Pixel 4a) と Android 16 (Pixel 6a) の両方で 3 件とも成功した。前提が崩れる端末では黙って通らず、理由付きで失敗する書き方になっている
- **計数の分類が「読み込み中を経由していない = 0」を成立させるか**: 両プラットフォームとも、枠未確定の分岐 (取得を始めない側) が確実に `unsized` に落ちることをコードで確認した。Android は `KsImage.kt:154-163` の外側の制約がそのまま `CountedLoadingSlot` の `BoxWithConstraints` へ渡る
- **計測の土俵の一致**: Android の `CountedLoadingSlot` は本体既定 (`KsImageDefaultLoading`) と同じく semantics を持たない `Box` + 同じ色で、読み上げの木を変えない。iOS の `CountedImageLoadingPlaceholder` は本体既定が持つ `.accessibilityElement(children: .ignore)` と `.isImage` を写しており、どちらも「数えること以外は変えない」を実際に満たしている
- **合意済み差分の扱い**: deviation.md に記録済みの乖離・付随修正 (`androidx.test:runner` のカタログ追加、計数の有効化がプラットフォーム間で非対称、既定色の写し、`allowHardware(false)` による要再計測など) は違反として扱っていない。`androidx-test-runner` の版が本体カタログと Sample カタログで一致していること (どちらも 1.7.0) は確認済み
- **不要な足場の書き換え**: `specs/` `proposal.md` `design.md` に変更は無く、足場凍結は守られている。作業ツリーの差分は `deviation.md` と `samples/` のみ

## アクションプラン

1. **Major**: iOS のアクセシビリティテストを OS 版に依らず成立する形へ直し、空振りしても緑になる 2 件に事前条件を足す。あわせて完了報告に検証した Simulator の OS 版を残す
2. **Minor**: Android の計数を実行時 opt-in に寄せる (または検証画面の観測点への波及を記録する)
3. **Minor**: 計数の読み出しをログ 1 本に依存させない (画面の印との突き合わせ、または欠落の確認を証跡に残す)
4. **Suggestion**: benchmark の生存確認の計測値への影響を裏付けるか、記述を「未検証」に改める
5. **Suggestion**: `build.gradle.kts` のソースセット説明を実態に合わせる
6. **Suggestion**: iOS の計数の分類に UI テストを 1 本足すか、非対称を deviation に明記する
