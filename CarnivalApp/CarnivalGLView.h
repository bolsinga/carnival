#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

/// A fresh AppKit/OpenGL view showing the same roller-coaster/ferris-wheel
/// scene as the original 1992 GLUT `carnival` app, by calling straight into
/// its untouched drawing code (`drawScene`/`getCoasterPts`/`avgPts`, shared
/// with the `carnival` targets via `carnival.c`/`coaster.c`/
/// `ferris.c`/`tent.c`, which are also members of this target). This is a
/// new implementation, not a port of `main.c` -- GLUT's `glutMainLoop()`
/// never returns and would block this app's own run loop, and its `Key()`
/// calls `exit(0)` on Escape, which would quit this whole app rather than
/// just close a window.
@interface CarnivalGLView : NSOpenGLView
@end

#endif
