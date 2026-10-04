#import "CarnivalGLView.h"

#if TARGET_OS_OSX

#import "carnival.h"
#import "coaster.h"

/// Mirrors the original demo's three camera styles (`View_Style` in
/// `main.c`), but as this view's own fresh state -- not read from any of
/// `main.c`'s globals.
typedef NS_ENUM(NSInteger, CarnivalGLViewStyle) {
    CarnivalGLViewStyleCoaster,
    CarnivalGLViewStyleFerris,
    CarnivalGLViewStyleFreeLook
};

/// Real-time rates, not tied to the timer's own tick frequency -- same
/// reasoning and the same chosen values as CarnivalKit's Renderer.swift
/// (wheelAngularVelocity/coasterPointsPerSecond): there's no faithful
/// "original" rate to preserve (the original's idle-based throttle was
/// calibrated to whatever its 1992 hardware's callback rate happened to
/// be), so this picks a fresh, real-world pace instead -- and matches the
/// Metal port's pace since both now show the same underlying demo.
static const double kWheelAngularVelocity = 2.0 * M_PI / 20.0;  // radians/sec
static const double kCoasterPointsPerSecond = 15.0;             // points/sec
static const NSTimeInterval kTickInterval = 1.0 / 60.0;

@implementation CarnivalGLView {
    NSTimer *_timer;
    BOOL _animating;
    CarnivalGLViewStyle _style;
    Coord _rotation;
    int _rollPts;
    double _coasterPosition;
    Coord _fwv[3];
    GLdouble _eyeX, _eyeY, _eyeZ;
    GLdouble _centerX, _centerY, _centerZ;
    GLdouble _upX, _upY, _upZ;
    GLdouble _step;
}

- (instancetype)init {
    NSOpenGLPixelFormatAttribute attrs[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFADepthSize, 24,
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
        0
    };
    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
    self = [super initWithFrame:NSMakeRect(0, 0, 640, 480) pixelFormat:pixelFormat];
    if (self) {
        _animating = YES;
        _style = CarnivalGLViewStyleCoaster;
        _rotation = 0;
        _coasterPosition = 0;
        _fwv[0] = 0;
        _fwv[1] = -6.0;
        _fwv[2] = 0;
        _step = 0.1;
    }
    return self;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [[self window] makeFirstResponder:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [super viewWillMoveToWindow:newWindow];
    if (newWindow == nil) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)dealloc {
    [_timer invalidate];
}

- (void)prepareOpenGL {
    [super prepareOpenGL];
    _rollPts = getCoasterPts();
    glClearColor(0.33, 0.67, 1.0, 1.0);
    glEnable(GL_DEPTH_TEST);
    _timer = [NSTimer scheduledTimerWithTimeInterval:kTickInterval
                                               target:self
                                             selector:@selector(tick:)
                                             userInfo:nil
                                              repeats:YES];
}

- (void)reshape {
    [super reshape];
    [[self openGLContext] makeCurrentContext];
    // glViewport wants real framebuffer pixels, not points -- on a Retina
    // display [self bounds] alone under-covers the backing store (e.g. a
    // quarter of it at 2x), leaving the rest of the drawable never drawn
    // into. convertRectToBacking: converts points to the actual pixel size.
    NSRect backingBounds = [self convertRectToBacking:[self bounds]];
    GLsizei width = (GLsizei)backingBounds.size.width;
    GLsizei height = (GLsizei)backingBounds.size.height;
    if (height <= 0) {
        return;
    }
    glViewport(0, 0, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    gluPerspective(60.0, (GLdouble)width / (GLdouble)height, 0.01, 150.0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
}

- (void)drawRect:(NSRect)dirtyRect {
    [[self openGLContext] makeCurrentContext];
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glPushMatrix();
    gluLookAt(_eyeX, _eyeY, _eyeZ, _centerX, _centerY, _centerZ, _upX, _upY, _upZ);
    drawScene(_rotation, _rollPts, _fwv);
    glPopMatrix();
    [[self openGLContext] flushBuffer];
}

- (void)tick:(NSTimer *)timer {
    if (_animating) {
        switch (_style) {
            case CarnivalGLViewStyleCoaster: {
                int index = (int)_coasterPosition % _rollPts;
                int nextIndex = (index + 1) % _rollPts;
                Coord rider[3], nextrider[3];
                avgPts(rollerin[index], rollerout[index], rider);
                avgPts(rollerin[nextIndex], rollerout[nextIndex], nextrider);
                _eyeX = rider[0];
                _eyeY = rider[1] + 0.5;
                _eyeZ = rider[2];
                _centerX = nextrider[0];
                _centerY = nextrider[1] + 0.5;
                _centerZ = nextrider[2];
                _upX = 0.0;
                _upY = 1.0;
                _upZ = 0.0;
                break;
            }
            case CarnivalGLViewStyleFerris:
                // fwv was last written by drawScene's own ferris() call
                // during the previous -drawRect: -- one frame of lag,
                // same as the original's gFWV/Idle() relationship.
                _eyeX = _fwv[0];
                _eyeY = _fwv[1];
                _eyeZ = _fwv[2];
                _centerX = _fwv[0] + 1.0;
                _centerY = _fwv[1];
                _centerZ = _fwv[2];
                _upX = 0.0;
                _upY = 1.0;
                _upZ = 0.0;
                break;
            case CarnivalGLViewStyleFreeLook:
                // Adjusted directly by -keyDown: instead.
                break;
        }
        _rotation -= (Coord)(kWheelAngularVelocity * kTickInterval);
        _coasterPosition += kCoasterPointsPerSecond * kTickInterval;
    }
    [self setNeedsDisplay:YES];
}

- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 53:  // Escape -- closes only this window, not the whole app.
            [[self window] close];
            return;
        case 126:  // Up arrow
            if (_style == CarnivalGLViewStyleFreeLook) {
                _eyeY += _step;
            }
            break;
        case 125:  // Down arrow
            if (_style == CarnivalGLViewStyleFreeLook) {
                _eyeY -= _step;
            }
            break;
        case 123:  // Left arrow
            if (_style == CarnivalGLViewStyleFreeLook) {
                _eyeX -= _step;
            }
            break;
        case 124:  // Right arrow
            if (_style == CarnivalGLViewStyleFreeLook) {
                _eyeX += _step;
            }
            break;
        default: {
            NSString *characters = [event charactersIgnoringModifiers];
            if (characters.length > 0) {
                switch ([characters characterAtIndex:0]) {
                    case ' ':
                        _animating = !_animating;
                        break;
                    case 't':
                        if (_style != CarnivalGLViewStyleFreeLook) {
                            _style = (_style == CarnivalGLViewStyleCoaster)
                                ? CarnivalGLViewStyleFerris
                                : CarnivalGLViewStyleCoaster;
                        }
                        break;
                    case 's':
                        _style = (_style == CarnivalGLViewStyleFreeLook)
                            ? CarnivalGLViewStyleCoaster
                            : CarnivalGLViewStyleFreeLook;
                        break;
                    case 'z':
                        if (_style == CarnivalGLViewStyleFreeLook) {
                            _eyeZ -= _step;
                        }
                        break;
                    case 'x':
                        if (_style == CarnivalGLViewStyleFreeLook) {
                            _eyeZ += _step;
                        }
                        break;
                    default:
                        break;
                }
            }
            break;
        }
    }
    [self setNeedsDisplay:YES];
}

@end

#endif
