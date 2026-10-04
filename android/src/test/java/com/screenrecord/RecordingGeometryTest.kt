package com.screenrecord

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RecordingGeometryTest {
  // videoSize

  @Test
  fun keepsTheViewsProportions() {
    // 1080 × 2992 / 1344 = 2404.3, rounded to an even 2404.
    assertEquals(VideoSize(1080, 2404), RecordingGeometry.videoSize(1080, 1344, 2992))
  }

  @Test
  fun squareViewMakesASquareVideo() {
    assertEquals(VideoSize(1080, 1080), RecordingGeometry.videoSize(1080, 660, 660))
  }

  @Test
  fun makesTheWidthEven() {
    assertEquals(1080, RecordingGeometry.videoSize(1081, 100, 100).width)
  }

  @Test
  fun makesTheHeightEven() {
    // 100 × 111 / 333 = 33.3, which an even height rounds to 34.
    assertEquals(VideoSize(100, 34), RecordingGeometry.videoSize(101, 333, 111))
  }

  @Test
  fun isAtLeastTwoPixelsEachWay() {
    assertEquals(VideoSize(2, 2), RecordingGeometry.videoSize(1, 100, 100))
    assertEquals(2, RecordingGeometry.videoSize(1080, 10_000, 1).height)
  }

  @Test
  fun viewWithoutSizeGetsASquare() {
    assertEquals(VideoSize(720, 720), RecordingGeometry.videoSize(720, 0, 0))
  }

  // widthsToTry

  @Test
  fun triesTheRequestedWidthFirstThenTheFallback() {
    assertEquals(listOf(1080, 720), RecordingGeometry.widthsToTry(1080))
  }

  @Test
  fun triesTheFallbackOnceWhenItWasRequested() {
    assertEquals(listOf(720), RecordingGeometry.widthsToTry(720))
  }

  // sourceRegion

  @Test
  fun copiesAllOfAViewOfTheSameProportions() {
    val video = VideoSize(400, 200)
    assertEquals(Region(10, 20, 200, 100), RecordingGeometry.sourceRegion(10, 20, 200, 100, video))
  }

  @Test
  fun trimsTheSidesOfAWiderView() {
    val region = RecordingGeometry.sourceRegion(0, 0, 300, 100, VideoSize(200, 100))
    assertEquals(Region(50, 0, 200, 100), region)
  }

  @Test
  fun trimsTheTopAndBottomOfATallerView() {
    val region = RecordingGeometry.sourceRegion(0, 0, 100, 300, VideoSize(100, 200))
    assertEquals(Region(0, 50, 100, 200), region)
  }

  @Test
  fun keepsTheViewsPlaceInTheWindow() {
    val region = RecordingGeometry.sourceRegion(40, 156, 1264, 2000, VideoSize(1080, 1708))
    assertEquals(40 + (1264 - region.width) / 2, region.left)
    assertEquals(156 + (2000 - region.height) / 2, region.top)
    assertEquals(region.left + region.width, region.right)
    assertEquals(region.top + region.height, region.bottom)
  }

  // frameIntervalMs

  @Test
  fun spacesFramesForTheFrameRate() {
    assertEquals(33L, RecordingGeometry.frameIntervalMs(30))
    assertEquals(100L, RecordingGeometry.frameIntervalMs(10))
  }

  @Test
  fun neverWaitsLessThanAMillisecond() {
    assertEquals(1L, RecordingGeometry.frameIntervalMs(5000))
    assertEquals(1000L, RecordingGeometry.frameIntervalMs(0))
  }

  // isFinished

  @Test
  fun finishesWhenTheDurationIsUp() {
    assertFalse(RecordingGeometry.isFinished(4999, 5000))
    assertTrue(RecordingGeometry.isFinished(5000, 5000))
  }

  @Test
  fun withoutADurationRecordsUntilStopped() {
    assertFalse(RecordingGeometry.isFinished(Long.MAX_VALUE, 0))
    assertFalse(RecordingGeometry.isFinished(Long.MAX_VALUE, -1))
  }

  // videoTimeUs

  @Test
  fun videoStartsAtItsFirstFrame() {
    assertEquals(0L, RecordingGeometry.videoTimeUs(9_000_000_000, 9_000_000_000))
    assertEquals(33_333L, RecordingGeometry.videoTimeUs(9_000_033_333, 9_000_000_000))
  }
}
