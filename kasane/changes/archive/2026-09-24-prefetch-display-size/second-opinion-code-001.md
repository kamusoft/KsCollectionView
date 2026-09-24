# セカンドオピニオン: prefetch-display-size (code-001)
**相方**: codex / **label**: so-code-prefetch-display-size / **日付**: 2026-09-23 / **対象**: 3e4a918 (HEAD) に対する作業ツリーの未コミット差分 (android/kscollectionview/、ios/Sources・ios/Tests、samples/android/、samples/ios/、kasane/changes/prefetch-display-size/)
---
## 独立コードレビュー結果

提示されたテスト結果と合意済みの `deviation.md` を前提に、変更アーティファクト、未コミット差分、昇格済みルール、担当範囲の handbook を静的に照合しました。レビュー中にビルド・テストは実行していません。適用した規約は `cross/comment-policy`、`sample-parity`、`test-execution`、`runtime-behavior-verification`、`scroll-performance-gate`、`ios/performance-verification`、`android/performance-verification` です。

### 🟠 Major — 共有中のキーで署名 URL を差し替えても取得が更新されない

**該当箇所:** `ios/Sources/KsCollectionView/KsImagePrefetcher.swift:193`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:250`

**問題点:** 同じ `key`・幅を２アイテムが共有すると、片方の署名 URL が変わっても参照数は `2 → 1 → 2` となり、旧 URL の要求は停止・再発行されません。両方の URL が変わる場合も、アイテムごとの照合中に参照数がゼロにならず同様です。旧 URL が失効すると、仕様が要求する新 URL での先読みが起きません。既存テストは１アイテムの差し替えだけを確認しています。

**推奨修正:** 取得単位に開始時の URL を保持し、共有中でも宣言の URL が変わったときは旧要求を停止して新 URL で開始してください。複数アイテムが同じキーを共有したまま署名を更新するテストを両プラットフォームに追加してください。

### 🟡 Minor — `disk` 到達点でも未解決の列幅に阻まれる

**該当箇所:** `ios/Sources/KsCollectionView/KsImagePrefetcher.swift:179`、`android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsImagePrefetchWindow.kt:233`

**問題点:** 両実装とも列幅を解決してから到達点を判定するため、列幅が未解決なら `disk` の取得も開始しません。仕様では `disk` は表示幅を使わず、元データを保存する契約です。

**推奨修正:** `disk` の取得単位を幅の解決前に確定し、列幅が未解決でも開始できるようにしてください。列幅ゼロ・`disk` のテストを加えてください。

**件数:** Critical 0、Major 1、Minor 1、Suggestion 0。

**判定: CHANGES_REQUESTED**



## 突き合わせ結果

ホスト側: review-001.md (NEEDS_DISCUSSION。Minor 1 (設計判断が要る) / Suggestion 2)。

| 指摘 | 出典 | 採否 | 根拠 |
|---|---|---|---|
| 共有中のキーで署名 URL を差し替えても取得が更新されない (Major) | 相方のみ | **採用** | 該当箇所と実害シナリオ (2 アイテムが同じ `key`・幅を共有すると参照数が 0 にならず旧 URL の要求が残る) が特定されている。Requirement「画像の任意キー」Scenario「署名だけが変わった配列の差し替えでは新しい URL で出し直す」の共有時の穴。ホスト側の見逃しとして修正サイクルに入れる |
| `disk` 到達点でも未解決の列幅に阻まれる (Minor) | 相方のみ | **降格** | spec「プリフェッチの表示幅」の本文は「列幅が 0 以下に解ける間は、列幅の要素の先読みを開始しない (SHALL)」で到達点を限定しておらず、design Decision 5 も「列幅で宣言した URL の先読みを開始しない」。現実装は spec の文面どおり。修正は spec からの乖離になるため回さない |
| Android の表示の鍵に当てはめ方が無く、範囲外の項目がローダーから返る (Minor・設計判断) | ホストのみ | NEEDS_DISCUSSION (オーナー判断へ) | design Decision 3「`ks#scale` は付けない」の改訂を伴う |
| iOS の不正入力の警告が同じ文面で繰り返される (Suggestion) | ホストのみ | 対処 (軽微) | Android と同じく同一文面は 1 回に抑える |
| Android 便宜形 `KsImage(url, …)` で `key` が `contentDescription` の前 (Suggestion) | ホストのみ | 対処 (軽微) | 位置引数の取り違えを防ぐ並びに直す |

件数: 確定 0 / 採用 1 / 降格 1 / 未解決 0
