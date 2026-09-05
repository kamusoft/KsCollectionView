# concepts 更新履歴 (append-only)

- 2026-08-26: Kasane 導入 (器の設置。concepts は空で開始)

## 2026-09-01
- distilled: kasane-initial-assets (ADR cross/0002〜0005 は変更内で accepted 済み / handbook/cross 5 本を変更内で設置 / concepts 本文の変更なし。rules.md は maui ドメイン除去の検証で timestamp 更新済み)

## 2026-09-03
- distilled: ios-engine-foundation (ADR ios/0005・ios/0006・ios/0007・core/0010・core/0011 を proposed で起票 / handbook/ios/performance-verification.md 新設 / concepts 初起票: core/core-model/collection-items.md・core/core-model/collection-interaction.md・core/styling/collection-layout.md・ios/architecture/collection-engine.md / core・ios のドメイン index 新設)

## 2026-09-05
- distilled: revival-feasibility (ADR cross/0001・core/0001 は探索内で accepted 済み / handbook・concepts の変更なし — 探索のみの change でロードマップ v1-foundation へハンドオフ済み / lessons inbox に調査所見の訂正を 1 件捕捉)
- distilled: android-wrapper-foundation (ADR android/0001・0002・core/0010・0011・ios/0007 を実装後の視点で見直して accepted / android/0003 (material3 依存)・android/0004 (行の高さ変化の補間) を起票して accepted / handbook/android/performance-verification.md 新設・handbook/cross/runtime-behavior-verification.md に Android 観測点を追記 / concepts: core の collection-items・collection-interaction・collection-layout を両プラットフォーム共通に改訂、ios/architecture/collection-engine.md を KsTemplate 改名に追随して節構造を整理、android/architecture/compose-wrapper.md を新設 (android ドメイン index 新設) / lessons inbox: reviewer-reproduces-evidence-numbers-by-probe を count 2 に)
- distilled: template-parent-state-observation (ADR ios/0008 を実装後の視点で見直し amends 0006 で accepted・ios/0006 に amended-by を追記 / handbook の変更なし / concepts: core/core-model/collection-items.md に観測する値の契約と再構成条件の表を追記、ios/architecture/collection-engine.md に再構成の 2 段とトランザクション spike の結論を追記、android/architecture/compose-wrapper.md に Android では不要の旨を 1 文追記 / lessons inbox: 新規 3 件・count 更新 2 件、昇格なし)
