# proposed の ADR と Android 実装の突き合わせ

`proposed` のまま残っている 3 本の ADR の Decision を、Android 実装 (`android/kscollectionview/src/main/kotlin/`)
とそのテストに 1 項目ずつ当てて確かめた結果。**ADR 本体は書き換えていない** (accepted への昇格と本文の
手入れは蒸留の責務)。列の意味は次のとおり。

| 判定 | 意味 |
|---|---|
| 一致 | ADR の記述どおりに実装されており、テストが観測している |
| 補足が要る | 実装は ADR に反していないが、ADR が書いていない事柄を実装が決めている (昇格時に本文へ足すか、意図的に書かないと決める) |
| 不一致 | ADR の記述と実装が食い違っている |

## core/ADR-0010 — list の区切り線の既定外観

| Decision の項目 | Android 実装 | 判定 |
|---|---|---|
| 位置: 先頭行の上端・各行の間・最終行の下端 | `KsListSeparator.kt` が先頭の項目にだけ上端の線を、すべての項目に下端の線を引く | 一致 (`listSeparatorsAreDrawnByDefault` が 3 本を画素で確認) |
| 幅: セルの左右いっぱい (インセットなし) | 線は `size.width` 全幅。項目の `Box` は `fillMaxWidth` | 一致 |
| 太さ: 1pt (論理ポイント) | `KsListSeparatorDefaults.thickness = 1.dp` | 一致 (iOS の pt と Android の dp はどちらも密度非依存の論理単位) |
| 色: 既定はライブラリ内部の固定値 `#D9D9DE` | `KsListSeparatorDefaults.color = Color(0xFFD9D9DE)` | 一致 |
| 色: `listSeparatorColor =` 引数で変更でき、表示の有無とは別語彙 | `KsCollectionView` の `listSeparatorColor: Color?` 引数。未指定で既定色 | 一致 (`listSeparatorColorChangesOnlyTheColor` / `listSeparatorColorDrawsNothingWhenSeparatorsAreHidden`) |
| opt-out: `listSeparators = false` で全て非表示。グリッドでは描かない | `showsSeparators` が false のとき modifier は何もしない。grid では線を描かない | 一致 (`listSeparatorsCanBeTurnedOff` / `gridDrawsNoSeparators`) |
| Consequences: `rowSpacing > 0` では行間の中央ではなく各行の直下に出る | 線は項目の `Box` の下端に描かれるため同じ挙動 | 一致 |

### 補足が要る点: 描画順 (content の前面)

ADR-0010 は位置・太さ・色・幅を定めているが、**線を content の前面に描くか背面に描くかを書いていない**。

Android は当初 design Decision 5 に従って `drawBehind` (content の背面) で描いていたが、review-002 の指摘
(不透明な背景を持つテンプレートでは線が content に隠れ、iOS の見え方と食い違う) を受けて
`drawWithContent { drawContent(); … }` (content の前面) に変えた (deviation.md 1 件目)。iOS も
`KsHostingCell` で content の前面に置いている。

- ADR-0010 の文面との関係: **不一致ではない** — 位置・太さ・色・幅・opt-out の各項目はすべて満たしている
- 影響: 現状は両プラットフォームとも前面描画で揃っているが、その一致は ADR に書かれていない。片方の実装を
  背面描画へ変えても ADR の文面には違反せず、Sample の視覚比較 (cross/ADR-0004) だけが崩れる
- 昇格時の提案: Decision に「線は content の前面に描く (不透明な背景を持つテンプレートでも隠れない)」を
  1 行足す。Alternatives に「背面描画 (却下: 不透明背景のテンプレートで線が消える)」を添える

## core/ADR-0011 — 不正入力の release 挙動

| Decision の行 | Android 実装 | 判定 |
|---|---|---|
| 未登録テンプレートキー: debug は assertion | `KsDiagnostics.assertValid` が debug で `IllegalStateException` を投げる | 一致 (`unregisteredKeyStopsInDebug`) |
| 未登録テンプレートキー: release は最小高の空セル + 警告ログ | 該当位置に高さ 1dp の空の `Box` を置き、件数と後続の位置を保つ。警告は `KsDiagnostics.WarnOnce` | 一致 (`unregisteredKeyShowsEmptyItemWhenNotDebug`。iOS の 1pt と同じ最小高) |
| 配列内の重複 ID: debug は assertion | `resolveItems` が診断を集めて `assertValid` で停止 | 一致 (`duplicateIdStopsInDebug`) |
| 配列内の重複 ID: release は後勝ち + 警告ログ | `deduplicate` が同じ ID を一度取り除いてから入れ直し、後の要素をその位置で採用する | 一致 (`duplicateIdKeepsLaterItemWhenNotDebug`) |
| 同じキーへの二重登録: debug は assertion | 登録表の重複を診断に積んで停止 | 一致 (`duplicateTemplateRegistrationStopsInDebug`) |
| 同じキーへの二重登録: release は後勝ち + 警告ログ | `LinkedHashMap.put` の後勝ち | 一致 (`duplicateTemplateRegistrationKeepsLastWhenNotDebug`) |
| 共通方針: release では落とさず・消さず・黙らず | 3 種とも表示を継続し、要素を消さず、警告を残す | 一致 |

### 補足が要る点 1: 4 つ目の不正入力 (`key` の型)

Android には ADR-0011 の表に無い不正入力がある。`key` ラムダが Bundle に載せられない型 (`String` / `Char` /
`Boolean` / 数値 / enum / `Serializable` / `Parcelable` のいずれでもない値) を返す場合で、実装は他の 3 種と
同じ原則 (debug は assertion、release は警告ログ + 表示継続) で扱っている
(`KsItemsPlan.kt` の `isSavableKey`、`unsavableKeyStopsInDebug`)。

デルタスペック (collection-core「プレーンな配列と安定 ID による表示 (Android)」) には書かれているが、
ADR-0011 の表には無い。Android 固有の制約 (Compose の Lazy 系が識別子を状態保存の対象にする) のため、
昇格時に「Android のみ」と分かる形で表へ足すか、Android の ADR として別に起こすかの判断が要る。

### 補足が要る点 2: 「debug ビルド」の判定基準

ADR-0011 は「debug ビルド」としか書いていない。Android 実装はこれを**組み込み先アプリの debuggable
フラグ**で判定する (`KsDiagnostics.isDebugBuild`)。ライブラリ自身のビルド種別ではなく、利用者が今どちらの
ビルドを動かしているかが判定したい対象のためである。

利用者が release ビルドのアプリで確かめる限り縮退挙動が働き、debug ビルドのアプリでは (ライブラリが
release 版の AAR であっても) assertion で止まる。ADR の意図と矛盾しないが、判定の主語が書かれていないと
「ライブラリの版で決まる」と読まれうる。

### 補足が要る点 3: 警告ログの形式と重複抑止

ADR-0011 は Consequences で「警告ログの出力先・形式は現時点で規約化されていない」と自認している。
Android 実装は次を決めている。

- 出力先は OS 標準のログ、タグは `KsCollectionView`、水準は warn
- 同じ内容の警告は再コンポーズを繰り返しても 1 回だけ出す (`WarnOnce`。`sameWarningIsReportedOnlyOnce`)

重複抑止は ADR に無い決定で、コレクションのように毎フレーム再評価されうる部品では実質的に必要になる
(抑止が無いとスクロール中にログが埋まる)。規約化するなら両プラットフォーム共通の事項になる。

## ios/ADR-0007 — セル content は行の上端に固定・水平は中央

この ADR は iOS の決定だが、Consequences で「Android にはこの罠が無く、grid の行内でのセルの伸び方が
プラットフォーム間で異なりうる。対称性の確認は Android 実装時の論点になる」と、本 change への申し送りを
残している。その確認結果を記す。

| ADR-0007 の配置規則 | Android 実装 | 判定 |
|---|---|---|
| 縦: content は自然高のまま上端に固定 | 項目の `Box` に `contentAlignment = Alignment.TopCenter` | 一致 (`rowHeightFollowsContent` が行ごとの高さと余分な空白の不在を確認) |
| 横: 自然幅が項目幅より小さいときは中央、幅いっぱいの content は先頭から敷く | 同じ `TopCenter` と `fillMaxWidth` の組み合わせ | 一致 (`narrowContentIsCenteredAndWideContentFillsFromStart` が実座標で確認) |
| content へ行の高さを提案しない | Compose の Lazy 系は項目に行の高さを提案しない (縦は無制限の制約で測る) | 一致 (仕組みとして同じ結果になる) |

申し送りにあった非対称の懸念 (grid の行内でのセルの伸び方) は、**今回の観察では現れていない**。
Sample「大量件数」画面 (2 列・可変行高混在) を両プラットフォームで並べた照合で、長文の行の対向にある
背の低いセルは行の高さいっぱいには広がらず、余りが背景色として見える点まで一致していた
(`sample-parity-comparison.md` #9、判定「一致」)。ADR-0007 の負の帰結
「行全体を塗りたい利用者は content 側で高さを揃える必要がある」は Android でも同じである。

### 補足が要る点: iOS の対策の理由は Android には無い

ADR-0007 の Decision (上端固定) は、iOS の `UIHostingConfiguration` が行の高さを提案して content を測り、
行の高さが遅れて追いつく間に content が上下へはみ出す罠への対策である。Android にはこの罠が無く、
同じ配置規則を**対称性のために**選んでいる (`KsCollectionView.kt` の該当コメントも ios/ADR-0007 を参照する)。

昇格時に、この規則が iOS 固有の対策ではなく**両プラットフォームの content 配置契約**であることが
読み取れるようにするとよい (core への昇格、または core 側の ADR からの参照)。現状は `ios/` 配下の ADR で
あるため、Android 側の実装者が探しに行かない置き場になっている。

## まとめ

- **不一致は 0 件**。3 本とも Android 実装は Decision の各項目を満たしている
- 補足が要る点は 6 件。うち影響が大きいのは ADR-0010 の描画順 (両プラットフォームの一致が文面に無い) と
  ios/ADR-0007 の置き場 (両プラットフォームの契約が iOS 配下にある)
- ADR-0011 には Android 固有の 4 つ目の不正入力 (`key` の型) が抜けている。デルタスペックにはあるため、
  実装とスペックの間には乖離が無い
