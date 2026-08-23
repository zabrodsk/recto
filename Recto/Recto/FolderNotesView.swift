import SwiftUI

struct FolderNotesView: View {
    @Environment(AppStore.self) private var store
    var folderId: UUID
    @Binding var path: [Route]

    var folder: Folder? { store.folder(id: folderId) }

    var body: some View {
        let notes = store.notes(in: folderId)
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: folder?.role == .trash ? "Deleted" : "Notes")
                if notes.isEmpty {
                    Text(emptyCopy)
                        .font(.system(size: 15))
                        .foregroundStyle(RectoTheme.secondaryLabel)
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                } else {
                    CardGroup {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                            Button {
                                path.append(.note(note.id))
                            } label: {
                                NoteListRow(note: note)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if folder?.role == .trash {
                                    Button("Restore") { store.restoreNote(note.id) }
                                } else {
                                    Button(note.pinned ? "Unpin" : "Pin") { store.togglePinned(noteId: note.id) }
                                    Button("Delete", role: .destructive) { store.deleteNote(note.id) }
                                }
                            }
                            if index < notes.count - 1 {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                }
                Spacer(minLength: 140)
            }
            .padding(.top, 8)
        }
        .background(RectoTheme.canvas.ignoresSafeArea())
        .navigationTitle(folder?.name ?? "Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if folder?.role != .trash && folder?.role != .taskCenter {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let created = store.createNote(in: folderId)
                        path.append(.note(created.id))
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 76)
        }
    }

    private var emptyCopy: String {
        switch folder?.role {
        case .trash: return "Recently deleted notes will appear here."
        case .archive: return "Archive notes you want out of the way."
        default: return "No notes in this folder yet."
        }
    }
}
