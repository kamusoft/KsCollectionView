# 利用者役の手元の確認 (tasks 3.4)

実行した日: 2026-10-15 / 環境: Xcode 27.0 (Simulator は作らず、起動もしていない) / 実行した人: tasks 3 の実装のワーカー (結果は実装の報告から写した)

| 確認 | コマンド | 所要 | 結果 |
|---|---|---|---|
| iOS local | `python3 scripts/ci/verify-consumer-ios.py --mode local` | 31 秒 | 終了コード 0。Simulator 向けと実機向けがどちらも BUILD SUCCEEDED |
| Android local | `python3 scripts/ci/verify-consumer-android.py --mode local` | 11 秒 | 終了コード 0。`jp.kamusoft:kscollectionview:0.1.0-SNAPSHOT` を確認。利用者の `~/.m2/repository/jp/kamusoft` に kscollectionview は作られない |
| 写しの準備 | `python3 scripts/distribution/sync-spm-snapshot.py <作業用>/artifact-ios/KsCollectionView-SPM` | 1 秒未満 | Sources 93・Tests 45 ファイル |
| 発行物の準備 | `android/` で `./gradlew -Dmaven.repo.local=<作業用>/artifact-android/maven -Pversion=0.1.0-beta.1 :kscollectionview:publishToMavenLocal` | 2 秒 | aar・pom・module・sources・javadoc |
| iOS artifact | `python3 scripts/ci/verify-consumer-ios.py --mode artifact --snapshot <作業用>/artifact-ios/KsCollectionView-SPM` | 26 秒 | 終了コード 0。2 つのビルドがどちらも成功。写しは作っていない |
| Android artifact | `python3 scripts/ci/verify-consumer-android.py --mode artifact --repository <作業用>/artifact-android/maven --version 0.1.0-beta.1` | 2 秒 (コード縮小は前の組み立てのまま) → ビルドの出力を消して流し直すと 18 秒 (コード縮小を実行) | どちらも終了コード 0。発行はしていない。`kscollectionview:0.1.0-beta.1` を確認 |
| Android artifact (無い版) | 上と同じリポジトリで `--version 9.9.9` | 数秒 | 期待どおり終了コード 1 (`Could not find jp.kamusoft:kscollectionview:9.9.9`) |

確認の後、git が追跡しているファイルは実装の編集のほかに変わっていない。`<作業用>` はセッションの一時の置き場で、今は残っていない。
