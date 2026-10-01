import Foundation

// 並べ替えのドラッグのセッションに付ける、持ち上げた一覧の目印。同じアプリの別の一覧から来た
// セッションを受けないために、目印が自分のものかをオブジェクトの同一性で見分ける。
internal final class KsReorderDragContext: NSObject {}
