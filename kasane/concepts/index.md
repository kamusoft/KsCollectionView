# concepts 目次 (ドメイン地図)

concepts はドメイン別に分割して管理する。カテゴリ定義・配置基準・ドメイン導出規則は [rules.md](rules.md) を参照。

| ドメイン | 内容 |
|---|---|
| [core](core/index.md) | 全 platform が共有する契約 (architecture / core-model / cells / styling) |
| [ios](ios/index.md) | iOS 固有の公開 API・エンジンの契約 |
| [android](android/index.md) | Android 固有の公開 API・ラッパーの契約 |
| cross | リポジトリ横断のメタ事項 (リポジトリ構成・命名規約) |

概念を持つドメインは名前がその index へのリンクになっている。ドメインディレクトリと各ドメインの index は最初の概念が生まれるときに作成する。

[log.md](log.md) は全ドメイン共通の append-only 履歴。
