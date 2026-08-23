import Foundation
import UIKit

struct PDFExportOptions: Equatable {
    var includeCover = true
    var includeTOC = true
    var twoColumn = false
    var includeEmoji = true
    var footerText = ""
}

enum NotePDFRenderer {
    static func render(note: Note, folderName: String, options: PDFExportOptions) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let inset: CGFloat = 48
        let columnGap: CGFloat = 18

        return renderer.pdfData { context in
            var pageIndex = 0
            func beginPage() {
                context.beginPage()
                pageIndex += 1
                drawChrome(in: pageRect, page: pageIndex, options: options)
            }

            beginPage()

            var y = inset + 18
            let contentWidth = pageRect.width - inset * 2
            let colWidth = options.twoColumn ? (contentWidth - columnGap) / 2 : contentWidth
            var x = inset
            var column = 0

            func ensureSpace(_ height: CGFloat) {
                if y + height > pageRect.height - 56 {
                    if options.twoColumn, column == 0 {
                        column = 1
                        x = inset + colWidth + columnGap
                        y = inset + 18
                    } else {
                        beginPage()
                        column = 0
                        x = inset
                        y = inset + 18
                    }
                }
            }

            if options.includeCover {
                drawCover(note: note, folderName: folderName, options: options, in: pageRect)
                beginPage()
                y = inset + 18
                column = 0
                x = inset
            }

            if options.includeTOC {
                let headings = note.blocks.filter { $0.kind == .heading1 || $0.kind == .heading2 }
                if !headings.isEmpty {
                    ensureSpace(28)
                    draw("Contents", font: .boldSystemFont(ofSize: 16), at: CGPoint(x: x, y: y), width: colWidth)
                    y += 26
                    for heading in headings {
                        ensureSpace(18)
                        draw(heading.text, font: .systemFont(ofSize: 12), color: .darkGray, at: CGPoint(x: x, y: y), width: colWidth)
                        y += 18
                    }
                    y += 16
                }
            }

            let title = options.includeEmoji ? "\(note.emoji)  \(note.title)" : note.title
            ensureSpace(36)
            draw(title, font: .boldSystemFont(ofSize: 22), at: CGPoint(x: x, y: y), width: colWidth)
            y += 34

            for block in note.blocks {
                switch block.kind {
                case .heading1:
                    ensureSpace(30)
                    draw(block.text, font: .boldSystemFont(ofSize: 16), at: CGPoint(x: x, y: y), width: colWidth)
                    y += 28
                case .heading2:
                    ensureSpace(26)
                    draw(block.text, font: .boldSystemFont(ofSize: 13), at: CGPoint(x: x, y: y), width: colWidth)
                    y += 22
                case .paragraph:
                    let height = block.text.boundingHeight(width: colWidth, font: .systemFont(ofSize: 12))
                    ensureSpace(height + 10)
                    draw(block.text, font: .systemFont(ofSize: 12), at: CGPoint(x: x, y: y), width: colWidth)
                    y += height + 12
                case .checklist:
                    for item in block.items {
                        let box: CGFloat = 11
                        let textWidth = colWidth - 22
                        let height = max(16, item.text.boundingHeight(width: textWidth, font: .systemFont(ofSize: 12)))
                        ensureSpace(height + 10)
                        let boxRect = CGRect(x: x, y: y + 2, width: box, height: box)
                        UIColor(red: 0.29, green: 0.53, blue: 0.91, alpha: 1).setStroke()
                        UIColor(red: 0.62, green: 0.80, blue: 0.98, alpha: 1).setFill()
                        let path = UIBezierPath(roundedRect: boxRect, cornerRadius: 2)
                        if item.isDone { path.fill() } else { path.stroke() }
                        if item.isDone {
                            let check = "✓" as NSString
                            check.draw(at: CGPoint(x: x + 1.5, y: y + 1), withAttributes: [
                                .font: UIFont.boldSystemFont(ofSize: 9),
                                .foregroundColor: UIColor.white
                            ])
                        }
                        var attrs: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 12),
                            .foregroundColor: item.isDone ? UIColor.gray : UIColor.black
                        ]
                        if item.isDone {
                            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
                        }
                        (item.text as NSString).draw(with: CGRect(x: x + 18, y: y, width: textWidth, height: height), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
                        y += height + 8
                    }
                    y += 6
                case .linkPreview:
                    if let preview = block.preview {
                        ensureSpace(40)
                        draw(preview.title, font: .boldSystemFont(ofSize: 12), at: CGPoint(x: x, y: y), width: colWidth)
                        y += 16
                        draw(preview.urlLabel, font: .systemFont(ofSize: 11), color: .gray, at: CGPoint(x: x, y: y), width: colWidth)
                        y += 22
                    }
                }
            }
        }
    }

    private static func drawCover(note: Note, folderName: String, options: PDFExportOptions, in rect: CGRect) {
        let title = options.includeEmoji ? "\(note.emoji)\n\(note.title)" : note.title
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        let titleRect = CGRect(x: 48, y: 260, width: rect.width - 96, height: 160)
        (title as NSString).draw(with: titleRect, options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        let sub: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.gray,
            .paragraphStyle: paragraph
        ]
        ("\(folderName)  ·  Made with Recto" as NSString).draw(
            with: CGRect(x: 48, y: 430, width: rect.width - 96, height: 24),
            options: .usesLineFragmentOrigin,
            attributes: sub,
            context: nil
        )
    }

    private static func drawChrome(in rect: CGRect, page: Int, options: PDFExportOptions) {
        let footer = options.footerText.isEmpty ? "Made with Recto" : options.footerText
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.gray
        ]
        (footer as NSString).draw(at: CGPoint(x: 48, y: rect.height - 32), withAttributes: attrs)
        ("\(page)" as NSString).draw(at: CGPoint(x: rect.width - 64, y: rect.height - 32), withAttributes: attrs)
    }

    private static func draw(_ text: String, font: UIFont, color: UIColor = .black, at point: CGPoint, width: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(with: CGRect(x: point.x, y: point.y, width: width, height: 500), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
    }
}

private extension String {
    func boundingHeight(width: CGFloat, font: UIFont) -> CGFloat {
        let rect = (self as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }
}
