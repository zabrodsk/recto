import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: AppTab = .notes
    @State private var notesPath: [Route] = []
    @State private var tasksPath: [Route] = []
    var body: some View {
        let tabBarVisible = isTabBarVisible
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .tasks:
                    NavigationStack(path: $tasksPath) {
                        TaskCenterView(path: $tasksPath)
                            .navigationDestination(for: Route.self) { routeDestination($0) }
                    }
                case .notes:
                    NavigationStack(path: $notesPath) {
                        AllNotesView(tab: $tab, path: $notesPath)
                            .navigationDestination(for: Route.self) { routeDestination($0) }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if tabBarVisible {
                FloatingTabBar(selection: $tab)
                    .padding(.horizontal, 56)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(RectoTheme.canvas.ignoresSafeArea())
        .preferredColorScheme(store.preferredScheme)
        .animation(.easeInOut(duration: 0.22), value: tabBarVisible)
    }

    private var isTabBarVisible: Bool {
        let path = tab == .tasks ? tasksPath : notesPath
        if case .note = path.last { return false }
        return true
    }

    @ViewBuilder
    private func routeDestination(_ route: Route) -> some View {
        switch route {
        case .folder(let id):
            FolderNotesView(folderId: id, path: tab == .tasks ? $tasksPath : $notesPath)
        case .note(let id):
            NoteEditorView(noteId: id)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 6) {
            tabButton(.tasks, title: "Task Center", symbol: "checklist")
            tabButton(.notes, title: "All Notes", symbol: "doc.text")
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, y: 8)
    }

    private func tabButton(_ tab: AppTab, title: String, symbol: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                if selected {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .padding(.horizontal, selected ? 16 : 14)
            .padding(.vertical, 11)
            .background(
                Capsule(style: .continuous)
                    .fill(selected ? RectoTheme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    RootView()
        .environment(AppStore.load())
}

