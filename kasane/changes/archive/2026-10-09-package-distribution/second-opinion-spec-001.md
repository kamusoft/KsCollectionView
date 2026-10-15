# セカンドオピニオン: package-distribution (spec-001)
**相方**: codex / **label**: so-spec-package-distribution-001 / **日付**: 2026-10-09 / **対象**: 提案一式 (`kasane/changes/package-distribution/` の proposal.md・design.md・specs/・tasks.md。指摘を反映する前の版)
---
実装前に修正すべき指摘は **Major 3 件、Minor 2 件**です。ビルド・テストの実行、ファイルへの書き込みは行っていません。

1. **Major — `kasane/changes/package-distribution/specs/package-distribution/spec.md:95` — 依存範囲の分類が既存の公開方針を扱えていない**
   
   公開 API に型が現れるかどうかだけでは、compile／runtime を決められません。既存の `android/kscollectionview/build.gradle.kts:89` は、Coil の型を公開 API に出さなくても、利用者が `AsyncImage` を直接使ってキャッシュを共有できるよう、意図的に `api` 依存にしています。今回の分類では、この依存を維持すべきか判断できません。
   
   **推奨修正:** 「利用者が直接利用することを契約としている依存」も compile に含め、tasks 3.3 の監査対象にも加えてください。

2. **Major — `kasane/changes/package-distribution/specs/consumer-verification/spec.md:51`、同 `:94` — published モードのビルド契約が不足している**
   
   両 Requirement のビルド義務は `local` の場合に限定されています。`published` は受け付ける入力として宣言されていますが、指定した公開版を使って何をビルドし、何をもって成功とするかが決まっていません。参照形式の Scenario だけでは、後のリリース工程から呼べる確認としての挙動を検証できません。
   
   **推奨修正:** ビルドと成功判定を両モード共通の契約にし、成果物の準備だけをモード別にしてください。`published` では写しの作成・ローカル発行を行わず、指定版を参照して共通の確認を行う Scenario を追加してください。実際の公開物取得は今回の検証対象外のままで構いません。

3. **Major — `kasane/changes/package-distribution/specs/consumer-verification/spec.md:102`、`kasane/changes/package-distribution/specs/package-distribution/spec.md:99` — Android 本体のビルド出力が Side Effects から漏れている**
   
   ローカル発行には、本体の release AAR・sources jar・POM などの生成が必要です。しかし宣言されている書き込み先は、発行先の Maven リポジトリと利用者役のビルド出力だけです。本体側に残り、発行処理が読む生成物は、契約の欄で数える状態変更に当たります。このままでは通常の Gradle 発行でも宣言外の書き込みが必要になります。
   
   **推奨修正:** 本体のビルド・発行用生成物の作成／更新を、関係する Requirement の Side Effects に追加してください。あるいは生成先を一時ディレクトリへ移す設計を明記してください。

4. **Minor — `kasane/changes/package-distribution/specs/package-distribution/spec.md:34` — 存在しない行き先が Requires を満たせない**
   
   本文 `:21` は「行き先が無ければ作る」と規定していますが、Requires は「空のディレクトリか配信用リポジトリの作業コピー」に限定しています。存在しないパスを受け付けるべきか、前提違反として拒否すべきかが矛盾しています。
   
   **推奨修正:** Requires に「存在しない行き先」を追加し、外部の未作成パスを指定するとディレクトリと写しの 5 点が作られる Scenario を追加してください。

5. **Minor — `kasane/changes/package-distribution/tasks.md:48` — 既存のジョブ集合テストの更新が抜けている**
   
   `scripts/ci/tests/test_workflow_files.py:97` は、入口のジョブ集合が厳密に `{lint, ios, android}` であることを要求しています。新しいテストを追加するだけでは、consumer ジョブを足した時点で既存テストが失敗します。
   
   **推奨修正:** tasks 6.3 に、既存のジョブ集合の期待値を 5 ジョブへ更新し、既存 3 ジョブの名前と呼び出し形式の検査を維持する作業を明記してください。


## ホスト側の自己レビューの記録

2 周行った。1 周目で直したのは 2 か所で、2 周目では新しい問題は出なかった。

| 直した箇所 | 内容 |
|---|---|
| proposal.md の Non-Goals | 配信用リポジトリの設定 (Issue と Pull Request を閉じる) と、写しを送る工程も、後のリリースのフェーズへ送ることを明記した (フェーズの決定事項との照合で、行き先が書かれていなかった) |
| tasks.md の 3.4 | 使い捨ての署名の鍵をリポジトリの外に作り、鍵の中身を証跡に書かないことを足した |

新設・変更した契約を、同じ契約を書いている成果物と既存のコードに突き合わせた結果 (lessons の spec-review の L-001):

| 契約 | 突き合わせた先 | 結果 |
|---|---|---|
| 検証 CI の起動条件 (変更) | `.github/workflows/ci.yml` の起動の条件と同時実行、cross/ADR-0014、`kasane/handbook/cross/verification-ci.md` の「走る時点」 | 今の形と一致。足すのは Pull Request のときだけ走る 2 つのジョブで、handbook の表は蒸留で直す |
| ブランチの保護 (変更) | `kasane/handbook/cross/branch-and-github-settings.md` の保護の値と「設定を入れる順」 | 必須の検査を 3 つから 5 つにする以外は変えない。名前を見てから入れる順は handbook と同じ |
| SwiftPM の写しを作る | cross/ADR-0015、フェーズの決定事項の「配布物の中身」 | 5 点と、マニフェストを書き換えないことが一致 |
| Android の発行物 | cross/ADR-0003 の座標、`android/build.gradle.kts` の版の受け口、`samples/android/settings.gradle.kts` のソースへの置き換え | 座標と版の決め方は変えない。依存の範囲の分類が、今の `api` の宣言 (Coil の Compose 連携) を扱えていなかった点は、相方の指摘 1 で気付いた (自己レビューの見逃し) |
| 利用者の立場のビルドの確認 | cross/ADR-0013 (Simulator・エミュレータを使わない)、cross/ADR-0016 | 総称の行き先へのビルドだけで、起動しない。起動の確認は手元で 1 回 |
| iOS のマニフェストの宣言 | `ios/Package.swift`、`samples/ios` のローカル参照、`.github/workflows/verify-ios.yml` の Xcode の版、handbook と README の Xcode の版の記述 | 検証 CI と手元はどちらも Xcode 27.0。handbook と README に、Swift 6.2 や Xcode 26 を前提にした記述は無い (検証 CI の文書を除いて検索) |

外部の道具の具体的な使い方を前提にした契約の確かめ (同 L-002):

| 前提 | 確かめた場所と結果 |
|---|---|
| 公開のプラグイン (`com.vanniktech.maven.publish` 0.37.0) の設定の書き方と、鍵なしでの発行 | 提案の段階の試作 (2026-10-09。AGP 9.4.0・Gradle 9.7.0)。design.md の「提案の段階で試して確かめたこと」 |
| 鍵をプロパティで渡したときの署名と、Maven Central 向けのタスクの名前 | 試作では確かめていない。兄弟ライブラリが同じ版のプラグインと同じ書き方で運用している (`../KsSettingsView/android/kssettingsview/build.gradle.kts` の公開の設定と歯止め)。本変更では tasks の 3.2 と 3.4 で、手元で確かめる |
| 写しをパスで参照したときの package の名前が、ディレクトリの名前になること。署名なしの実機向けのビルド | 提案の段階の試作 (Xcode 27.0)。同上の表 |
| コード縮小を有効にした利用者役の組み立てと起動 | 確かめていない。確かめる作業を tasks の 5.2 (最初に確かめる) と 5.7 に置き、失敗したら止めて諮る |
| 再利用 workflow を呼ぶジョブに条件を付ける書き方と、検査の名前の決まり方 | 兄弟ライブラリの入口の workflow (`../KsSettingsView/.github/workflows/ci.yml`) が同じ書き方で運用している。検査の名前は tasks の 9.2 で、報告を見て確かめる |

## 突き合わせ結果

ホスト側の自己レビューは、相方の 5 件のどれも挙げていなかった。5 件とも、該当の箇所と既存のコードを開いて根拠を確かめ、採用した。

| 指摘 | 採否 | 根拠と反映 |
|---|---|---|
| 1 (Major) 依存の範囲の分類が、今の公開の方針を扱えていない | 採用 | `android/kscollectionview/build.gradle.kts` は、公開 API に型が現れない Coil の Compose 連携を、利用者が直接使う前提で `api` にしている (core/ADR-0012)。スペックの分類のままでは、これを runtime へ動かす読み方ができた。スペックの分類に「利用者が直接使うことを契約にしている依存」と BOM を足し、今 compile の範囲にある依存を動かさないことを書いた。design の Decision 2 と tasks の 3.3 にも反映 |
| 2 (Major) published のビルドの契約が足りない | 採用 | 両方の Requirement が、ビルドの義務を `local` に限っていた。ビルドと成功の条件を切り替えに関わらず同じにし、準備だけを切り替えで分ける形に書き直した。`published` では準備を飛ばして同じビルドを始める Scenario を足した (コマンドを差し替えたテストで確かめる。取得の実行は本変更の対象外のまま)。design の Decision 3 と tasks の 4.3・5.4 にも反映 |
| 3 (Major) Android の本体のビルドの出力が Side Effects から漏れている | 採用 | 利用者役のビルドの出力は数えているのに、本体のビルドの出力は数えていなかった。「Android の発行物」と「Android の利用者の立場のビルドの確認」の Side Effects に足した |
| 4 (Minor) まだ無い行き先が Requires と食い違う | 採用 | 本文は「無ければ作る」、Requires は空のディレクトリか作業コピーに限っていた。Requires に無いパスを足し、Scenario を足した。design の Decision 1 と tasks の 2.3 にも反映 |
| 5 (Minor) 既存のジョブの集合のテストの更新が抜けている | 採用 | `scripts/ci/tests/test_workflow_files.py` が、入口のジョブの集合を 3 つと決めている。tasks の 6.3 に、期待を 5 つに直し、既存の 3 つの検査を保つことを書いた |

確定 0 件 / 採用 5 件 / 降格 0 件 / 未解決 0 件。
