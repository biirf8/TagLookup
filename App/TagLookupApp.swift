import SwiftUI

@main
@MainActor
struct TagLookupApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView().environmentObject(model)
                    .privacySensitive()
                if scenePhase != .active {
                    Theme.background.ignoresSafeArea()
                    VStack(spacing: 14) {
                        Image(systemName: "viewfinder").font(.system(size: 46, weight: .semibold))
                        Text("Tag Lookup").font(.title2.bold())
                    }.foregroundStyle(Theme.accent)
                }
            }
            .tint(Theme.accent)
            .preferredColorScheme(.dark)
            .task { await model.restoreSession() }
        }
    }
}

enum Theme {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.075)
    static let card = Color(red: 0.07, green: 0.095, blue: 0.12)
    static let accent = Color(red: 0.47, green: 0.94, blue: 0.71)
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView(selection: $model.tab) {
            NavigationStack { LookupScreen() }
                .tabItem { Label("Lookup", systemImage: "magnifyingglass") }.tag(0)
            NavigationStack { SavedScreen() }
                .tabItem { Label("Saved", systemImage: "bookmark") }.tag(1)
            NavigationStack { InventoryScreen() }
                .tabItem { Label("My items", systemImage: "tshirt") }.tag(2)
            NavigationStack { SessionScreen() }
                .tabItem { Label("Session", systemImage: "person.crop.circle") }.tag(3)
        }
    }
}

struct Page<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .frame(maxWidth: 620)
                .padding(20)
                .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }
}

struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.06), lineWidth: 1))
    }
}

struct Notice: View {
    let message: String
    var symbol = "info.circle"
    var body: some View {
        Label {
            Text(message).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActionButton: View {
    let title: String
    var symbol = "arrow.right"
    var busy = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if busy { ProgressView().tint(.black) }
                else { Image(systemName: symbol) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(.black)
        .controlSize(.large)
        .disabled(busy)
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        Card {
            Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(Theme.accent)
            Text(title).font(.title3.bold())
            Text(detail).foregroundStyle(.secondary).font(.subheadline)
        }
    }
}
