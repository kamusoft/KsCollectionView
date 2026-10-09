# Deviation: package-distribution

- Android の発行物 (依存の範囲): spec では「公開 API の宣言に現れる型を持つ依存」を compile の範囲で宣言する → 指示により、`Color` を持つ `ui-graphics` と `Dp` を持つ `ui-unit` は直接は宣言せず、compile の範囲で宣言している Compose UI (`ui`) が届ける形のままにする。`@DrawableRes` を持つ `androidx.annotation` は、版 1.9.1 で直接宣言する。理由: 兄弟ライブラリ KsSettingsView と宣言の形を揃える。3 つとも利用者の compile のクラスパスに届くことは実測で確かめてある (2026-10-09)
