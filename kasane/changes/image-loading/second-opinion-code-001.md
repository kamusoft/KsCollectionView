# セカンドオピニオン: image-loading (code-001)

**相方**: codex / **label**: so-code-image-loading / **日付**: 2026-09-07 / **対象**: 作業ツリーの未コミット変更の全体 (契約は `kasane/changes/image-loading/` の proposal / design / specs / tasks / ui、合意済み差分は deviation.md 14 件)

---

# 判定: CHANGES_REQUESTED

Critical 0 / Major 6 / Minor 4 / Suggestion 0

ホスト側のテスト・lint 結果は提示内容を前提とし、再実行していません。静的レビューでは、既存テストが通っていても捕捉できない契約違反が残っています。

## Major

### 1. iOS の `memory` プリフェッチ後も、`KsImage` 表示時に再デコードされる

該当箇所:

- `ios/Sources/KsCollectionView/KsNukeImageLoading.swift:31`
- `ios/Sources/KsCollectionView/KsImageRequestFactory.swift:36`
- `ios/Tests/KsCollectionViewTests/KsImageCacheContractTests.swift:65`

問題点:

プリフェッチは `thumbnail` のない要求をメモリへ保存しますが、`KsImage` は `ThumbnailOptions` 付きの別キャッシュキーを要求します。Nuke 13.2.0 はこの場合、元寸のメモリ画像を再利用せず、元データへフォールバックして再デコードします。

既存テストは `pipeline.image(for: target)` という縮小指定のない要求で確認しているため、実際の `KsImageRequestFactory` 経路を検査できていません。これは「ネットワークアクセスもデコードのやり直しもなし」という spec 56–59 行に違反します。

推奨修正:

元寸のプリフェッチ済みメモリ画像を明示的に再利用する経路を設けるか、表示要求と互換性のあるキャッシュ戦略へ変更してください。テストは `KsImageRequestFactory.makeRequest` が生成した実際の縮小要求を使い、デコード回数が増えないことを確認する必要があります。

### 2. `clear(.disk)` が表示中画像の再取得を保証しない

該当箇所:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:32`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:106`
- `ios/Sources/KsCollectionView/KsImageCache.swift:27`
- `ios/Sources/KsCollectionView/KsImage.swift:117`

問題点:

両実装とも `.disk` ではディスクだけを消し、表示の世代番号を進めています。しかし世代番号はビューの再生成にしか使われず、Coil/Nuke の要求キャッシュキーには反映されません。

したがってメモリキャッシュに画像が残っていれば、再生成されたビューは直ちに同じメモリ項目へヒットし、読み込み中にも再ダウンロードにもなりません。spec 170–176 行の明示的な契約と矛盾します。

既存テストは「ディスク操作が呼ばれ、世代が進んだこと」だけを確認しており、メモリ済み画像を表示した状態からの再取得経路を確認していません。

推奨修正:

`.disk` 後の最初の要求について古いメモリ項目を確実に回避または無効化し、契約どおり再取得させてください。メモリ済み画像を用意した表示レベルの回帰テストで、loading → network → success を確認してください。

### 3. `clear` 中の進行中リクエストが、削除後にキャッシュを復活させる

該当箇所:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:32`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:113`
- `ios/Sources/KsCollectionView/KsImageCache.swift:27`
- `ios/Sources/KsCollectionView/KsNukeImageLoading.swift:17`

問題点:

キャッシュ操作と、プリフェッチ／表示中リクエストの台帳との間に連携がありません。`clear(.all/.disk)` が戻った後で、それ以前に開始したリクエストが完了すると同じキャッシュへ書き戻せます。

Android の `remove` も要求キーに世代を含めないため、削除前に始まったプリフェッチが対象 URL を再投入できます。これは「戻った時点で削除完了」「以後の要求は削除前の項目に当たらない」という契約を満たしません。

推奨修正:

キャッシュ世代と進行中リクエストを統合し、削除時に旧世代の要求を停止するか、旧世代の完了結果を書き込ませないフェンスを設けてください。取得完了を保留できるテストダブルで、「clear/remove → return → 旧要求完了」の順を再現するテストが必要です。

### 4. Android はメモリヒットでも最初の composition で loading を構成する

該当箇所:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:120`

問題点:

Coil 3.5.0 の `AsyncImagePainter` の初期状態は常に `State.Empty` です。現在の `when` は `Empty` を loading として扱うため、メモリキャッシュに画像がある場合でも最初の composition で loading スロットを構成します。

静止画で最終状態を確認しても、この一瞬は検出できません。spec 113–114、165–168 行の「メモリキャッシュにあれば読み込み中を経由しない」に違反します。

推奨修正:

メモリキャッシュを同期的に判定できる初期表示経路を設けるなど、`Empty` を無条件に loading としない実装にしてください。プリロード済み画像を用意し、loading スロットの呼び出し回数がゼロであることを検査するテストを追加してください。

### 5. `KsImage` のスロット宣言構造がプラットフォーム間で非対称

該当箇所:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:51`
- `ios/Sources/KsCollectionView/KsImage.swift:33`
- `ios/Sources/KsCollectionView/KsImage.swift:155`
- `kasane/decisions/core/0002-symmetry-granularity.md:16`

問題点:

Android は `loading` と `failure` を独立に省略・指定できます。iOS は「両方指定」または「両方既定」の initializer しかなく、片方だけを差し替えられません。

たとえば Android の次の宣言をiOSへ1対1で書き写せません。

```kotlin
KsImage(source = source, failure = { RetryView() })
```

これは accepted の core/ADR-0002 が要求する宣言構造の1対1対応に反します。

推奨修正:

iOS に loading-only / failure-only の initializer を追加するなど、片方ずつ差し替えられる公開面を両プラットフォームで揃えてください。公開APIテストにも4組（両既定・loadingのみ・failureのみ・両指定）を追加してください。

### 6. Android の性能計測入口が Sample と同じ固定 fixture になっていない

該当箇所:

- `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementDestinations.kt:206`
- `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MeasurementDestinations.kt:244`
- `samples/android/app/src/measurement/kotlin/jp/kamusoft/kscollectionview/samples/android/MemoryRoundTripScreen.kt:129`
- `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/ImageGridBenchmark.kt:66`

問題点:

計測入口は `DemoData.imageGridItems` ではなく `largeItems(count)` を使用するため、セルの文言が Sample の `#ID` と一致しません。さらにメモリ往復画面では Sample にある外周の `contentPadding` が渡されていません。

また3試行の `setupBlock` はホームへ戻るだけで、画像キャッシュの初期状態を揃えていません。試行が進むにつれてディスク／メモリが温まり、同じ負荷の独立試行になりません。証跡の「同じデータ・同じ配置」「同じセル」という説明とも一致しません。

未計測であること自体は指摘していませんが、現状の入口で得られる数値は tasks 7.5 の証明として使えません。

推奨修正:

画像グリッド専用の件数可変factoryを共用し、`contentPadding` も共通値として渡してください。各試行を cold または warm のどちらで測るか決め、setupで同じキャッシュ状態を作り、証跡へ明記してください。fixture一致を静的に確認するテストも追加すべきです。

## Minor

### 7. Android の `remove` が接頭辞の一致する別URLまで削除する

該当箇所:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:58`

問題点:

`startsWith("$cacheKey-")` により、たとえば対象が `https://example/a` のとき、無関係な `https://example/a-preview` も削除対象になります。Coil のサイズ等の extras は `MemoryCache.Key.key` とは別に保持されるため、リモートURLでは完全一致だけでサイズ違いを削除できます。

推奨修正:

リモートは完全一致に限定し、合意済みのbest-effort接頭辞処理が必要ならファイルソースだけに限定してください。接頭辞衝突の回帰テストも必要です。

### 8. iOS の必須ディスクキャッシュ設定が利用入口から発見できない

該当箇所:

- `ios/Sources/KsCollectionView/KsCollectionView.swift:195`
- `ios/Sources/KsCollectionView/KsPrefetchDestination.swift:1`
- `kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md:328`

問題点:

合意済み deviation により、iOS のディスクキャッシュは `KsImagePipeline.enableSharedDiskCache()` の起動時呼び出しが必要です。しかし既定値 `.disk` のAPI説明と利用例には、その前提も設定APIへのリンクもありません。Sampleだけは正しく呼んでいるため、外部利用者だけが「宣言したのにディスクへ残らない」状態になり得ます。

推奨修正:

`prefetchResources`、`.disk`、DSLサンプルの各入口から設定APIへリンクし、起動時に一度呼ぶ完全な例を示してください。

### 9. ディスクキャッシュ作成失敗が完全に無通知

該当箇所:

- `ios/Sources/KsCollectionView/KsImagePipeline.swift:25`

問題点:

`try?` と早期returnにより、ディスクキャッシュを有効化できなかったことを利用者が検知できません。公開API名は有効化の成功を期待させますが、失敗時は黙ってメモリのみになります。

これはADR-0011の列挙対象そのものではありませんが、汎用観点のエラー処理・観測可能性に問題があります。

推奨修正:

少なくともOS標準ログへ警告を出してください。可能なら内部factoryを注入できるようにして、作成失敗時の警告をテストしてください。

### 10. 証跡がiOS観測コードの配布構成について事実と矛盾する

該当箇所:

- `kasane/changes/image-loading/evidence/image-behavior-observation.md:16`
- `kasane/changes/image-loading/deviation.md:16`

問題点:

証跡は「観測用コードは配布する構成には入らない」と記載していますが、合意済み deviation と実装では、iOS の観測コードはRelease Sampleにも含まれ、起動引数でのみ到達します。

推奨修正:

iOSは「Release Sampleにも含まれるが、起動引数がなければ不活性」、Androidは「measurementソースセット限定」と正確に書き分けてください。

## 確認結果と修正優先順

- core/ADR-0011対象の既存不正入力経路について、新たな違反は見つかりませんでした。
- 14件の deviation は合意済みとして扱いました。付随修正は同一能力内かつ局所的ですが、`MemoryRoundTripScreen` の引数化は上記Major 6のとおり、fixture一致を保証するテストが不足しています。
- 承認モックと両プラットフォームの最終UI画像には、指摘すべき視覚差は見つかりませんでした。
- 修正順は、キャッシュ契約（Major 1–3）→ Android表示状態（Major 4）→ 公開API対称性（Major 5）→ 計測fixture（Major 6）→ Minor、を推奨します。

現時点の `git status` は依頼文の83件ではなく、30 modified + 66 untracked = 96件でした。対象外の別change、lesson 2件、独立性を守るため未読とした既存 `review-001.md` を除く92件をレビュー対象としました。ファイルへの書き込みは行っていません。また、別worktreeに関する過去の実装履歴はレビュー結論に使用していません。

---

## 突き合わせ結果 (2026-09-07)

ホスト側 `review-001.md` (Critical 0 / Major 0 / Minor 4 / Suggestion 3、判定 CHANGES_REQUESTED) と突き合わせた。**未解決 (両者の主張が矛盾) は無し**。

| 相方の指摘 | ホスト側の対応する指摘 | 採否 | 判定根拠 |
|---|---|---|---|
| Major 1 iOS の memory プリフェッチ後の再デコード | なし | **採用** | 該当箇所 3 点を特定し、既存テストが縮小指定のない要求で確認しているため実経路を検査できていない、と検証の穴まで示している。spec「メモリ到達点の後の表示」の契約違反 |
| Major 2 `clear(.disk)` が再取得を保証しない | Minor 3 (公開 doc と実挙動の食い違い) | **確定 (重要度は Major)** | ホストは doc の書き方の問題と見たが、相方は spec「キャッシュのクリア」の契約を満たさない実装の問題と見た。spec が契約を定めている以上、後者の見立てを採る |
| Major 3 `clear` 中の進行中リクエストがキャッシュを復活させる | なし | **採用** | キャッシュ操作と進行中リクエストの台帳に連携が無いという構造的指摘。「戻った時点で削除完了」への反例シナリオが具体的 |
| Major 4 Android はメモリヒットでも最初の composition で読み込み中 | なし | **採用** | Coil 3.5.0 の描画状態の初期値が常に空である API の事実に基づく。spec「読み込み中から成功へ」「戻ってきたときの再表示」に反し、かつ静止画では検出できないことまで指摘している |
| Major 5 `KsImage` のスロット宣言構造が非対称 | なし | **採用** | core/ADR-0002 (accepted) の「宣言構造の 1 対 1」に対し、Android で書ける宣言が iOS で書けない具体例を提示 |
| Major 6 Android の計測入口が Sample と同じ固定 fixture でない | なし (未計測自体は指摘対象外としていた) | **採用** | 計測入口の項目生成が Sample と別経路で、セル文言・外周余白が一致せず、3 試行がキャッシュ状態を揃えていない。tasks 7.5 の「Sample を固定 fixture として」に反し、証跡の説明とも食い違う |
| Minor 7 `remove` が接頭辞の一致する別 URL まで削除 | Suggestion 7 (全鍵走査 = 性能の観点) | **確定 (重要度は Minor)** | ホストは性能問題と見たが、相方は誤削除という正しさの問題として具体例を示した。問題の質は相方の見立てが正しい |
| Minor 8 iOS のディスクキャッシュ設定が利用入口から発見できない | なし | **採用** | deviation で合意した仕様の帰結として、外部利用者だけが「宣言したのにディスクへ残らない」状態になる導線の欠落 |
| Minor 9 ディスクキャッシュ作成失敗が無通知 | Suggestion 6 (同一) | **確定** | 双方一致 |
| Minor 10 証跡が iOS 観測コードの配布構成について事実と矛盾 | なし | **採用** | evidence の記述と deviation の記述が食い違っている。事実は deviation 側 (release にも入るが起動引数でのみ到達) |

**ホスト側のみの指摘 (相方は触れず、根拠が明確なため維持)**: Minor 1 (デモ画面追加に対する観測点表への追随漏れ — handbook の明文に基づく) / Minor 2 (Android のキャッシュ操作が未初期化時に例外を投げ回避手段が無い) / Minor 4 (`KsImage` が表示枠の大きさを要求することが公開 doc に無い) / Suggestion 5 (iOS の `remove` の doc 文言が実装より強い)。

**集計**: 確定 3 / 採用 7 / 降格 0 / 未解決 0 + ホスト側のみ維持 4。修正対象は Major 相当 6 件・Minor 相当 7 件・Suggestion 1 件。

**所見**: 相方の Major 1〜4 はいずれも「既存テストが緑でも契約が満たされていない」型で、テストが実経路を検査できていない理由まで添えられている。ホスト側はビルド・テストを実行した上で Major 0 と判定しており、**テストの通過を契約充足の根拠にしてしまった**構図。降格に値する重箱の隅は 1 件も無かった。
