import Observation

/// Which ride `CarnivalView` is currently showing the camera from.
/// Equivalent of the original's `gStyle`/`View_Style` (`View_Point`,
/// free look-around, isn't ported as a case here — see `Renderer`).
public enum CameraMode: Equatable, Sendable {
    case coaster
    case ferris
}

/// The model backing a `CarnivalView`. Own one, pass it to
/// `CarnivalView(carnival:)`, and it's the single source of truth for
/// the ride: set `camera` to switch views from outside the view
/// hierarchy entirely — a SwiftUI menu command or button, for instance
/// — the same way `CarnivalView`'s own built-in keyboard/touch/remote
/// input does internally. Reading `camera` back also reflects whichever
/// of those the person last used, since they all go through this same
/// property rather than some separate, view-private state.
@Observable
public final class Carnival {
    public var camera: CameraMode

    public init(camera: CameraMode = .coaster) {
        self.camera = camera
    }

    /// Switches `camera` to whichever of the two modes it isn't
    /// currently showing. `MetalView`'s `'t'`/swipe/remote input
    /// handlers call this directly; exposed publicly too so a client
    /// wanting the same "switch to the other ride" behavior (a button,
    /// a menu command) doesn't need to spell out the coaster/ferris
    /// cases itself.
    public func toggleCamera() {
        camera = (camera == .coaster) ? .ferris : .coaster
    }
}
