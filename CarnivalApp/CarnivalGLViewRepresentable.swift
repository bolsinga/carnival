import SwiftUI

#if os(macOS)

/// Hosts `CarnivalGLView` -- a fresh Objective-C `NSOpenGLView` showing the
/// original 1992 OpenGL scene in-process -- inside SwiftUI. See
/// `CarnivalGLView.h` for why this is Objective-C rather than Swift.
struct CarnivalGLViewRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> CarnivalGLView {
        CarnivalGLView()
    }

    func updateNSView(_ nsView: CarnivalGLView, context: Context) {}
}

#endif
