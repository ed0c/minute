import CoreGraphics
import CoreVideo
import Foundation
@preconcurrency import ScreenCaptureKit

public enum ScreenCaptureKitAdapter {
    public static func fetchShareableContent(
        excludingDesktopWindows: Bool,
        onScreenWindowsOnly: Bool,
        fallbackError: Error
    ) async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(excludingDesktopWindows, onScreenWindowsOnly: onScreenWindowsOnly) {
                content,
                error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: fallbackError)
                }
            }
        }
    }

    public static func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration,
        fallbackError: Error
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: fallbackError)
                }
            }
        }
    }

    public static func startCapture(stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public static func stopCapture(stream: SCStream) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.stopCapture { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    public static func makeScreenshotConfiguration(
        contentRect: CGRect,
        pointPixelScale: CGFloat,
        capturesAudio: Bool,
        showsCursor: Bool,
        scalesToFit: Bool,
        maxDimension: CGFloat? = nil
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = capturesAudio
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = showsCursor
        configuration.scalesToFit = scalesToFit

        guard contentRect.width > 0, contentRect.height > 0 else {
            return configuration
        }

        let sourceWidth = contentRect.width * pointPixelScale
        let sourceHeight = contentRect.height * pointPixelScale

        let fitRatio: CGFloat
        if let maxDimension {
            fitRatio = min(1.0, maxDimension / max(sourceWidth, sourceHeight))
        } else {
            fitRatio = 1.0
        }

        configuration.width = size_t(max(1, Int(sourceWidth * fitRatio)))
        configuration.height = size_t(max(1, Int(sourceHeight * fitRatio)))
        return configuration
    }
}
