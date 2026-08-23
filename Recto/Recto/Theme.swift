import SwiftUI
import UIKit

enum RectoTheme {
    static let accent = Color(red: 74 / 255, green: 134 / 255, blue: 232 / 255)
    static let accentDeep = Color(red: 45 / 255, green: 98 / 255, blue: 210 / 255)

    static var canvas: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.black
                : UIColor(red: 0.945, green: 0.953, blue: 0.972, alpha: 1)
        })
    }

    static var card: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.11, alpha: 1)
                : UIColor.white
        })
    }

    static var groupedRow: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.12, alpha: 1)
                : UIColor.white
        })
    }

    static var hairline: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.08)
                : UIColor(white: 0, alpha: 0.06)
        })
    }

    static var secondaryLabel: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.62, alpha: 1)
                : UIColor(white: 0.45, alpha: 1)
        })
    }

    static var dateFill: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.24, blue: 0.38, alpha: 1)
                : UIColor(red: 0.89, green: 0.94, blue: 1.0, alpha: 1)
        })
    }

    static var dateText: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1)
                : UIColor(red: 0.33, green: 0.52, blue: 0.88, alpha: 1)
        })
    }

    static var checkFill: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.38, green: 0.62, blue: 0.98, alpha: 1)
                : UIColor(red: 0.62, green: 0.80, blue: 0.98, alpha: 1)
        })
    }

    static var doneText: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.38, alpha: 1)
                : UIColor(white: 0.62, alpha: 1)
        })
    }

    static let tabBarFill = Color.white.opacity(0.72)
}

enum NoteAccent: String, Codable, CaseIterable {
    case red, blue, orange, green, purple, gray

    var color: Color {
        switch self {
        case .red: return Color(red: 0.91, green: 0.30, blue: 0.28)
        case .blue: return RectoTheme.accent
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.20)
        case .green: return Color(red: 0.30, green: 0.72, blue: 0.47)
        case .purple: return Color(red: 0.62, green: 0.42, blue: 0.90)
        case .gray: return Color(white: 0.55)
        }
    }
}

extension Date {
    var rectoChip: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: self)
    }

    var rectoListTime: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: self)
        }
        if abs(timeIntervalSinceNow) < 120 {
            return "just now"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM-yyyy"
        return formatter.string(from: self)
    }
}
