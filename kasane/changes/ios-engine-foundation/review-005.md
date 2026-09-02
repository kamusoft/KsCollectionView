# コード最終レビュー: ios-engine-foundation

## メタデータ

- 日付: 2026-09-02
- 対象: オーナー判断後の現行成果物全体
- 判定: **APPROVED**

## サマリー

`review-004.md` で残っていた性能受け入れは、オーナー承認済みの iPhone 15 代替を記録した `deviation.md` と実測 evidence により解消した。基準機 iPhone 11 相当の保証にはならない限界も明記されており、合意済み差分の範囲を過大に表していない。3 回の hitch 計測はすべて基準内で、メモリは 1 往復後から 5 往復後まで増加せず定常化している。tasks 8.1〜8.3 の完了状態も、この deviation と evidence を合わせて読む限り実態と一致する。

`review-004.md` で解消済みの interactive control Scenario は再燃していない。Sample XCUITest の実座標 tap と、interactive hit 判定から highlight / feedback / item selection を抑止するコード経路は維持され、現行 UI test も成功した。

Development Team 設定は現行 Xcode project に存在せず、identity lint も成功した。Debug / Release / Sample UI test / Sample build / iOS 16 build はすべて成功している。

重要度別件数: **Critical 0 / Major 0 / Minor 0 / Suggestion 0**

## 前回指摘の追跡

| 出典 | 状態 | 確認結果 |
|---|---|---|
| `review-004.md` #1 性能受け入れ | **解消** | iPhone 15 代替がオーナー判断として記録され、3 試行の hitch 値、1〜5 往復後のメモリ、計測条件、サニタイズ結果が evidence に保存された |
| `review-004.md` interactive control Scenario | **解消維持** | 実座標 tap の XCUITest が成功し、Button action 1 回・item tap 0 回の検証と関連コード経路に後退なし |

降格済み指摘は再評価対象としていない。

## オーナー判断と性能 evidence の評価

### iPhone 15 代替

`kasane/changes/ios-engine-foundation/deviation.md:10` は、性能検証の基準機を iPhone 11 から接続可能な iPhone 15 へ変更したことを、オーナー承認済みの代替として記録している。同時に、iPhone 15 は基準機より高速で、この結果だけでは iPhone 11 相当の性能保証にならないことも明示している。

`evidence/performance-early-measurement.md:5` にも同じ制約が記録されており、成果物間の説明は一致する。本レビューでは合意済み deviation として扱い、iPhone 11 未使用を違反とは判定しない。

### hitch とメモリ

- Sample の Release app、10,000 件、固定 2 列、7 件ごとの長文による可変行高混在という fixture が記録されている。
- Animation Hitches の 3 試行はすべて `0.0 ms/s` で、各試行 5 ms/s 未満という合格条件を満たす。各 20 秒の収録窓で hitch event が 0 件だったことから、包含される 3 秒連続フリック区間も 0.0 ms/s とした算出説明がある。
- `TASK_VM_INFO.phys_footprint` は 1 往復後 35,373,904 bytes、2 往復後 27,640,656 bytes で増加していない。3〜5 往復後も 23,266,128 → 21,873,488 → 21,857,104 bytes と減少しており、再利用プール分を超えて増え続けないという定常化条件を満たす。
- `scripts/log-sanitize.py --summary` の再確認は置換対象なしで、local-path lint と identity lint も成功した。evidence には個体識別子、開発者識別子、ローカル絶対パス、生 trace が保存されていない。

`tasks.md:49`〜`:51` の 8.1〜8.3 はすべて完了済みである。8.1 の行内には元の基準機 iPhone 11 が残るが、適用条件を変更する `deviation.md` と実測 evidence が明示的に対応しているため、未申告の不一致ではない。

## Development Team 設定と identity

`samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj` を `DEVELOPMENT_TEAM` で検索した結果は 0 件であり、Debug / Release 構成に Development Team の固定値は残っていない。`python3 scripts/identity-lint.py` および対象ファイル限定の再実行も成功した。

## Findings

### 🔴 Major

なし。

### 🟡 Minor

なし。

### 🔵 Suggestion

なし。

## 実行したコマンドと結果

個体識別子を成果物へ残さないため、Simulator は名前と OS のみ記載する。

| コマンド | 結果 |
|---|---|
| `xcrun simctl list devices available` | 成功。iPhone 17 Pro / iOS 26.0.1 を利用可能と確認 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' -configuration Debug -quiet` | destination の OS 指定が実在する 26.0.1 と一致せず exit 70。実装・テスト失敗ではないため、下記の正しい OS で再実行 |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug` (`ios/`) | 成功。33 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild test -scheme KsCollectionView -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Release ENABLE_TESTABILITY=YES` (`ios/`) | 成功。34 tests、0 failures、`TEST SUCCEEDED` |
| `xcodebuild test -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug` (`samples/ios/`) | 成功。3 tests、0 failures。interactive control の実座標 tap、性能用フリック、メモリ往復テストを実行 |
| `xcrun xcresulttool get test-results summary --path <Sample xcresult>` | 成功。total 3、passed 3、failed 0、skipped 0 を確認 |
| `xcodebuild build -project KsCollectionViewSamples.xcodeproj -scheme KsCollectionViewSamples -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0.1' -configuration Debug CODE_SIGNING_ALLOWED=NO -quiet` (`samples/ios/`) | 成功、exit 0 |
| `xcodebuild build -scheme KsCollectionView -destination 'generic/platform=iOS Simulator' -configuration Debug IPHONEOS_DEPLOYMENT_TARGET=16.0 CODE_SIGNING_ALLOWED=NO -quiet` (`ios/`) | 成功、exit 0 |
| `python3 scripts/comment-policy-lint.py` | 成功。検査対象 58 ファイル、禁止 0 件 |
| `python3 scripts/local-path-lint.py` | 成功 |
| `python3 scripts/identity-lint.py` | 成功 |
| `python3 scripts/log-sanitize.py --summary kasane/changes/ios-engine-foundation/evidence/performance-early-measurement.md` | 成功。置換対象なし |
| `rg -n 'DEVELOPMENT_TEAM' samples/ios/KsCollectionViewSamples.xcodeproj/project.pbxproj` | 該当 0 件 |
| `python3 scripts/doc-structure-lint.py` | 失敗。差分外の既存 7 ファイルに 25 件。今回変更された handbook / roadmap artifact および change 成果物には該当なしのため、本 change の finding には含めない |

## 最終判定

合意済み deviation を含む現行仕様、実装、テスト、実機性能 evidence、完了タスクの間に承認を妨げる不一致はない。**APPROVED** とする。
