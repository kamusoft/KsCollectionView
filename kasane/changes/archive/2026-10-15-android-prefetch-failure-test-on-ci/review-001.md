# レビュー結果: android-prefetch-failure-test-on-ci (001 回目)

**日付**: 2026-10-15
**判定**: APPROVED

## サマリー
変更は `KsImageCacheContractTest` だけで、exploration.md「決定事項」の 4 項目 (ネットワーク層の失敗の口と失敗の記録・失敗のテストの作り直し・呼び出しの中で失敗し終える新しいテスト・残り 2 件の保留) をそのまま満たし、製品のコードには触れていない。要求の直後の確かめは、保留で取得が終わらない状態を作ってから行う形になり、取得用のスレッドが先に走る順番を強制した検証でも通る。製品の数え漏れを入れると、失敗の 2 件がどちらも落ちる (空振りしない) ことも確かめた。指摘は、ネットワーク層の説明コメントが古くなった Minor 1 件だけ。

## 照合した規約
- ソースコメント規約 (`kasane/handbook/cross/comment-policy.md`、always)
- テスト実行規約 (`kasane/handbook/cross/test-execution.md`、テストの追加・実行・結果の報告): 「実行件数の確認までが検証」「全系統の合計は 10 分以内」「収束を待つアサーション」「Android: 差分なし再実行と Robolectric の描画限界」の各節
- 関連概念: `kasane/concepts/core/core-model/image-loading.md` (失敗した先読みは、Android では取得中から外れる)・`kasane/concepts/android/architecture/image-pipeline.md` (`KsImageMemoryIndex` の取得中の記録)
- `kasane/lessons/code-review.md` (L-001 に沿って、exploration.md の検証の主張を自前の検証で再現した。L-002 は動きの過程を見る機能ではないので当たらない)

ロードしたスキル: kotlin-impl-skill

## 確認した観点

**ビルドとテスト**
- `android/` で `./gradlew :kscollectionview:testDebugUnitTest --rerun-tasks`: BUILD SUCCESSFUL。`build/test-results/testDebugUnitTest/TEST-*.xml` の合計で 31 クラス・513 件・失敗 0・エラー 0・スキップ 0 (決定事項の 512 → 513 と一致)。追加した `memoryPrefetchThatFailsBeforeEnqueueReturnsIsNotLeftInFlight` が結果に出ていることも確かめた

**仕様充足 (合意スコープ = exploration.md「決定事項」)**
- 製品のコード (`android/kscollectionview/src/main/`) に差分が無い
- `CountingNetworkClient.fails` (保留が解けた後に `IOException` を投げる) と `failedData` (`EventListener.onError` で記録。`succeededData` と同じ形) を足している
- `failedMemoryPrefetchLeavesInFlight`: ネットワーク上の URL を保留と失敗の設定で要求し、直後に 1 件、保留を解いた後は「失敗の記録に入る かつ 取得中 0 件」を待ち、成功に入っていないことも確かめている
- 新しいテスト: `fetcherCoroutineContext(Dispatchers.Unconfined)` のローダーで未対応の形式の URL を要求し、呼び出しから戻った時点で失敗が届いていること・取得中 0 件・looper を回した後も 0 件を確かめている
- `memoryPrefetchIsInFlightOnlyUntilItCompletes`・`cancelledMemoryPrefetchLeavesInFlightImmediately`: 直後の確かめを保留の下で行い、保留を解いた後の確かめは元のまま
- 長命層 (handbook) への反映は「蒸留時に反映」の行で申し送られており、実装の範囲に入っていない
- tasks.md・デルタスペック・deviation.md は無い (S 級)。exploration.md の差分は探索の結果 (調査・選択肢・決定事項) の記入で、決定事項と実装の範囲は一致している

**テスト (空振りと実行機の順番への依存)** — 手元の写し (scratchpad に `android/` を複製) で次を確かめた。作業ツリーには手を入れていない
- 製品の `onError` から取得中を外す処理を抜くと、`failedMemoryPrefetchLeavesInFlight` (待ちの上限で失敗) と新しいテスト (呼び出し直後の 0 件の確かめで失敗) の 2 件が落ちる。数え漏れを捕まえられる
- 取得とデコードに「取得用のスレッドで先に走らせ、main からの dispatch なら最初の中断か完了まで main を待たせる」検証用の dispatcher を差し込むと、HEAD のテストは取得中を確かめる 3 件 (成功・失敗・取り消し) が要求直後の確かめで落ちる (失敗のテストは CI と同じ `expected:<1> but was:<0>`)。直した後のテストは、同じ条件で取得中を確かめる 7 件すべてが通る。exploration.md の表の最後の 2 行を再現した
- 新しいテストの最初の確かめ (`failedData.contains(target)`) が「呼び出しの中で失敗し終える」流れが実際にできたかを見張っている。この流れができなければ黙って通らず落ちる
- 取得中を確かめるほかのテスト (`clearFencesEveryPrefetchInFlight` 等) は記録用の偽のローダーか索引を直接呼んでいて、同じ順番の依存は無い

**後片付け**
- 保留したまま終わる取り消しのテストや、途中で落ちた失敗のテストで保留が残っても、`tearDown` の `loader.shutdown()` がローダーのスコープを取り消すので、`delay(1)` で回っている取得は止まる。`network` はテストごとに作り直される
- 新しいテストの `inlineLoader` は `finally` で止め、共有のローダーへの差し替えは `tearDown` の `SingletonImageLoader.reset()` が戻す。`newBuilder()` でメモリキャッシュ・ディスクキャッシュ・event listener は共有され、ディスクの置き場は `tearDown` が消す

**設計品質・コメント**
- 収束を待つ確かめは既存の `awaitCondition` (実時間の上限・`Thread.sleep(1)` で譲る・上限で実測値付きで失敗) を使い、失敗の記録を実測値に足している。固定時間の待ちは足していない
- 確かめの失敗のメッセージを足し、どの前提が崩れたか読める
- `scripts/comment-policy-lint.py` (通常・`--advisory`): 禁止 0・要確認 0。目視でも、作業文書・変更の識別子・通番への参照、履歴の記述、仕様構文のキーワードは無い。テスト関数の名前への参照 (`[memoryPrefetchThatFailsBeforeEnqueueReturnsIsNotLeftInFlight]`) はコードの識別子なので許される
- テストの件数は 1 件増えるだけで、全系統の合計 10 分への影響は無視できる (新しいテストは約 4 ms)
- オーバーエンジニアリングは無い (検証用の dispatcher は決定事項どおりテストに残していない)
- kotlin-impl-skill の観点: `@Volatile` の印 (取得用のスレッドから読む)・`CopyOnWriteArrayList` (スレッド間の記録)・`CancellationException` を握りつぶさない (`delay` の取り消しをそのまま伝える) で問題は無い。テストの中の `runBlocking` は既存の使い方で、今回は足していない

## 指摘事項

### 🟡 Minor ネットワーク層の説明コメントが、失敗の口を足した後の挙動と合っていない
**該当箇所**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsImageCacheContractTest.kt:64`
**問題点**: `CountingNetworkClient` の KDoc は「取得の回数を数え、常に同じ 1 枚分のデータを返すネットワーク層。」のままだが、`fails` を足したので「常に」データを返すわけではなくなった。ファイルだけを読む人が、クラスの説明と `fails` の説明の食い違いで戸惑う。
**推奨修正**: 例えば「取得の回数を数え、同じ 1 枚分のデータを返すネットワーク層。応答の保留と失敗を切り替えられる。」のように、保留と失敗の口があることを 1 文で添える。

## アクションプラン
1. (任意・低優先) `CountingNetworkClient` の KDoc を `fails` を足した後の挙動に合わせる
