import SwiftUI

// ページングを付けた一覧のフッターの枠の中身。ページングの表示を上、利用者のフッターを下に縦に並べる。
// どちらも左右の内側余白の内側に置き、同じ幅にそろえる。ページングの表示はその幅の中で横方向の
// 中央に揃える (グリッドでも全列にまたがる)。下の内側余白は枠の最後に入れる (core/ADR-0006)。
// どちらも無いときは下の内側余白の分の高さだけになる。
internal struct KsPagingFooterStack: View {
    let paging: AnyView?
    let footer: AnyView?
    let padding: EdgeInsets

    var body: some View {
        VStack(spacing: 0) {
            if let paging {
                paging
                    .frame(maxWidth: .infinity)
                    .padding(.leading, padding.leading)
                    .padding(.trailing, padding.trailing)
            }
            if let footer {
                footer
                    .padding(.leading, padding.leading)
                    .padding(.trailing, padding.trailing)
            }
            Color.clear
                .frame(height: padding.bottom)
        }
    }
}
