---
scope: test
kind: pain
severity: normal
count: 1
first-seen: 2026-09-07
last-seen: 2026-09-07
evidence:
  - image-loading (KsImageTest で composeTestRule.waitUntil の条件式だけでは再コンポジションが進まず、runOnIdle で書き込んだ状態の反映を観測できなかった。各試行で waitForIdle() を挟むと 1 回で通ることを実測し、実時間 deadline + waitForIdle + 実測値付き失敗メッセージの自前待機に置き換えた)
---

## ルール文
Robolectric 上の Compose UI Test で、状態を書き込んでから UI への反映を待つコードを書くときは、`composeTestRule.waitUntil` の条件式だけに頼らず、待機ループの各試行で `waitForIdle()` を呼んで再コンポジションを進める。時間切れの失敗メッセージには期待値と**そのとき実際に観測していた値**を含める (条件式だけの待機は「何が起きていないか」を報告しないため、原因が待機側か実装側か切り分けられない)。

## 経緯
- 2026-09-07 image-loading: `KsImage` の再取得・スロット切り替えのテストで、`runOnIdle` で書き込んだ状態が `waitUntil` の条件式から見えず時間切れになった。`waitForIdle()` を挟むだけで通ることが分かるまで、実装側 (状態の伝播経路) を疑って調べる時間が発生した。既存の Android テストにも `waitUntil` を使っている箇所があるかは未調査。
