import XCTest
@testable import PrimitiveCore

final class PrimitiveCoreTests: XCTestCase {
    func testTriangleCommand() throws {
        let settings = RenderSettings(
            shapeMode: .triangle,
            shapeCount: 200,
            alpha: 96,
            inputSize: 256,
            outputSize: 2048,
            format: .png
        )
        let args = try PrimitiveCommandBuilder().arguments(
            input: URL(fileURLWithPath: "/tmp/in photo.jpg"),
            outputs: [URL(fileURLWithPath: "/tmp/out.png")],
            settings: settings
        )

        XCTAssertEqual(Array(args.prefix(12)), [
            "-i", "/tmp/in photo.jpg",
            "-n", "200",
            "-m", "1",
            "-a", "96",
            "-r", "256",
            "-s", "2048"
        ])
        XCTAssertTrue(args.contains("-j"))
        XCTAssertTrue(args.contains("0"))
        XCTAssertTrue(args.contains("-o"))
        XCTAssertEqual(args.last, "-v")
    }

    func testMultipleOutputsAndFrameStride() throws {
        let args = try PrimitiveCommandBuilder().arguments(
            input: URL(fileURLWithPath: "/tmp/input.png"),
            outputs: [
                URL(fileURLWithPath: "/tmp/preview.png"),
                URL(fileURLWithPath: "/tmp/frame-%04d.png")
            ],
            settings: RenderSettings(shapeMode: .circle, shapeCount: 100),
            frameStride: 5
        )
        XCTAssertTrue(args.contains("-nth"))
        XCTAssertTrue(args.contains("5"))
        XCTAssertEqual(args.filter { $0 == "-o" }.count, 2)
    }

    func testValidationRejectsBadAlpha() {
        XCTAssertThrowsError(try RenderSettings(alpha: 300).validated()) { error in
            XCTAssertEqual(error as? RenderValidationError, .invalidAlpha)
        }
    }

    func testShapeCountLimitIsTwentyThousand() throws {
        XCTAssertEqual(try RenderSettings(shapeCount: 20_000).validated().shapeCount, 20_000)
        XCTAssertThrowsError(try RenderSettings(shapeCount: 20_001).validated()) { error in
            XCTAssertEqual(error as? RenderValidationError, .invalidShapeCount)
        }
    }

    func testAllUpstreamShapeModesRemainStable() {
        XCTAssertEqual(ShapeMode.allCases.map(\.rawValue), Array(0...8))
    }

    func testQuickPreviewIsBoundedAndKeepsStyle() {
        let full = RenderSettings(
            shapeMode: .polygon,
            shapeCount: 600,
            alpha: 111,
            inputSize: 512,
            outputSize: 4096,
            format: .svg
        )
        let preview = full.quickPreviewSettings()

        XCTAssertEqual(preview.shapeMode, .polygon)
        XCTAssertEqual(preview.alpha, 111)
        XCTAssertEqual(preview.shapeCount, 120)
        XCTAssertEqual(preview.inputSize, 256)
        XCTAssertEqual(preview.outputSize, 1536)
        XCTAssertEqual(preview.format, .png)
    }

    func testPresetMatchingIgnoresExportFormat() {
        var settings = ArtPreset.portrait.settings!
        settings.format = .svg
        XCTAssertEqual(ArtPreset.matching(settings), .portrait)

        settings.shapeCount += 1
        XCTAssertEqual(ArtPreset.matching(settings), .custom)
    }
}
