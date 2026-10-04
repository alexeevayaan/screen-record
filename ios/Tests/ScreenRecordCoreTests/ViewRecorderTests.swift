import AVFoundation
import UIKit
import XCTest

@testable import ScreenRecordCore

/// Records real views into real files and reads them back. The test process has no app on screen, so the views are
/// drawn through their layers, which is what these views (plain colors) need.
final class ViewRecorderTests: XCTestCase {
  private var files: [URL] = []

  override func tearDown() {
    files.forEach { try? FileManager.default.removeItem(at: $0) }
    files = []
    super.tearDown()
  }

  func testRecordsTheViewForTheDuration() throws {
    let view = coloredView(.red, size: CGSize(width: 200, height: 100))

    let video = try inspect(try record(view, durationMs: 600, width: 400))

    XCTAssertEqual(video.size, CGSize(width: 400, height: 200))
    XCTAssertEqual(video.duration, 0.6, accuracy: 0.1)
    XCTAssertGreaterThan(video.frames, 8)
    XCTAssertLessThanOrEqual(video.frames, 20)
    assertColor(video.firstFrameCenter, isClose: (255, 0, 0))
  }

  func testRecordsChangesWhileRecording() throws {
    let view = coloredView(.red, size: CGSize(width: 100, height: 100))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      view.backgroundColor = .blue
    }

    let video = try inspect(try record(view, durationMs: 800, width: 200))

    assertColor(video.firstFrameCenter, isClose: (255, 0, 0))
    assertColor(video.lastFrameCenter, isClose: (0, 0, 255))
  }

  func testTrimsTheViewToEvenDimensions() throws {
    let view = coloredView(.green, size: CGSize(width: 333, height: 111))

    let video = try inspect(try record(view, durationMs: 300, width: 101))

    XCTAssertEqual(video.size, CGSize(width: 100, height: 34))
  }

  func testCapsTheFrameRate() throws {
    let view = coloredView(.red, size: CGSize(width: 100, height: 100))

    let video = try inspect(try record(view, durationMs: 1000, width: 100, fps: 10))

    XCTAssertGreaterThanOrEqual(video.frames, 7)
    XCTAssertLessThanOrEqual(video.frames, 11)
  }

  func testStopEndsARecordingWithoutADuration() throws {
    let view = coloredView(.red, size: CGSize(width: 100, height: 100))

    let video = try inspect(try record(view, durationMs: 0, width: 100, stopAfter: 0.4))

    XCTAssertEqual(video.duration, 0.4, accuracy: 0.15)
  }

  func testStoppingBeforeTheFirstFrameFails() throws {
    let view = coloredView(.red, size: CGSize(width: 100, height: 100))
    let recorder = try makeRecorder(view, durationMs: 1000, width: 100, fps: 30)
    let done = expectation(description: "finished")
    var result: (URL?, Error?)
    recorder.start { url, error in
      result = (url, error)
      done.fulfill()
    }
    recorder.stop()
    wait(for: [done], timeout: 5)

    XCTAssertNil(result.0)
    XCTAssertEqual((result.1 as NSError?)?.localizedDescription, "no frames were recorded")
  }

  func testRefusesAViewWithoutSize() {
    let view = UIView(frame: .zero)
    XCTAssertThrowsError(try makeRecorder(view, durationMs: 1000, width: 100, fps: 30)) { error in
      XCTAssertEqual((error as NSError).localizedDescription, "the view has no size")
    }
  }

  // MARK: Helpers

  private func coloredView(_ color: UIColor, size: CGSize) -> UIView {
    let view = UIView(frame: CGRect(origin: .zero, size: size))
    view.backgroundColor = color
    return view
  }

  private func makeRecorder(_ view: UIView, durationMs: Double, width: Int, fps: Int) throws -> SRViewRecorder {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).mp4")
    files.append(url)
    return try SRViewRecorder(view: view, url: url, durationMs: durationMs, width: width, fps: fps, bitRate: 2_000_000)
  }

  private func record(
    _ view: UIView,
    durationMs: Double,
    width: Int,
    fps: Int = 30,
    stopAfter: TimeInterval? = nil
  ) throws -> URL {
    let recorder = try makeRecorder(view, durationMs: durationMs, width: width, fps: fps)
    let done = expectation(description: "recorded")
    var result: (URL?, Error?)
    recorder.start { url, error in
      result = (url, error)
      done.fulfill()
    }
    if let stopAfter {
      DispatchQueue.main.asyncAfter(deadline: .now() + stopAfter) { recorder.stop() }
    }
    wait(for: [done], timeout: 10)
    if let error = result.1 {
      throw error
    }
    return try XCTUnwrap(result.0)
  }

  private struct Video {
    var size: CGSize
    var duration: Double
    var frames: Int
    var firstFrameCenter: (Int, Int, Int)
    var lastFrameCenter: (Int, Int, Int)
  }

  /// Reads the video back: its size, length, number of frames and the color in the middle of the first and last.
  private func inspect(_ url: URL) throws -> Video {
    let asset = AVURLAsset(url: url)
    let track = try XCTUnwrap(asset.tracks(withMediaType: .video).first)
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
      track: track,
      outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    )
    reader.add(output)
    XCTAssertTrue(reader.startReading())
    var frames = 0
    var first: (Int, Int, Int)?
    var last = (0, 0, 0)
    while let sample = output.copyNextSampleBuffer() {
      guard let buffer = CMSampleBufferGetImageBuffer(sample) else {
        continue
      }
      frames += 1
      last = centerColor(of: buffer)
      first = first ?? last
    }
    return Video(
      size: track.naturalSize,
      duration: asset.duration.seconds,
      frames: frames,
      firstFrameCenter: try XCTUnwrap(first),
      lastFrameCenter: last
    )
  }

  private func centerColor(of buffer: CVPixelBuffer) -> (Int, Int, Int) {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    let pixel = base
      + CVPixelBufferGetHeight(buffer) / 2 * CVPixelBufferGetBytesPerRow(buffer)
      + CVPixelBufferGetWidth(buffer) / 2 * 4
    return (Int(pixel[2]), Int(pixel[1]), Int(pixel[0]))
  }

  /// Video compression shifts colors a little.
  private func assertColor(
    _ color: (Int, Int, Int),
    isClose expected: (Int, Int, Int),
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let distance = max(abs(color.0 - expected.0), abs(color.1 - expected.1), abs(color.2 - expected.2))
    XCTAssertLessThan(distance, 40, "\(color) isn't close to \(expected)", file: file, line: line)
  }
}
