# D&D 並べ替え

リスト・グリッドのドラッグ並べ替えを両プラットフォームで対称に提供する。

## 論点

- iOS: diffable `reorderingHandlers` + drag delegate での実装。iOS 27 `.reorderable()` との関係 (最低 OS 16 のため当面使えない — 将来の置き換え余地としてだけ意識)
- Android: Compose に公式 API が無い — OSS (`sh.calvin.reorderable`) 依存か自前実装かの判断 (依存の持ち込みはライブラリとして重い判断)
- 同一セクション内移動 → セクション間移動の段階提供
- 移動可否 (drag handle・業務ルール)・永続化失敗時の rollback 契約
- ソート中の D&D の意味論: sort 適用中は無効化するか、D&D 開始で manual order へ切り替えるか (どちらかを契約化する)
- edge auto-scroll・長押し開始・アクセシビリティ

### phase-4 からの申し送り (2026-09-24)

- Android の項目の移動・挿入・削除のアニメーションは、セクション / グループ化の change (`sections-grouping`) で `animateItem` を入れて解決する (android/ADR-0006 proposed、amends android/ADR-0004 の「`animateItem` は重ねない」)。D&D はこの前提から始められる

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
