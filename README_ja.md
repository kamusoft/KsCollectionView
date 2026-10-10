# KsCollectionView

[English](README.md)

## 概要と特徴

KsCollectionView は、iOS の SwiftUI と Android の Jetpack Compose で使える、リストとグリッドのライブラリです。ページング、Pull to Refresh、グループ化、ドラッグ & ドロップでの並べ替えといった、リスト画面でよく使う機能を、両プラットフォームで揃えた API で提供します。

- 安定した ID を持つ項目の配列を渡すだけで、リストとグリッドを表示します。配列を差し替えると、差分がアニメーションします
- グリッドの列は、固定の列数、縦向きと横向きで別の列数、項目の最小の幅のいずれかで指定できます
- 項目の型によるテンプレートの切り替え、全体のヘッダーとフッター、区切り線、間隔、内側の余白を指定できます
- グループ化に対応し、グループの見出しはスクロール中も上端に固定されます
- ページングに対応し、読み込み中・失敗・終端・空のときの表示を持ちます。Pull to Refresh も使えます
- ドラッグ & ドロップで並べ替えられます。グループをまたぐ移動と、スクリーンリーダー向けの移動の操作にも対応します
- これから表示される項目の画像を先読みできます。同じキャッシュを使う画像のコンポーネントも提供します
- タップと長押しのコールバック、タッチのフィードバック、コードからのスクロールを提供します

## スクリーンショット

以下は、このリポジトリのサンプルアプリの画面です。

| | リスト | グリッド | グループ化 |
| --- | --- | --- | --- |
| **iOS** | <img src="assets/ios-list.png" width="220" alt="iOS の区切り線つきのリスト"> | <img src="assets/ios-grid.png" width="220" alt="iOS の固定 3 列のグリッド"> | <img src="assets/ios-grouping.png" width="220" alt="iOS のグループ化したグリッドと、固定された見出し"> |
| **Android** | <img src="assets/android-list.png" width="220" alt="Android の区切り線つきのリスト"> | <img src="assets/android-grid.png" width="220" alt="Android の固定 3 列のグリッド"> | <img src="assets/android-grouping.png" width="220" alt="Android のグループ化したグリッドと、固定された見出し"> |

## 対応プラットフォーム

| プラットフォーム | 最低の OS | 利用する側のビルドに必要なもの | ライブラリのビルドに使っているもの |
| --- | --- | --- | --- |
| iOS | iOS 16 | Xcode 27 以上 | Xcode 27.0 (Swift tools 6.4) |
| Android | Android 10 (API 29) | minSdk 29 以上、compileSdk 36 以上 | Android Gradle Plugin 9.4.0、Kotlin 2.4.10、Gradle 9.7.0、Compose BOM 2026.06.01、JDK 21 (配布物の対象は Java 17) |

「ライブラリのビルドに使っているもの」は、ライブラリをビルドした道具の版で、利用する側のプロジェクトに求める下限ではありません。iOS は、パッケージのマニフェストが Swift tools 6.4 を宣言しているため、それより古い Xcode ではパッケージを解決できません。Android の「利用する側のビルドに必要なもの」は、配布物と、配布物が持ち込むライブラリのメタデータから決まる値です。Android Gradle Plugin と Kotlin の下限は示していません。確かめてあるのは、「ライブラリのビルドに使っているもの」の版との組み合わせだけです。

## インストール

KsCollectionView はまだ公開していないため、以下の宣言は現時点では解決できません。最初の版を公開した後の、依存の書き方を示しています。

宣言では、版をプレースホルダ `{version}` で書いています。使う版に置き換えてください。そのままでは依存の解決に失敗します。最新の版は、このリポジトリの [Releases](https://github.com/kamusoft/KsCollectionView/releases) で確かめられます。

### iOS

`Package.swift` に、パッケージと product を追加します。Xcode のプロジェクトでは、Add Package Dependencies から同じ Package URL を追加し、product の `KsCollectionView` を選びます。

```swift
dependencies: [
    .package(url: "https://github.com/kamusoft/KsCollectionView-SPM", exact: "{version}"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "KsCollectionView", package: "KsCollectionView-SPM"),
        ]
    ),
]
```

### Android

ライブラリを使うモジュールに、依存を追加します。配布物は Maven Central から配ります。

```kotlin
dependencies {
    implementation("jp.kamusoft:kscollectionview:{version}")
}
```

## 最小コード例

どちらの例も、100 行のリストを 1 つ表示する、1 つのファイルの全体です。

### iOS

```swift
import KsCollectionView
import SwiftUI

struct Item: Identifiable, Equatable, Sendable {
    let id: Int
    let title: String
}

struct ItemListScreen: View {
    private static let itemCount = 100

    private let items = (0..<itemCount).map { index in
        Item(id: index, title: "Item \(index)")
    }

    var body: some View {
        KsCollectionView(items) { item in
            Text(item.title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
    }
}
```

### Android

```kotlin
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import jp.kamusoft.kscollectionview.KsCollectionView

data class Item(val id: Int, val title: String)

private const val ItemCount = 100

@Composable
fun ItemListScreen(modifier: Modifier = Modifier) {
    val items = remember { List(ItemCount) { index -> Item(id = index, title = "Item $index") } }
    KsCollectionView(
        items = items,
        key = { it.id },
        modifier = modifier.fillMaxSize().safeDrawingPadding(),
    ) {
        template { item ->
            BasicText(
                text = item.title,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            )
        }
    }
}
```

この例は、Material に依存しないように、文字を Compose Foundation の `BasicText` で描いています。コンパイルするには、モジュールで Compose を有効にし、Compose Foundation への依存を持たせてください。

## Skill

詳しい使い方は Agent Skill にあります。機能ごとに、できること、動くコード、守る約束ごとを書いています。使うプラットフォームの Skill を自分のプロジェクトにコピーして、コーディングエージェントに読ませてください。

- [iOS の Skill](skills/ja/kscollectionview-ios/SKILL.md)
- [Android の Skill](skills/ja/kscollectionview-android/SKILL.md)
- [Skill の索引](skills/README_ja.md) (導入の手順と、英語版の案内)

## リポジトリ構成

| ディレクトリ | 役割 |
| --- | --- |
| `ios/` | iOS のライブラリと、その Swift パッケージ |
| `android/` | Android のライブラリ |
| `samples/` | iOS と Android のサンプルアプリ |
| `skills/` | ライブラリの利用者向けの Agent Skill (英語と日本語) |
| `verification/` | 利用者のプロジェクトと同じ形でライブラリをビルドして確かめる、最小のアプリ |
| `scripts/` | lint・検証・配布のスクリプト |
| `assets/` | この README で使う画像 |
| `kasane/` | 開発の記録 (決定・概念・変更の履歴) |

## 貢献

不具合の報告、提案、質問は GitHub Issue で受け付けています。外部のコントリビューターからの Pull Request は受け付けていません。詳しくは[貢献の案内](.github/CONTRIBUTING_ja.md)を参照してください。

## ライセンス

KsCollectionView は [MIT License](LICENSE) で提供します。

KsCollectionView は、次のライブラリに直接依存しています。インストールすると、これらと、これらが依存するライブラリが、依存として取得されます。それぞれ、そのライブラリのライセンスで配布されています。

| プラットフォーム | ライブラリ | ライセンス |
| --- | --- | --- |
| iOS | Nuke | MIT License |
| Android | Jetpack Compose と、そのほかの AndroidX のライブラリ | Apache License 2.0 |
| Android | Coil | Apache License 2.0 |
| Android | Kotlin の標準ライブラリ | Apache License 2.0 |
