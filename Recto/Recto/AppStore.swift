import Foundation
import Observation
import SwiftUI

enum FolderKind: String, Codable {
    case user
    case smart
    case system
}

enum SystemRole: String, Codable {
    case taskCenter
    case allNotes
    case archive
    case trash
}

struct Folder: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var kind: FolderKind
    var role: SystemRole?
    var symbol: String
    var createdAt: Date
}

struct ChecklistItem: Identifiable, Codable, Hashable {
    var id: UUID
    var text: String
    var isDone: Bool
    var dueDate: Date?
}

struct LinkPreview: Codable, Hashable {
    var title: String
    var subtitle: String
    var urlLabel: String
}

struct NoteBlock: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case heading1
        case heading2
        case paragraph
        case checklist
        case linkPreview
    }

    var id: UUID
    var kind: Kind
    var text: String
    var items: [ChecklistItem]
    var preview: LinkPreview?

    static func heading1(_ text: String) -> NoteBlock {
        NoteBlock(id: UUID(), kind: .heading1, text: text, items: [], preview: nil)
    }

    static func heading2(_ text: String) -> NoteBlock {
        NoteBlock(id: UUID(), kind: .heading2, text: text, items: [], preview: nil)
    }

    static func paragraph(_ text: String) -> NoteBlock {
        NoteBlock(id: UUID(), kind: .paragraph, text: text, items: [], preview: nil)
    }

    static func checklist(_ items: [ChecklistItem]) -> NoteBlock {
        NoteBlock(id: UUID(), kind: .checklist, text: "", items: items, preview: nil)
    }

    static func linkPreview(_ preview: LinkPreview) -> NoteBlock {
        NoteBlock(id: UUID(), kind: .linkPreview, text: "", items: [], preview: preview)
    }
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID
    var folderId: UUID
    var originalFolderId: UUID?
    var title: String
    var emoji: String
    var symbol: String
    var accent: NoteAccent
    var blocks: [NoteBlock]
    var updatedAt: Date
    var pinned: Bool
    var isDeleted: Bool

    var snippet: String {
        if let paragraph = blocks.first(where: { $0.kind == .paragraph && !$0.text.isEmpty }) {
            return paragraph.text
        }
        if let heading = blocks.first(where: { ($0.kind == .heading1 || $0.kind == .heading2) && !$0.text.isEmpty }) {
            return heading.text
        }
        if let item = blocks.flatMap(\.items).first {
            return item.text
        }
        return "Empty note"
    }

    var openTaskCount: Int {
        blocks.flatMap(\.items).filter { !$0.isDone }.count
    }
}

struct AggregatedTask: Identifiable, Hashable {
    var id: UUID { item.id }
    var item: ChecklistItem
    var note: Note
    var folder: Folder
}

enum TaskGroup: String, CaseIterable, Identifiable {
    case overdue
    case today
    case tomorrow
    case thisWeek
    case later
    case noDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue: return "Overdue"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .thisWeek: return "This Week"
        case .later: return "Later"
        case .noDate: return "No date"
        }
    }
}

enum AppTab: Hashable {
    case tasks
    case notes
}

enum Route: Hashable {
    case folder(UUID)
    case note(UUID)
}

@MainActor
@Observable
final class AppStore {
    static let emojis = ["🎟️", "🚲", "📦", "🗺️", "✨", "📌", "🎯", "🛠️", "📝", "💡", "🌊", "🦊"]

    var folders: [Folder] = []
    var notes: [Note] = []
    var preferredScheme: ColorScheme?
    var hideCompletedTasks = false

    private var persistTask: Task<Void, Never>?
    private let saveURL: URL = {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return folder.appendingPathComponent("recto-store.json")
    }()

    struct Snapshot: Codable {
        var folders: [Folder]
        var notes: [Note]
        var scheme: String?
        var hideCompletedTasks: Bool
    }

    static func load() -> AppStore {
        let store = AppStore()
        store.restore()
        return store
    }

    var userFolders: [Folder] {
        folders.filter { $0.kind == .user }.sorted { $0.createdAt < $1.createdAt }
    }

    var activeNotes: [Note] {
        notes.filter { !$0.isDeleted }
    }

    var folderCountLabel: String {
        let n = userFolders.count
        return "\(n) \(n == 1 ? "folder" : "folders")"
    }

    var noteCountLabel: String {
        let n = activeNotes.count
        return "\(n) \(n == 1 ? "note" : "notes")"
    }

    func folder(id: UUID) -> Folder? { folders.first { $0.id == id } }
    func note(id: UUID) -> Note? { notes.first { $0.id == id } }

    func folder(role: SystemRole) -> Folder {
        folders.first { $0.role == role }!
    }

    func notes(in folderId: UUID) -> [Note] {
        let folder = folder(id: folderId)
        let list: [Note]
        if folder?.role == .allNotes {
            list = activeNotes
        } else if folder?.role == .trash {
            list = notes.filter(\.isDeleted)
        } else if folder?.role == .archive {
            list = activeNotes.filter { $0.folderId == folderId }
        } else {
            list = activeNotes.filter { $0.folderId == folderId }
        }
        return list.sorted {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func aggregatedTasks(now: Date = Date()) -> [(TaskGroup, [AggregatedTask])] {
        let calendar = Calendar.current
        var buckets: [TaskGroup: [AggregatedTask]] = [:]
        for note in activeNotes {
            guard let folder = folder(id: note.folderId), folder.role != .archive, folder.role != .trash else { continue }
            for item in note.blocks.flatMap(\.items) {
                if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                if hideCompletedTasks, item.isDone { continue }
                let group = Self.group(for: item.dueDate, now: now, calendar: calendar)
                let task = AggregatedTask(item: item, note: note, folder: folder)
                buckets[group, default: []].append(task)
            }
        }
        return TaskGroup.allCases.compactMap { group in
            guard var items = buckets[group], !items.isEmpty else { return nil }
            items.sort { lhs, rhs in
                switch (lhs.item.isDone, rhs.item.isDone) {
                case (false, true): return true
                case (true, false): return false
                default:
                    let l = lhs.item.dueDate ?? .distantFuture
                    let r = rhs.item.dueDate ?? .distantFuture
                    return l < r
                }
            }
            return (group, items)
        }
    }

    static func group(for date: Date?, now: Date, calendar: Calendar) -> TaskGroup {
        guard let date else { return .noDate }
        let startNow = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startNow, to: startDate).day ?? 0
        if days < 0 { return .overdue }
        if days == 0 { return .today }
        if days == 1 { return .tomorrow }
        if days < 7 { return .thisWeek }
        return .later
    }

    func toggleItem(noteId: UUID, itemId: UUID) {
        mutateItem(noteId: noteId, itemId: itemId, immediately: true) { item in
            item.isDone.toggle()
        }
    }

    func updateItemText(noteId: UUID, itemId: UUID, text: String) {
        mutateItem(noteId: noteId, itemId: itemId, immediately: false) { item in
            let parsed = DateTokenParser.consume(text)
            item.text = parsed.text
            if let date = parsed.date {
                item.dueDate = date
            }
        }
    }

    func setItemDueDate(noteId: UUID, itemId: UUID, dueDate: Date?) {
        mutateItem(noteId: noteId, itemId: itemId, immediately: true) { item in
            item.dueDate = dueDate
        }
    }

    func deleteItem(noteId: UUID, itemId: UUID) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        for blockIndex in notes[noteIndex].blocks.indices {
            if let itemIndex = notes[noteIndex].blocks[blockIndex].items.firstIndex(where: { $0.id == itemId }) {
                notes[noteIndex].blocks[blockIndex].items.remove(at: itemIndex)
                notes[noteIndex].updatedAt = Date()
                persist(immediately: true)
                return
            }
        }
    }

    private func mutateItem(noteId: UUID, itemId: UUID, immediately: Bool, _ body: (inout ChecklistItem) -> Void) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        for blockIndex in notes[noteIndex].blocks.indices {
            if let itemIndex = notes[noteIndex].blocks[blockIndex].items.firstIndex(where: { $0.id == itemId }) {
                body(&notes[noteIndex].blocks[blockIndex].items[itemIndex])
                notes[noteIndex].updatedAt = Date()
                persist(immediately: immediately)
                return
            }
        }
    }

    func addChecklistItem(noteId: UUID, blockId: UUID) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard let blockIndex = notes[noteIndex].blocks.firstIndex(where: { $0.id == blockId }) else { return }
        notes[noteIndex].blocks[blockIndex].items.append(
            ChecklistItem(id: UUID(), text: "", isDone: false, dueDate: nil)
        )
        notes[noteIndex].updatedAt = Date()
        persist(immediately: true)
    }

    func updateBlockText(noteId: UUID, blockId: UUID, text: String) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        guard let blockIndex = notes[noteIndex].blocks.firstIndex(where: { $0.id == blockId }) else { return }
        notes[noteIndex].blocks[blockIndex].text = text
        notes[noteIndex].updatedAt = Date()
        persist(immediately: false)
    }

    func updateNoteTitle(noteId: UUID, title: String) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[noteIndex].title = title
        notes[noteIndex].updatedAt = Date()
        persist(immediately: false)
    }

    func renameFolder(id: UUID, to name: String) {
        guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        folders[index].name = trimmed
        persist(immediately: true)
    }

    func togglePinned(noteId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == noteId }) else { return }
        notes[index].pinned.toggle()
        notes[index].updatedAt = Date()
        persist(immediately: true)
    }

    func addBlock(noteId: UUID, kind: NoteBlock.Kind) {
        guard let noteIndex = notes.firstIndex(where: { $0.id == noteId }) else { return }
        let block: NoteBlock
        switch kind {
        case .heading1: block = .heading1("")
        case .heading2: block = .heading2("")
        case .paragraph: block = .paragraph("")
        case .checklist:
            block = .checklist([ChecklistItem(id: UUID(), text: "", isDone: false, dueDate: nil)])
        case .linkPreview:
            block = .linkPreview(LinkPreview(title: "Title", subtitle: "", urlLabel: "example.com"))
        }
        notes[noteIndex].blocks.append(block)
        notes[noteIndex].updatedAt = Date()
        persist(immediately: true)
    }

    @discardableResult
    func createFolder(named name: String) -> Folder {
        let folder = Folder(
            id: UUID(),
            name: name,
            kind: .user,
            role: nil,
            symbol: "folder",
            createdAt: Date()
        )
        folders.append(folder)
        persist(immediately: true)
        return folder
    }

    @discardableResult
    func createNote(in folderId: UUID, title: String = "Untitled") -> Note {
        let target = folder(id: folderId)
        let resolvedFolderId: UUID
        if target?.role == .allNotes || target?.role == .taskCenter {
            resolvedFolderId = userFolders.first?.id ?? folderId
        } else if target?.role == .trash || target?.role == .archive {
            resolvedFolderId = userFolders.first?.id ?? folderId
        } else {
            resolvedFolderId = folderId
        }
        let note = Note(
            id: UUID(),
            folderId: resolvedFolderId,
            originalFolderId: nil,
            title: title,
            emoji: Self.emojis.randomElement() ?? "📝",
            symbol: "note.text",
            accent: NoteAccent.allCases.randomElement() ?? .blue,
            blocks: [
                .heading1(""),
                .paragraph(""),
                .checklist([ChecklistItem(id: UUID(), text: "", isDone: false, dueDate: nil)])
            ],
            updatedAt: Date(),
            pinned: false,
            isDeleted: false
        )
        notes.insert(note, at: 0)
        persist(immediately: true)
        return note
    }

    func deleteNote(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].originalFolderId = notes[index].folderId
        notes[index].folderId = folder(role: .trash).id
        notes[index].isDeleted = true
        notes[index].updatedAt = Date()
        persist(immediately: true)
    }

    func restoreNote(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].folderId = notes[index].originalFolderId ?? userFolders.first?.id ?? notes[index].folderId
        notes[index].originalFolderId = nil
        notes[index].isDeleted = false
        notes[index].updatedAt = Date()
        persist(immediately: true)
    }

    func moveNote(_ id: UUID, to folderId: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].folderId = folderId
        notes[index].isDeleted = folder(id: folderId)?.role == .trash
        if notes[index].isDeleted {
            notes[index].originalFolderId = notes[index].originalFolderId ?? notes[index].folderId
        } else {
            notes[index].originalFolderId = nil
        }
        notes[index].updatedAt = Date()
        persist(immediately: true)
    }

    func persist(immediately: Bool = true) {
        if immediately {
            persistTask?.cancel()
            writeToDisk()
            return
        }
        persistTask?.cancel()
        persistTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.writeToDisk()
        }
    }

    func flushPersist() {
        persistTask?.cancel()
        writeToDisk()
    }

    private func writeToDisk() {
        let snapshot = Snapshot(
            folders: folders,
            notes: notes,
            scheme: preferredScheme.map { $0 == .dark ? "dark" : "light" },
            hideCompletedTasks: hideCompletedTasks
        )
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: saveURL, options: .atomic)
        } catch {
            print("Recto save failed: \(error)")
        }
    }

    private func restore() {
        if let data = try? Data(contentsOf: saveURL) {
            if let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), !snapshot.folders.isEmpty {
                apply(snapshot)
                return
            }
            if let legacy = try? JSONDecoder().decode(LegacySnapshot.self, from: data), !legacy.folders.isEmpty {
                apply(Snapshot(
                    folders: legacy.folders,
                    notes: legacy.notes,
                    scheme: legacy.scheme,
                    hideCompletedTasks: legacy.hideCompletedTasks ?? false
                ))
                return
            }
        }
        SeedData.populate(store: self)
        persist(immediately: true)
    }

    private func apply(_ snapshot: Snapshot) {
        folders = snapshot.folders
        notes = snapshot.notes
        hideCompletedTasks = snapshot.hideCompletedTasks
        if snapshot.scheme == "dark" { preferredScheme = .dark }
        if snapshot.scheme == "light" { preferredScheme = .light }
    }
}

private struct LegacySnapshot: Codable {
    var folders: [Folder]
    var notes: [Note]
    var isPro: Bool?
    var scheme: String?
    var hideCompletedTasks: Bool?
}

enum DateTokenParser {
    static func consume(_ raw: String) -> (text: String, date: Date?) {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?i)(?:^|\s)@([A-Za-z0-9][A-Za-z0-9\-]*(?:\s+[A-Za-z0-9]+){0,2})(?=\s|$)"#
        ) else {
            return (raw, nil)
        }
        let ns = raw as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.matches(in: raw, range: full).last else {
            return (raw, nil)
        }
        let token = ns.substring(with: match.range(at: 1))
        guard let date = parse(token: token) else { return (raw, nil) }
        var result = raw
        if let range = Range(match.range, in: raw) {
            result.replaceSubrange(range, with: " ")
            result = result
                .replacingOccurrences(of: "  ", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (result, date)
    }

    static func parse(token: String) -> Date? {
        let t = token.lowercased().trimmingCharacters(in: .whitespaces)
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        switch t {
        case "today": return start
        case "tomorrow": return calendar.date(byAdding: .day, value: 1, to: start)
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: start)
        default: break
        }

        let weekdays: [String: Int] = [
            "sun": 1, "sunday": 1,
            "mon": 2, "monday": 2,
            "tue": 3, "tues": 3, "tuesday": 3,
            "wed": 4, "wednesday": 4,
            "thu": 5, "thur": 5, "thurs": 5, "thursday": 5,
            "fri": 6, "friday": 6,
            "sat": 7, "saturday": 7
        ]
        if let weekday = weekdays[t] {
            return nextWeekday(weekday, calendar: calendar, from: start)
        }

        let formats = ["d MMM", "MMM d", "EEE d MMM", "d MMMM", "MMMM d", "yyyy-MM-dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.defaultDate = start
        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: t) {
                var comps = calendar.dateComponents([.month, .day], from: parsed)
                comps.year = calendar.component(.year, from: start)
                if format.contains("yyyy") {
                    return calendar.startOfDay(for: parsed)
                }
                if let dated = calendar.date(from: comps) {
                    if dated < start {
                        return calendar.date(byAdding: .year, value: 1, to: dated)
                    }
                    return dated
                }
            }
        }
        return nil
    }

    private static func nextWeekday(_ weekday: Int, calendar: Calendar, from start: Date) -> Date {
        let current = calendar.component(.weekday, from: start)
        var delta = weekday - current
        if delta < 0 { delta += 7 }
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }
}

@MainActor
enum SeedID {
    static let taskCenter = UUID(uuidString: "11111111-1111-1111-1111-111111111101")!
    static let allNotes = UUID(uuidString: "11111111-1111-1111-1111-111111111102")!
    static let raamwerk = UUID(uuidString: "11111111-1111-1111-1111-111111111103")!
    static let stories = UUID(uuidString: "11111111-1111-1111-1111-111111111104")!
    static let verso = UUID(uuidString: "11111111-1111-1111-1111-111111111105")!
    static let archive = UUID(uuidString: "11111111-1111-1111-1111-111111111106")!
    static let trash = UUID(uuidString: "11111111-1111-1111-1111-111111111107")!

    static let marketing = UUID(uuidString: "22222222-2222-2222-2222-222222222201")!
    static let meeting = UUID(uuidString: "22222222-2222-2222-2222-222222222202")!
    static let shipments = UUID(uuidString: "22222222-2222-2222-2222-222222222203")!
    static let roadmap = UUID(uuidString: "22222222-2222-2222-2222-222222222204")!
    static let backlog = UUID(uuidString: "22222222-2222-2222-2222-222222222205")!
    static let bugs = UUID(uuidString: "22222222-2222-2222-2222-222222222206")!
    static let feedback = UUID(uuidString: "22222222-2222-2222-2222-222222222207")!
    static let inspiration = UUID(uuidString: "22222222-2222-2222-2222-222222222208")!
}

@MainActor
enum SeedData {
    static func day(_ offset: Int, hour: Int = 9) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let dated = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return calendar.date(bySettingHour: hour, minute: offset == 0 ? 16 : 0, second: 0, of: dated) ?? dated
    }

    static func populate(store: AppStore) {
        store.folders = [
            Folder(id: SeedID.taskCenter, name: "Task Center", kind: .system, role: .taskCenter, symbol: "checklist", createdAt: day(-30)),
            Folder(id: SeedID.allNotes, name: "All Notes", kind: .smart, role: .allNotes, symbol: "square.grid.2x2", createdAt: day(-30)),
            Folder(id: SeedID.raamwerk, name: "Raamwerk bicycles", kind: .user, role: nil, symbol: "folder", createdAt: day(-20)),
            Folder(id: SeedID.stories, name: "Stories", kind: .user, role: nil, symbol: "folder", createdAt: day(-18)),
            Folder(id: SeedID.verso, name: "Verso", kind: .user, role: nil, symbol: "folder", createdAt: day(-16)),
            Folder(id: SeedID.archive, name: "Archive", kind: .system, role: .archive, symbol: "archivebox", createdAt: day(-30)),
            Folder(id: SeedID.trash, name: "Recently Deleted", kind: .system, role: .trash, symbol: "trash", createdAt: day(-30))
        ]

        let marketingItems = [
            ChecklistItem(id: UUID(), text: "Find a Marketing Co-founder", isDone: false, dueDate: day(-2)),
            ChecklistItem(id: UUID(), text: "Refine website", isDone: false, dueDate: day(1)),
            ChecklistItem(id: UUID(), text: "Collect feedback of founding customers", isDone: false, dueDate: day(-3)),
            ChecklistItem(id: UUID(), text: "Define marketing strategy", isDone: true, dueDate: day(-5)),
            ChecklistItem(id: UUID(), text: "Define business model", isDone: true, dueDate: day(-6))
        ]

        let marketing = Note(
            id: SeedID.marketing,
            folderId: SeedID.verso,
            originalFolderId: nil,
            title: "01. Marketing",
            emoji: "🎟️",
            symbol: "ticket.fill",
            accent: .red,
            blocks: [
                .heading1("1. Introduction of Verso"),
                .heading2("1.1 How it works"),
                .paragraph("Inventory and BOM management for the manufacturing founders/teams, starting small and keep track the right and practical way"),
                .checklist(marketingItems),
                .paragraph("Let's see how the text is coming along."),
                .linkPreview(LinkPreview(title: "Verso", subtitle: "Inventory and BOM for manufacturing teams", urlLabel: "getverso.eu"))
            ],
            updatedAt: Date(),
            pinned: true,
            isDeleted: false
        )

        let meeting = Note(
            id: SeedID.meeting,
            folderId: SeedID.raamwerk,
            originalFolderId: nil,
            title: "01. Meeting notes",
            emoji: "📓",
            symbol: "book.closed.fill",
            accent: .blue,
            blocks: [
                .heading1("Analysis"),
                .paragraph("Kick-off with the frame shop. Confirm geometry freeze before paint."),
                .checklist([
                    ChecklistItem(id: UUID(), text: "Send recap to the team", isDone: false, dueDate: day(1)),
                    ChecklistItem(id: UUID(), text: "Lock next prototype date", isDone: false, dueDate: day(1))
                ])
            ],
            updatedAt: Date(),
            pinned: false,
            isDeleted: false
        )

        let shipments = Note(
            id: SeedID.shipments,
            folderId: SeedID.raamwerk,
            originalFolderId: nil,
            title: "02. Shipments",
            emoji: "📦",
            symbol: "shippingbox.fill",
            accent: .orange,
            blocks: [
                .paragraph("Verify box sizes with"),
                .checklist([
                    ChecklistItem(id: UUID(), text: "Verify box sizes with supplier", isDone: false, dueDate: day(3)),
                    ChecklistItem(id: UUID(), text: "Build product configurator", isDone: false, dueDate: day(2))
                ])
            ],
            updatedAt: day(0, hour: 16),
            pinned: false,
            isDeleted: false
        )

        let roadmap = Note(
            id: SeedID.roadmap,
            folderId: SeedID.raamwerk,
            originalFolderId: nil,
            title: "03. Roadmap",
            emoji: "🗺️",
            symbol: "map.fill",
            accent: .green,
            blocks: [
                .paragraph("Limited edition drop. Keep the story in one place so tasks don't float away from the why."),
                .checklist([
                    ChecklistItem(id: UUID(), text: "Photograph sample frames", isDone: false, dueDate: day(8))
                ])
            ],
            updatedAt: Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 10)) ?? day(-60),
            pinned: false,
            isDeleted: false
        )

        store.notes = [
            marketing,
            meeting,
            shipments,
            roadmap,
            Note(
                id: SeedID.backlog,
                folderId: SeedID.verso,
                originalFolderId: nil,
                title: "02. Backlog",
                emoji: "📋",
                symbol: "list.bullet.rectangle.fill",
                accent: .gray,
                blocks: [.paragraph("Unscheduled product work lives here until it earns a date.")],
                updatedAt: day(-4),
                pinned: false,
                isDeleted: false
            ),
            Note(
                id: SeedID.bugs,
                folderId: SeedID.verso,
                originalFolderId: nil,
                title: "03. Bugs found",
                emoji: "🐞",
                symbol: "ant.fill",
                accent: .red,
                blocks: [.paragraph("Capture issues in the note that owns the context.")],
                updatedAt: day(-6),
                pinned: false,
                isDeleted: false
            ),
            Note(
                id: SeedID.feedback,
                folderId: SeedID.verso,
                originalFolderId: nil,
                title: "04. Feedback Breed Metaal",
                emoji: "💬",
                symbol: "text.bubble.fill",
                accent: .purple,
                blocks: [.paragraph("Founding-customer notes from the workshop visit.")],
                updatedAt: day(-8),
                pinned: false,
                isDeleted: false
            ),
            Note(
                id: SeedID.inspiration,
                folderId: SeedID.verso,
                originalFolderId: nil,
                title: "06. Inspiration",
                emoji: "✨",
                symbol: "sparkles",
                accent: .orange,
                blocks: [.paragraph("Screens, layouts, and words worth stealing from — carefully.")],
                updatedAt: day(-10),
                pinned: false,
                isDeleted: false
            )
        ]
    }
}
