import SwiftUI

/// Money input that live-filters everything except digits and one decimal
/// separator; a comma is normalized to a dot. Emits `Decimal?` (`nil` when empty).
struct DecimalField: View {
    private let titleKey: LocalizedStringKey
    @Binding private var value: Decimal?
    @State private var text: String

    // fixed dot as the decimal separator, independent of the system locale
    private static let posix = Locale(identifier: "en_US_POSIX")

    init(_ titleKey: LocalizedStringKey, value: Binding<Decimal?>) {
        self.titleKey = titleKey
        self._value = value
        _text = State(initialValue: value.wrappedValue.map(Self.string(from:)) ?? "")
    }

    var body: some View {
        TextField(titleKey, text: $text)
            .onChange(of: text) { _, newValue in
                let clean = Self.sanitize(newValue)
                if clean != text { text = clean } // sanitize is idempotent — no update loop
                value = clean.isEmpty ? nil : Decimal(string: clean, locale: Self.posix)
            }
    }

    private static func string(from value: Decimal) -> String {
        value.formatted(.number.grouping(.never).locale(posix))
    }

    /// Keeps digits and the first separator (dot/comma → dot).
    private static func sanitize(_ raw: String) -> String {
        var result = ""
        var hasSeparator = false
        for ch in raw {
            if ch.isNumber {
                result.append(ch)
            } else if (ch == "." || ch == ",") && !hasSeparator {
                result.append(".")
                hasSeparator = true
            }
        }
        return result
    }
}
