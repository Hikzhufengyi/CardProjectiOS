import SwiftUI

enum AppTheme {
    static let officialBlue = Color(red: 0.00, green: 0.28, blue: 0.67)
    static let ink = Color(red: 0.10, green: 0.12, blue: 0.16)
    static let secondaryInk = Color(red: 0.34, green: 0.37, blue: 0.42)
    static let pageBackground = Color.white
    static let groupedBackground = Color(red: 0.96, green: 0.97, blue: 0.98)
    static let cardBackground = Color.white
    static let border = Color.black.opacity(0.08)
    static let success = Color(red: 0.08, green: 0.51, blue: 0.28)
    static let warning = Color(red: 0.78, green: 0.45, blue: 0.04)
    static let danger = Color(red: 0.75, green: 0.10, blue: 0.10)

    static let cornerRadius: CGFloat = 10
}

struct ProfessionalCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func professionalCard() -> some View {
        modifier(ProfessionalCard())
    }
}
