import SwiftUI

/// The entire carnival scene (roller coaster, ferris wheel, tent), rendered
/// with Metal and driven by SwiftUI. Drop this into any window/scene on
/// macOS, iOS, iPadOS, or tvOS (via `CarnivalKitTV`) to show it.
public struct CarnivalView: View {
    public init() {}

    public var body: some View {
        MetalView()
            .ignoresSafeArea()
    }
}
