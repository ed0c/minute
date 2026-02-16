import Foundation
@testable import MinuteCore

func makeClosedWindowTestSource(windowTitle: String = "Fixture Window") -> ScreenContextCaptureSource {
    ScreenContextCaptureSource(
        windowTitle: windowTitle,
        captureImageData: {
            throw MinuteError.screenCaptureUnavailable
        },
        isWindowAvailable: {
            false
        }
    )
}

func makeTransientFailureTestSource(windowTitle: String = "Fixture Window") -> ScreenContextCaptureSource {
    ScreenContextCaptureSource(
        windowTitle: windowTitle,
        captureImageData: {
            throw MinuteError.screenCaptureUnavailable
        },
        isWindowAvailable: {
            true
        }
    )
}
