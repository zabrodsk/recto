import SwiftUI

struct AllNotesView: View {
    @Environment(AppStore.self) private var store
    @Binding var tab: AppTab
    @Binding var path: [Route]
    @State private var showNewFolder = false
    @State private var showRenameFolder = false
    @State private var renamingFolderId: UUID?
    @State private var folderName = ""
    @State private var showSettings = false
    @State private var showSearch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                section("Tasks") {
                    Button {
                        tab = .tasks
                    } label: {
                        FolderRow(folder: store.folder(role: .taskCenter))
                    }
                    .buttonStyle(.plain)
                }

                section("Smart Folders") {
                    row(store.folder(role: .allNotes)) {
                        path.append(.folder(store.folder(role: .allNotes).id))
                    }
                }

                section("Folders") {
                    ForEach(store.userFolders) { folder in
                        row(folder) { path.append(.folder(folder.id)) }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") {
                                    folderName = folder.name
                                    renamingFolderId = folder.id
                                    showRenameFolder = true
                                }
                                Button("New note", systemImage: "square.and.pencil") {
                                    let created = store.createNote(in: folder.id)
                                    path.append(.folder(folder.id))
                                    path.append(.note(created.id))
                                }
                            }
                        if folder.id != store.userFolders.last?.id {
                            Divider().padding(.leading, 58)
                        }
                    }
                }

                section("Archive") {
                    row(store.folder(role: .archive)) {
                        path.append(.folder(store.folder(role: .archive).id))
                    }
                    Divider().padding(.leading, 58)
                    row(store.folder(role: .trash)) {
                        path.append(.folder(store.folder(role: .trash).id))
                    }
                }

                HStack {
                    Text(store.folderCountLabel)
                    Text("·")
                    Text(store.noteCountLabel)
                }
                .font(.system(size: 13))
                .foregroundStyle(RectoTheme.secondaryLabel)
                .padding(.horizontal, 22)
                .padding(.top, 18)

                Spacer(minLength: 140)
            }
            .padding(.top, 4)
        }
        .background(RectoTheme.canvas.ignoresSafeArea())
        .navigationTitle("Recto")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    Button {
                        showNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("New Folder", isPresented: $showNewFolder) {
            TextField("Folder name", text: $folderName)
            Button("Create") {
                let created = store.createFolder(named: folderName.isEmpty ? "Untitled" : folderName)
                path.append(.folder(created.id))
                folderName = ""
            }
            Button("Cancel", role: .cancel) { folderName = "" }
        }
        .alert("Rename Folder", isPresented: $showRenameFolder) {
            TextField("Folder name", text: $folderName)
            Button("Save") {
                if let id = renamingFolderId {
                    store.renameFolder(id: id, to: folderName)
                }
                renamingFolderId = nil
                folderName = ""
            }
            Button("Cancel", role: .cancel) {
                renamingFolderId = nil
                folderName = ""
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showSearch) {
            SearchView { route in
                showSearch = false
                path.append(route)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 76)
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: title)
            CardGroup { content() }
        }
    }

    private func row(_ folder: Folder, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            FolderRow(folder: folder)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Button("System") { store.preferredScheme = nil; store.persist(immediately: true) }
                    Button("Light") { store.preferredScheme = .light; store.persist(immediately: true) }
                    Button("Dark") { store.preferredScheme = .dark; store.persist(immediately: true) }
                }
                Section("About") {
                    Text("Recto is free. Notes, tasks, dates, and PDF export are all included — no caps, no subscription.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("Your data stays on this device. Nothing is uploaded, no analytics, no one is watching.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
