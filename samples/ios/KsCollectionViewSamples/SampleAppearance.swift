import Foundation
import UIKit

/// ルートメニューで選ぶアプリ全体の外観。
///
/// 見出し・項目の文言・選択中の読み上げ文言・初期値・保存のキーはここ 1 箇所に置き、
/// Android Sample の `SampleAppearance.kt` と同じ値にそろえる。
enum SampleAppearance: String, CaseIterable, Identifiable {
    /// 端末の表示モードに従う。
    case system
    /// 端末の表示モードに関わらずライト。
    case light
    /// 端末の表示モードに関わらずダーク。
    case dark

    var id: Self { self }

    /// ルートメニューに出す項目名。
    var title: String {
        switch self {
        case .system: "システム"
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }

    /// window に上書きする外観。`.unspecified` は上書きなし (端末の表示モードがそのまま効く)。
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// ルートメニューで外観の項目群につける見出し。
    static let sectionTitle = "外観"

    /// 選択中の項目で、項目名とあわせて読み上げる文言。
    static let selectedAccessibilityValue = "選択中"

    /// 選んだ値が保存されていないとき (初回起動) の選択。
    static let initial = SampleAppearance.system

    /// 選択の保存に使う `UserDefaults` のキー。
    static let storageKey = "appearance"

    /// 保存した選択を消す起動引数。UI テストが保存の無い状態から始め、選んだ外観を
    /// 後の起動に持ち越さないために使う。
    static let resetArgument = "--reset-appearance"

    /// 起動引数で求められたときだけ、保存した選択を消す。
    static func resetIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains(resetArgument) else { return }
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
