import AppKit
import SwiftUI

/// Moves the window's close, minimize and zoom buttons inside the sidebar's glass panel, so they sit in its
/// top-left corner instead of straddling the panel's edge. AppKit lays the buttons out again on resize, full screen
/// and key changes, so the inset is re-applied after each of those.
struct TrafficLightInset: NSViewRepresentable {
    /// Distance from the window's left edge to the close button.
    var x: CGFloat = 24
    /// Distance from the window's top edge to the buttons' vertical center.
    var centerY: CGFloat = 28

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.x = x
        view.centerY = centerY
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingView)?.reposition()
    }

    final class TrackingView: NSView {
        var x: CGFloat = 0
        var centerY: CGFloat = 0
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            let names: [Notification.Name] = [
                NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
                NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification, NSWindow.didChangeScreenNotification,
            ]
            for name in names {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.reposition()
                })
            }
            // SwiftUI finishes the title bar after the first layout pass.
            DispatchQueue.main.async { self.reposition() }
        }


        func reposition() {
            guard let window, !window.styleMask.contains(.fullScreen),
                  let close = window.standardWindowButton(.closeButton),
                  let mini = window.standardWindowButton(.miniaturizeButton),
                  let zoom = window.standardWindowButton(.zoomButton),
                  let titlebar = close.superview, let container = titlebar.superview else { return }

            // Grow the title bar container down far enough to hold the buttons at the new height.
            let buttonHeight = close.frame.height
            let height = centerY + buttonHeight / 2 + 4
            var frame = container.frame
            if frame.height != height {
                frame.size.height = height
                frame.origin.y = window.frame.height - height
                container.frame = frame
            }

            let spacing = mini.frame.minX - close.frame.minX
            let y = titlebar.bounds.height - centerY - buttonHeight / 2
            for (index, button) in [close, mini, zoom].enumerated() {
                let origin = NSPoint(x: x + CGFloat(index) * spacing, y: titlebar.isFlipped ? centerY - buttonHeight / 2 : y)
                if button.frame.origin != origin { button.setFrameOrigin(origin) }
            }
        }
    }
}
