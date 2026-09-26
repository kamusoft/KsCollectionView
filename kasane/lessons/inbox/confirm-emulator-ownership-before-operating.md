---
scope: code-review
kind: pain
severity: normal
count: 1
first-seen: 2026-09-26
last-seen: 2026-09-26
evidence:
  - sample-dark-mode-toggle (review-001 の実行時の再現で、レビュアーが自分の AVD を port 5610 で起動しようとし、同じ port で動いていた他セッションのエミュレータ `ksn_validation_ime` に Sample の APK のインストールと `cmd uimode night no` を行った。APK はアンインストールしたが、夜間モードの元の値は分からず戻せなかった)
---

## ルール文
レビュー・検証・実装で Android エミュレータ (または iOS シミュレータ) に adb / simctl の操作を送る前に、宛先のシリアル (`emulator-<port>`) または UDID が、自分がこの作業で起動したデバイスであることを `adb -s <serial> emu avd name` (iOS は `simctl list` の名前) で確かめ、確かめた名前を報告に書く。自分が起動するときは `adb devices` で使用中の port を確かめてから空いている port を指定する。一致しないデバイスには操作を送らない。

## 経緯
- 2026-09-26 sample-dark-mode-toggle: port の衝突で起動が失敗したことに気づかないまま、既存のエミュレータに操作が届いた。他セッションの検証環境の設定 (夜間モード) を変えた可能性が残った。
