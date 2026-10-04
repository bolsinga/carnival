import Observation

/// Which ride `CarnivalView` is currently showing the camera from.
/// Equivalent of the original's `gStyle`/`View_Style` (`View_Point`,
/// free look-around, isn't ported as a case here — see `Renderer`).
public enum CameraMode: Equatable, Sendable {
    case coaster
    case ferris
}

/// Whether `CarnivalView`'s ride is animating or paused, independent of
/// `CameraMode`: every camera/state combination is valid, and pausing
/// means the same thing regardless of which camera is active. Equivalent
/// of the original's `gAnimating`.
public enum State: Equatable, Sendable {
    case animating
    case paused
}

/// The model backing a `CarnivalView`. Own one, pass it to
/// `CarnivalView(carnival:)`, and it's the single source of truth for
/// the ride: set `camera`/`state` to control it from outside the view
/// hierarchy entirely — a SwiftUI menu command or button, for instance
/// — the same way `CarnivalView`'s own built-in keyboard/touch/remote
/// input does internally. Reading them back also reflects whichever of
/// those the person last used, since they all go through these same
/// properties rather than some separate, view-private state.
@Observable
public final class Carnival {
    public var camera: CameraMode
    public var state: State

    /// `state`'s value as of the last `checkAndClearStateTransition()`
    /// call. `@ObservationIgnored` since this is pure bookkeeping for
    /// that method, never read by a View.
    @ObservationIgnored
    private var previousState: State

    public init(camera: CameraMode = .coaster, state: State = .animating) {
        self.camera = camera
        self.state = state
        self.previousState = state
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

    /// Switches `state` between animating and paused. Same reasoning as
    /// `toggleCamera()`: `MetalView`'s `' '`/tap/Play-Pause input
    /// handlers call this directly, and it's exposed publicly for the
    /// same reason.
    public func togglePause() {
        state = (state == .animating) ? .paused : .animating
    }

    /// Whether the ferris wheel itself should keep turning: true unless
    /// paused while riding it (`camera == .ferris`), in which case the
    /// whole wheel (not just the ferris-view camera) holds still,
    /// matching what someone actually sitting in a stopped carriage
    /// would see — looking around from a fixed vantage up high or down
    /// low, rather than the wheel visibly rotating out from under a
    /// frozen eye. Paused on the coaster, by contrast, the wheel is just
    /// background scenery still visibly turning while the coaster
    /// camera itself is frozen — the same way it would keep turning if
    /// you stepped off the ride and just watched. A property of
    /// `camera`/`state` together, read by `Renderer.draw(in:)` each
    /// frame to decide whether to advance the wheel's own rotation.
    var wheelShouldTurn: Bool {
        state == .animating || camera != .ferris
    }

    /// Reports whether `state` has changed since the last call to this
    /// method, regardless of however it changed (`togglePause()`, a
    /// direct `state = ...` assignment, etc), then clears that pending
    /// change so the next call returns `false` until `state` changes
    /// again. Intended to be polled once per frame by
    /// `Renderer.draw(in:)`, which needs to detect pause/resume
    /// transitions at frame boundaries to run their one-time side
    /// effects -- not part of the public model surface, since no other
    /// caller has a reason to poll for this.
    func checkAndClearStateTransition() -> Bool {
        guard state != previousState else { return false }
        previousState = state
        return true
    }
}
