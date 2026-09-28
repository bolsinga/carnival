import Foundation

extension Notification.Name {
    /// Posting this notification toggles between the coaster and
    /// ferris-wheel cameras — the same effect as the platform-native
    /// input `CarnivalView` already wires up on its own (`'t'` on
    /// macOS, a swipe on iOS, Siri Remote arrow presses on tvOS).
    ///
    /// Exists so a host app can hook its own macOS menu bar command or
    /// iPadOS keyboard shortcut — declared with SwiftUI's `.commands`,
    /// a `Scene`-level API — up to this toggle. `.commands` has no way
    /// to reach the `Renderer` instance directly: it lives inside
    /// `CarnivalView`'s own view hierarchy, not anywhere a `Scene`'s
    /// commands closure can address. `CarnivalView` observes this on
    /// macOS and iOS/iPadOS (not tvOS, which has no menu bar or
    /// keyboard-shortcut system in this sense — its Siri Remote input
    /// is already wired up separately).
    public static let carnivalToggleCamera = Notification.Name("CarnivalToggleCamera")
}
