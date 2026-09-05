// KsCollectionView Android — ルートプロジェクトのビルドファイル
//
// プラグインは各モジュールの build.gradle.kts が `gradle/libs.versions.toml` の
// alias 経由で宣言するため、ルートでは何も適用しない。
//
// Maven 座標のうち group と version は全モジュール共通の事項のため、ここで一括設定する
// (cross/ADR-0003)。

// カタログ由来の値は subprojects ブロックの外で解決する。ブロック内の `libs` は
// 対象サブプロジェクトの拡張として解決されるため参照できない。
val ksCollectionViewVersion =
    providers.gradleProperty("version").orNull ?: libs.versions.kscollectionview.get()

subprojects {
    group = "jp.kamusoft"
    version = ksCollectionViewVersion
}
