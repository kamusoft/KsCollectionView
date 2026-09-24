# セクション / グループ化

sticky ヘッダ付きグループ化と、画面向きで列数が変わる可変グリッド (自社実績機能)。両プラットフォーム。

## 論点

- セクションモデル: 安定セクション ID・header/footer の契約
- sticky ヘッダ: iOS は Compositional Layout の pinned、Android は `stickyHeader` — **グリッドでの sticky 可否が未確定** (`LazyGridScope` に stickyHeader が無い可能性。全幅ヘッダ + 非固定への縮退も検討)
- 画面向き可変グリッド: ポートレイト/ランドスケープでの列数切替の宣言方法と、回転時のスクロール位置維持
- ソート連携の吸収: データ層並べ替え + 差分 move アニメ (iOS diffable / Compose `animateItem`) の確認をこのフェーズで行うか
- グループ変更時の差分更新 (旧実装は Android で full reset だった — 作り直し対象)

### phase-1 からの申し送り (2026-09-01)

- レイアウトは単一コンポーネント + `layout` 値で確定 (core/ADR-0006)。本フェーズの拡張は「セクションごとに layout 値を付与する」形で同じ語彙に乗せる
- 旧語彙の申し送り (core/ADR-0009) — グループ化系: `IsGroupingEnabled` / `GroupHeaderTemplate` / `GroupHeaderHeight` / `IsGroupHeaderSticky` (旧 iOS のみ → 両対応が論点)
- 旧語彙の申し送り (core/ADR-0009) — 余白系: `GroupFirstSpacing` / `GroupLastSpacing` / `BothSidesMargin` / `SpacingType` は contentPadding / spacing の流儀へ簡素化する方向
- ソート連携は DSL 追加なしで確定 (データ層並べ替え + 自動差分 move — core/ADR-0003)。本フェーズでは差分 move アニメの動作確認のみ

### phase-2 からの申し送り (2026-09-03)

- list の区切り線は「先頭行の上端 + 全セルの下端」に全幅で描く規則 (ios-engine-foundation deviation.md)。セクションが入ると前セクション末尾の下線と次セクション先頭の上線が二重になるため、セクション境界での規則を決める
- 区切り線はセル bounds の底辺に描かれ、幅はセル幅 (`contentPadding` の分だけ内側に寄る)。`rowSpacing > 0` の list では線が行間の中央ではなく各行の直下に出る。セクション単位の余白・装飾を設計する際にこの見え方を含めて決める

### phase-3 からの申し送り (2026-09-05)

- 区切り線は両プラットフォームとも content の前面に描く (core/ADR-0010 accepted)。Android は項目単位の `drawWithContent`、iOS はセルのサブビューで、いずれも「行間に区切り線用の item / decoration を挿入する」形ではない。セクション境界の装飾はこの前提 (項目単位の描画) の上で設計する
- Android の `LazyVerticalGrid` は `stickyHeader` を持つ (Foundation 1.8 以上、android/ADR-0001)。論点「グリッドでの sticky 可否が未確定」の Android 側はこれで解ける

### performance-criteria-review からの申し送り (2026-09-15)

- **利用者の論理セクションと、内部の分割単位の責務**: 両者は別物で、内部分割は利用者の語彙に現れない (core/ADR-0006 の単一コンポーネントを守る)。phase-4 の 2 段 ID (論理セクション ID + 項目 ID) と内部分割の ID をどう重ねるかは本フェーズで決める

背景: iOS の compositional layout は estimated 高さの再解決 (solver) をセクション単位で行い、1 セクション 10,000 件では少数派の行が可視になるたびに全件を解き直す (最頻値化後も主スレッドの 36%、2,000 件の 4.1 倍。`kasane/changes/performance-criteria-review/evidence/manual-largeData-ios-2026-09-15.md`)。対策として「1 論理セクションを列数の倍数の塊 (内部セクション) に分けて snapshot を組む」内部セクション分割を performance-criteria-review の提案改訂で追加する。

- 内部分割が満たすべき 3 条件 (phase-4 のセクション設計はこの条件を壊さないこと):
  1. sticky ヘッダが内部分割の末尾で止まらない (pinned の単位は論理セクション)
  2. 列数に合わない分割で不完全な行を作らない (塊の件数は列数の倍数。画面向きで列数が変わっても崩れない)
  3. 先頭挿入で塊の所属が変わるときの差分更新と位置維持 (スクロール位置のアンカーは項目 ID で持ち、塊の境界に依存しない)

- 内部分割の決定は ios/ADR-0009 (proposed、2026-09-16) と performance-criteria-review の design Decision 10〜12 にある。本フェーズのセクション設計はこの上に「論理セクション ID + 項目 ID」を重ねる

決定の要点: 塊の件数は 500 を列数候補の最小公倍数の倍数に切り上げる (向き別列数は回転で組み直さない)。境界は行間・余白・区切り線・ヘッダー / フッターのいずれにも出さない。位置維持は項目 ID のアンカーで行う。

### performance-criteria-review からの申し送り・追記 (2026-09-17、実装完了後)

内部セクション分割は実装済み (件数比例 4.1 倍 → 1.04 倍、体感合格。`kasane/changes/performance-criteria-review/evidence/manual-largeData-ios-2026-09-17.md`。archive 後は `kasane/changes/archive/*-performance-criteria-review/`)。塊方式がグループ化の妨げになりうる点をオーナーが懸念し、本フェーズの**最初の論点**として次を積む。いずれも「論理セクションが塊の件数 (500 件超) を超えて複数の塊に割れる場合」にだけ現れる — 小さい論理セクションは塊 = セクションで、現行の仕組みの読み替えで済む。

- **固定 (sticky) ヘッダーの複製**: compositional layout のピン留めはセクション単位で、論理セクションが 3 塊に割れるとヘッダーは先頭の塊にしか付かず、先頭の塊が画面から抜けた時点で外れる (上の 3 条件の 1 を実装で満たす方法が未決)

  候補: その論理セクションの全塊に同じヘッダーをピン留めで付ける (10,000 件でも 20 個で費用は小さい。ios/ADR-0009 がルートヘッダーで却下した「全塊にヘッダー」は、論理セクションのヘッダーでは妥当になりうる)。視覚的に切れ目が出ないかを Simulator で試作して確かめてから決める
- **セクションの背景装飾の塊またぎ**: decoration item もセクション単位なので、角丸の板などの装飾は塊ごとに切れる。候補: 先頭の塊だけ上の角、末尾の塊だけ下の角を丸め、中間の塊は角なし (余白と同じ手法)。concepts の「decoration item は将来のセクション装飾のために温存」はこの用途で使う
- **塊の件数をセクションごとに持つ**: 列数の倍数の規則はセクションごとに計算する。論理セクションをまたぐ挿入・削除では 2 つのセクションの塊が同時に組み直る (差分適用とアンカー復元の重なり)

  確かめること: 現行の塊の件数の変化判定と世代番号つきのアンカー (performance-criteria-review の deviation.md「アンカーの控えの扱い」) が複数セクションでも成り立つか
- **試作の勧め**: phase-4 の探索に入る前に「500 件超の論理セクション + 固定ヘッダー」だけを試作し、ピン留めの複製が視覚的に破綻しないかを Simulator で確かめるのが安上がり (performance-criteria-review の design Decision 13 と同じ「試作 → 確認 → 本実装」の順)

### android-scrollbar-parity からの申し送り (2026-09-24)

Android のスクロールインジケータ (iOS 既定と同じ、スクロール中だけ出て消えるバー) は、全体の長さを Compose 公式の `LazyGridState.scrollIndicatorState` の値のまま使う。

公式の全体の長さは、全幅の項目 (ヘッダー・フッター) を「1 ÷ 列数」行として数える。このため、グリッドでは全幅の項目 1 つごとに約 1 行分、全体が短く見積もられ、末尾より手前でバーが下端に着く。今はルートのヘッダー / フッターだけ (最大 2 つ) なので約 1 行で、オーナー判断で受け入れた。セクションごとに全幅のヘッダーが並ぶと、ずれはセクション数に比例して大きくなる。

- **決めること**: セクションのヘッダーの形 (固定ヘッダー / 全幅ヘッダー) を決めるときに、インジケータの全体の長さの扱いも合わせて決める。候補は、全幅の項目の数え方を補う、公式の値のまま受け入れる、など
- **確かめること**: 位置の値は、上側の余白に前の行が見える間の食い違いを補正済み。セクションの境目で、この補正が複数の全幅ヘッダーと組み合わさっても成り立つか (補正の中身は `kasane/changes/archive/2026-09-24-android-scrollbar-parity/deviation.md`)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
- [ ] 相対計測の前に、比較対象の画面へスクロールインジケータを付ける (android-scrollbar-parity で既定機能になったが未付与。[Android 性能検証の手順](../../../../handbook/android/performance-verification.md) の「比較対象と、それが測るもの」)
