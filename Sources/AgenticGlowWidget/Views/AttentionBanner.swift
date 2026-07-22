import SwiftUI

struct AttentionBanner: View {
    let count: Int

    var body: some View {
        Label(
            count == 1 ? "1 session needs you" : "\(count) sessions need you",
            systemImage: "exclamationmark.circle.fill"
        )
        .font(.caption.weight(.bold))
        .fontWidth(.condensed)
        .foregroundStyle(.yellow)
    }
}

#Preview {
    AttentionBanner(count: 2)
        .padding()
}
