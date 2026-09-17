# 教訓の経緯: レビュアーは修正された計測対象の数値を自前のプローブで再現する

昇格先: kasane/lessons/code-review.md「重点観点」L-001 (2026-09-17、success の count 5 で閾値到達。出典 change: ios-engine-foundation / android-wrapper-foundation / template-parent-state-observation / image-loading / performance-criteria-review)

## ルール文
レビュー対象の証跡・deviation に計測値 (contentSize・回数・比率など) が含まれ、その計測対象のコードが直前のサイクルで修正されているときは、証跡の手順を自前のプローブで再実行し、現行コードで同じ値が再現するかを判定に含める。再現しなければ Major として測り直しを求める。

昇格の際に、対象を「証跡」から「証跡・deviation」に広げた。performance-criteria-review で誤りが見つかったのは、deviation に「確定した事実」として書かれた数値と機構の説明だったため。

## 根拠
- ios-engine-foundation: review-013 が証跡の数値を自前プローブで再計測し、前サイクルの Minor 対応が入れた回帰 — 初回レイアウトで実測値が捨てられ推定高さが既定値に戻る — を検出した
- android-wrapper-foundation: review-006〜008 が実装に触れない別経路 — `animator_duration_scale` で引き伸ばした連続静止画の画素列・文字認識によるスクロール位置の復元・基準機での性能再計測 — で証跡の数値を再現し、review-006 は帯 (約 240 ms)、review-007 は「切り取りが一度も働かない」実装欠陥を検出した
- template-parent-state-observation: review-001 / 002 がテンプレートのクロージャ呼び出し回数と読まれた観測値を記録する自前プローブで挙動を再現し、review-002 は宣言なし経路の doc コメントの過剰約束 (Minor) と宣言有無の非対称を検出した。Simulator の 1 タップ目の証跡も独立に再現した
- image-loading: review-012 / 013 が手元保管の Instruments trace を独立に解析して証跡の hitch 内訳・主スレッド占有率・自動化の割合を再現し、review-012 は commit 内訳の誤帰属 (製品コードの費用を自動化に付け替え) を Minor 優先度高として検出、review-013 は追記された分類定義が実値を再現しない 2 語の欠落を検出した
- performance-criteria-review: review-003〜005 が作業ツリーに触れず `ios/` の複製に手を入れた自前プローブで deviation と証跡の数値を再計測し、「確定した事実」として記録されていた解き直しの機構の説明 2 点が誤り (境界は最下位桁ではなく半画素) であること、計数の「上界」の説明が実測と 8 倍ずれていること、積み上がりの実測値 5.3 pt が再現しないことを検出した。deviation は半画素の境界と 6.0 pt の積み上がりに書き直され、蒸留で concepts に流れる前に誤りが止まった

## 経緯
- 2026-09-03 ios-engine-foundation: 幅変化でのリセット追加 (Minor 対応) が初回レイアウトで実測を捨てる回帰を入れ、証跡の「誤差 −26.9% → 0%」が現行コードで再現しなくなっていた。実装側のテストは全て通過しており、プローブ再計測だけが検出した
- 2026-09-05 android-wrapper-foundation: 動きの不具合の修正サイクルで、レビュアーが証跡 (帯の画素数・スクロール量の系列・性能値) を自前経路で再計測し、実装者の数値と食い違わないまま 2 件の実装欠陥を Major として検出した。3 サイクルで収束
- 2026-09-05 template-parent-state-observation: 修正サイクル後のレビューが証跡 (evidence/height-change-tap-verification.md) を Simulator で独立に再現し、プローブ 5 本でクロージャ呼び出し回数を数えて、実装の正しさと doc コメントの射程の食い違い (配列が変わる更新で宣言なし経路は既存セルを呼び直さない) を切り分けた
- 2026-09-08 image-loading: iOS 画像グリッドの hitch 計測 (13 周目までのレビュー) で、レビュアーが trace を自前の抽出器で数え直し、証跡の内訳が一次データと一字一句一致するまで 2 周で収束させた。前半 (改善前) の trace も同一定義で再現でき、「前半は追試不能」という前周の前提の誤りも同時に正した
- 2026-09-15 performance-criteria-review: 推定高さの最頻値化の修正サイクルで、レビュアーが自前プローブ (渡す推定高さを 1 画素未満ずつ変えて測定回数と合計高さを数える) を 3 周続けて走らせ、deviation の「確定した事実」の機構の誤り・上界の説明のずれ・再現しない実測値を順に検出した
