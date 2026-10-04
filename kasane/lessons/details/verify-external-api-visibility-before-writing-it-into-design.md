---
scope: spec-review
kind: pain
severity: normal
count: 3
first-seen: 2026-09-07
last-seen: 2026-10-04
evidence:
  - image-loading (design Decision 1 が「現在の共有パイプラインの configuration と delegate をそのまま引き継ぐ」と決めたが、Nuke 13.2.0 の ImagePipeline.delegate は internal 宣言で外から読めず、実装フェーズの tasks 3.3 / 3.5 で停止。この記述は相方の spec-review 指摘 #1「dataCache が nil でも独自 DataLoader / delegate を持つ構成を壊す」への対応として採用されたもので、ホスト・相方どちらの突き合わせでも実現可能性を確認していなかった。オーナー判断で自動差し替えを取りやめ、明示的な公開 API へ方針変更)
  - image-loading / 同一 change 内の再発 (design Decision 8 が Android の統合テストで BlackholeDecoder を使うと決めたが、Coil 3.5.0 の BlackholeDecoder は @ExperimentalCoilApi で opt-in を要することが design に書かれていなかった。実装側が opt-in を internal な adapter の 1 メソッドに閉じて回避。同一作業単位のため count は増やさない)
  - performance-criteria-review (design Decision 15 が「compositional layout の group に item と別の estimated 高さを渡せば行の配置に使われる」を前提に Scenario「混在 2 列でも合計高さの見積もりを損ねない」を追加。design 自身が「Apple の文書に明記が無く実装の A/B で確かめる」と書いており停止条件も置いていたが、A/B は tasks 7.8 (本実装の最後) に置かれ、前提が崩れた (iPad @2x で group の推定が無効、iPhone @3x で全行を解いた後の合計高さ自体が推定値で 1.6 倍振れる) と分かるまでに提案改訂・spec レビュー・7 系の実装を経た。オーナー判断で Scenario を取り下げ)
  - paging-indicator-color (デルタスペックが「色を指定すると Pull to Refresh のインジケータが指定した色で描かれる (SHALL)」と決め、探索の裏取りは「iOS の標準の引っ張りの部品が色の指定 (tintColor) を受ける」という API の存在の確認だけだった。実装後の視覚照合で、iOS の標準の部品は渡した色を 2 回掛けて最大で約 57% の不透明度で描くと分かり (ダークの Sample で下地とのコントラスト比 約 1.7)、公開 API だけでは指定した色の濃さにできず、tasks 1.3・4.1 で停止。ホストの自己レビュー・相方の提案レビューのどちらも、描いた結果の色を確かめていなかった)
---

## ルール文
提案・設計のレビューで、記述が外部ライブラリの値を読む・引き継ぐ・差し替えるといった具体的な API 利用を前提にしているときは、その API が**採用版のソースまたは公式リファレンスで公開宣言されている**ことを確かめ、確認した宣言の位置 (ファイルと行、またはリファレンスの該当項目) をレビュー結果に書く。設計文書の疑似コードが自然に読めることを実現可能性の根拠にしない。指摘への対応として新しい API 利用が書き加えられた場合も、突き合わせの時点で同じ確認を行う。

## 経緯
- 2026-09-07 image-loading: 相方の spec-review 指摘を受けて「configuration と delegate を引き継ぐ」形へ設計を直し、突き合わせ表で「採用・反映済み」として閉じた。実装に入って初めて delegate が internal と判明し、指摘が解こうとした問題 (利用者構成の破壊) は結局解けていなかった。configuration 側は public で引き継げたため、実際に失われるのは delegate だけと分かったが、design と spec を凍結したまま方針を決め直す判断がオーナーに戻り、実装は 2 タスク分停止した。
- 2026-09-07 image-loading (同一 change 内の再発): Android 側でも design が指定した Coil の API が experimental (opt-in 必須) であることを提案段階で確認しておらず、実装側の判断で opt-in の露出範囲を internal に閉じて処理した。停止には至らなかったが、確認していれば design に「opt-in の露出をどこで止めるか」を書けた。
- 2026-09-16 performance-criteria-review: 前提が未確認であることは design に明記され停止条件もあったが、確認 (A/B) が本実装の末尾に置かれたため、崩れたときには Requirement 本文に SHALL として載った後だった。外部 API の挙動が前提になる Scenario は、提案段階の最小試作 (Decision 13 の段階 1 と同じ形) で前提だけ先に確かめるか、前提が確かめられるまで Requirement 本文に SHALL で書かない。
- 2026-10-04 paging-indicator-color: API が色を受け取れること (宣言の存在) は確かめていたが、受け取った色がどう描かれるかは確かめていなかった。色・見え方を約束する Scenario が外部の部品の描き方を前提にするときは、提案段階の最小試作で、実際の操作 (指で引っ張る) で出した表示の画素の色を、ライト / ダークで確かめる。テストの都合で出した表示 (取り直し中にする命令) は実物と描き方が違う場合がある。
