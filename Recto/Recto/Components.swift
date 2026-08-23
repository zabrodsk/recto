import SwiftUI
import UIKit

struct RectoCheckbox: View {
    var isDone: Bool
    var compact: Bool = false
    var action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
                action()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(RectoTheme.accent, lineWidth: isDone ? 0 : 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isDone ? RectoTheme.checkFill : Color.clear)
                    )
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .opacity(isDone ? 1 : 0)
                    .scaleEffect(isDone ? 1 : 0.4)
            }
            .frame(width: 22, height: 22)
            .scaleEffect(isDone ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .frame(width: compact ? 22 : 44, height: compact ? 22 : 44)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isDone ? "Mark incomplete" : "Mark complete")
        .accessibilityValue(isDone ? "Completed" : "Open")
    }
}

struct DateBadge: View {
    var date: Date
    var dimmed: Bool = false

    var body: some View {
        Text(date.rectoChip)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(dimmed ? RectoTheme.doneText : RectoTheme.dateText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(dimmed ? RectoTheme.dateFill.opacity(0.45) : RectoTheme.dateFill)
            )
    }
}

struct ProjectChip: View {
    var title: String
    var symbol: String
    var accent: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.12))
        )
    }
}

struct FolderRow: View {
    var folder: Folder
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: folder.symbol)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(RectoTheme.accent)
                .frame(width: 28)
            Text(folder.name)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 15))
                    .foregroundStyle(RectoTheme.secondaryLabel)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.45))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct NoteListRow: View {
    var note: Note

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(note.accent.color.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: note.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(note.accent.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    if note.pinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(RectoTheme.secondaryLabel)
                    }
                    Spacer()
                    Text(note.updatedAt.rectoListTime)
                        .font(.system(size: 13))
                        .foregroundStyle(RectoTheme.secondaryLabel)
                }
                Text(note.snippet)
                    .font(.system(size: 14))
                    .foregroundStyle(RectoTheme.secondaryLabel)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct VersoMiniPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verso")
                    .font(.system(size: 9, weight: .bold))
                Group {
                    label("Workspaces")
                    label("Inventory", active: true)
                    label("Utilities")
                }
                Spacer()
            }
            .padding(10)
            .frame(width: 88)
            .background(Color(white: 0.96))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    column("SKU")
                    column("Name")
                    column("Supplier")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(white: 0.94))
                row("BOLT-DIN912", "Bolt DIN912", "Metaal BV")
                Divider()
                row("FENDER-01", "Fender", "Raamwerk")
                Divider()
                row("AXLE-QR", "Quick-release", "DT Swiss")
                Spacer(minLength: 0)
            }
            .background(Color.white)
        }
        .frame(height: 132)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(RectoTheme.hairline, lineWidth: 1)
        )
    }

    private func label(_ text: String, active: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 8, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? RectoTheme.accent : Color.secondary)
    }

    private func column(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ sku: String, _ name: String, _ supplier: String) -> some View {
        HStack {
            Text(sku).frame(maxWidth: .infinity, alignment: .leading)
            Text(name).frame(maxWidth: .infinity, alignment: .leading)
            Text(supplier).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 8))
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

struct LinkPreviewCard: View {
    var preview: LinkPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VersoMiniPreview()
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.title)
                    .font(.system(size: 16, weight: .semibold))
                Text(preview.urlLabel)
                    .font(.system(size: 13))
                    .foregroundStyle(RectoTheme.secondaryLabel)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(RectoTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(RectoTheme.hairline, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 4)
    }
}

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(RectoTheme.secondaryLabel)
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

struct CardGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(RectoTheme.groupedRow)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }
}
