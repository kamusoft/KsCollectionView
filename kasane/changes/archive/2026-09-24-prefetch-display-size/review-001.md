# レビュー結果: prefetch-display-size (001 回目)

**日付**: 2026-09-23
**判定**: NEEDS_DISCUSSION

## サマリー

許容範囲による引き当て・索引・識別子 (任意キー)・2 段の台帳・`KsResource` / `KsWidth` の公開型は、デルタスペックの Requirement と Scenario に沿って両プラットフォームで実装されている。Scenario に対応するテストも揃っている。Critical / Major に当たる実装の欠陥は無く、実装の質だけを見れば APPROVED の水準にある。

ただし Android では、design Decision 3 が「表示の鍵に当てはめ方を付けない」と定めているため、引き当てで範囲外と判定した項目がローダーのメモリキャッシュから返ってしまう経路が残る。条件は限られるが、spec の Scenario「大きすぎる項目は使わない」「小さすぎる項目は使わない」に反する。直すには design の文言を変える必要があり、実装側だけでは解決できないため NEEDS_DISCUSSION とする。

## 照合した規約

- ソースコメント規約 (always): 追加・変更したコメントを規約の節ごとに照合した。許容参照・禁止参照・禁止記述類型・公開 doc コメントの内部用語のいずれも違反なし。lint は禁止 0 件。ライブラリの要確認 2 件は internal の宣言とテストで、公開 doc コメントには当たらない
- Sample のプラットフォーム間一致 (`samples/**` を触る): 選択肢の文言・順序・到達点と幅の対応が両プラットフォームで一致している。メニュー形式への変更は deviation に記録済み
- テスト実行規約 (テスト実行・結果の報告): 実行件数を集計して確認した。Android はクラス単位の XML、iOS は `Executed N tests` で数えた
- 実行時挙動の検証規約 (実行環境で実体が変わる資源 = ハードウェアビットマップ): Android の分岐は実機テスト `KsImageDeviceDecodeTest` (ホスト側で Pixel 4a、4 件成功・skip 0) が踏んでいる。iOS の実機 (tasks 6.6) は未実施だが、未実施であること自体は指摘の対象外と合意済み。iOS の「原寸の項目を実機でも使う」は本規約の意味でまだ未検証として扱う

## 確認したこと

- **ビルド・テスト (レビュアーが自分で実行)**
  - iOS パッケージ (Simulator iPhone 17e / 他と重ならない機種、DerivedData はスクラッチ): 1 回目は 250 tests / 1 failure。失敗したのは `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` で、Android の Gradle を並走させた高負荷下で 111 秒かかって落ちた。本 change が触っていない、先読みを使わないテストである。単独での再実行は成功した。全件の再実行は **250 tests / 0 failures**
  - Android ライブラリ (`--rerun-tasks`): **193 件 / 失敗 0**
  - Android Sample (`--rerun-tasks`): **37 件 / 失敗 0**
  - comment-policy-lint: 禁止 0
- **仕様充足**: ADDED 3 本・MODIFIED 10 本の Requirement と各 Scenario を実装・テストと突き合わせた。引き当ての 6 Scenario、要求を出さないこと、識別子の衝突なし (key と URL、世代と `"p1#1"`)、署名の差し替えでの出し直しとキャッシュ命中、`disk` の幅違いの統合、`memory` の幅違いの独立、回転で進行中の要求を触らないこと、列幅が解けない間は始めないこと、無効な固定値・空文字のキーの縮退。いずれも両プラットフォームにテストがある
- **tasks のチェック**: [x] の各項目に対応する実装とテストがあり、虚偽のチェックは無い。6.6・8.x が未チェックなのは合意どおり
- **足場**: proposal / design / specs は未変更。tasks は差分がチェックの付与だけであることを確認した
- **deviation**: 識別子の文字列形 (`ks-key ` / `ks-gen N `) は design Decision 9 が形を実装に任せた範囲の中にあり、衝突しないことを契約テストで固定している。付随修正 2 件 (Android の Intent 追加情報 `ks_prefetch`、iOS の `--prefetch memory-column`) は計測の土俵を揃えるための最小の同梱で、Android は `ImageGridMeasurementFixtureTest` で固定している
- **並行性**: Android の索引は 1 つの錠で直列化され、窓の台帳の錠と入れ子になっても逆順の取得が無い (デッドロックしない)。`clear` / `remove` は「ローダーを消す → 索引を消す → 世代を進める」の順で、復帰時点で両方が無効になる。iOS は `@MainActor` に閉じている
- **lessons L-001**: 証跡の数値は本実装前のコードを測った対照 (before) で、測り直す対象の「直前サイクルで修正されたコード」を測った値ではない。実機の手動計測でもあるため、再現プローブは適用外と判断した

## 指摘事項

### 🟡 Minor (設計判断が要る) Android の表示の鍵に当てはめ方が無く、範囲外と判定した項目がローダーから返る

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageIdentity.kt:49-50`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImageRequestFactory.kt:57,65`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCoilImageLoading.kt:59,66`

**問題点**: 幅つきの先読み (`size(w, w)` + `Scale.FILL`) と表示の要求は、どちらも鍵が `MemoryCache.Key(識別子, {"coil#size": Size(...)})` で、当てはめ方を含まない。Coil 3.5.0 の `MemoryCacheService.isCacheValueValidForSize` は、鍵に `coil#size` があると寸法の文字列が一致するかだけを見て有効とする。この判定はバイトコードで確かめた。そのため次のとき、ライブラリの引き当てが範囲外として退けた項目を、続いて出す縮小要求がメモリからそのまま受け取ってしまう。

1. 列幅 / 固定値 `w` で先読みした横長の画像 (縦横比 4:1 超) を、`w × w` の枠の `fit` で表示する。引き当てでは拡大率が 1/4 未満 (大きすぎる) で退けられる。しかし表示の鍵 `(識別子, w×w)` が先読みの鍵と同じなので、要求はメモリで当たり、先読みの項目が使われる。Scenario「大きすぎる項目は使わない」に反する
2. 同じ URL を同じ枠の大きさで `fit` と `fill` の両方で表示する (縦横比 2:1 超)。先に `fit` で載った小さい項目が、`fill` の要求でメモリから返って拡大表示される。Scenario「小さすぎる項目は使わない」に反し、ぼやける

iOS は `ThumbnailOptions` の `contentMode` が鍵に入るため、どちらも起きない (プラットフォーム間で非対称)。以前の `ks#scale` は 2. を防ぐためのものだった。Sample の画像グリッド (正方形の枠・`fill`) は該当せず、条件は狭い。一方、design Decision 3 が「`ks#scale` は付けない」と明記しているため、実装側だけでは直せない。

**推奨修正 (選択肢。オーナー判断)**:
- A: **表示の縮小要求の鍵にだけ**当てはめ方の付随情報を付ける (先読みの鍵は `coil#size` のまま)。引き当ては索引経由なので、先読みの項目を使う経路には影響しない。design Decision 3 の該当の一文を改める必要がある。回帰テストとして、1. と 2. の条件で要求の結果が枠の実サイズでデコードし直されることを足す
- B: 既知の制約として受け入れ、deviation と蒸留時の concepts に「Android では fit の枠と先読みの正方形が同じ大きさのとき、範囲外の先読み項目が使われうる」と記録する
- 推奨は A。変更は小さく、Scenario との矛盾とプラットフォーム間の非対称が両方消える

### 🔵 Suggestion iOS では不正入力の警告が繰り返し出る (Android は 1 回)

**該当箇所**: `ios/Sources/KsCollectionView/KsImageIdentity.swift:29`、`ios/Sources/KsCollectionView/KsPrefetchDeclaration.swift:23`、呼び出し元は `ios/Sources/KsCollectionView/KsImage.swift:122,176`

**問題点**: 空文字のキーは `KsImageIdentity.identifier` の中で報告される。これは `KsImage` の body が評価されるたびに `prepare` と `reloadToken` の 2 か所から呼ばれる。無効な固定値も先読みの通知ごとに報告される。release では警告ログがスクロール中に大量に出る。Android は `KsDiagnostics.WarnOnce` と窓の `reportOnce` で同じ文面を 1 回に抑えており、両プラットフォームで挙動が揃っていない。spec が 1 回を求めているわけではないため、違反ではない。
**推奨修正**: `KsInvalidInput.report` で同じ文面を 1 回だけ記録する (既に持っている `reportedWarnings` を集合として使えば足りる)。

### 🔵 Suggestion Android の便宜形 `KsImage(url, …)` で `key` の位置が `contentDescription` の前にある

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImage.kt:128`

**問題点**: 既存の位置引数の呼び出し `KsImage(url, modifier, "説明")` は、型が同じ `String?` のため、コンパイルエラーにならずに `key` へ結び付く。説明が消え、キーが変わるという意味の変化が黙って起きる。配布前でリポジトリ内の呼び出しはすべて名前付き引数なので、実害はまだ無い。
**推奨修正**: `key` を既存の省略可能な引数の後ろ (`failure` の後など) に置くか、このままにするならオーナー判断として残す。

### 観察 (本 change の範囲外)

- `KsCollectionEngineTests.test2000件を全件走査しても同時生存セルを可視範囲と再利用プールに留める` は、高負荷下 (Gradle の並走・起動直後の Simulator) で 1 度失敗した (実測の最大 2000 件 / 上限 160 件)。単独と全件の再実行では成功している。本 change は触っておらず、先読みも使わないテストなので判定には含めない。flaky の兆候として記録するにとどめる

## アクションプラン

1. (オーナー判断) Android の表示の鍵に当てはめ方を戻すか (選択肢 A)、既知の制約として記録するか (選択肢 B) を決める。A なら design Decision 3 の一文を改めてから実装とテストを足す。B なら deviation に記録する。どちらでも、この項目が片付けば APPROVED 相当になる
2. (任意) iOS の不正入力の警告を同じ文面につき 1 回にする
3. (任意) Android の `KsImage(url, …)` で `key` の引数の位置を見直す
