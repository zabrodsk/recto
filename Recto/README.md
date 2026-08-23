# Recto

iOS 17+ SwiftUI app: notes live in folders, checklists inside those notes aggregate into **Task Center**. Dates on tasks (`@tomorrow`, or the calendar chip) are the only extra — nothing to tag, nothing to sync.

The app is **free**. No subscription, no folder or note caps.

This environment cannot compile for iOS (no Xcode). Open the project on a Mac.

## Open in Xcode

Requires **Xcode 15+** and **iOS 17**. Open `Recto.xcodeproj` (this folder).

## What is in here

- **All Notes** — Task Center, smart All Notes, user folders, Archive, Recently Deleted
- **Folder list** — icon, title, relative time, snippet; pin and rename
- **Note editor** — headings, body, working checkboxes, date chips, Verso-style link preview, random emoji on new notes
- **Task Center** — live aggregation grouped Overdue / Today / Tomorrow / This Week / Later; tap the box to complete, tap the row to open the note; swipe to complete or delete
- **@ dates** — type `@today`, `@tomorrow`, `@fri`, or `@21 aug` on a task
- **Export as PDF** — cover, TOC, two-column, emoji, footer; share sheet
- **Light / dark** — sparkles control on Task Center, or Settings

Data is stored as JSON in the app Documents directory. Nothing leaves the device.

## Seed content

First launch fills folders **Raamwerk bicycles**, **Stories**, and **Verso**, including the **01. Marketing** note from the mockups.
