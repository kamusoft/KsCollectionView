# セカンドオピニオン: image-loading (code-003)

**相方**: codex / **label**: so-code-image-loading-3 / **日付**: 2026-09-07 / **対象**: 修正 7 便の後の作業ツリー全体 (変更 32 / 新規 66)

**独立性**: 前 2 周の指摘もホスト側のレビュー結果も渡していない。

---

# レビュー結果: image-loading

**日付**: 2026-09-07  
**判定**: **CHANGES_REQUESTED**

## サマリー

Critical 0 / Major 3 / Minor 1。

プリフェッチ台帳、共有キャッシュ、公開 API の対称性、Sample の構成、計測入口、承認モックとの外観は概ね整っています。合意済みの deviation 40 件と未実施の性能計測自体は指摘に含めていません。

一方、Android の正当な drawable 入力でクラッシュする経路、実データと矛盾する完了証跡、iOS のシナリオ未通過テストが残っています。

## 照合した規約

- core/ADR-0002 — 公開語彙・パラメータ・宣言構造の対称性
- core/ADR-0008 — `prefetchResources` と `KsImage`
- core/ADR-0011 — 不正入力時の release 継続方針
- core/ADR-0012 — proposed のため判定根拠にはせず、設計整合のみ確認
- ソースコメント規約
- Sample のプラットフォーム間一致
- テスト実行規約
- 実行時挙動の検証規約
- 公開識別子と配布座標
- iOS / Android 性能検証規約
- Kotlin / Jetpack Compose / SwiftUI のコードレビュー観点

## 指摘事項

### [🟠 Major] Android の有効な XML drawable が失敗表示ではなくクラッシュする

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:217`

**問題点**: `hasResource()` は ID が存在することしか確認せず、その後 `painterResource()` を直接呼んでいます。`painterResource()` が扱えるのは VectorDrawable と PNG/JPG/WEBP などに限られ、`@DrawableRes` として正当な shape／selector 等の XML drawable は例外になります。

そのため、公開契約上の「バンドル済みリソース」として有効な入力でも、成功・失敗状態のいずれにも遷移せず利用者アプリが停止します。既存テストは対応形式の `android.R.drawable.ic_menu_gallery` しか通していないため検出できません。

```kotlin
// 現在
if (context.hasResource(source.id)) {
    Image(painter = painterResource(source.id), ...)
}
```

```kotlin
// 修正イメージ
val painter = rememberDrawablePainterOrNull(source.id)
if (painter != null) {
    Image(painter = painter, ...)
} else {
    failureContent()
}
```

**推奨修正**: 一般の `@DrawableRes` を同期的に描画できる経路を設けるか、未対応形式を安全に検出して failure スロットと警告ログへ落としてください。shape／selector と非 drawable ID を使い、release 相当でクラッシュせず失敗表示になるテストも追加してください。

### [🟠 Major] 「戻ったときに読み込み中を経由しない」という完了証跡が観測値と矛盾する

**該当箇所**: `kasane/changes/image-loading/evidence/image-behavior-observation.md:75`  
**関連箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:168`、`kasane/changes/image-loading/tasks.md:56`

**問題点**: Android の観測値は、戻った36件のうち3件がディスクキャッシュから返ったと記録しています。しかし本番コードが読み込み中を省略できるのは、`prepared.cachedImage` をメモリから同期取得できた場合だけです。ディスクヒットでは `cachedPainter == null` のまま非同期デコードを待つため、読み込み中表示を経由します。

したがって「ネットワークに出なかった」「最終スクリーンショットにプレースホルダーがない」だけでは、過程として読み込み中を経由しなかった根拠になりません。証跡自身の3件のディスクヒットは、むしろ現在の結論に反する値です。

**推奨修正**:

- tasks 7.4 をいったん未完了へ戻す。
- 最初の表示完了と対象のメモリキャッシュ存在を確認してから画面外へ送り、同じサイズで戻す。
- 本番の `KsImage` に loading スロットの構成回数を記録する検証口を置き、回数が0であることを直接確認する。
- メモリから追い出された場合は別条件として記録し、ディスク再デコード時の読み込み表示と混同しない。

### [🟠 Major] iOS の「3種のソースを表示」テストが実表示経路を通っていない

**該当箇所**: `ios/Tests/KsCollectionViewTests/KsImageTests.swift:31`  
**関連箇所**: `kasane/changes/image-loading/tasks.md:40`

**問題点**: 該当テストが確認しているのは `KsImageRequestFactory.route()` の enum 値だけです。実際のファイル読み込みを行う `LazyImage`、アセットを解決する `UIImage(named:)`、成功／失敗状態の切り替えは一度も通していません。

それにもかかわらず tasks 5.4 は Scenario「3 種のソースを表示する」まで担保したものとして完了しています。ルーティングが正しくても、ファイル URL の取得失敗、bundle 解決の誤り、描画状態の不具合は緑のままです。

**推奨修正**: テスト中に一時画像ファイルと test bundle の画像リソースを用意し、remote／file／asset の3種類を実際の `KsImage` と `UIHostingController` で表示してください。画像が現れ、failure スロットへ落ちないところまで確認した後に tasks 5.4 を完了扱いにしてください。

### [🟡 Minor] 読み込み・失敗状態で画像のアクセシビリティ情報が失われる

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:182`  
**関連箇所**: `ios/Sources/KsCollectionView/KsImage.swift:243`

**問題点**:

- Android の `contentDescription` は成功画像とメモリ画像にしか付きません。読み込み中・失敗中は同じコンポーネントが TalkBack のツリーから消えます。
- iOS の既定失敗表示にある `photo` シンボルは装飾ですが、アクセシビリティから隠されておらず、利用者がラベルを付けない場合に意味の薄い「photo」だけが読まれ得ます。

```kotlin
// 現在: 状態ごとに semantics が変わる
Image(contentDescription = contentDescription)
failure?.invoke() ?: KsImageDefaultFailure()
```

```kotlin
// 修正イメージ: ルートが状態をまたいで説明を保持する
Box(modifier = rootImageSemantics(contentDescription)) {
    // 子の Image は contentDescription = null
}
```

**推奨修正**: Android はルートに画像 semantics を置き、状態にかかわらず `contentDescription` を維持してください。iOS の既定失敗マークには `.accessibilityHidden(true)` を付けてください。loading／failure 状態の semantics テストも追加してください。

## アクションプラン

1. Android の Resource 描画を、対応外 XML drawable でもクラッシュしない実装にする。
2. Android の戻り再表示を、loading スロットの構成回数で直接再検証し、tasks 7.4 と証跡を修正する。
3. iOS の file／asset を実 `KsImage` で表示するテストを追加する。
4. 両プラットフォームの既定状態にアクセシビリティ修正を入れる。
5. 修正後に独立レビューを再実施する。

ファイルへの書き込み、ビルド、テスト実行は行っていません。過去メモは検証観点の補助にのみ使い、今回の判定根拠は現在の契約・コード・テスト・証跡です。

---

## 突き合わせ結果 (2026-09-07)

ホスト側 `review-003.md` (Critical 0 / Major 2 / Minor 2 / Suggestion 1、判定 CHANGES_REQUESTED) と突き合わせた。**両者とも「前周の指摘はすべて解消」で一致**。未解決 (主張の矛盾) は無し。

| 相方の指摘 | ホスト側の対応する指摘 | 採否 | 判定根拠 |
|---|---|---|---|
| Major 1 Android の有効な XML 形式のリソースがクラッシュする | なし | **採用** | 公開契約上有効な入力 (バンドル済みリソース) で、成功にも失敗にも遷移せずアプリが停止する。**core/ADR-0011 (accepted) の「落とさず」に対する明確な違反**。既存テストが対応形式のリソースしか通していないため検出できていない理由まで示している |
| Major 2 「戻ったときに読み込み中を経由しない」の証跡が観測値と矛盾 | なし | **採用** | 証跡自身が「戻った 36 件のうち 3 件はディスクから返った」と記録しているが、読み込み中を省略できるのはメモリから同期取得できた場合だけ。**証跡の内部の値が証跡の結論に反している**という指摘で、根拠は証跡自身にある |
| Major 3 iOS の「3 種のソースを表示する」テストが実表示経路を通っていない | Major 2 (表示経路の Scenario 検査が本番の呼ばない関数に対して行われている) | **確定 (Major)** | 同型の指摘。相方は特定の Scenario のテストが経路の分岐値しか見ていないこと、ホストは検査 13 箇所が本番の呼ばない関数に向いていることを指摘。どちらも「テストが本番経路を通っていない」 |
| Minor 1 読み込み中・失敗の状態で画像のアクセシビリティ情報が失われる | なし | **採用** | 両プラットフォームの具体箇所を挙げ、Android は状態が変わると読み上げのツリーから消えること、iOS は既定の失敗表示の記号が隠されていないことを示している |

**ホスト側のみの指摘 (相方は触れず、いずれも根拠が明確なため維持)**:

- **Major 1**: iOS で一度表示した画像を表示し直すと読み込み中を経由する (先読みの有無に関わらず)。レビュアーが一時プローブで実測 (iOS 1 回 / Android 0 回)
- Minor 1 (Android の `removeMakesTheDisplayedImageReload` の待機が原理的に落ちうる — 機序を特定) / Minor 2 (縮小を表示の組み立て中に同期で行う設計の費用が未記録) / Suggestion (iOS の `prepare` が SwiftUI の body 評価の中で共有キャッシュへ書き込む)

**集計**: 確定 1 / 採用 3 / 降格 0 / 未解決 0 + ホスト側のみ維持 4。**Major 相当 4 件 / Minor 相当 3 件 / Suggestion 1 件**。

**所見**: 3 周を通じて降格は 1 件も出ていない。相方は 3 周とも前周の指摘を渡されずに実施したが、毎回まったく新しい領域を突いている (1 周目キャッシュ契約 / 2 周目 台帳と計測入口 / 3 周目 リソース描画と証跡の内部矛盾)。ホスト側はビルドとテストを実行できる立場を活かし、3 周目は一時プローブで実測して Major 1 を確定させた。**両者の役割が補完的に働いている**一方、「テストが本番経路を通っていない」型は 3 周連続で検出されており、この change の構造的な弱点になっている。
