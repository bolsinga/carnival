import SwiftUI

/// The entire carnival scene (roller coaster, ferris wheel, tent), rendered
/// with Metal and driven by SwiftUI. Drop this into any window/scene on
/// macOS, iOS, iPadOS, tvOS, or visionOS to show it.
public struct CarnivalView: View {
    private var carnival: Carnival

    /// `carnival` defaults to a fresh, unshared `Carnival()` so
    /// `CarnivalView()` still works on its own, same as before this
    /// model existed — pass your own instance in if you want to read or
    /// control the ride (e.g. `camera`) from outside the view.
    public init(carnival: Carnival = Carnival()) {
        self.carnival = carnival
    }

    public var body: some View {
        MetalView(carnival: carnival)
            .ignoresSafeArea()
    }
}

#Preview("Coaster") {
  CarnivalView(carnival: Carnival(camera: .coaster, state: .paused))
}

#Preview("Ferris") {
  CarnivalView(carnival: Carnival(camera: .ferris, state: .paused))
}
