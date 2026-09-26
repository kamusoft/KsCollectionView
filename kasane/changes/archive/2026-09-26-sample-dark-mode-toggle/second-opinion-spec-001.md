# セカンドオピニオン: sample-dark-mode-toggle (spec-001)
**相方**: codex / **label**: so-spec-sample-dark-mode-toggle / **日付**: 2026-09-26 / **対象**: 提案一式 (proposal.md / specs/samples/spec.md / tasks.md / ui/brief.md / ui/mock/plan-b-navy.html / exploration.md)
---
**判定: CHANGES_REQUESTED**（Major 2件、Minor 1件）

提案・デルタスペック・tasks・brief・承認 mock を、現行の Sample コード、sample-parity 規約、accepted ADR-0004／core ADR-0010 と照合しました。proposed の ADR-0007 は確定済み規約として扱っていません。静的レビューのため、ビルド・テストは実行していません。

### 🟠 Major — Android の検証画面名が承認 mock と衝突する

**該当箇所:** `kasane/changes/sample-dark-mode-toggle/ui/mock/plan-b-navy.html:44`、`kasane/changes/sample-dark-mode-toggle/tasks.md:32`  
**問題点:** Android のルートメニューにも「検証: 行の高さ変化 (iOS 固有)」と描かれています。現行 Android コードは「Android 固有」で、`sample-parity.md:62-67` もプラットフォーム固有の検証画面を例外として認めています。一方、task 5.1 は Android のルートメニューをこの mock と照合するため、実装者がどちらを正とすべきか決められません。  
**推奨修正:** Android mock の表記を現行の「Android 固有」に合わせて承認し直すか、この行を視覚照合の対象外と明記してください。

### 🟠 Major — ダークのアクセント上の文字色が読みやすさの条件と噛み合わない

**該当箇所:** `kasane/changes/sample-dark-mode-toggle/tasks.md:28`、`kasane/changes/sample-dark-mode-toggle/ui/mock/plan-b-navy.html:44`  
**問題点:** task 4.2 はアクセント上の文字を両外観とも白に固定します。mock のダーク用アクセント `#5B8DF6` と白のコントラスト比は約 **3.19:1** で、現行の `TemplateSwitchDemoScreen.kt:74-78` の小さな「!」などが対象です。spec の「読める」という合格条件には判定基準がなく、task 5.3 の目視だけでは合否が揺れます。  
**推奨修正:** ダーク用の「アクセントの上の色」を別値にできるようにし、対象の文字・印について判定可能な視認性の基準を定めてください。

### 🟡 Minor — 全画面確認の範囲が再現可能な手順になっていない

**該当箇所:** `kasane/changes/sample-dark-mode-toggle/specs/samples/spec.md:54-57`、`kasane/changes/sample-dark-mode-toggle/tasks.md:34`  
**問題点:** 「全画面」「操作をひととおり」では、画像の loading／error など、どの状態を確認したら完了かが人によって変わります。  
**推奨修正:** 画面と確認する操作・状態の一覧を task 5.3 に付け、証跡との対応を記録できるようにしてください。

まず mock の Android 固有表記とアクセント上の色を確定し、その後に確認対象の一覧を整えるのがよいと考えます。

## 突き合わせ結果

ホスト側の自己レビュー (2 周) は、上位層違反なし・新たな問題なしで通過していた。1 周目の修正は 3 件 (UI テストで選んだ外観の持ち越し防止、`Color.White` を配色定義の「アクセントの上の色」に載せる、spec の MAY の書き方)。相方の 3 件はどれもホスト側の自己レビューで見逃していたもので、該当箇所を実物で確かめて判定した。

| # | 指摘 | 採否 | 根拠と対応 |
|---|---|---|---|
| 1 | Android の検証画面名が mock と食い違う (Major) | 採用 | `samples/android/.../VerificationScreen.kt:7` は「検証: 行の高さ変化 (Android 固有)」で、mock の Android フレームが iOS の名前を描いていた。`ui/mock/plan-b-navy.html` (と却下案の `plan-a-neutral.html`) の Android フレームの項目名を直した。承認画像の範囲外の行のため `ui/mock/approved.png` は撮り直しても同じ画像になり、変わらない。brief の承認モックの節に記録 |
| 2 | ダークのアクセントの上の白のコントラスト不足 (Major) | 採用 | 検算で白 / ダークのアクセントは 3.19:1 (ライトは 4.55:1)。対象は Android の自前の segmented の選択中の文字と「テンプレート切り替え」の「!」の印 (iOS にアクセントの上の白は無い)。承認済みのアクセントは変えず、ダークの「アクセントの上の色」を下地の紺 (5.82:1) にする。brief に視認性の基準 (ダークの組だけに当てる。文字 4.5:1・印と塗り 3:1・区切りはライト同程度) を足し、spec の Scenario「ダークで崩れない」の判定をそこへ向け、tasks 1.3 に計算での確認、4.2 に値の定めを足した。基準をライトに当てるとライトの今の値 (アクセント / 下地 4.08:1、補助の文字 / 下地 4.44:1) が届かず「ライトの組は今の値のまま」と矛盾するため、対象をダークの組に限った |
| 3 | 全画面確認の範囲が再現できる手順になっていない (Minor) | 採用 (軽く) | 画面と操作の一覧を tasks 5.3 に付けた (ルートメニュー・デモ 12 画面・検証画面ごとの操作)。一覧以上の仕組み (自動の画面走査など) は足さない |

- 確定 (双方一致): 0 件 / 採用 (相方のみ・根拠強): 3 件 / 降格: 0 件 / 未解決: 0 件
