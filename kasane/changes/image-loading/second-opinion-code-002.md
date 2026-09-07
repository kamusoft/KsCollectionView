# セカンドオピニオン: image-loading (code-002)

**相方**: codex / **label**: so-code-image-loading-2 / **日付**: 2026-09-07 / **対象**: 修正 4 便の後の作業ツリー全体 (変更 32 / 新規 60)

**独立性**: 前周の指摘 (`second-opinion-code-001.md`) も突き合わせ結果もホスト側のレビュー結果も渡していない。前周の指摘が解消されていなければ同じ指摘が再び出る、という形で収束を判定するため。

---

# レビュー結果: image-loading

**日付**: 2026-09-07  
**判定**: **CHANGES_REQUESTED**  
**件数**: Critical 0 / Major 3 / Minor 1 / Suggestion 0

## サマリー

公開 API の主要な対称性、プリフェッチ到達点、Sample の構成、画像縮小、キャッシュ共有は概ね契約に沿っています。`deviation.md` の28件は合意済み差分として扱い、違反には数えていません。付随修正も局所的で、提示された全件テスト結果による担保があります。

一方、キャッシュ消去の競合、同一IDの内容更新、Android計測入口に契約上の欠落があり、修正が必要です。静的レビューのため、ビルド・テストは再実行せず、依頼文記載の結果を前提としました。

## 照合した規約

- ソースコメント規約（always）
- Sample のプラットフォーム間一致
- テスト実行規約
- 実行時挙動の検証規約
- 公開識別子と配布座標
- iOS 性能検証の手順と合格基準
- Android 性能検証の手順と合格基準
- core/ADR-0002、0008、0011
- core/ADR-0012 は proposed のため、判定根拠ではなく変更契約の文脈としてのみ参照

## 指摘事項

### [🟠 Major] `clear(memory)` 後に進行中のプリフェッチがメモリキャッシュを書き戻せる

**該当箇所**:

- `ios/Sources/KsCollectionView/KsImageCache.swift:24`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageCache.kt:30`
- `ios/Tests/KsCollectionViewTests/KsImagePrefetchTests.swift:290`
- `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt:398`
- `specs/image-loading/spec.md:178`

**問題点**: 両実装とも、進行中の先読みを停止するのは `all` の場合だけです。`memory` 到達点のプリフェッチを保留中に `clear(memory)` を呼ぶと、呼び出しが戻った後に先読みが完了し、メモリキャッシュを再充填できます。その後の表示はメモリにヒットし、契約上要求される「ディスクから再デコード」になりません。

テストも「メモリのみ消去では先読みを止めない」ことを期待しており、契約違反を固定しています。`deviation.md` にある「取り消しと完了が同時に競った場合」の合意済み限界とは異なり、この経路では取り消し自体を行っていません。

**推奨修正**: `clear(memory)` の前に、少なくともメモリへ書き込む進行中のプリフェッチを停止してください。現在の registry が到達点を区別できないなら、まずは `fenceAll()` してからメモリを消す形でも契約を満たせます。応答を保留した `.memory` プリフェッチについて「clear → 応答解放 → メモリに戻らない → 次回はディスクから再デコード」を両プラットフォームでテストしてください。

### [🟠 Major] 同じ安定IDの項目内容が変わっても、プリフェッチURLが更新されない

**該当箇所**:

- `ios/Sources/KsCollectionView/KsCollectionViewController.swift:133`
- `ios/Sources/KsCollectionView/KsImagePrefetcher.swift:32`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:76`
- `specs/image-loading/spec.md:7`

**問題点**: 台帳は安定IDだけで既存要求を判定しています。

```kotlin
if (urlsByItemId.containsKey(itemId)) continue
```

例えば、ID `X` の画像URLが `A` から `B` に変わる配列更新では、iOSの `retain` はID `X`を残し、Androidも既存IDとして処理を飛ばします。以後の通知でも古いURL `A` が台帳にあるため、新しいURL `B` は先読みされません。古い取得も不要になった時点で取り消されません。

`prefetchResources` クロージャ自体を差し替えないという制約は、同じクロージャへ渡される項目内容の更新を禁止していません。既存のコレクション契約も、同一IDの内容更新を通常の更新として扱っています。

**推奨修正**: 配列更新時または先読み通知時に、追跡中IDについて現在の項目からURL集合を再解決し、旧集合との差分を参照数へ反映してください。概念的には次の形です。

```kotlin
reconcile(itemId, resources(item), destination)
```

同じIDでURLだけを変更したときに、旧URLが解放され、新URLが開始され、他の項目と共有中のURLは誤って取り消されないテストを両プラットフォームへ追加してください。

### [🟠 Major] Android画像メモリ計測から1,000件対10,000件の比較を取得できない

**該当箇所**:

- `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/ImageGridBenchmark.kt:45`
- `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/ImageGridBenchmark.kt:87`
- `samples/android/benchmark/src/main/kotlin/jp/kamusoft/kscollectionview/samples/android/benchmark/ImageGridBenchmark.kt:130`
- `kasane/handbook/android/performance-verification.md:20`

**問題点**: 画像メモリ計測はディスク・メモリ到達点の双方で `ItemCount = 10_000` だけを実行します。計測画面とルートは件数を受け取れるものの、benchmark入口から1,000件を起動するテストがありません。

Android性能規約は、メモリ定常値が1,000件から10,000件への件数比に比例しないことまで合格条件にしています。現在の入口をそのまま実行しても、この判定材料を生成できません。これは未計測そのものではなく、計測入口の不足です。

**推奨修正**: 少なくとも `disk` / `memory` の各到達点について1,000件と10,000件を走らせる入口を用意し、4系統の定常値を比較できるようにしてください。証跡テンプレートにも件数比較欄を追加してください。

### [🟡 Minor] 新規テストコメントが作業タスク番号へ依存している

**該当箇所**: `samples/android/app/src/test/kotlin/jp/kamusoft/kscollectionview/samples/android/ImageGridMeasurementFixtureTest.kt:20`

**問題点**: `tasks 7.5` はアーカイブされる作業文書のローカル通番で、cross/comment-policy の禁止する参照に該当します。禁止件数0というlint結果は、この表現を検出できていません。

**推奨修正**: 「画像グリッドの性能計測がデモ画面と同じ土俵であることの証明になる」のように、ファイル単体で意味が閉じる説明へ置き換えてください。

## アクションプラン

1. 両プラットフォームの `clear(memory)` で進行中のメモリ書き込みをフェンスし、競合テストを追加する。
2. 同一安定IDのURL集合変更を台帳へ反映し、共有URLを含む回帰テストを追加する。
3. Android画像メモリ計測へ1,000件の入口と件数比較用の証跡欄を追加する。
4. `tasks 7.5` コメントを自己完結した説明へ変更する。
5. 修正後に全件テストと独立再レビューを行う。

結果ファイルは、依頼どおり作成していません。

---

## 突き合わせ結果 (2026-09-07)

ホスト側 `review-002.md` (Critical 0 / Major 2 / Minor 1 / Suggestion 2、判定 CHANGES_REQUESTED) と突き合わせた。**両者とも「1 周目の指摘はすべて解消」で一致**。未解決 (主張の矛盾) は無し。

| 相方の指摘 | ホスト側の対応する指摘 | 採否 | 判定根拠 |
|---|---|---|---|
| Major 1 `clear(memory)` 後に進行中の先読みが書き戻せる | Minor 3 (フェンスが先読み層だけを対象にしており範囲差が未記録) | **確定 (重要度は Major)** | 両者が別々の範囲差を突いているが根は同じ (消去時のフェンスの適用範囲)。相方は「メモリ消去では取り消し自体を行っていない」、ホストは「表示中の要求は止まらない」。相方の方が契約違反として直接的 |
| Major 2 同じ安定 ID の項目内容が変わっても先読み URL が更新されない | なし | **採用** | 台帳が安定 ID だけで既存判定していることをコード引用付きで示し、ID 据え置きで URL が変わる更新という具体シナリオを提示。spec の Requirement「プリフェッチ宣言」に照らして違反 |
| Major 3 Android の画像メモリ計測に 1,000 件の入口が無い | なし | **採用** | `handbook/android/performance-verification.md` がメモリ定常値の件数比を合格条件にしているのに、計測入口が 10,000 件だけ。未計測ではなく計測入口の不足という切り分けも正確 |
| Minor 4 新規テストコメントが作業タスク番号 (`tasks 7.5`) に依存 | なし | **採用** | `handbook/cross/comment-policy.md` の禁止する参照に該当。lint が検出できていない点まで指摘しており、lint 側の穴の材料にもなる |

**ホスト側のみの指摘 (相方は触れず、いずれも根拠が明確なため維持)**:

- **Major 1 (iOS)**: 到達点メモリの先読みの後でも `KsImage` の初回表示が読み込み中を経由する
- **Major 2 (Android)**: 到達点メモリの先読みの後、`KsImage` が元寸の画像をそのまま表示・保持する
- Suggestion 1 (iOS の計測入口が Sample と宣言元を共有していない) / Suggestion 2 (`evidence/image-grid-measurement-ios.md` の状態表が本文の自己申告と食い違う)

**集計**: 確定 1 / 採用 3 / 降格 0 / 未解決 0 + ホスト側のみ維持 4 (Major 2・Suggestion 2)。

**所見**: 相方の 2 周目は 1 周目の指摘を一切渡さずに実施したが、**前周の指摘は 1 件も再出現しなかった** — 修正が実際に効いていることの独立した裏づけになる。一方でホスト側だけが捉えた Major 2 件は、**1 周目の修正が新たに生んだ契約違反**で、同じ継ぎ目 (到達点メモリの先読み → `KsImage` の表示) をプラットフォームごとに逆向きへ倒した結果。相方はこの継ぎ目を今周は見ていない。降格に値する指摘は今周も 0 件。
