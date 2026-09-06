# セカンドオピニオン: image-loading (spec-001)
**相方**: codex / **label**: so-spec-image-loading / **日付**: 2026-09-06 / **対象**: 提案一式 (proposal.md / design.md / specs/image-loading/spec.md / tasks.md / ui/brief.md)
---
## 1. 総評

画像ロードの主要機能は広く整理されていますが、共有ローダーの変更、キャッシュ削除、プリフェッチの寿命管理に未解決の設計問題があります。  
特に iOS の共有パイプライン差し替えは利用者設定を失う可能性があり、現状のまま実装へ進むのは危険です。  
また、受け入れ基準と性能検証計画が既存 handbook を満たしていません。  
静的レビューのため、ビルド・テスト・ファイル変更は実施していません。

## 2. 指摘一覧

### [🟠 Major] アプリが構成した Nuke パイプラインを破壊し得る

**該当箇所**: `design.md:23`、`specs/image-loading/spec.md:82`、`kasane/decisions/core/0012-image-loader-direct-dependency.md:20`

**問題点**: `dataCache == nil` は「アプリが未構成」を意味しません。認証用 delegate、独自 DataLoader、URLCache、リクエスト設定などを持つカスタムパイプラインでも `dataCache` は nil にできます。その状態で `.withDataCache()` の新規パイプラインへ差し替えると、仕様の「アプリが先に構成していれば変更しない」に反して設定を失います。Nuke 自身もパイプラインの構成要素として configuration と delegate を明示しています。[Nuke ImagePipeline 公式資料](https://kean-docs.github.io/nuke/documentation/nuke/imagepipeline/)

**推奨修正**: 「未構成」の判定方法と既存構成の保存方法を設計してください。実現不能なら、明示的な初期化 API、アプリ側による事前構成、または専用パイプラインへ方針変更する必要があります。少なくとも「独自 delegate/DataLoader を持つが dataCache は nil」のテストを追加してください。

### [🟠 Major] iOS の縮小方式が縮小デコード契約を十分に満たさない

**該当箇所**: `design.md:85`、`specs/image-loading/spec.md:126`、`specs/image-loading/spec.md:134`

**問題点**: 設計は `ImageProcessors.Resize` を使いますが、これは画像処理であり、Nuke がデコード時の省メモリ手段として提供する `ImageRequest.ThumbnailOptions` よりメモリ効率が劣ります。Nuke 公式資料も ThumbnailOptions の方が特にメモリ面で効率的と説明しています。[Nuke ImageRequest 公式資料](https://kean-docs.github.io/nuke/documentation/nuke/imagerequest/)

さらに `fill` ではアスペクト比維持と切り抜きが必要ですが、設計の要求例には `contentMode` と `crop` の写像がありません。このままでは「枠を埋める」と「デコード画像が枠サイズを超えない」の両立方法が決まりません。

**推奨修正**: `fit`／`fill` ごとの ThumbnailOptions、表示倍率、crop の具体的な写像を定義してください。最終画像サイズだけでなく、元寸画像を展開しないことを観測できる実ローダー試験とメモリ試験も必要です。

### [🟠 Major] プリフェッチ要求の寿命と再構成時の扱いが未定義

**該当箇所**: `specs/image-loading/spec.md:25`、`design.md:135`、`tasks.md:21`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:88`、`ios/Sources/KsCollectionView/KsCollectionViewController.swift:712`

**問題点**: 現行 iOS 実装は取消通知時の IndexPath を、その時点の snapshot と `itemsByID` で引き直します。配列差し替え後には、削除された旧アイテム X を復元して取り消せません。iOS のタスクにも「配列差し替え」「画面破棄」の自動テストがありません。

また、SwiftUI 更新で prefetcher が差し替わる場合、Compose のラムダや destination が変わる場合、同じ URL を複数アイテムが要求する場合の所有権も未定義です。単純な URL 単位取消では、別アイテムがまだ必要としている共有 URLまで止める可能性があります。

**推奨修正**: アイテム ID → URL 集合 → 実要求の台帳と、URLごとの参照数を持つ寿命モデルを定義してください。配列・クロージャ・destination の変更時に差分調整し、disconnect／composition 離脱時に全停止する設計としてください。両プラットフォームで共有 URL、配列差し替え、宣言解除、destination 変更、破棄をテスト対象に含めてください。

### [🟠 Major] `KsImageCache` の削除保証と表示中画像の再取得が成立していない

**該当箇所**: `design.md:114`、`specs/image-loading/spec.md:160`、`ui/brief.md:21`、`tasks.md:35`

**問題点**: iOS の「弱参照の台帳」では、表示 View が破棄された後もキャッシュに残る縮小鍵を列挙できません。一方、強参照で全 URL・全サイズを保持すると、10,000 件の画像を走査した際に台帳が増え続けます。削除保証とメモリ定常化の両立方法が決まっていません。

また、キャッシュを削除しても、表示中の `LazyImage`／`AsyncImage` が保持している画像状態は自動では無効化されません。そのため brief の「押すと表示中の画像が読み込み中を経由して再取得される」は、現在のタスクだけでは実現されません。

**推奨修正**: 次のいずれかを選択してください。

- `remove` の保証を現在の具体的な要求鍵だけに狭める
- キャッシュ eviction と連動する上限付き台帳を設計する
- v1 からソース単位削除を外す

加えて、`clear/remove` の完了タイミングと、表示中の `KsImage` を再要求させる世代番号等の無効化機構を仕様化してください。

### [🟠 Major] 公開 API の外形が確定しておらず、対称性と Android の実装方式が衝突する

**該当箇所**: `design.md:57`、`design.md:85`、`tasks.md:14`、`tasks.md:35`、`kasane/decisions/core/0002-symmetry-granularity.md:16`

**問題点**:

- Swift の `destination` に対して Kotlin は `prefetchDestination`
- Swift の `contentMode` に対して Kotlin は `contentScale`
- Android `KsImage` の `Modifier` と `contentDescription` が未定義
- スロットが任意の SwiftUI／Composable content なのか、画像 Painter なのか不明

これは「パラメータ名・宣言構造を1対1対応させる」という accepted ADR と衝突します。また Coil の `AsyncImage` の placeholder/error は `Painter` であり、Composable slot を持つのは `SubcomposeAsyncImage` です。後者は Lazy UI では遅いと公式に注意されています。[Coil Compose 公式資料](https://coil-kt.github.io/coil/compose/)

**推奨修正**: 両プラットフォームの完全な公開シグネチャと利用例を design に固定してください。同じ語彙へ揃えられない場合は、実装前に ADR の改訂判断が必要です。Android の slot は Painter に限定するか、制約サイズを保持した `rememberAsyncImagePainter` ベースで Composable slot を構成するかを決定し、アクセシビリティラベルも契約へ追加してください。

### [🟠 Major] 性能検証計画が handbook の必須基準を満たさない

**該当箇所**: `proposal.md:18`、`tasks.md:48`、`kasane/handbook/ios/performance-verification.md:17`、`kasane/handbook/android/performance-verification.md:18`

**問題点**: 「実機計測1回」では既存規約を満たしません。

- iOS は hitch time ratio の独立3試行、メモリ定常化、独立2実行が必要
- Android は P90/P99 の相対値、`frameOverrunMs` P99、3試行、1,000件対10,000件のメモリ比較が必要
- 新しい3列画像グリッドは既存固定 fixture の代替にはならない
- Android の prefetch 有効側だけ追加処理を持たせて素の Grid と比較すると、「ラッパー上乗せ」ではなくプリフェッチ機能自体の負荷を測ることになる

**推奨修正**: 既存固定 fixture による回帰計測と、画像グリッド固有の取得・取消・メモリ計測を分けてください。Android の相対比較では比較対象にも同等のプリフェッチ処理を持たせるか、有効時は絶対基準のみで評価してください。

### [🟠 Major] Fake 中心のテストでは機能の中核契約を判定できない

**該当箇所**: `design.md:135`、`tasks.md:24`、`tasks.md:38`、`tasks.md:52`

**問題点**: Fake が証明できるのは「destination が adapter に渡った」ことまでです。次の契約は実 Nuke／Coil のキャッシュ鍵・デコーダ・共有インスタンスの挙動に依存するため、Fake では判定できません。

- disk 後にネットワークアクセスが起きない
- memory 後に再デコードしない
- ローダー付属ビューと共有できる
- ソース単位削除で対象だけ消える
- BlackholeDecoder が本当にデコードを行わない

**推奨修正**: URLProtocol／制御可能な fetcher、実 Nuke／Coil、取得回数・デコード回数のカウンタを組み合わせた決定的な統合試験を追加してください。公開プレースホルダーサービスによる手動確認だけを合否根拠にしないでください。

### [🟡 Minor] 読み込み状態と再試行の発火条件が矛盾・曖昧

**該当箇所**: `specs/image-loading/spec.md:108`、`specs/image-loading/spec.md:147`

**問題点**: 「remote/file は読み込み中を経由する」という要求と、「キャッシュ済みなら読み込み中を経由せず表示する」という要求が矛盾します。また「同じソースが再度表示されたら再試行」が、同じ View の再評価、再利用、画面再入場のどれを意味するか決まっていません。

**推奨修正**: 読み込み中表示は cold miss の場合に限ることを明記し、再試行の発火条件を「失敗した View の再生成」「明示的 restart」など観測可能な条件へ固定してください。

## 3. 判定

**NEEDS_DISCUSSION**

Critical 0件、Major 7件、Minor 1件です。特に共有パイプラインの扱い、キャッシュ削除保証、Android slot API は実装だけでは解消できず、仕様・設計判断が必要です。


## 突き合わせ結果 (2026-09-06)

ホスト側の自己レビュー (整合性チェックリスト・UI lint・上位層違反・agenda 決定事項の照合) は通過していたため、以下はすべて「相方のみ」の指摘。根拠の強さで採否を判定した。

| # | 指摘 | 採否 | 反映 |
|---|---|---|---|
| 1 | `dataCache == nil` を未構成とみなす差し替えがアプリ構成を失う | **採用** (根拠強: 独自 DataLoader / delegate で dataCache nil は成立する) | design Decision 1 を「現在の configuration と delegate を引き継ぎ dataCache だけ足す」に変更。tasks 3.3 / 3.5 |
| 2 | `Resize` より `ThumbnailOptions` が省メモリ、fill の写像未定義 | **採用** (根拠強: Nuke 公式の案内、fill の crop が未定義だった) | design Decision 5 を `ThumbnailOptions` + fit / fill の目標寸法に変更。spec「縮小デコード」を fit / fill で明文化。tasks 5.1 / 5.4 |
| 3 | 取り消しの寿命 (配列差し替えの旧アイテム・共有 URL・宣言差し替え) が未定義 | **採用** (根拠強: iOS は差し替え後の IndexPath から旧アイテムを引けない) | design Decision 3 に台帳 + 参照数の寿命モデルを追加。spec「取り消し」に共有 URL と宣言差し替えの契約と Scenario を追加。tasks 3.1 / 3.4 / 4.2 / 4.3 |
| 4 | 弱参照の台帳では削除保証が成立せず、表示中ビューが無効化されない | **採用** (根拠強) | design Decision 7 を上限付き値型の台帳 + 世代番号による無効化に変更。spec「キャッシュのクリア」を保証範囲・完了タイミング・表示中の再取得で明文化。iOS の `remove` は当初「上限付き台帳」で反映したが、オーナー確認で「台帳から落ちた鍵は古い画像が出る」窓が残ると判明し、世代付きキャッシュ識別子 (`imageIdKey`) に変更 (2026-09-06) |
| 5 | 公開 API の外形が未確定で ADR-0002 の名前 1 対 1 と衝突 | **採用** (根拠強: `contentMode` ⇔ `contentScale` は名前も値も揃っていなかった) | design Decision 6 に両プラットフォームの公開シグネチャを固定。当てはめ方は共通の `KsImageContentMode` (fit / fill)。Kotlin `prefetchDestination` は `touchFeedbackColor` と同じ接頭辞規則で維持。Android は `modifier` / `contentDescription` を追加、スロットは `rememberAsyncImagePainter` ベースの Composable (`SubcomposeAsyncImage` 不使用) |
| 6 | 性能検証が handbook の必須基準を満たさない | **採用** (根拠強: Android の先読み窓はスクロール経路に乗り、handbook/android の rule が適用される) | design Risks と tasks 7.1 / 7.2 / 7.5 を、Android は既存 fixture で全系統の回帰計測 + 画像グリッド fixture で絶対基準、iOS は画像グリッド fixture で hitch 3 試行 + メモリ定常化に変更。agenda の「実機計測 1 回」は handbook の rule が上位なのでそれに従う |
| 7 | fake だけではキャッシュ契約を判定できない | **採用** (根拠強) | design Decision 8 に取得層をスタブした実ローダーの統合テストを追加。tasks 3.6 / 4.4 |
| 8 | 読み込み中の経由条件と再試行の発火条件が曖昧 | **採用** (Minor) | spec「表示状態」を cold miss の場合に限定し、再試行をビューの再生成と世代更新に固定。Scenario 追加 |

未解決 (NEEDS_DISCUSSION) はなし。#4 はオーナー確認の結果、世代付き識別子の案 (削除後はどのサイズでも旧項目に当たらない。消したソースに限りローダー付属ビューとの共有が切れる) で確定した。
