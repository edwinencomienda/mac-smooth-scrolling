import Cocoa
import CoreGraphics

final class ScrollEngine {
    static let shared = ScrollEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var displayLink: CVDisplayLink?

    // Momentum state — the remaining distance we still owe the user.
    private var pendingX: Double = 0
    private var pendingY: Double = 0

    // Sub-pixel accumulator so small frame deltas aren't lost to Int32 rounding.
    private var residualX: Double = 0
    private var residualY: Double = 0

    private let lock = NSLock()

    // Fraction of remaining distance consumed per frame (~60fps).
    // 0.15 → ~95% travelled in ~18 frames (~300ms). Higher = snappier.
    private let frameFraction: Double = 0.15

    // Throttle for Cmd+Shift+scroll jump-to-top/bottom.
    private var lastJumpTime: CFTimeInterval = 0
    private let jumpThrottle: CFTimeInterval = 0.4

    func start() {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.scrollWheel.rawValue)
        let tap = CGEvent.tapCreate(
            tap: .cgAnnotatedSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<ScrollEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap = tap else {
            NSLog("Failed to create event tap — Accessibility permission missing?")
            return
        }

        self.eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        startDisplayLink()
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        stopDisplayLink()
    }

    // MARK: - Event tap callback

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard Settings.shared.enabled else {
            return Unmanaged.passUnretained(event)
        }

        // Prefer point deltas (sub-pixel), fall back to line deltas * 10.
        let pointY = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let pointX = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
        let lineY = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        let lineX = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
        let dY = pointY != 0 ? pointY : lineY * 10
        let dX = pointX != 0 ? pointX : lineX * 10

        // Configured modifier + scroll → jump to top (scroll up) or bottom (scroll down).
        // Handled for both wheel and continuous devices.
        let flags = event.flags
        let requiredJumpFlags = CGEventFlags(rawValue: Settings.shared.jumpModifierFlags)
        let hasJumpModifiers = requiredJumpFlags.rawValue != 0 && flags.contains(requiredJumpFlags)
        if Settings.shared.jumpShortcutEnabled && hasJumpModifiers {
            if dY != 0 {
                let now = CACurrentMediaTime()
                if now - lastJumpTime >= jumpThrottle {
                    lastJumpTime = now
                    let reversed = Settings.shared.reverse
                    let up = reversed ? (dY < 0) : (dY > 0)
                    jumpToEdge(up: up)
                }
            }
            return nil
        }

        // Skip trackpad / Magic Mouse for smoothing — macOS already smooths those.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        if isContinuous {
            return Unmanaged.passUnretained(event)
        }

        if dY == 0 && dX == 0 {
            return Unmanaged.passUnretained(event)
        }

        let sign: Double = Settings.shared.reverse ? -1 : 1
        let speed = Settings.shared.speed

        // Shift + wheel → horizontal scroll. Re-route the wheel's Y delta onto the X axis.
        // Exclude Command/Option/Control so jump shortcuts aren't misread as horizontal scroll.
        let shiftOnly = flags.contains(.maskShift)
            && !flags.contains(.maskCommand)
            && !flags.contains(.maskAlternate)
            && !flags.contains(.maskControl)

        lock.lock()
        if shiftOnly {
            pendingX += dY * speed * sign
        } else {
            pendingY += dY * speed * sign
            pendingX += dX * speed * sign
        }
        lock.unlock()

        // Swallow original — the display link will emit smoothed events.
        return nil
    }

    // MARK: - Display link (per-frame tick)

    private func startDisplayLink() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link = link else { return }
        self.displayLink = link
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, ctx in
            guard let ctx = ctx else { return kCVReturnSuccess }
            let engine = Unmanaged<ScrollEngine>.fromOpaque(ctx).takeUnretainedValue()
            engine.tick()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
    }

    private func tick() {
        lock.lock()
        let py = pendingY
        let px = pendingX

        // Nothing to do.
        if abs(py) < 0.01 && abs(px) < 0.01 {
            pendingY = 0; pendingX = 0
            residualY = 0; residualX = 0
            lock.unlock()
            return
        }

        // Consume a fraction this frame — exponential ease-out.
        var consumeY = py * frameFraction
        var consumeX = px * frameFraction

        // When the remainder is tiny, finish it off so we don't asymptote forever.
        if abs(py) < 1.0 { consumeY = py }
        if abs(px) < 1.0 { consumeX = px }

        pendingY -= consumeY
        pendingX -= consumeX

        // Accumulate sub-pixel remainder into residual so Int32 rounding never drops motion.
        residualY += consumeY
        residualX += consumeX
        let emitY = residualY.rounded(.towardZero)
        let emitX = residualX.rounded(.towardZero)
        residualY -= emitY
        residualX -= emitX
        lock.unlock()

        if emitY == 0 && emitX == 0 { return }

        post(deltaX: emitX, deltaY: emitY, fineX: consumeX, fineY: consumeY)
    }

    private func post(deltaX: Double, deltaY: Double, fineX: Double, fineY: Double) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: Int32(deltaY),
            wheel2: Int32(deltaX),
            wheel3: 0
        ) else { return }
        // Carry the precise sub-pixel value so apps that read point-delta get smooth motion.
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: fineY)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: fineX)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.post(tap: .cgSessionEventTap)
    }

    // MARK: - Jump to top/bottom

    private func jumpToEdge(up: Bool) {
        // Clear any in-flight smoothing so the jump isn't fought by momentum.
        lock.lock()
        pendingX = 0; pendingY = 0
        residualX = 0; residualY = 0
        lock.unlock()

        // One huge scroll event. Positive Y = scroll up (toward content top).
        let magnitude: Int32 = 100_000
        let deltaY: Int32 = up ? magnitude : -magnitude

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: deltaY,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        // Clear modifier flags so apps don't interpret this as Cmd+scroll (zoom, etc.).
        event.flags = []
        event.post(tap: .cgSessionEventTap)
    }
}
