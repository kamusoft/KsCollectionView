import SwiftUI

extension KsCollectionView {
    /// 一覧にページング (無限スクロール) を付けます。
    ///
    /// 一覧は、画面に出ているいちばん後ろの項目より後に残っている項目の数が
    /// 「`threshold` × 画面に出ている項目の数 (端数は切り上げ)」以下になったときに、`onLoadMore` を呼んで
    /// 次のページを頼みます。項目が 1 件も無いときは、しきい値によらず最初のページを頼みます。
    /// 数えるのは項目だけで、グループの見出しやヘッダー / フッターは数えません。
    ///
    /// 頼むのは `state` が ``KsPagingState/idle`` のときだけです。一度頼んだら、`onLoadMore` が終わり、
    /// かつ `state` か配列が変わるまで、次を頼みません。`state` は一覧が書き換えることはないため、
    /// 読み込みの進み具合に合わせて呼び出し側で書き換えてください。`onLoadMore` から戻る前に
    /// `state` を ``KsPagingState/appending`` にしておくと、その間の Pull to Refresh も受け付けません。
    ///
    /// ```swift
    /// KsCollectionView(model.items) { item in
    ///     Row(item: item)
    /// }
    /// .paging(model.pagingState) {
    ///     await model.loadNextPage()
    /// }
    /// .refreshable {
    ///     await model.reload()
    /// }
    /// ```
    ///
    /// `onLoadMore` は一覧の表示の中で実行され、一覧が画面から取り除かれると取り消されます。
    /// 画面を閉じても続けたい読み込みは、呼び出し側のモデルの中で始めてください。
    ///
    /// 状態が ``KsPagingState/appending`` の間は一覧の見えている範囲の下端に、項目が 1 件も無い間は一覧の
    /// 真ん中に、標準の読み込み中の表示が出ます。失敗・終端・空の表示は、既定では何も出ません。
    /// 表示は ``pagingAppendingIndicator(_:)`` などで差し替えられます。標準の読み込み中の表示の色は
    /// ``loadingIndicatorColor(_:)`` で指定できます。
    ///
    /// 取り直しの結果は、コンテンツの先頭から表示します。
    ///
    /// - Pull to Refresh (`.refreshable`) で始めた取り直しでは、処理を呼んでからインジケータが消えるまでの間に
    ///   配列を差し替えると、取得の速さや状態の書き換え方によらず、差し替えと同時に先頭を表示します。
    ///   取り直しても配列が同値のままの場合は、インジケータが消えるときに先頭を表示します
    /// - 引っ張らずに自分で始めた取り直し (再読み込みのボタンなど) では、状態が ``KsPagingState/refreshing``
    ///   になったことが一覧に届いた後の差し替えで、先頭を表示します。取得がすぐ終わり、状態を
    ///   ``KsPagingState/refreshing`` にする書き換えと配列の差し替えが同じ画面の更新にまとまると、一覧からは
    ///   取り直しだと分からず先頭へ送られません。状態を ``KsPagingState/refreshing`` にした画面の更新が済んでから
    ///   配列を差し替えるか、差し替えと一緒に ``KsScrollController/scrollToStart(animated:)`` で先頭へ送ってください
    ///
    /// また、状態が ``KsPagingState/endReached`` になるまでは、末尾を表示しているときに末尾へ項目を足しても、
    /// 表示範囲は末尾へ動きません。
    ///
    /// - Parameters:
    ///   - state: ページングの状態
    ///   - threshold: 何画面分手前で次のページを頼むかを表す画面数。0 は最後の項目が画面に入ったときに
    ///     頼みます。負の数と有限でない数は誤りで、デバッグビルドでは停止して知らせ、リリースビルドでは
    ///     警告を記録して 0 として扱います
    ///   - onLoadMore: 次のページを読み込む処理
    public func paging(
        _ state: KsPagingState,
        threshold: Double = 1,
        onLoadMore: @escaping @MainActor () async -> Void
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.paging = KsPaging(state: state, threshold: threshold, onLoadMore: onLoadMore)
        return copy
    }

    /// 次のページの読み込み中 (項目があり、状態が ``KsPagingState/appending``) に出す表示を差し替えます。
    ///
    /// この表示は一覧の見えている範囲の下端 (画面下端の安全領域の上) の中央に止めて重ね、
    /// 項目はその裏を流れます。状態が ``KsPagingState/appending`` の間だけ出て、短いフェードで出入りします。
    ///
    /// 差し替えない場合は、標準の読み込み中の表示がそのまま (下地なしで) 出ます。その色は
    /// ``loadingIndicatorColor(_:)`` で指定でき、差し替えた表示には効きません。既定の表示はタッチを
    /// 受けず、下の項目を押せます。差し替えた表示はそのまま置き、その表示の範囲だけタッチを
    /// 受けます。差し替えた表示の範囲から始めたドラッグでも、一覧はスクロールします。
    /// 何も出したくない場合は `EmptyView()` を返してください。
    /// ``paging(_:threshold:onLoadMore:)`` を付けていない一覧では使われません。
    public func pagingAppendingIndicator<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.appendingIndicator = { AnyView(content()) }
        return copy
    }

    /// 次のページの読み込みに失敗したとき (項目があり、状態が ``KsPagingState/failed``) に最後の項目の後ろへ
    /// 出す表示を設定します。
    ///
    /// クロージャには、次のページを頼み直す再試行の操作が渡されます。設定しない場合は何も出ません。
    public func pagingFailedFooter<Content: View>(
        @ViewBuilder _ content: @escaping (_ retry: @escaping @MainActor () -> Void) -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.failedFooter = { AnyView(content($0)) }
        return copy
    }

    /// 最後のページまで読み込んだとき (項目があり、状態が ``KsPagingState/endReached``) に最後の項目の後ろへ
    /// 出す表示を設定します。設定しない場合は何も出ません。
    public func pagingEndReachedFooter<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.endReachedFooter = { AnyView(content()) }
        return copy
    }

    /// 項目が 1 件も無く、状態が ``KsPagingState/appending`` か ``KsPagingState/refreshing`` のときに、
    /// 一覧の真ん中へ出す表示を差し替えます。
    ///
    /// 差し替えない場合は、標準の読み込み中の表示が出ます。その色は ``loadingIndicatorColor(_:)`` で
    /// 指定でき、差し替えた表示には効きません。何も出したくない場合は `EmptyView()` を返してください。
    public func pagingLoadingPlaceholder<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.loadingPlaceholder = { AnyView(content()) }
        return copy
    }

    /// 項目が 1 件も無く、状態が ``KsPagingState/failed`` のときに一覧の真ん中へ出す表示を設定します。
    ///
    /// クロージャには、次のページを頼み直す再試行の操作が渡されます。Pull to Refresh を付けていても、
    /// 再試行で呼ばれるのは次のページを読み込む処理です。設定しない場合は何も出ません。
    public func pagingFailedPlaceholder<Content: View>(
        @ViewBuilder _ content: @escaping (_ retry: @escaping @MainActor () -> Void) -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.failedPlaceholder = { AnyView(content($0)) }
        return copy
    }

    /// 項目が 1 件も無く、状態が ``KsPagingState/endReached`` のときに一覧の真ん中へ出す表示を設定します。
    /// 設定しない場合は何も出ません。
    public func pagingEmptyPlaceholder<Content: View>(
        @ViewBuilder _ content: @escaping () -> Content
    ) -> KsCollectionView<Item> {
        var copy = self
        copy.configuration.pagingDisplays.emptyPlaceholder = { AnyView(content()) }
        return copy
    }
}
