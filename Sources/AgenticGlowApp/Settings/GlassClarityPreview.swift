import SwiftUI

struct GlassClarityPreview: View {
    let clarity: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.42, blue: 0.96),
                    Color(red: 0.10, green: 0.68, blue: 0.48),
                    Color(red: 0.94, green: 0.56, blue: 0.14)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            Circle()
                .fill(.white.opacity(0.42))
                .frame(width: 92, height: 92)
                .offset(x: 128, y: -30)

            LiquidGlassSurface(clarity: clarity)

            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid")
                Text("Glass Preview")
                    .fontWeight(.semibold)
                Spacer()
                Text(clarity, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
            .padding(.horizontal, 14)
        }
        .frame(height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Glass preview")
        .accessibilityValue(Text(
            verbatim: "\(Int((clarity * 100).rounded())) percent clarity"
        ))
        .accessibilityIdentifier("AgenticGlow.GlassClarityPreview")
    }
}
