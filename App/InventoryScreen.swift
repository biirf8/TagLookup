import SwiftUI

struct InventoryScreen: View {
    @EnvironmentObject var model: AppModel
    @State private var filter = ""

    private var filtered: [OwnedItem] {
        model.items.filter { filter.isEmpty || $0.itemID.localizedCaseInsensitiveContains(filter) || $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        Page {
            Text("Your inventory.").font(.largeTitle.bold())
            Text("Owned items returned for your connected account, including cosmetics. Equipped cosmetics are not reported by this endpoint.")
                .foregroundStyle(.secondary)
            Card {
                if let player = model.account {
                    Label(player.displayName, systemImage: "person.crop.circle").font(.headline)
                    Text(player.id).font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                }
                ActionButton(title: model.isLoadingItems ? "Loading" : "Refresh my items",
                             symbol: "arrow.clockwise", busy: model.isLoadingItems) {
                    Task { await model.loadItems() }
                }.disabled(!model.connected)
                if !model.connected {
                    Button("Connect in Session") { model.tab = 3 }
                }
                if let date = model.inventoryDate {
                    Text("Last fetched \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let message = model.inventoryMessage { Notice(message: message, symbol: "exclamationmark.circle") }
            if model.inventoryDate != nil {
                TextField("Filter item names or IDs", text: $filter)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                Text("\(filtered.count) item types").font(.caption).foregroundStyle(.secondary)
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { item in
                        Card {
                            HStack(alignment: .top) {
                                Image(systemName: "tshirt.fill").foregroundStyle(Theme.accent)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(item.name).font(.headline)
                                    Text(item.itemID).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                    if let itemClass = item.itemClass, !itemClass.isEmpty {
                                        Text(itemClass).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 0)
                                if item.quantity > 1 { Text("×\(item.quantity)").font(.caption.bold()) }
                            }
                        }
                    }
                }
                if filtered.isEmpty {
                    Notice(message: model.items.isEmpty ? "No inventory items were returned for this account." : "No items match your filter.")
                }
            } else if !model.isLoadingItems {
                EmptyCard(symbol: "shippingbox", title: "Ready when you are",
                          detail: "Connect a session and refresh. Other players' inventories are excluded.")
            }
        }
        .navigationTitle("My items")
        .navigationBarTitleDisplayMode(.inline)
    }
}
