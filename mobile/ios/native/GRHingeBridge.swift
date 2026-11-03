// gen1recomp iOS native bridge: foldable hinge state (iPhone Duo).
//
// Reached from liblove's wrap_System.cpp through the Objective-C runtime as
// love.system.getHinge() -> status, angle (see mobile/ios/patch_love_src.py).
// The Lua side (src/core/DuoPosture.lua) polls it ~10 times a second and
// lays the game and the touch pad out per posture.
//
// iOS 27.1 added UIHingeInteraction: added to a view, it reports the device
// hinge's status (closed / partially open / fully open) and angle (UIKit
// reports radians; this bridge converts to degrees for Lua). There is
// no API for where the fold sits on screen, so the Lua side derives that
// from the window geometry. On older systems, and on devices without a
// hinge, status is -1 and Lua keeps the stock layouts.
//
// Status codes: -1 no hinge, 0 unknown, 1 closed, 2 partially open, 3 fully
// open. The angle is returned in tenths of a degree as an integer so the
// C++ side needs no floating-point objc_msgSend variant.

import UIKit

@objc(GRHingeBridge)
public final class GRHingeBridge: NSObject {

    private static var status: Int = -1
    private static var angleTenths: Int = 0
    private static weak var attachedView: UIView?
    private static var interaction: AnyObject?

    /// love.system.getHinge() status code (see the header).
    @objc public static func hingeStatus() -> Int {
        attachIfNeeded()
        return status
    }

    /// Last hinge angle in tenths of a degree (1800 = flat).
    @objc public static func hingeAngleTenths() -> Int {
        return angleTenths
    }

    // MARK: - Attachment

    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first
        return active?.windows.first { $0.isKeyWindow } ?? active?.windows.first
    }

    /// Adds the interaction to the current key window, and moves it when the
    /// window changes (the Duo can hand the app from the cover display to
    /// the inner one). Lua calls this on the main thread every poll.
    private static func attachIfNeeded() {
        guard Thread.isMainThread else { return }
        guard #available(iOS 27.1, *) else { return }
        guard let window = keyWindow() else { return }
        if attachedView === window, interaction != nil { return }
        if let old = interaction as? UIHingeInteraction {
            old.view?.removeInteraction(old)
        }
        let hinge = UIHingeInteraction { _, update in
            GRHingeBridge.apply(update.hinge)
        }
        window.addInteraction(hinge)
        interaction = hinge
        attachedView = window
    }

    @available(iOS 27.1, *)
    private static func apply(_ hinge: UIHinge?) {
        guard let hinge else {
            status = -1
            angleTenths = 0
            return
        }
        switch hinge.status {
        case .closed: status = 1
        case .partiallyOpen: status = 2
        case .fullyOpen: status = 3
        default: status = 0
        }
        angleTenths = Int((Double(hinge.angle) * 180 / .pi * 10).rounded())
    }
}
