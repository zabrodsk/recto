import SwiftUI

struct NoteEditorView: View {
    @Environment(AppStore.self) private var store
    var noteId: UUID
    @State private var showExport = false
    @State private var itemForDate: ChecklistItem?
    @State private var dateDraft = Date()

    var note: Note? { store.note(id: noteId) }

    var body: some View {
        Group {
            if let note {
                editor(note)
            } else {
                Text("This note is gone.")
                    .foregroundStyle(.secondary)
            }
        }
        .background(RectoTheme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let note {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(note.accent.color)
                            .frame(width: 16, height: 16)
                        Text(note.title)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(note?.pinned == true ? "Unpin" : "Pin", systemImage: note?.pinned == true ? "pin.slash" : "pin") {
                        store.togglePinned(noteId: noteId)
                    }
                    Button("Export as PDF", systemImage: "square.and.arrow.up") {
                        showExport = true
                    }
                    if !store.userFolders.isEmpty {
                        Menu("Move to") {
                            ForEach(store.userFolders) { folder in
                                Button(folder.name) {
                                    store.moveNote(noteId, to: folder.id)
                                }
                            }
                            Button("Archive") {
                                store.moveNote(noteId, to: store.folder(role: .archive).id)
                            }
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        store.deleteNote(noteId)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showExport) {
            if let note {
                PdfExportView(note: note)
            }
        }
        .sheet(item: $itemForDate) { item in
            NavigationStack {
                DatePicker("Due date", selection: $dateDraft, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Date")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Clear") {
                                store.setItemDueDate(noteId: noteId, itemId: item.id, dueDate: nil)
                                itemForDate = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Set") {
                                store.setItemDueDate(noteId: noteId, itemId: item.id, dueDate: dateDraft)
                                itemForDate = nil
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            addBar
        }
    }

    private func editor(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(note.emoji)
                    .font(.system(size: 44))
                    .padding(.top, 8)

                TextField("Title", text: titleBinding(note))
                    .font(.system(size: 32, weight: .bold))

                ForEach(note.blocks) { block in
                    blockView(note: note, block: block)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private func blockView(note: Note, block: NoteBlock) -> some View {
        switch block.kind {
        case .heading1:
            TextField("Heading", text: blockBinding(note, block), axis: .vertical)
                .font(.system(size: 22, weight: .bold))
        case .heading2:
            TextField("Heading", text: blockBinding(note, block), axis: .vertical)
                .font(.system(size: 18, weight: .bold))
        case .paragraph:
            TextField("Write…", text: blockBinding(note, block), axis: .vertical)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
        case .checklist:
            VStack(alignment: .leading, spacing: 2) {
                ForEach(block.items) { item in
                    checklistRow(note: note, block: block, item: item)
                }
                Button {
                    store.addChecklistItem(noteId: note.id, blockId: block.id)
                } label: {
                    Label("Add task", systemImage: "plus")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(RectoTheme.accent)
                }
                .padding(.leading, 44)
                .padding(.top, 4)
            }
        case .linkPreview:
            if let preview = block.preview {
                LinkPreviewCard(preview: preview)
            }
        }
    }

    private func checklistRow(note: Note, block: NoteBlock, item: ChecklistItem) -> some View {
        HStack(alignment: .center, spacing: 2) {
            RectoCheckbox(isDone: item.isDone) {
                store.toggleItem(noteId: note.id, itemId: item.id)
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField("Task", text: itemTextBinding(note, item), axis: .vertical)
                    .font(.system(size: 17))
                    .strikethrough(item.isDone, color: RectoTheme.doneText)
                    .foregroundStyle(item.isDone ? RectoTheme.doneText : Color.primary)
                    .submitLabel(.next)
                    .onSubmit {
                        store.addChecklistItem(noteId: note.id, blockId: block.id)
                    }

                HStack(spacing: 10) {
                    if let date = item.dueDate {
                        Button {
                            dateDraft = date
                            itemForDate = item
                        } label: {
                            DateBadge(date: date, dimmed: item.isDone)
                        }
                        .buttonStyle(.plain)
                    } else if !item.isDone {
                        Button {
                            dateDraft = Date()
                            itemForDate = item
                        } label: {
                            Label("@date", systemImage: "calendar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RectoTheme.dateText)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 6)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button(item.isDone ? "Mark as open" : "Mark as done") {
                store.toggleItem(noteId: note.id, itemId: item.id)
            }
            Button("Set date") {
                dateDraft = item.dueDate ?? Date()
                itemForDate = item
            }
            Button("Delete task", role: .destructive) {
                store.deleteItem(noteId: note.id, itemId: item.id)
            }
        }
    }

    private var addBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tip: type @today, @tomorrow or @fri on a task")
                .font(.system(size: 12))
                .foregroundStyle(RectoTheme.secondaryLabel)
            HStack(spacing: 18) {
                addButton("Title", "textformat.size.larger") { store.addBlock(noteId: noteId, kind: .heading1) }
                addButton("Text", "text.alignleft") { store.addBlock(noteId: noteId, kind: .paragraph) }
                addButton("Task", "checklist") { store.addBlock(noteId: noteId, kind: .checklist) }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func addButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
        }
    }

    private func titleBinding(_ note: Note) -> Binding<String> {
        Binding(
            get: { store.note(id: note.id)?.title ?? note.title },
            set: { store.updateNoteTitle(noteId: note.id, title: $0) }
        )
    }

    private func blockBinding(_ note: Note, _ block: NoteBlock) -> Binding<String> {
        Binding(
            get: {
                store.note(id: note.id)?.blocks.first(where: { $0.id == block.id })?.text ?? block.text
            },
            set: { store.updateBlockText(noteId: note.id, blockId: block.id, text: $0) }
        )
    }

    private func itemTextBinding(_ note: Note, _ item: ChecklistItem) -> Binding<String> {
        Binding(
            get: {
                store.note(id: note.id)?
                    .blocks.flatMap(\.items)
                    .first(where: { $0.id == item.id })?.text ?? item.text
            },
            set: { store.updateItemText(noteId: note.id, itemId: item.id, text: $0) }
        )
    }
}
