# Exploration: kasane-initial-assets

## 課題 / 動機

v1-foundation ロードマップの実装開始前に、同型 monorepo の先行プロジェクト `../KsSettingsView/` の kasane 資産 (handbook / decisions) から「初期に決めておくべき項目」を移植する。開発初期の今なら、翻案元が後から是正コストを払った決定 (artifactId の drift、docs → skills の作り直し、Sample 差異の蓄積後の是正) を最初から正しい形で敷ける。

前史: 同目的の live セッション (kasane-assets-import) が存在したが、やりかけのまま中断していたためユーザー判断で破棄済み (2026-09-01)。そこでの決定 (「ADR は移植しない」等) は引き継がない。ただし作業ツリーに残る config.yaml の maui ドメイン除去・各 index 修正は cross/ADR-0001 (MAUI 非対応) と整合するため存置 (本 change のまとめ時に扱いを確定する)。

## 検討した選択肢 (却下案と理由を含む)

### handbook の移植範囲
- 採用: `../KsSettingsView/kasane/handbook/cross/` の 5 本を改変移植する — sample-parity / test-execution / runtime-behavior-verification / local-development-setup / public-identifiers
- 対象外 (ユーザー指定): comment-policy (別セッションで設置済み)、aiforms-origin-reference、user-skill-api-listing

### ADR の扱い
- 採用: 「移植」ではなく「翻案して自リポジトリの決定として起こす」。初期に決めないと後で高くつく 4 本に絞る (下記 ADR 候補)
- 却下: 配布・リリース系 (翻案元 cross/0018 SPM 配信リポジトリ・0019 lockstep・0020 dispatch リリース) の今回 ADR 化 — 翻案元でも status: proposed のままで未実行。phase-7 の agenda に論点として送る
- 却下: CI 構成 (翻案元 cross/0025/0026) の今回 ADR 化 — CI を書く直前で足りる。構造 (platform 別再利用 workflow + 入口、テスト 0 件は緑でも失敗) は phase の論点として先取り可能

### Sample の導入時期 (ロードマップ見直し)
- 採用: Sample を各フェーズの完了条件に組み込む — phase-2/3 の初手タスクに対称 scaffold (`SampleScreen` / `SampleTheme` / メニュー構造)、以降の全フェーズ (4〜6, 8) の完了条件に「デモ画面を両プラットフォームへ sample-parity 準拠で追加」。phase-7 は「配布・ドキュメント」に純化
- 却下: 独立した「sample フェーズ」の新設 — Sample は単体成果物ではなく各フェーズの検証装置。フェーズ化すると「後でまとめて」に戻り、sample-parity の緩衝設計 (収束状態への要求) と噛み合わない
- 却下: 現状維持 (phase-7 で一括) — phase-2「大量件数での性能検証」・phase-3「再利用効率の検証」が動くホストアプリなしに解消できず成立しない

## 決定事項

- handbook 5 本を改変移植する (MAUI 前提の記述を削除・読み替え、参照リンクを張り替え、実測値は自前値に差し替え)
- handbook 本文が根拠を要する箇所は翻案元 (`../KsSettingsView/kasane/decisions/`) を翻案元として明記してよいが、初期 4 決定は自リポジトリの ADR として起こす
- public-identifiers は翻案元の artifactId 規則 `ks-settingsview-*` を持ち込まず、後発決定 (翻案元 android/ADR-0016) の結論を先取りして `jp.kamusoft:kscollectionview` (ブランド 1 トークン、ハイフンなし) とする
- ロードマップ改訂は上記「採用」案のとおり (ksn-roadmap で実施)
- 実施は二本立て: 移植 = 本 change (M 級、ksn-propose へ) / ロードマップ改訂 = ksn-roadmap の改訂

## ADR 候補 (未起票: 4 本、本 change の提案に含める)

1. monorepo + プラットフォーム別ビルドルート (翻案元 cross/0001。ルートに共通ビルドファイルを置かない)
2. 公開識別子の名前空間 (翻案元 cross/0002 + android/0016 の結論を合体)
3. Sample をプラットフォーム間パリティ検証装置と位置づける (翻案元 cross/0016。ロードマップ改訂の根拠)
4. 利用者ドキュメント方針: skills/ 方式 + README ルート 2 枚 (翻案元 cross/0022 + 0023)

## 未決の論点

- local-development-setup の具体内容 (コマンド・版の定義元) は実構成ができるまで骨格のみ。phase-2/3 実装時に追随が必要
- 作業ツリーに残る前セッション由来の編集 (config.yaml maui 除去・index 修正) のコミット単位
- 翻案元 handbook/maui/performance-verification.md (未精読) — リスト/グリッドではスクロール性能計測規約として同種の必要性がありうる。phase-2 の性能検証論点の材料候補
- lessons/ ディレクトリ不在 (config.yaml に節はある)。翻案元の昇格済みルール 18 本はプロジェクト非依存が多いとの調査所見あり — 本 change のスコープ外、別途検討

## UI 素材

なし (ドキュメントのみの変更)

## 変更級の推奨: M (理由)

コード変更なしのドキュメント変更だが、handbook 5 本の改変移植 + ADR 4 本の翻案起草 + 各 index 更新と、相互参照の整合を要するため S の受け持ちを超える。可逆で公開 API 影響なしのため L には満たない。
