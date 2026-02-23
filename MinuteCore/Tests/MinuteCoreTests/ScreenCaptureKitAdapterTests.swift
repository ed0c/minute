import CoreGraphics
@preconcurrency import ScreenCaptureKit
import Testing
@testable import MinuteCore

struct ScreenCaptureKitAdapterTests {
    @Test
    func makeScreenshotConfiguration_appliesPixelScale() {
        let configuration = ScreenCaptureKitAdapter.makeScreenshotConfiguration(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 50),
            pointPixelScale: 2,
            capturesAudio: false,
            showsCursor: false,
            scalesToFit: false
        )

        #expect(configuration.width == 200)
        #expect(configuration.height == 100)
        #expect(configuration.capturesAudio == false)
        #expect(configuration.showsCursor == false)
        #expect(configuration.scalesToFit == false)
    }

    @Test
    func makeScreenshotConfiguration_respectsMaxDimensionFit() {
        let configuration = ScreenCaptureKitAdapter.makeScreenshotConfiguration(
            contentRect: CGRect(x: 0, y: 0, width: 1600, height: 800),
            pointPixelScale: 1,
            capturesAudio: false,
            showsCursor: false,
            scalesToFit: true,
            maxDimension: 560
        )

        #expect(configuration.width == 560)
        #expect(configuration.height == 280)
        #expect(configuration.scalesToFit)
    }

    @Test
    func makeScreenshotConfiguration_zeroRect_keepsDefaultDimensions() {
        let baseline = SCStreamConfiguration()
        let configuration = ScreenCaptureKitAdapter.makeScreenshotConfiguration(
            contentRect: .zero,
            pointPixelScale: 2,
            capturesAudio: false,
            showsCursor: false,
            scalesToFit: false
        )

        #expect(configuration.width == baseline.width)
        #expect(configuration.height == baseline.height)
    }
}
