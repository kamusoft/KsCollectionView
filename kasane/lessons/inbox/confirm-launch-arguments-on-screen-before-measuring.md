---
scope: process
kind: pain
severity: normal
count: 1
first-seen: 2026-09-15
last-seen: 2026-09-15
evidence:
  - performance-criteria-review (tasks 4.1 の実機計測で `devicectl device process launch` に `--screen` / `--large-count` を `--` 区切りなしで渡し、引数がアプリに届かないまま 2,000 件のつもりの走行を採取。帯が出ないことで発覚し、2,000 件は取り直しになった。あわせて Sample の Debug 構成に `DEBUG` が定義されておらず、不一致率の帯のボタンが出ないことも実機で初めて分かった。オーナーから「ちゃんとやれ」)
---

## ルール文
実機計測でアプリを起動引数つきで起動したら、記録の合図を出す前に、その引数が効いていることを画面上の表示 (件数の帯・画面名) でオーナーに確認してもらう。引数が届かなくても既定値で動く画面 (既定 10,000 件など) は、見た目では区別できないので確認を省かない。`devicectl device process launch` にアプリの引数を渡すときは `--` の後ろに置く。

## 経緯
- 2026-09-15 performance-criteria-review: 起動は成功と出るのに引数が届かない組み合わせで、2 走行分の時間とオーナーの操作が無駄になった。
