import SubusCore
import SwiftUI

struct CategoriesTab: View {
    let model: AppModel
    @State private var error: String?

    var body: some View {
        NamedColorList(
            items: model.library.categories.map { NamedColorItem(id: $0.id, name: $0.name, color: $0.color) },
            addTitle: String(localized: "New category"),
            usage: { id in model.library.subscriptions.filter { $0.categoryID == id }.count },
            deleteMessage: { String(localized: "\($0) subscriptions will lose this category") },
            error: error,
            onRename: { id, name in edit { l in
                if let i = l.categories.firstIndex(where: { $0.id == id }) { l.categories[i].name = name }
            } },
            onRecolor: { id, color in _ = edit { l in
                if let i = l.categories.firstIndex(where: { $0.id == id }) { l.categories[i].setColor(color) }
            } },
            onDelete: { id in _ = edit { $0.removeCategory(id) } },
            addSheet: AnyView(NewCategorySheet(model: model) { _ in }))
    }

    private func edit(_ change: (inout Library) -> Void) -> Bool {
        error = model.editLibrary(change)
        return error == nil
    }
}
