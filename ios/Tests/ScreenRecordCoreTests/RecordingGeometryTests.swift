import CoreGraphics
import XCTest

@testable import ScreenRecordCore

final class RecordingGeometryTests: XCTestCase {
  // MARK: SRVideoSize

  func testKeepsTheViewsProportions() {
    // 1080 × 700 / 393 = 1923.7, rounded to an even 1924.
    XCTAssertEqual(SRVideoSize(1080, CGSize(width: 393, height: 700)), CGSize(width: 1080, height: 1924))
  }

  func testSquareViewMakesASquareVideo() {
    XCTAssertEqual(SRVideoSize(1080, CGSize(width: 240, height: 240)), CGSize(width: 1080, height: 1080))
  }

  func testMakesTheWidthEven() {
    XCTAssertEqual(SRVideoSize(1081, CGSize(width: 100, height: 100)).width, 1080)
  }

  func testMakesTheHeightEven() {
    // 100 × 111 / 333 = 33.3, which an even height rounds to 34.
    XCTAssertEqual(SRVideoSize(101, CGSize(width: 333, height: 111)), CGSize(width: 100, height: 34))
  }

  func testIsAtLeastTwoPixelsEachWay() {
    XCTAssertEqual(SRVideoSize(1, CGSize(width: 100, height: 100)), CGSize(width: 2, height: 2))
    XCTAssertEqual(SRVideoSize(1080, CGSize(width: 10_000, height: 1)).height, 2)
  }

  func testViewWithoutSizeGetsASquare() {
    XCTAssertEqual(SRVideoSize(720, .zero), CGSize(width: 720, height: 720))
  }

  // MARK: SRSourceRect

  func testRecordsAllOfAViewOfTheSameProportions() {
    let rect = SRSourceRect(CGSize(width: 200, height: 100), CGSize(width: 400, height: 200))
    XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 200, height: 100))
  }

  func testTrimsTheSidesOfAWiderView() {
    let video = CGSize(width: 400, height: 134)
    let rect = SRSourceRect(CGSize(width: 300, height: 100), video)
    XCTAssertEqual(rect.height, 100)
    XCTAssertEqual(rect.width / rect.height, video.width / video.height, accuracy: 1e-9)
    // Centered: as much left out on the left as on the right.
    XCTAssertEqual(rect.minX, 300 - rect.maxX, accuracy: 1e-9)
  }

  func testTrimsTheTopAndBottomOfATallerView() {
    let video = CGSize(width: 200, height: 598)
    let rect = SRSourceRect(CGSize(width: 100, height: 300), video)
    XCTAssertEqual(rect.width, 100)
    XCTAssertEqual(rect.width / rect.height, video.width / video.height, accuracy: 1e-9)
    XCTAssertEqual(rect.minY, 300 - rect.maxY, accuracy: 1e-9)
  }

  // MARK: SRFrameDue

  func testFrameIsDueAfterTheInterval() {
    XCTAssertTrue(SRFrameDue(1.0 / 30, 0, 1.0 / 30))
    XCTAssertTrue(SRFrameDue(0, -.infinity, 1.0 / 30))
  }

  func testFrameIsNotDueTooSoon() {
    // A 120 Hz display refreshes four times per frame at 30 fps.
    XCTAssertFalse(SRFrameDue(1.0 / 120, 0, 1.0 / 30))
    XCTAssertFalse(SRFrameDue(2.0 / 120, 0, 1.0 / 30))
  }

  func testFrameIsDueSlightlyEarly() {
    // Refreshes don't line up exactly with the frame rate.
    XCTAssertTrue(SRFrameDue(0.95 / 30, 0, 1.0 / 30))
  }
}
