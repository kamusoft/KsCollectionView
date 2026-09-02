struct DemoItem: Equatable, Identifiable {
    let id: Int
    let title: String
    let detail: String?

    init(id: Int, title: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.detail = detail
    }
}
