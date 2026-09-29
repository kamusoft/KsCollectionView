# セカンドオピニオン: paging-state-machine (code-001)
**相方**: codex / **label**: so-code-paging-state-machine / **日付**: 2026-09-27 / **対象**: 作業ツリーの未コミットの変更すべて (HEAD との差分と未追跡ファイル。ios/ android/ samples/ 配下)
---
# 独立コードレビュー: paging-state-machine

**判定: CHANGES_REQUESTED** — Critical 0、Major 2、Minor 0、Suggestion 0。変更アーティファクト、`ios/`・`android/`・`samples/` の差分と未追跡ファイルを静的に確認しました。ビルド・テストは実行せず、提示された成功結果を前提にしています。`deviation.md` と UI brief の合意済み差分は指摘に含めていません。

### 🟠 Major: 有効なしきい値で iOS がクラッシュする

**該当箇所:** [KsPagingRequester.swift:38](ios/Sources/KsCollectionView/KsPagingRequester.swift:38)  
**問題点:** 検証では「0 以上かつ有限」の `threshold` を有効としますが、`Double` の計算結果を `Int` に変換しています。たとえば `threshold = 1e19` は有効と判定され、可視項目がある状態で `Int` への変換が範囲外となり、release でもクラッシュします。  
**推奨修正:** 残件数を `Double` にして比較するか、`Int` へ変換する前に上限で飽和させてください。大きな有限値と、乗算結果が無限大になる値をテストに加えてください。

### 🟠 Major: Android の下端安全領域が埋め込み先で誤計算される

**該当箇所:** [KsTopSafeArea.kt:78](android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsTopSafeArea.kt:78)  
**問題点:** `bottomInWindow` はウィンドウ座標ですが、比較先の `rootHeight` は Compose ルートの高さです。ComposeView がウィンドウ上端から下がった位置に埋め込まれると、下端のシステムバーに重なっていなくても、その上端位置の分まで重なりとして数え、0 件表示の中心を大きく上へずらします。現在のテストは全画面のルートだけを扱っています。  
**推奨修正:** 下端もウィンドウ座標で求め、同じ座標系で重なりを比較してください。上部に別のネイティブ View がある ComposeView の配置をテストに加えてください。

**完了前の確認:** [tasks.md:56](kasane/changes/paging-state-machine/tasks.md:56) の 7.2〜7.4 は未完了のままです。フッター高さ変更時の位置、両プラットフォームの体感ゲート、iOS の 500 件境界の目視確認は、修正後の完了判定で確認が必要です。

## 突き合わせ結果

ホスト側: review-001.md (ksn-reviewer、判定 NEEDS_DISCUSSION)。2026-09-27。

| 指摘 | 出典 | 採否 | 重要度 | 根拠 |
|---|---|---|---|---|
| Android の下端の重なりがウィンドウの座標とコンポジションの根の高さを混ぜている (`KsTopSafeArea.kt` の `bottomOverlapPx`) | 双方 | 確定 | Major (相方の高い方) | 同じ箇所・同じ原因を独立に指摘。埋め込み構成で 0 件の表示の真ん中がずれる |
| 有効なしきい値 (例 1e19) で iOS がクラッシュする (`KsPagingRequester.swift` の `isNearEnd` の `Int(...)` 変換) | 相方のみ | 採用 | Major | 該当箇所を確認。有限でも `Int` の範囲を超える値で変換がトラップし、release でも落ちる実害シナリオあり |
| 取り直しの結果を先頭から出す規則が、描画の回のまとまり方しだいで効かなくなる | ホストのみ | NEEDS_DISCUSSION としてオーナーへ | — | 契約 (core/ADR-0021) の扱いの判断が要る |
| 待ち方の控えを捨てる判定が、判定を飛ばす間は行われない | ホストのみ | 確定 (ホスト側の指摘) | Minor | — |
| Android の `KsPagingRequester.cancel()` が本番の経路から呼ばれていない | ホストのみ | 確定 (ホスト側の指摘) | Suggestion | — |

降格: なし / 未解決: なし (NEEDS_DISCUSSION の 1 件はオーナー判断待ち)
