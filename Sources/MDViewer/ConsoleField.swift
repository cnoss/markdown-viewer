import SwiftUI

/// Einzeiliges Eingabefeld, das Pfeiltasten, Enter, Esc, Tab und Rückschritt
/// an die Liste weiterreicht – so bleibt der Fokus immer in der Eingabezeile.
struct ConsoleField: NSViewRepresentable {
    enum Key { case up, down, enter, escape, tab, backspaceOnEmpty, parent, leftOnEmpty, rightOnEmpty }

    @Binding var text: String
    var placeholder: String
    var focusToken: Int
    var onKey: (Key) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.placeholderString = placeholder
        field.cell?.usesSingleLineMode = true
        field.cell?.lineBreakMode = .byTruncatingHead
        field.delegate = context.coordinator
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectAll(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ConsoleField
        var lastFocusToken: Int

        init(_ parent: ConsoleField) {
            self.parent = parent
            self.lastFocusToken = parent.focusToken
        }

        func controlTextDidChange(_ note: Notification) {
            guard let field = note.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            let key: Key?
            switch selector {
            case #selector(NSResponder.moveUp(_:)): key = .up
            case #selector(NSResponder.moveDown(_:)): key = .down
            case #selector(NSResponder.insertNewline(_:)): key = .enter
            case #selector(NSResponder.cancelOperation(_:)): key = .escape
            case #selector(NSResponder.insertTab(_:)): key = .tab
            case #selector(NSResponder.moveToBeginningOfDocument(_:)): key = .parent
            case #selector(NSResponder.deleteBackward(_:)) where textView.string.isEmpty: key = .backspaceOnEmpty
            case #selector(NSResponder.moveLeft(_:)) where textView.string.isEmpty: key = .leftOnEmpty
            case #selector(NSResponder.moveRight(_:)) where textView.string.isEmpty: key = .rightOnEmpty
            default: key = nil
            }
            guard let key else { return false }
            parent.onKey(key)
            return true
        }
    }
}
