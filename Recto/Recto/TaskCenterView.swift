import SwiftUI

struct TaskCenterView: View {
    @Environment(AppStore.self) private var store
    @Binding var path: [Route]
    @State private var showAppearance = false

    var body: some View {
        List {
            ForEach(store.aggregatedTasks(), id: \.0) { group, tasks in
                Section {
                    ForEach(tasks) { task in
                        TaskRow(task: task) {
                            store.toggleItem(noteId: task.note.id, itemId: task.item.id)
                        } open: {
                            path.append(.note(task.note.id))
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                        .listRowBackground(RectoTheme.card)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                store.toggleItem(noteId: task.note.id, itemId: task.item.id)
                            } label: {
                                Label(task.item.isDone ? "Reopen" : "Done", systemImage: "checkmark.square")
                            }
                            .tint(RectoTheme.accent)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                store.deleteItem(noteId: task.note.id, itemId: task.item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(group.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RectoTheme.secondaryLabel)
                        .textCase(nil)
                }
            }

            if store.aggregatedTasks().isEmpty {
                Section {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(RectoTheme.canvas.ignoresSafeArea())
        .navigationTitle("Task Center")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        store.hideCompletedTasks.toggle()
                        store.persist(immediately: true)
                    } label: {
                        Image(systemName: store.hideCompletedTasks ? "eye.slash" : "eye")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Toggle completed tasks")

                    Button {
                        showAppearance = true
                    } label: {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Appearance")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .confirmationDialog("Appearance", isPresented: $showAppearance, titleVisibility: .visible) {
            Button("System") { store.preferredScheme = nil; store.persist(immediately: true) }
            Button("Light") { store.preferredScheme = .light; store.persist(immediately: true) }
            Button("Dark") { store.preferredScheme = .dark; store.persist(immediately: true) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 76)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 28))
                .foregroundStyle(RectoTheme.accent)
            Text("Nothing to do — yet")
                .font(.system(size: 17, weight: .semibold))
            Text("Add a checkbox in any note. Type @tomorrow and it lands here automatically.")
                .font(.system(size: 14))
                .foregroundStyle(RectoTheme.secondaryLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
}

struct TaskRow: View {
    var task: AggregatedTask
    var toggle: () -> Void
    var open: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            RectoCheckbox(isDone: task.item.isDone, action: toggle)

            Button(action: open) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.item.text)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(task.item.isDone ? RectoTheme.doneText : Color.primary)
                        .strikethrough(task.item.isDone, color: RectoTheme.doneText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if let date = task.item.dueDate {
                            DateBadge(date: date, dimmed: task.item.isDone)
                        }
                        ProjectChip(
                            title: task.note.title,
                            symbol: task.note.symbol,
                            accent: task.item.isDone ? RectoTheme.doneText : task.note.accent.color
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
    }
}
