# 配布 / ドキュメント

パッケージ配布・利用者ドキュメントの整備。サンプルアプリは各フェーズの完了条件で育つため本フェーズの対象外 (roadmap 前提参照)。

## 論点

- 配布: SPM / Maven のパッケージング (翻案元 `../KsSettingsView/kasane/decisions/cross/` の 0018 SPM 配信リポジトリ・0019 lockstep 単一バージョン・0020 dispatch リリース/tag 後置/version CI 注入は翻案元でも proposed — 本フェーズで自リポジトリの ADR として判断する)
- 検証 CI の構成と保証範囲 (翻案元 cross/0025・0026: platform 別再利用 workflow + 入口、パス絞り込みなし、テスト 0 件は緑でも失敗)
- skills/ 方式の利用者ドキュメントの実制作 (方針は [cross/ADR-0005](../../../../decisions/cross/0005-user-docs-as-agent-skills-and-root-readme.md) で accepted 済み)
- 大量件数の性能検証をリリース基準に含めるか (実機・件数・計測手順)

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
