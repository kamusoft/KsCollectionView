# ADR 一覧 (ドメイン地図)

ADR はドメイン別に管理する。参照の正式形は `<domain>/ADR-NNNN` (同一ドメイン内からは `ADR-NNNN` だけでもよい)。ドメイン導出規則は [concepts/rules.md](../concepts/rules.md) を参照。

| ドメイン | 説明 |
|---|---|
| core | 全 platform が共有する契約の決定 |
| ios | iOS 固有の決定 |
| android | Android 固有の決定 |
| maui | .NET MAUI 固有の決定 |
| cross | リポジトリ横断のメタ決定 (リポジトリ構成・命名・ハーネス運用) |

## core

| ID | タイトル | status |
|---|---|---|
| [ADR-0001](core/0001-asymmetric-rendering-engines.md) | 描画エンジンの非対称構成 — iOS は UICollectionView ベース、Android は Compose Lazy 系ラッパー | accepted |

## cross

| ID | タイトル | status |
|---|---|---|
| [ADR-0001](cross/0001-two-platform-declarative-library-scope.md) | KsCollectionView を SwiftUI / Compose の2プラットフォームライブラリとして新設する (MAUI 非対応) | accepted |

採番規則: ドメインごとに 0001 から採番する (そのドメインの既存最大値 + 1)。
