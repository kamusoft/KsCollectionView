# Tasks: kasane-initial-assets

デルタスペックなし (proposal.md の逸脱申告参照・オーナー承認済み)。本 tasks が代替仕様を兼ねる。各タスクの対応先は proposal.md「What Changes」の項番。

## 1. ADR の翻案起草 (→ What Changes 2)

- [x] 1.1 cross/0002 monorepo + プラットフォーム別ビルドルート (翻案元 `../KsSettingsView/kasane/decisions/cross/0001`。ルートに共通ビルドファイルを置かない・各 IDE が直接開ける、を KsCollectionView の 2 面構成 `ios/` `android/` で書く)
- [x] 1.2 cross/0003 公開識別子の名前空間 (翻案元 cross/0002 + android/0016 の合体。groupId `jp.kamusoft` / artifactId `kscollectionview` ブランド 1 トークン / bundle ID・package `jp.kamusoft.kscollectionview.*` / Sample `jp.kamusoft.kscollectionview.samples.{ios,android}`。android/0016 は翻案元でも proposed である旨を出典に明記)
- [x] 1.3 cross/0004 Sample をプラットフォーム間パリティ検証装置と位置づける (翻案元 cross/0016)。収束境界を明文化する: phase-2/3 は各自 scaffold + 対向への追随タスク、両フェーズ完了時が最初の収束ゲート、phase-4 以降は各変更内で両プラットフォームを揃える。「追跡付き片側先行の許容」を保持する
- [x] 1.4 cross/0005 利用者ドキュメント方針 (翻案元 cross/0022 + 0023 の合体)。ドラフトで確定する決定点: Skill の分割軸と本数 / en/ja ロックステップ / ルート README 2 枚と skills/ の関係 / 「開発者向け知識は kasane/ に一本化」の現行 Kasane への読み替え (契約 = concepts、規範・手順 = handbook) / 持ち込まない条件 (MAUI・AiForms 移行 Skill・翻案元固有の docs-refresh 運用)。翻案元 Decision ごとの採否をドラフト提示時に示す
- [x] 1.5 全 ADR 共通: status: proposed、footer は `出典:` 形式で翻案元を明記。Alternatives は本プロジェクトで実際に再検討したものだけを書き、翻案元のみの検討は「参考 (翻案元での検討)」と区別する。捏造しない
- [x] 1.6 **ゲート: ADR 4 本のドラフトをオーナーに提示し、確定 (accepted 昇格) を得る** — 昇格前に handbook 本文の相互参照を最終化しない (2026-09-01 オーナー承認、4 本 accepted へ昇格済み)

## 2. handbook/cross の改変移植 (→ What Changes 1)

共通方針 (proposal「共通の改変方針」): platform 固有の実測手順・数値は「翻案元での実測知見 (KsCollectionView では未検証、phase-2/3 で検証)」の注記付きで移植し、現行規範はプロジェクト非依存の規律のみ。

- [x] 2.1 sample-parity.md (一致必須 4 項目・SampleTheme 方式・許容差異・収束状態の緩衝設計を保持。例外枠の MAUI 具体例を KsCollectionView の例外枠に書き換え、参照先を cross/0004 と自リポジトリに張り替え)
- [x] 2.2 test-execution.md (現行規範 = 実行件数確認・収束待ちアサーション。iOS Simulator 実行・Android `--rerun-tasks`・Robolectric 制約の各節は未検証注記付きで移植し、翻案元の実測件数は書かない)
- [x] 2.3 runtime-behavior-verification.md (前半の一般規約 = 再現→解消→証跡・真因断定禁止を現行規範として移植。後半の SettingsView 固有目視表は削除し、観測点は実装フェーズで追記する旨の注記に)
- [x] 2.4 local-development-setup.md (骨格のみ: 章立て・「版の定義元」の考え方・「デモ画面一覧は SampleScreen 実装が正」の原則。具体コマンド・版は phase-2/3 で実測後に追記する旨を冒頭に明記し、未検証の手順を現行 guide として書かない)
- [x] 2.5 public-identifiers.md (製品名差し替え。翻案元の `ks-settingsview-*` 規則と「Maven 座標の drift」節は持ち込まず、cross/0003 と整合する現在形で書く)

## 3. index の再構成・更新 (→ What Changes 3)

- [x] 3.1 decisions/index.md を薄いドメイン地図 (ドメイン一覧 + 1 行説明のみ、ADR は列挙しない) へ再構成する (domain-axis 準拠)
- [x] 3.2 decisions/core/index.md 新設 (既存 core/0001 を収載) / decisions/cross/index.md 新設 (既存 cross/0001 + 新規 0002〜0005 を収載)
- [x] 3.3 handbook/cross/index.md に 5 本を追記 (文書 / 適用のきっかけ / 種別)

## 4. 完了検査 (→ 代替仕様の検証)

- [x] 4.1 標準 lint を全て実行し PASS: `scripts/local-path-lint.py` / `identity-lint.py` / `doc-structure-lint.py` / `comment-policy-lint.py` (既存違反の comment-policy.md:56 は本 change のスコープ外として報告のみ)。各 lint は検査対象の件数まで記録する — comment-policy は検査対象 0 ファイル (ソースコード未存在) であり「実行件数の確認までが検証」の規律に従い 0 件実行と明記
- [x] 4.2 残存検査: 全成果物を走査し「MAUI」「SettingsView」「settingsview」「AiForms」の出現が翻案元参照 (`../KsSettingsView/...` と `出典:` 行) と以下の許容箇所 (決定の根拠・非対応宣言・先行実装参照としての意図的言及。2026-09-01 オーナー承認) 以外に無いこと: cross/0005 の「MAUI 向けの Skill・記述は作らない」/ cross/0003 Context の `ks-settingsview-*` 経緯 / decisions/cross/index.md の既存 ADR-0001 タイトル転記と概要欄の「MAUI facade は持たない」/ cross/0002 の「参考 (翻案元での検討)」行 (同一意図のため許容に含める) / roadmap.md の先行実装参照 (`KsSettingsViewUI`・`../AiForms.CollectionView/`)
- [x] 4.3 参照検査: 成果物内の Markdown 相対リンク (ADR ↔ handbook ↔ roadmap 前提 ↔ index) を実在パスに解決できること
- [x] 4.4 決定対応表: exploration.md「決定事項」の各項目 (handbook 5 本移植 / ADR 4 本翻案 / artifactId 先取り / 二本立て実施) と成果物の対応を 1 件ずつ照合して記録 (下表)

### 4.4 決定対応表 (2026-09-01 記録)

| exploration の決定事項 | 成果物 |
|---|---|
| handbook 5 本を改変移植 (MAUI 記述削除・参照張り替え・実測値は注記化) | handbook/cross/ の sample-parity / test-execution / runtime-behavior-verification / local-development-setup / public-identifiers |
| 初期 4 決定を自リポジトリの ADR として起草 (根拠は翻案元を `出典:` で明記) | decisions/cross/0002〜0005 (accepted)、decisions の各 index 再構成 |
| artifactId `jp.kamusoft:kscollectionview` (ブランド 1 トークン) の先取り | decisions/cross/0003 + handbook/cross/public-identifiers.md (drift 節は不採用) |
| 二本立て実施 (移植 = 本 change / ロードマップ改訂 = ksn-roadmap) | 本 change 一式 + roadmaps/v1-foundation の roadmap.md・history.md・phase-2/3/7 agenda |
