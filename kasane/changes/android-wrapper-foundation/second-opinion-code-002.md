# セカンドオピニオン: android-wrapper-foundation (code-002)
**相方**: codex / **label**: so-code-android-wrapper-foundation-002 / **日付**: 2026-09-05 / **対象**: Android 本体 (tasks.md グループ 2〜6) — android/ ビルド定義・kscollectionview 本体 9 ファイル・テスト 4 ファイル
---
# レビュー結果: android-wrapper-foundation（Android グループ2〜6）

**判定**: CHANGES_REQUESTED

## サマリー

ビルド成功・49 tests / 0 failures は確認済みの前提として扱いました。公開DSLと主要レイアウトは概ね仕様に沿っていますが、インタラクティブ子要素のフィードバック排他、件数比例メモリ、Scenarioテストの実効性にMajorが残っています。

## 照合した規約

- `kasane/handbook/cross/comment-policy.md`（常時）
- `kasane/handbook/cross/test-execution.md`（テスト結果の報告）
- `kasane/handbook/cross/public-identifiers.md`（Gradle・公開識別子）
- `kotlin-impl-skill`
- `jetpack-compose-impl-skill`

## 指摘事項

### [🟠 Major] 子要素がタッチを処理しても親rippleが開始され得る

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:219`  
**関連テスト**: `android/kscollectionview/src/test/kotlin/jp/kamusoft/kscollectionview/KsCollectionViewInteractionTest.kt:83`

**問題点**: 親の`combinedClickable`は、子の`clickable`が最終的にクリックを消費して親コールバックをキャンセルできても、親のPress interactionが先に開始される可能性があります。コードには「子がタッチを処理したか」を判定して親indicationを抑止する処理がありません。

既存テストも親コールバックだけを確認しており、コメントでripple描画を未検証と明記しています。したがって「子が処理した場合は親フィードバックも発火しない」というSHALL NOTを担保できません。

```kotlin
// 現状
Modifier.combinedClickable(
    indication = tapIndication,
    onClick = { onItemTap?.invoke(resolved.item) },
)
```

**推奨修正**: 子がdownを消費したpointer sequenceでは、親のPress interactionもコールバックも開始しないgesture処理を実装してください。子を長押しした場合を含め、親InteractionSourceにPressが流れないことをinstrumented testまたは検査可能なindicationで確認してください。

---

### [🟠 Major] ライブラリ保持メモリが項目数に比例する

**該当箇所**:

- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:106`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:130`
- `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsResolvedItems.kt:29`

**問題点**: 入力配列とは別に、全要素について`KsResolvedItem`を保持し、さらに全IDの`List`も保持しています。通常入力でも追加メモリがO(n)となり、collection-coreの「ライブラリが保持するメモリが件数に比例して増加してはならない」に構造的に反します。

```kotlin
val resolvedItems = remember(items) { resolveItems(...) }
val latestItemIds by rememberUpdatedState(resolvedItems.map { it.id })
```

`resolvedItems.map`は再コンポーズごとにO(n)の一時割り当ても発生させます。これはグループ8の計測未実施を指摘するものではなく、グループ3で導入された保持構造自体の問題です。

**推奨修正**: 正常系では元の`items`だけを保持し、`key`・`contentType`をLazy DSL内で解決してください。重複検査用集合は入力変更時の一時値に限定し、重複があるrelease縮退時だけ補正リストを生成する構成が考えられます。スクロール先IDは命令処理時に最新配列を検索できます。

---

### [🟠 Major] 完了扱いのScenarioテストに実質未検証の条件が残る

**該当箇所**: `kasane/changes/android-wrapper-foundation/tasks.md:36`

**問題点**: グループ6は完了扱いですが、少なくとも次の契約が検証されていません。

- `KsCollectionViewLayoutTest.kt:201`は先頭の`item-0`を表示したままlayoutを切り替えるだけで、非先頭位置のアンカー保持を検証していません。スクロール位置が先頭へリセットされる実装でも通ります。
- release時の重複ID・二重登録・未登録キーのテストは表示だけを見ており、必須の警告ログを検証していません。
- 子要素操作時の親フィードバック抑止は明示的に未検証です。
- `contentPadding`内側を基準とするStart/Center/End、およびヘッダーをitem indexに数えないスクロールはテストされていません。

**推奨修正**:

1. 非0位置までスクロールして先頭可視IDを取得し、layout切替後もそのIDが表示範囲内にあることを検証する。
2. release縮退では`ShadowLog`等で警告を検証する。
3. 子要素の押下中に親Press interactionが発生しないテストを追加する。
4. 上下の`contentPadding`とヘッダーを併用したStart/Center/Endの位置検証を追加する。

---

### [🟡 Minor] Composition中にログ副作用を実行している

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:94`

**問題点**: 二重登録、無効layout、未登録キーの`Log.w`がComposable本体から直接呼ばれます。releaseでは同じ不正入力が再コンポーズのたびに再報告され、ログスパムになります。破棄されたCompositionからログだけが残る可能性もあります。

**推奨修正**: 検査を純粋な値へ分離し、release警告は診断内容をkeyにした`LaunchedEffect`など、成功したCompositionのライフサイクルに結び付けて一度だけ出してください。

---

### [🟡 Minor] 任意のNumberを保存可能と誤判定する

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsResolvedItems.kt:68`

**問題点**: `is Number`は独自`Number`実装も許可しますが、すべての`Number`がBundle保存可能とは限りません。その場合、事前検査を通過した後にCompose側で例外になる可能性があります。

```kotlin
is Number -> true
```

**推奨修正**: Bundleが直接扱える具体的な数値型に限定するか、Composeの保存可能性判定と同等の検査へ置き換えてください。

---

### [🟡 Minor] 実装済み機能を「未実装」とするTODOが残っている

**該当箇所**: `android/kscollectionview/src/main/kotlin/jp/kamusoft/kscollectionview/KsCollectionView.kt:237`

**問題点**: `onItemTap`等は直前の`combinedClickable`へ接続済みですが、コメントは未実装と記述しています。現在のコード単体で意味が通ることを求めるcomment-policyに反します。

**推奨修正**: TODOを削除してください。

## 件数

- Critical: 0
- Major: 3
- Minor: 3
- Suggestion: 0

## アクションプラン

1. 子コントロール操作時の親Press/ripple抑止を実装し、実際のpointer入力で検証する。
2. 正常系の項目数比例メタデータ保持を解消する。
3. グループ6の未検証Scenarioを補い、タスク完了状態を実態と一致させる。
4. Composition中の診断副作用、保存可能型判定、古いTODOを修正する。

**判定: CHANGES_REQUESTED**


---
## 突き合わせ結果 (ホスト側 review-002.md との照合、2026-09-05)

| 相方の指摘 | ホスト側 | 採否 | 根拠 |
|---|---|---|---|
| [Major] 子要素がタッチを処理しても親 ripple が開始され得る | 指摘なし (Suggestion で ripple の検証層が未定と指摘) | **採用・Minor に降格** (テストで確定) | Compose のポインタ処理は Main pass で子の `clickable` が down を消費し、親の `awaitFirstDown` は消費済みを無視するため構造上は親の Press が始まらない。ただし未検証なので、親の `InteractionSource` に `PressInteraction` が流れないことを Robolectric で確認するテストを追加する。テストが落ちたら実装修正へ昇格 |
| [Major] ライブラリ保持メモリが項目数に比例する | Suggestion (再コンポジションごとの O(n)×3 走査) | **採用 (Major)** | 該当箇所が特定され、spec「ライブラリが保持するメモリが件数に比例して増加してはならない (SHALL NOT)」と「メモリが件数に比例しない」Scenario に構造的に反する。性能計測 (8.2) の前に直すほうが安い |
| [Major] 完了扱いの Scenario テストに実質未検証の条件が残る | Minor 2 (ヘッダー index / contentPadding 補正未検証)・Minor 4 (警告ログ未アサート) と一致。非先頭アンカー・子要素押下は相方のみ | **確定 (Minor)** — 4 項目とも修正対象 | 双方一致 2 項目 + 相方のみ 2 項目 (根拠強: 現行テストが先頭固定・親コールバックのみ) |
| [Minor] Composition 中にログ副作用を実行している | 指摘なし | **採用 (Minor)** | release で再コンポジションごとに同じ警告が出るのは実害 (ログスパム)。診断内容をキーにした effect で 1 回だけ出す |
| [Minor] 任意の `Number` を保存可能と誤判定する | 指摘なし | **降格** (Suggestion・対応不要) | 独自 `Number` 実装を key に使うのは稀で、その場合も Compose 側の例外で判明する。契約は KDoc に明記済み |
| [Minor] 実装済み機能を「未実装」とする TODO | Minor 1 で同一指摘 | **確定** (Minor) | 双方一致 |

ホスト側のみの指摘: Major 1 (不透明背景で区切り線が隠れる) は実測付きで確定 — design Decision 5 の `drawBehind` からの乖離として deviation.md に記録する。Minor 3 (`detachedControllerIsNoOp` の空振り) も修正対象。採用 4 / 確定 3 / 降格 1 / 未解決 0。
