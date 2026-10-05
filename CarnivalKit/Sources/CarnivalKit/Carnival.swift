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

/// Where `CarnivalView`'s paused ride camera is currently looking.
/// `Renderer`'s pause/look-around feature (macOS: two-finger trackpad
/// drag; iOS: one-finger drag + pinch; tvOS: remote arrow presses)
/// rotates `yaw`/`pitch` and scales `zoom`, while the eye itself stays
/// exactly where the ride camera was paused. The defaults are the
/// identity (no rotation, no zoom) — see `Carnival.lookAround`.
public struct LookAround: Equatable, Sendable {
    public var yaw: Float
    public var pitch: Float
    public var zoom: Float

    public init(yaw: Float = 0, pitch: Float = 0, zoom: Float = 1) {
        self.yaw = yaw
        self.pitch = pitch
        self.zoom = zoom
    }

    /// Keeps `pitch` well short of vertical, so the look-around right
    /// vector (`cross(gazeDirection, up)`) never degenerates.
    static let maxPitch: Float = 80 * .pi / 180

    static let minZoom: Float = 0.5
    static let maxZoom: Float = 3.0
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

    /// Set by `MetalView.Coordinator.makeConfiguredView` if GPU/resource
    /// setup fails, instead of crashing the host process. `nil` means setup
    /// succeeded (the overwhelmingly common case). CarnivalKit itself has
    /// no opinion on how to surface a failure -- this just makes it
    /// observable to whatever embeds `CarnivalView` (an app, a screen
    /// saver), which can react however makes sense for that context.
    public var rendererError: RendererError?

    /// Setting this keeps `lookAround` in sync (see its `didSet`), so
    /// that invariant holds regardless of whether `state` changes via
    /// `togglePause()` or a direct assignment here.
    public var state: State {
        didSet {
            guard state != oldValue else { return }
            lookAround = (state == .paused) ? LookAround() : nil
        }
    }

    /// Where the paused ride camera is looking — `nil` while animating,
    /// since the ride camera otherwise just tracks the ride itself.
    /// Freshly reset to the identity `LookAround()` the instant pausing
    /// begins, and `nil`-ed out again the instant it resumes (see
    /// `state`'s `didSet`), so a resume always returns cleanly to the
    /// normal ride camera regardless of how far look-around had
    /// drifted. `Renderer` reads and writes this directly while paused.
    public var lookAround: LookAround?

    public init(camera: CameraMode = .coaster, state: State = .animating) {
        self.camera = camera
        self.state = state
        // state's didSet doesn't run during initialization, so this
        // mirrors it manually to keep the same invariant from the start.
        self.lookAround = (state == .paused) ? LookAround() : nil
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

    /// Pause/look-around input (see `lookAround`): rotates the gaze
    /// direction by `deltaYaw`/`deltaPitch`, clamping `pitch` well short
    /// of vertical. A no-op while `lookAround` is `nil` (i.e. while
    /// animating) — callers (macOS's pan gesture, iOS's gesture
    /// delegate, tvOS's non-animating branch in `MetalView`) are
    /// expected to only call this while paused, but this guards against
    /// it regardless.
    public func adjustLookAround(deltaYaw: Float, deltaPitch: Float) {
        guard var lookAround = lookAround else { return }
        lookAround.yaw += deltaYaw
        lookAround.pitch = min(
            max(lookAround.pitch + deltaPitch, -LookAround.maxPitch), LookAround.maxPitch)
        self.lookAround = lookAround
    }

    /// Pause/look-around zoom input (see `lookAround`) — iOS only (via
    /// pinch); neither macOS's trackpad pan nor tvOS's remote has a
    /// zoom gesture wired up, so they have no zoom control. `factor` is
    /// a multiplier on the current zoom (as
    /// `UIPinchGestureRecognizer.scale` naturally is): >1 zooms in
    /// (narrows the field of view), <1 zooms out. A no-op while
    /// `lookAround` is `nil`, same as `adjustLookAround`.
    public func adjustZoom(byFactor factor: Float) {
        guard var lookAround = lookAround else { return }
        lookAround.zoom = min(max(lookAround.zoom * factor, LookAround.minZoom), LookAround.maxZoom)
        self.lookAround = lookAround
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
}
