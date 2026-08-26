# concepts 目次 (ドメイン地図)

concepts はドメイン別に分割して管理する。カテゴリ定義・配置基準・ドメイン導出規則は [rules.md](rules.md) を参照。

| ドメイン | 内容 |
|---|---|
| core | 全 platform が共有する契約 (architecture / core-model / cells / styling) |
| ios | iOS 固有の公開 API・Bridge 境界 |
| android | Android 固有の公開 API・Bridge 境界 |
| maui | .NET MAUI 固有の知識 |
| cross | リポジトリ横断のメタ事項 (リポジトリ構成・命名規約) |

まだ概念はない。ドメインディレクトリと各ドメインの index は最初の概念が生まれるときに作成する。

[log.md](log.md) は全ドメイン共通の append-only 履歴。
