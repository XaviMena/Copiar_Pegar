import AppKit
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
    var onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView()
        view.onWindowChange = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observerView = nsView as? WindowObserverView {
            observerView.onWindowChange = onResolve
            if let window = observerView.window, context.coordinator.lastResolvedWindow !== window {
                context.coordinator.lastResolvedWindow = window
                DispatchQueue.main.async {
                    onResolve(window)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        weak var lastResolvedWindow: NSWindow?
    }
}

private final class WindowObserverView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let currentWindow = window
        DispatchQueue.main.async { [weak self] in
            self?.onWindowChange?(currentWindow)
        }
    }
}
