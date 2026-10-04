# セカンドオピニオン: paging-indicator-color (code-001)
**相方**: codex / **label**: so-code-paging-indicator-color-001 / **日付**: 2026-10-04 / **対象**: 作業ツリーの未コミットの実装 diff (ios/・android/・samples/ 配下)
---
# レビュー結果: paging-indicator-color (001 回目)

**日付**: 2026-10-04  
**判定**: CHANGES_REQUESTED  
**保存予定先**: `kasane/changes/paging-indicator-color/review-001.md`  
**指摘件数**: Critical 0 / Major 1 / Minor 0 / Suggestion 0

## サマリー

色の適用範囲、差し替え表示への非適用、指定解除、iOS のドラッグ中の更新保留は、仕様と合意済み差分に沿って実装されています。ただし Android の公開関数への引数追加により、既存の一部の位置指定呼び出しがコンパイルできなくなり、提案の「破壊的変更なし」を満たしていません。

本レビューは静的レビューです。ビルド・テストの再実行、描画結果や計測値の再現確認は行っていません。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`：公開 doc コメントと変更されたソースコメント。
- `kasane/handbook/cross/test-execution.md`：新規テストの検証対象、条件待機、Android の NATIVE graphics。
- `kasane/handbook/cross/sample-parity.md`：両 Sample の共通トークンと外観追随。
- `kasane/handbook/cross/sample-debug-controls.md`：操作パネルと一覧の配置入力の維持。
- iOS / Android の性能検証規約：変更の適用範囲を確認。セル生成・再利用・レイアウト・スクロールの実装変更はありません。
- 関連する accepted ADR：core/ADR-0002・0023・0024・0033、ios/ADR-0004、cross/ADR-0007。

ロードしたスキル：`ksn-review`、`kotlin-impl-skill`。

core/ADR-0035 は proposed として扱い、accepted ADR 違反の判定根拠にはしていません。`deviation.md` の記録済み差分と蒸留への申し送りは、指摘対象から除外しました。

## 確認した観点

- 既定のページング表示 2 つと Pull to Refresh に、一覧の設定から色が渡ること。
- ページングなしでも Pull to Refresh に色が渡ること。
- 差し替え表示へ色や tint を流していないこと。
- 色未指定時に、既存の標準色を使うこと。
- 表示中の変更・指定解除が、既存の更新経路で反映されること。
- iOS のドラッグ中は構成を保留し、終了後に色を反映すること。
- Android の Pull to Refresh は矢印の色だけを変更すること。
- 新規テストが上記 Scenario を扱い、Android では画素を検証していること。
- Kotlin の null 安全、状態の捕捉、公開 KDoc、不要な依存追加の有無。
- 両 Sample が既存の `secondaryText` を参照し、操作・配置・その他の表示を変更していないこと。
- tasks 4.1・4.2 は未チェックであり、未完了の確認を完了扱いしていないこと。

ホストから提供されたテスト結果は、iOS ライブラリ 545 tests / 0 failures、Android ライブラリ 488 tests / 0 failures、Android Sample 163 tests / 0 failures、iOS Sample ユニットテスト 37 tests / 0 failures です。iOS ライブラリの実行環境は iPhone 17・iOS 27.0。UI テストを含む全件実行と合計時間の確認は継続中です。

## 指摘事項

### [🟠 Major] 括弧内で content まで位置指定する既存呼び出しが壊れる

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:193`

**問題点**: `loadingIndicatorColor` を `content` の前に挿入したため、既存の `content` の引数位置が 21 番目から 22 番目へ変わっています。末尾ラムダを括弧の外に書く呼び出しは維持されますが、全引数を括弧内に位置指定する呼び出しは維持されません。

例えば、次は変更前の署名で有効な呼び出しです。

```kotlin
KsCollectionView(
    listOf(1), { it }, Modifier, null, KsLayout.List, PaddingValues(0.dp),
    null, null, null, null, null, null, true, null, null, null,
    KsPrefetchDestination.Disk, null, null, null,
    { template { item -> Text("$item") } },
)
```

変更後は最後のラムダが `loadingIndicatorColor: Color?` に対応し、型不一致と必須の `content` 未指定になります。新引数の既定値は、位置指定された引数を飛ばして対応付けるものではありません。

これは `proposal.md` の「破壊的変更なし」「引数を位置で渡している既存の呼び出しもそのままコンパイルできる」という互換性の約束に反します。追加された公開 API テストは名前付き引数の確認で、この形を検証していません。

**推奨修正**: 新 API の引数配置を維持したまま、旧署名と同じ 21 引数を受ける互換 overload を用意し、新 API へ名前付き引数で転送してください。互換 overload の既定引数を省く方法などで、通常の呼び出しとの曖昧性を避けられます。

修正後は、上記の既存呼び出しを変更せずにコンパイルできることを公開 API テストで確認してください。利用側への `null` 追加や末尾ラムダへの書き換え要求では、互換性の約束を満たせません。

## アクションプラン

1. Android の旧署名による位置指定呼び出しを維持し、その形をコンパイルする回帰テストを追加する。
2. ホスト側で修正箇所を検証し、継続中の tasks 4.2 の全件結果・件数・合計時間を確定する。
3. tasks 4.1 の最終承認時に、`ui/brief.md` に記録された iOS ライトの Pull to Refresh のコントラスト比約 2.1 の扱いも確定する。この値は本レビューでは再測定しておらず、ダークの約 2.9 に対する合意とは区別して扱う。

## 突き合わせ結果

突き合わせの相手はホスト側の独立レビュー (review-001.md: NEEDS_DISCUSSION — Minor 1・Suggestion 1 と判断が要る論点 1、verify-001.md: INVALID)。

| # | 指摘 | 出典 | 採否 | 根拠と反映 |
|---|---|---|---|---|
| 1 | Android で、一覧の中身のブロックまで全引数を括弧の中に位置で並べて渡す既存の呼び出しがコンパイルできなくなる (proposal の Impact の約束と食い違う) | 相方のみ | 採用 → オーナー判断で乖離として記録 (コードは変えない) | 該当の位置と壊れる呼び出しの形が特定されており、根拠は強い。公開 API の宣言 (`KsCollectionView.kt` の引数の並び) と照合し、中身のブロックは末尾に置く形のため足す位置をこれ以上後ろにできないこと、過去の引数の追加 (2026-09-29 のページング・取り直しの処理、2026-10-01 の並べ替え) も同じ位置で互換用の入口を作っていないこと、配布前であることを確かめた。互換用の入口を足すか・受け入れるかをオーナーに諮り、受け入れると決定 (deviation.md に記録、2026-10-04) |
| 2 | iOS・ライトの Pull to Refresh のコントラスト比 約 2.1 が合意として記録されていない | ホストのみ (相方はアクションプラン 3 で同じ点に言及) | 確定 → 解消済み | レビューの実行中にオーナーが視覚照合を最終承認し、ライトの約 2.1 を受け入れた。deviation.md と ui/brief.md に記録済み (2026-10-04) |
| 3 | iOS の色の補正が iOS 16・17 で未確認 | ホストのみ (Minor) | 対応不要 | deviation.md の蒸留送りの行に記録済み。該当の版のシミュレータが無く確かめられない |
| 4 | 表示モードで変わる色を指定すると、色の等値の判定が効かず更新のたびに色を入れ直す可能性 | ホストのみ (Suggestion) | 降格 | 実害が確認されていない (レビュアーの撮影で取り直し中のインジケータに乱れなし)。入れ直しは同じ色の再設定で、見え方は変わらない |

確定 1 件 / 採用 1 件 / 降格 1 件 / 対応不要 1 件 / 未解決 0 件。コードの修正は発生していない。
