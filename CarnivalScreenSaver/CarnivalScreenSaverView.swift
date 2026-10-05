import CarnivalKit
import ScreenSaver
import SwiftUI
import os

/// Temporary, for diagnosing an intermittent black screen after several
/// rapid-fire open/closes of a screen saver preview within the same
/// long-lived host process -- confirms whether old instances actually
/// get deallocated between clicks, alongside Renderer's own init/deinit
/// logging under the same subsystem.
private let screenSaverViewLogger = Logger(subsystem: "gdb.CarnivalKit", category: "CarnivalScreenSaverView")

/// Hosts `CarnivalKit`'s `CarnivalView` -- the same animated roller-coaster/
/// ferris-wheel scene shown in `CarnivalApp` -- as a macOS screen saver.
/// `MetalView` (inside `CarnivalView`) hosts a plain `MTKView` that runs its
/// own display-link timer, so this view only needs to get it on screen;
/// nothing here needs to drive animation itself.
///
/// Each launch (a fresh preview, or the saver actually activating) randomly
/// picks which ride to show, rather than offering a configure-sheet choice
/// -- `ScreenSaverDefaults` didn't reliably carry a saved choice across the
/// separate processes that can host a saver (System Settings' preview vs.
/// the real screensaver engine), so this sidesteps that entirely.
final class CarnivalScreenSaverView: ScreenSaverView {
    private let instanceID = UUID()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        let camera: CameraMode = Bool.random() ? .coaster : .ferris
        let hosting = NSHostingView(rootView: CarnivalView(carnival: Carnival(camera: camera)))
        hosting.frame = bounds
        hosting.autoresizingMask = [.width, .height]
        addSubview(hosting)
        animationTimeInterval = 1.0 / 30.0
        screenSaverViewLogger.notice("init: \(self.instanceID, privacy: .public) isPreview=\(isPreview, privacy: .public)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        screenSaverViewLogger.notice("deinit: \(self.instanceID, privacy: .public)")
    }
}
