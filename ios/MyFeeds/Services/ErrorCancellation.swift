import Foundation

extension Error {
    /// True when a load was stopped rather than failed: the screen went away
    /// (switching tabs cancels its task) or a newer load replaced it. Screens
    /// skip their error message and offline banner for these, so a tab switch
    /// never shows "Couldn't load … CancellationError". Also looks inside
    /// errors that wrap a cancellation (the Supabase client does this).
    nonisolated var isCancellation: Bool {
        if self is CancellationError { return true }
        if let urlError = self as? URLError, urlError.code == .cancelled { return true }
        let ns = self as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error, underlying.isCancellation { return true }
        return String(describing: self).contains("CancellationError")
    }
}
