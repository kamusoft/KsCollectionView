# ADR 一覧 (ドメイン地図)

ADR はドメイン別に管理する。参照の正式形は `<domain>/ADR-NNNN` (同一ドメイン内からは `ADR-NNNN` だけでもよい)。ドメイン導出規則は [concepts/rules.md](../concepts/rules.md) を参照。

| ドメイン | 説明 |
|---|---|
| core | 全 platform が共有する契約の決定 |
| ios | iOS 固有の決定 |
| android | Android 固有の決定 |
| maui | .NET MAUI 固有の決定 |
| cross | リポジトリ横断のメタ決定 (リポジトリ構成・命名・ハーネス運用) |

まだ ADR はない。ドメインディレクトリと各ドメインの index は最初の ADR 起票時に作成する。

採番規則: ドメインごとに 0001 から採番する (そのドメインの既存最大値 + 1)。
