# セカンドオピニオン: image-loading (code-009)
**相方**: codex / **label**: so-code-image-loading-009 / **日付**: 2026-09-08 / **対象**: Android 到達点 memory の暫定回避 (`allowHardware(false)`) の撤去 (オーナー判断 C): KsCoilImageLoading / KsImageRequestFactory / KsImage の doc、KsImageCacheContractTest の追加テスト、KsImageDeviceDecodeTest の契約改訂
---

**日付**: 2026-09-08  
**判定**: CHANGES_REQUESTED

## サマリー

`Unreadable` 判定が `toBitmap` より前に残っているため、`allowHardware(false)` の撤去によるクラッシュ経路の復活は防げています。実機テストも本番の adapter・共有ローダー・要求組み立て経路を通しており、キャンセル、キャッシュ消去、iOS との実装非対称にも新たな問題は見つかりませんでした。

一方、指定された修正証跡が撤去前の契約を現在形で説明しており、新しい A/B 結果と正面から矛盾しています。

## 照合した規約

- ソースコメント規約（always）
- テスト実行規約
- 実行時挙動の検証規約
- Android 性能検証の手順と合格基準
- core/ADR-0001「描画エンジンの非対称構成」
- core/ADR-0002「対称性の粒度」
- Kotlin 実装・レビュー規律
- Jetpack Compose 実装・レビュー規律

テストは依頼文記載のホスト結果（本体 130 / 0、Sample 28 / 0、実機 3 / 0、release 成功、lint 禁止 0 件）を根拠とし、この静的レビューでは再実行していません。

## 指摘事項

### 🟠 Major: 修正証跡が撤去前の契約とテスト内容を報告している

**該当箇所**: `evidence/image-grid-memory-prefetch-crash-fix-android.md:37`、`evidence/image-grid-memory-prefetch-crash-fix-android.md:48`

**問題点**: 証跡は現在も次を修正後の結果として記載しています。

- 「画像は読み込み中を挟まずに出る」
- 先読み画像が「画素を読み出せる」ことを成功条件とする
- 元寸から同期作成した表示画像が枠内になることを成功条件とする

今回の到達点は逆であり、`deviation.md:83` と実装は「元寸は `HARDWARE`」「`cachedImage` は null」「読み込み中を経てローダーが縮小デコード」と定めています。テスト名と A/B の失敗内訳も既に変わっているため、この証跡からは今回の差分が実機で検証されたことを追跡できません。

**推奨修正**: 証跡へ撤去後の節を追加するか、現在の結果へ更新してください。最低限、以下を記録します。

- Pixel 6a での現在の 3 テストの検証内容と 3 / 0
- `Unreadable` 分岐を無効化した場合、2 / 3 が製品と同じ例外で失敗する A/B
- 元寸が `Bitmap.Config.HARDWARE` であること
- `prepare` が落ちず、初回画像を返さないこと
- 続くローダー要求が枠内の画像を返すこと
- 初回表示が読み込み中を一瞬経由すること

既存スクリーンショットが `allowHardware(false)` 適用中のものなら、その時点の履歴証跡であることも明記してください。

### 🟡 Minor: `cachedImage` と再デコードの説明が旧契約のまま

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageRequestFactory.kt:22`、`android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt:213`

**問題点**:

- `cachedImage` の KDoc は「メモリに何も無い場合だけ null」と説明していますが、現在は読み出せない元寸がメモリにある場合も null です。
- `memoryDestinationAvoidsSecondDecode` は到達点 memory が常に再デコードを避けるように読めますが、テストの `ColorImage` が読み出せる場合だけ成立します。実機の既定経路では、縮小された表示画像を得るためローダーのデコードを待ちます。

**推奨修正**: KDoc に `Unreadable` の場合を加え、テスト名と説明を「先読み画像の画素を読み出せる場合」に限定してください。テストロジック自体の変更は不要です。

## 確認結果

- クラッシュ防止: `isPixelReadable()` が `toBitmap()` より前に評価されるため維持されています。
- 本番経路の固定: 実機テストは `KsCoilImageLoading` → singleton `ImageLoader` → `KsImageRequestFactory.prepare` → サイズ付き要求の実行まで通しています。
- 取り消し・キャッシュ消去: `Disposable.dispose()`、prefetch fence、世代無効化の経路は今回変更されておらず、ハードウェア許可とは独立しています。
- iOS 非対称: iOS は読み出せない画像に相当する制約がなく、縮小失敗時も nil に落ちる既存経路です。Android 固有の `Unreadable` 分岐は、合意済み deviation の範囲内です。
- 指摘件数: Critical 0、Major 1、Minor 1、Suggestion 0。
- 指示どおりレビュー結果ファイルは作成していません。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果 (ホスト側 review-009.md との照合、2026-09-08)

| 相方の指摘 | ホスト側 | 採否 |
|---|---|---|
| Major: クラッシュ修正の証跡 (`evidence/image-grid-memory-prefetch-crash-fix-android.md`) が撤去前の契約を現在形で報告 | Major 3 (同内容) | **確定 (Major)** |
| Minor: `cachedImage` の KDoc が旧契約 / `memoryDestinationAvoidsSecondDecode` が「常に再デコードを避ける」と読める | Major 2 (同テストがソフトウェアビットマップの上でだけ緑) + Minor (記述の食い違い) | **確定** (重要度はホスト側の Major を採る。KDoc は相方のみだが根拠強で採用) |

ホスト側のみ: Major 1 (破れる SHALL が「デコードのやり直しなし」にも及ぶ記録漏れ → deviation に記録済み)、Minor (実機テストの HARDWARE 前提を `Assume` に)、Suggestion (iOS との非対称 → deviation に記録済み)。
集計: 確定 2 / 採用 0 / 降格 0 / 未解決 0。
