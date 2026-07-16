import AppKit

@MainActor
final class WaveStatusIconAnimator: NSObject {
    private let onFrame: (NSImage) -> Void
    private var timer: Timer?
    private var phase: CGFloat = 0

    init(onFrame: @escaping (NSImage) -> Void) {
        self.onFrame = onFrame
        super.init()
        render()
    }

    func setAnimating(_ shouldAnimate: Bool) {
        if shouldAnimate {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(
                timeInterval: 1.0 / 24.0,
                target: self,
                selector: #selector(handleTimerTick),
                userInfo: nil,
                repeats: true
            )
        } else {
            timer?.invalidate()
            timer = nil
            phase = 0
            render()
        }
    }

    private func render() {
        onFrame(Self.image(phase: phase))
    }

    private func advanceFrame() {
        phase += .pi / 8
        render()
    }

    @objc private func handleTimerTick() {
        advanceFrame()
    }

    static func image(phase: CGFloat) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1.6
        for x in stride(from: CGFloat(1), through: size.width - 1, by: 0.5) {
            let progress = x / size.width
            let y = size.height / 2 + sin(progress * .pi * 3 + phase) * 3.2
            if x == 1 {
                path.move(to: NSPoint(x: x, y: y))
            } else {
                path.line(to: NSPoint(x: x, y: y))
            }
        }
        path.stroke()
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}
