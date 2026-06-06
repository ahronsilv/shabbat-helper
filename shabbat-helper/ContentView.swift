import SwiftUI

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview("English LTR") {
    ContentView()
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Russian") {
    ContentView()
        .environment(\.locale, Locale(identifier: "ru"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("French") {
    ContentView()
        .environment(\.locale, Locale(identifier: "fr"))
        .environment(\.layoutDirection, .leftToRight)
}

#Preview("Hebrew RTL") {
    ContentView()
        .environment(\.locale, Locale(identifier: "he"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Amharic") {
    ContentView()
        .environment(\.locale, Locale(identifier: "am"))
        .environment(\.layoutDirection, .leftToRight)
}
