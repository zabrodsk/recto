import SwiftUI

struct PdfExportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var note: Note
    @State private var options = PDFExportOptions()
    @State private var exportURL: URL?
    @State private var footerDraft = ""

    var folderName: String {
        store.folder(id: note.folderId)?.name ?? "Recto"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    previewCard
                    optionsList
                }
                .padding(16)
            }
            .background(RectoTheme.canvas.ignoresSafeArea())
            .navigationTitle("Export as PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Text("Export")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .onAppear { regenerate() }
            .onChange(of: options) { _, _ in regenerate() }
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Made with Recto")
                    .font(.system(size: 11))
                    .foregroundStyle(RectoTheme.secondaryLabel)
                Spacer()
                Text("Preview")
                    .font(.system(size: 11))
                    .foregroundStyle(RectoTheme.secondaryLabel)
            }
            Text(note.title)
                .font(.system(size: 20, weight: .bold))
            ForEach(Array(note.blocks.prefix(6))) { block in
                switch block.kind {
                case .heading1, .heading2:
                    Text(block.text).font(.system(size: 14, weight: .semibold))
                case .paragraph:
                    Text(block.text).font(.system(size: 12)).lineLimit(3)
                case .checklist:
                    ForEach(block.items.prefix(4)) { item in
                        HStack(spacing: 8) {
                            RectoCheckbox(isDone: item.isDone, compact: true, action: {})
                                .disabled(true)
                            Text(item.text)
                                .font(.system(size: 12))
                                .strikethrough(item.isDone)
                                .foregroundStyle(item.isDone ? RectoTheme.doneText : Color.primary)
                        }
                    }
                default:
                    EmptyView()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
        .environment(\.colorScheme, .light)
    }

    private var optionsList: some View {
        VStack(spacing: 0) {
            toggle("Include cover page", $options.includeCover)
            Divider()
            toggle("Include table of contents", $options.includeTOC)
            Divider()
            toggle("Two-column layout", $options.twoColumn)
            Divider()
            toggle("Include emoji", $options.includeEmoji)
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("Footer text")
                    .font(.system(size: 16))
                TextField("Not set — appears on every exported PDF", text: $footerDraft)
                    .font(.system(size: 13))
                    .onChange(of: footerDraft) { _, value in
                        options.footerText = value
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(RectoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func toggle(_ title: String, _ value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func regenerate() {
        let data = NotePDFRenderer.render(note: note, folderName: folderName, options: options)
        let safeName = note.title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).pdf")
        try? data.write(to: url, options: .atomic)
        exportURL = url
    }
}
