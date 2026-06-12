import SwiftUI

/// Поле ввода денежной суммы. Вживую отбрасывает всё, кроме цифр и одного
/// десятичного разделителя: буквы, пробелы и разделители тысяч ввести нельзя.
/// Запятая нормализуется в точку. Наружу отдаёт `Decimal?` (`nil`, если пусто).
struct DecimalField: View {
    private let titleKey: LocalizedStringKey
    @Binding private var value: Decimal?
    @State private var text: String

    /// Фиксированная точка как десятичный разделитель — не зависим от системной локали.
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
                if clean != text { text = clean } // sanitize идемпотентен — цикла нет
                value = clean.isEmpty ? nil : Decimal(string: clean, locale: Self.posix)
            }
    }

    /// Представление существующей суммы для seed-а поля: точка, без группировки.
    private static func string(from value: Decimal) -> String {
        value.formatted(.number.grouping(.never).locale(posix))
    }

    /// Оставляет только цифры и первый разделитель (точку/запятую → точку).
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
