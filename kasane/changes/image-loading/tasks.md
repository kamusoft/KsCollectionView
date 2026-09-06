# Tasks: image-loading

対応する契約は `specs/image-loading/spec.md`。設計判断は `design.md` の Decision N。UI の見た目の正は `ui/mock/approved.png`。

## 1. 依存の追加と利用者要求値の確認

- [ ] 1.1 iOS: `ios/Package.swift` に Nuke (from: "13.2.0") を依存に追加し、本体 target に `Nuke` / `NukeUI` を繋ぐ。Swift 6 言語モードで警告なくビルドできることを確認する (→ Decision 2)
- [ ] 1.2 Android: `android/gradle/libs.versions.toml` に Coil 3.5.0 (`coil-compose` / `coil-network-okhttp`) を追加し、版固定の理由 (3.6 系は Compose 1.12 / compileSdk 37 を推移) をコメントに残す。本体に `api(coil-compose)` / `implementation(coil-network-okhttp)` (→ Decision 2)
- [ ] 1.3 Android: Sample (compileSdk 36) のビルドが通ること、`dependencies` レポートで `androidx.compose.foundation` が 1.11.4 のままであること、本体 AAR の `aar-metadata.properties` の `minCompileSdk` を確認し、結果を `evidence/dependency-requirements.md` に残す (→ Decision 2、lessons: check-consumer-compile-sdk-before-adopting-latest-dependency)
- [ ] 1.4 Sample のデモ画像に使う公開プレースホルダー画像サービスを選定し (アイテム ID から決定的な URL を作れること、サイズ指定で正方形が取れること)、`kasane/config.yaml` の identity lint 許可設定に必要ならホストを追加する

## 2. 公開型 (両プラットフォーム)

- [ ] 2.1 `KsPrefetchDestination` (`disk` / `memory`) と `KsImageSource` (remote / file / asset・resource) を両プラットフォーム同名で追加 (→ Requirement: プリフェッチ宣言、KsImage の画像ソース)
- [ ] 2.2 iOS: `KsCollectionView.prefetchResources(destination:_:)` modifier を追加し、`KsCollectionConfiguration.prefetcher` へ URL 解決層を経由して接続する (→ Requirement: プリフェッチ宣言)
- [ ] 2.3 Android: `KsCollectionView` に `prefetchResources: ((Item) -> List<String>)? = null` と `prefetchDestination: KsPrefetchDestination = Disk` を追加する (→ Requirement: プリフェッチ宣言)
- [ ] 2.4 公開 API テスト (iOS `KsPublicAPITests` の延長 / Android の既存の公開面テスト) に新しい型・引数の存在と既定値を追加する

## 3. iOS のプリフェッチ接続

- [ ] 3.1 internal な受け口 `KsImageLoading` (`prefetch(urls:destination:)` / `cancel(urls:)`) を定義し、`KsPrefetching` の実装 (アイテム → URL 解決 → 台帳 (アイテム ID → URL 集合、URL → 参照数) → 受け口) を追加する。snapshot 適用時に消えたアイテムの要求を取り消し、controller 解放時に全停止する (→ Requirement: プリフェッチの取り消し、Decision 3・8)
- [ ] 3.2 Nuke adapter: `ImagePrefetcher` を到達点ごとに持ち (`.diskCache` / `.memoryCache`)、URL 単位の `startPrefetching` / `stopPrefetching` に写像する (要求にはソースの世代に応じた識別子を付ける)。コレクション破棄時に全停止 (→ Requirement: プリフェッチの取り消し、プリフェッチの到達点、Decision 3)
- [ ] 3.3 共有パイプライン: 初回利用時にディスクキャッシュ未設定なら、現在の `configuration` と `delegate` を引き継ぎ `dataCache` だけを足した構成で `ImagePipeline.shared` を差し替える (→ Requirement: 共有キャッシュ、Decision 1)
- [ ] 3.4 テスト: 記録用 fake の受け口で、通知されたアイテムが URL に解決され到達点付きで開始・取り消しされること、複数 URL、空配列、宣言なしで何も起きないこと、共有 URL の参照数、配列差し替えで消えたアイテムの取り消し、controller 解放での全停止を確かめる (→ Scenario: もうすぐ表示されるアイテムの画像を取得する、宣言が無ければ何も起きない、複数 URL の宣言、到達点が伝わる、システムの先読み通知に従う、共有 URL は最後のアイテムが外れるまで取り消さない、配列の差し替えで消えたアイテム、画面から消えたら全て取り消す)
- [ ] 3.5 テスト: 共有パイプラインの差し替え条件 (未設定なら差し替え、設定済みなら不変) と、独自 DataLoader / delegate を持ち `dataCache` が nil の構成が差し替え後も引き継がれること (→ Scenario: iOS のディスクキャッシュ有効化)
- [ ] 3.6 統合テスト iOS: `URLProtocol` スタブとデコード回数カウンタ付きのテスト用パイプラインを受け口経由で注入し、ディスク到達点後にネットワークが走らないこと、メモリ到達点後に再デコードしないこと、`LazyImage` 直接利用でキャッシュが共有されること、ソース単位の削除で対象だけ消えることを確かめる (→ Scenario: ディスク到達点の後の表示、メモリ到達点の後の表示、ローダー付属ビューとキャッシュを共有する、ソース単位の削除、メモリのみ消去)

## 4. Android の先読み窓

- [ ] 4.1 internal な受け口 `KsImageLoading` (`enqueue(url, destination): Disposable`) と Coil adapter (`SingletonImageLoader`、disk = `memoryCachePolicy(DISABLED)` + `BlackholeDecoder`、memory = 既定) を追加する (→ Decision 3、Decision 8)
- [ ] 4.2 先読み窓: `LazyGridState.layoutInfo` の観測 → 進行方向判定 → 「可視範囲の外側・進行方向・可視件数と同数」の集合を計算し、台帳 (アイテム ID → URL 集合、URL → 参照数) の差分で enqueue / dispose する。宣言が無いときは観測を起動しない。配列差し替えとコンポジション離脱で dispose (→ Requirement: プリフェッチの先読み範囲 (Android)、プリフェッチの取り消し、Decision 3・4)
- [ ] 4.3 テスト (Robolectric + Compose UI Test): 記録用 fake で、初期表示で可視件数と同数が開始されること、進行方向へのスクロールで窓が進むこと、反転で取り消し + 新規開始、配列差し替えで消えたアイテムの取り消し、宣言なしで何も起きないこと、到達点の伝播、共有 URL の参照数、コンポジション離脱での全 dispose (→ Scenario: 可視件数と同数を先読みする、進行方向へ移動すると窓が進む、スクロール方向の反転で取り消される、配列の差し替えで消えたアイテム、宣言が無ければ何も起きない、到達点が伝わる、共有 URL は最後のアイテムが外れるまで取り消さない、画面から消えたら全て取り消す)
- [ ] 4.4 統合テスト Android: カウンタ付き `Fetcher.Factory` / `Decoder.Factory` を登録したテスト用 `ImageLoader` を注入し、ディスク到達点後に取得が走らないこと・`BlackholeDecoder` でデコードが走らないこと、メモリ到達点後に再デコードしないこと、`AsyncImage` 直接利用でキャッシュが共有されること、ソース単位の削除で対象だけ消えることを確かめる (→ Scenario: ディスク到達点の後の表示、メモリ到達点の後の表示、ローダー付属ビューとキャッシュを共有する、ソース単位の削除、メモリのみ消去)

## 5. `KsImage` と `KsImageCache`

- [ ] 5.1 iOS `KsImage`: `KsImageSource` の経路分岐 (remote / file は `LazyImage` + 実サイズからの `ThumbnailOptions` (fit は収まる最大、fill は覆う最小 + `clipped()`)、asset は `Image`)、サイズ確定前は要求しない、`contentMode` (`KsImageContentMode`、既定 `.fill`)、読み込み中・失敗の `ViewBuilder` スロット (未指定は既定表示)、ソースの世代に応じた識別子 (`imageIdKey`) の付与、`KsImageCache` の世代を読んで再要求 (→ Requirement: KsImage の画像ソース、表示状態、当てはめ方、縮小デコード、読み込み取り消しとメモリ保持、キャッシュのクリア、Decision 5・6・7)
- [ ] 5.2 Android `KsImage`: `rememberAsyncImagePainter` + `rememberConstraintsSizeResolver()` で `KsImageSource` の model を要求し、状態に応じて Composable スロット (`loading` / `failure`、未指定は既定表示) を切り替える (`SubcomposeAsyncImage` は使わない)。`contentMode` (`KsImageContentMode`、既定 `Fill` → `ContentScale.Crop`)、`modifier`、`contentDescription`、`KsImageCache` の世代を読んで再要求 (→ 同上)
- [ ] 5.3 `KsImageCache.clear(scope)` / `remove(source)` を両プラットフォームに追加 (iOS の `remove` はソースの世代を進めてディスクの元データを消す。asset は no-op。Android は URL 鍵でメモリ・ディスクを直接消す)。同期的に削除してから無効化の世代番号を進める (`clear(.memory)` は進めない) (→ Requirement: キャッシュのクリア、Decision 7)
- [ ] 5.4 テスト iOS: 要求された `ImageRequest` にレイアウトサイズと当てはめ方から決まる `ThumbnailOptions` が付くこと (fit / fill)、サイズ 0 では要求しないこと、ソース種別ごとの経路、`remove` 後の要求が世代付き識別子になり削除前の項目に当たらないこと (複数サイズ)、`clear(.all)` / `remove` で世代が進み `clear(.memory)` では進まないこと、失敗したビューの再生成で再試行すること (→ Scenario: 枠より大きい画像、サイズ確定前は取得しない、3 種のソースを表示する、便宜形、ソース単位の削除、削除後は別サイズでも旧項目に当たらない (iOS)、全消去の後の表示、失敗後の再試行)
- [ ] 5.5 テスト Android: ソース種別ごとに要求へ渡る model、`contentMode` の既定と `ContentScale` への写像、スロットの差し替え、`clear` / `remove` がローダーのキャッシュ操作に写像され世代が進むこと、失敗したビューの再生成で再試行すること (→ Scenario: 3 種のソースを表示する、便宜形、スロットの差し替え、fit と fill、全消去の後の表示、失敗後の再試行)

## 6. Sample「画像グリッド」(sample-parity)

- [ ] 6.1 iOS: `SampleScreen` に「画像グリッド」を「大量件数」の次に追加し、10,000 件・3 列・正方形 `KsImage` (fill) + 「#ID」のセル、プリフェッチ 3 択 (なし / ディスクまで / メモリまで、初期値「ディスクまで」)、「キャッシュを消去」を承認モックに従って実装する (→ Requirement: Sample のデモ画面「画像グリッド」)
- [ ] 6.2 Android: 同画面を同じ文言・構成・件数・初期値で実装し、`INTERNET` permission を Sample に追加する (→ 同上)
- [ ] 6.3 mock との視覚照合 (両プラットフォーム。`ui/verification/` に最終周のスクリーンショット、brief.md に照合記録)
- [ ] 6.4 dsl-samples (`kasane/roadmaps/v1-foundation/phases/phase-1-symmetric-dsl-spec/artifacts/dsl-samples.md`) のシナリオ 5 に `destination` と `KsImageSource` の利用形を追随させる

## 7. 実機計測と証跡

- [ ] 7.1 iOS: Sample「画像グリッド」を固定 fixture (10,000 件・3 列・ID から決定的な URL) として、フリング中のプリフェッチ開始 / 取消件数 (受け口のカウンタ) と、handbook/ios/performance-verification の手順で hitch time ratio (独立 3 試行) とメモリ定常化を計測し `evidence/image-grid-measurement-ios.md` に残す (→ agenda 決定: 検証方法、design.md Risks)
- [ ] 7.2 Android (回帰): handbook/android/performance-verification の全系統 (相対 P90/P99・絶対 frameOverrun P99・メモリ定常化と 1,000 件対 10,000 件、各 3 試行) を既存の固定 fixture (「大量件数」画面、宣言なし) で再計測し、先読み窓の追加でラッパーの上乗せが増えていないことを `evidence/performance-regression-android.md` に残す (→ design.md Risks)
- [ ] 7.5 Android (画像グリッド): Sample「画像グリッド」を固定 fixture として、開始 / 取消件数 (受け口のカウンタ) と、絶対基準 (frameOverrun P99、3 試行) とメモリ定常化を宣言あり (ディスク / メモリ) で計測し `evidence/image-grid-measurement-android.md` に残す (相対基準は比較対象に同等機能が無いため適用しない) (→ agenda 決定: 検証方法)
- [ ] 7.3 ローダー付属ビュー (`LazyImage` / `AsyncImage`) を直接使ったときにプリフェッチのキャッシュが効くことを Sample で確認し証跡に残す (→ Scenario: ローダー付属ビューとキャッシュを共有する)
- [ ] 7.4 フリングで画面外に出たセルの読み込みが取り消されること (受け口のカウンタまたはローダーのログ) と、戻ってきたセルが読み込み中を経由せず表示されることを Sample で確認し証跡に残す (→ Scenario: 画面外へ出た読み込みの取り消し、戻ってきたときの再表示)

## 8. 文書

- [ ] 8.1 利用者向け注記の原料を evidence/ または deviation.md に残す: グリッドにはサムネイル用途の URL を申告する運用、`ImagePipeline.shared` の差し替え条件、iOS で `remove` したソースはローダー付属ビューと共有されなくなる限界 (蒸留で concepts へ)
