# Exploration: performance-criteria-review

## 課題 / 動機

性能検証の規約 (`kasane/handbook/ios/performance-verification.md` / `kasane/handbook/android/performance-verification.md`) のスクロール性能の基準と固定 fixture を見直す。`image-loading` (L 級) の実機計測 (2026-09-08) で次が判明し、オーナー判断で「規約を見直してから判定する」(選択肢 B) と決めた。

- **iOS の基準「3 秒窓 × 5 ms/s 未満 × 3 試行すべて」は「3 秒間フレーム落ち 0」と同値** (60 Hz で 1 リフレッシュ = 16.7 ms → 5.56 ms/s)。画像グリッドは改善した駆動でも 0.00 / 3.94 / 5.54 ms/s で、落ちた 1 回はいずれも 1 フレーム (合成側の render / 自動化オーバーレイ / hosting のレイアウト) で画像ロードの実装は主因ではない
- **画像を出さない「大量件数」(10,000 件・2 列・可変行高混在) が基準機 iPhone 11 で 108 / 136 / 125 ms/s、窓内 hitch 17〜19 件**と桁違いに超える。アーカイブ済みの過去計測 (iPhone 15・20 秒窓・0.0 ms/s) は hitch を検出できない手順 (プロセス指定の接続が成立していなかった) の値で、基準機・現手順の値としては使えない。主スレッドは窓内サンプルの 94% を占めて飽和 (CA commit 19〜22%、XCTest の走査 20〜24%、`_updateVisibleCells` / hosting のレイアウト等)。原因は未特定
- **Android の絶対基準「frameOverrun P99 が 0.0 ms 以下」**も画像グリッドではディスク 6.2〜6.4 ms、メモリ 4.4〜4.6 ms で不合格。warm でも 7.4 ms で cold の取得が原因ではなく、画像 1 枚ごとの subcomposition 等の描画側の費用
- **計測の足場が主スレッドの 20〜37% を占める** (XCUITest のアクセシビリティ走査・自動化オーバーレイ)。座標駆動に変えても、指を離した後の静止待ちのため区間中もランナーが走査し続け、3 秒の区間に入るフリックの投入は 1 回で「連続フリック」を投入回数の意味では満たしていない
- **オーナー指示: 固定 fixture の「大量件数」に 10,000 件は要らない**。件数を減らす方向で見直す

発見の文脈と一次情報: `kasane/changes/image-loading/` の `evidence/image-grid-measurement-ios.md` (立て直した手順・3 試行・対照・「次に必要なこと」)、`evidence/image-grid-measurement-android.md`、`deviation.md` の 2026-09-08 の項 (iOS 7.1 の切り分けと再解析・大量件数の発見・warm の参考値) (archive 後は `kasane/changes/archive/*-image-loading/`)。`kasane/changes/ios-separator-update-guard/` (区切り線更新の無駄。大量件数の超過との関係は未確認)。

## 検討した選択肢 (却下案と理由を含む)

(未探索。起票時点の材料)

- 窓の長さ: 3 秒 → 10 秒 (1 フレーム落ちが 1.67 ms/s になり閾値 5 ms/s と整合する) 等
- 数え方: hitch time ratio のまま / 「連続 2 フレーム以上の落ちだけ数える」/ 自動化オーバーレイと XCTest の走査を除いた帰属
- Android の絶対基準: P99 0.0 ms 以下 → 何 ms まで許すか、P90 との組み合わせ
- fixture の件数: 10,000 → 1,000〜3,000 等。件数を減らすと「メモリ定常化の件数比 (1,000 対 10,000)」の系統も再定義が要る
- 駆動: 静止待ちをしない入力手段 (XCTest 以外) か、静止待ちを許容して窓を伸ばすか
- image-loading の証跡が「次に必要なこと」に挙げた計測: 改善後 trace の A/B (自動化なしの対照)、`thread-state` での待ちの確認、trace の実行ごとの退避

## 決定事項

(未探索)

## ADR 候補 (作成済み: ADR-NNNN / 未起票: ...)

(未起票) 性能検証の合格基準と fixture の改訂は handbook の改訂 + ADR (ios-engine-foundation で決めた基準の amends / supersede) になる見込み

## 未決の論点

**未探索 (簡易起票)** — 深掘りはこのメモを出発点に通常の探索で行う。現時点で見えている疑問:

- 基準を「合格できる値」に緩めるのではなく、何を保証したい基準なのか (利用者が体感する引っかかり / エンジン改修の退行検出) を先に決める
- 大量件数の 108〜136 ms/s は本当にエンジンの土台の性能なのか、計測の足場 (XCTest の走査 20〜24%) を除くとどこまで下がるのか。自動化なしの対照 (手動フリック + Instruments) を 1 度取る
- 件数を減らした fixture で、過去の証跡 (ios-engine-foundation / android-engine-foundation の性能値) との比較をどう扱うか (比較しない、と割り切るか)
- iOS の hosting (セル 1 枚ごとの `UIHostingConfiguration`) と Android の subcomposition という方式の帰結を、基準側で織り込むのか、方式側で改善するのか
- 既にアーカイブされた「合格」の証跡 (検出できない手順の値) をどう扱うか (drift で注記する等)
- image-loading の到達点 memory は別 change `prefetch-display-size` で方式が変わる予定。基準の見直しと順序をどうするか

## 変更級の推奨

未判定 (暫定: M。handbook 2 本と ADR の改訂・駆動の見直し・再計測を含む)
