# 対称 DSL 仕様の設計

SwiftUI / Compose の両言語でサンプルコードを書きながら、公開 API の形を確定する (全フェーズの土台)。

## 論点

- 対称性の粒度: 何を両プラットフォームで揃え (命名・構造)、何を各プラットフォームの流儀に残すか (modifier 記法・状態保持の仕組み等)
- コレクションの状態モデル: アイテム・セクションの表現、安定 ID の要求、差分更新の契約
- テンプレート種別の宣言方法: データ型 → テンプレートの対応をどう宣言させるか。再利用 (Compose `contentType` / iOS `CellRegistration`) にきれいに乗る形にする
- ページング契約の外形: 状態 (idle / refreshing / appending / failed / endReached) を利用者にどう見せるか (実装は後続フェーズ)
- レイアウト指定の DSL: リスト / 固定列グリッド / adaptive グリッド / 画面向き可変の宣言方法
- ソートの表現: データ層の並べ替え + 差分アニメで足りるか、DSL に何か要るか
- スクロール制御 (VM からのスクロール命令) の API 形
- 旧 AiForms.CollectionView の公開契約 (`../../../../../AiForms.CollectionView/README-ja.md`) から引き継ぐ語彙・捨てる語彙

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] 両言語のサンプルコード (利用側視点) を artifacts/ に書いて API 形状を固める
- [ ] 調査結果のまとめ
- [ ] ksn-roadmap で research 完了をマーク
