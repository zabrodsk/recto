import SwiftUI

struct SearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onSelect: (Route) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if !matchingNotes.isEmpty {
                    Section("Notes") {
                        ForEach(matchingNotes) { note in
                            Button {
                                onSelect(.note(note.id))
                            } label: {
                                NoteListRow(note: note)
                                    .padding(.horizontal, -16)
                            }
                        }
                    }
                }
                if !matchingTasks.isEmpty {
                    Section("Tasks") {
                        ForEach(matchingTasks) { task in
                            Button {
                                onSelect(.note(task.note.id))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.item.text)
                                    Text(task.note.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Notes and tasks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var matchingNotes: [Note] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let notes = store.activeNotes
        guard !q.isEmpty else { return notes }
        return notes.filter {
            $0.title.lowercased().contains(q) ||
            $0.snippet.lowercased().contains(q) ||
            $0.blocks.contains { $0.text.lowercased().contains(q) }
        }
    }

    private var matchingTasks: [AggregatedTask] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tasks = store.aggregatedTasks().flatMap(\.1)
        guard !q.isEmpty else { return [] }
        return tasks.filter { $0.item.text.lowercased().contains(q) }
    }
}
