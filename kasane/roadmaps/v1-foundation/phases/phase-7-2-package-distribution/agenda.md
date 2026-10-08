# 配布物の形 (SPM / Maven)

SPM と Maven の配布物の形を決め、公開物を利用者の立場でビルドして確かめる。

## 論点

- 配布の経路と配布物の形: SPM / Maven のパッケージング (翻案元 `../KsSettingsView/kasane/decisions/cross/` の 0018: 公開の経路だけを使い、SwiftPM は配信用の別リポジトリに置く。accepted で運用中 — 自リポジトリの ADR として判断する)
- 公開物を利用者の立場でビルドして確かめる仕組みと、それを main 宛て PR の検証に足すか (翻案元 cross/0028)

### phase-3 からの申し送り (2026-09-05)

- maven-publish の設定は基盤では行っていない (composite build の明示 substitution で Sample が本体を参照)。配布座標 `jp.kamusoft:kscollectionview` は cross/ADR-0003 どおり Sample で実地確認済み

### phase-7-1 からの申し送り (2026-10-08、public-repo-verify-ci)

- 公開物を利用者の立場でビルドする確認は、検証 CI の入口 (`.github/workflows/ci.yml`) から呼ぶ再利用 workflow として足せる (cross/ADR-0014)。`main` の必須の検査に足すときは、検査の名前を `main` の保護にも登録する
- 検証 CI では Simulator・エミュレータ・実機を使うテストを走らせない (cross/ADR-0013)。利用者の立場の確認も、ビルドまでにするか、実行まで確かめるかを、この決定と合わせて決める

## 決定事項

(議論で確定したらここに移動)

## TODO

- [ ] 論点の解消
- [ ] ksn-propose で変更提案を起こす
