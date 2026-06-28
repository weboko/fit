import Foundation

/// Zips a directory into a single `.zip` file using only Foundation.
///
/// `NSFileCoordinator` with a `.forUploading` reading intent on a directory URL
/// produces a temporary zipped copy of that directory; we then move/copy it to a
/// stable destination URL. This is the standard dependency-free way to zip a
/// folder on iOS. No SwiftUI, no third-party packages.
enum ZipPackager {

    /// Zip the contents of `directory` into a single `.zip` at `destinationURL`.
    /// `destinationURL` should already have a `.zip` extension and not exist.
    /// Returns the destination URL on success.
    @discardableResult
    static func zip(directory: URL, to destinationURL: URL) throws -> URL {
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var thrownError: Error?

        coordinator.coordinate(
            readingItemAt: directory,
            options: [.forUploading],
            error: &coordinatorError
        ) { (zippedURL: URL) in
            // `zippedURL` is a temporary .zip created by the coordinator. Copy it
            // to our destination while we are still inside the accessor block.
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: zippedURL, to: destinationURL)
            } catch {
                thrownError = error
            }
        }

        if let coordinatorError {
            throw ExportError.zipFailed(coordinatorError.localizedDescription)
        }
        if let thrownError {
            throw ExportError.zipFailed(thrownError.localizedDescription)
        }
        guard FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw ExportError.zipFailed("Archive was not produced.")
        }
        return destinationURL
    }
}
