import QuartzCore

/// Tracks elapsed real time between frames, in seconds, so scene animation
/// (coaster/ferris progression, once ported) advances in world-units-per-
/// second rather than by counting draw callbacks. This replaces the
/// `gThreshhold`-based frame counter in the original `main.c`'s `Idle`.
struct AnimationClock {
    private var lastTime: CFTimeInterval?

    /// Caps a single frame's delta so a stall (breakpoint, backgrounding,
    /// thermal throttling) doesn't cause the scene to leap forward to
    /// catch up once drawing resumes.
    private static let maximumStep: TimeInterval = 1.0 / 10.0

    /// Returns the elapsed time since the previous call, in seconds.
    /// Returns 0 on the very first call, since there's no previous frame
    /// to measure from yet.
    mutating func tick(now: CFTimeInterval = CACurrentMediaTime()) -> TimeInterval {
        defer { lastTime = now }
        guard let lastTime else { return 0 }
        return min(now - lastTime, Self.maximumStep)
    }
}
