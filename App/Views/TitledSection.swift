import SwiftUI

/// A list section whose title uses a Dynamic Type text style, so it grows with Larger Text
/// (plain `Section("Title")` headers don't fully, according to Apple's accessibility audit).
struct TitledSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            content
        } header: {
            Text(title)
                .font(.headline)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
