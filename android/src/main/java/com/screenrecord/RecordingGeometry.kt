package com.screenrecord

import kotlin.math.roundToInt

/** A size in pixels. */
data class VideoSize(val width: Int, val height: Int)

/** A rectangle in pixels. */
data class Region(val left: Int, val top: Int, val width: Int, val height: Int) {
  val right get() = left + width
  val bottom get() = top + height
}

/**
 * The sizes and timing of a recording, kept apart from the Android APIs that use them so that they can be tested on
 * their own (and match the iOS side's `SRRecordingGeometry`).
 */
object RecordingGeometry {
  /** Encoders don't all take every size, but every one takes this width. */
  const val FALLBACK_WIDTH = 720

  /** The widths to try, in order: the requested one, then the fallback. */
  fun widthsToTry(requestedWidth: Int): List<Int> = listOf(requestedWidth, FALLBACK_WIDTH).distinct()

  /**
   * The video's size for a view of `viewWidth` × `viewHeight`: `width` wide (made even, at least 2) and as tall as the
   * view's proportions make it, rounded to an even number, as H.264 needs.
   */
  fun videoSize(width: Int, viewWidth: Int, viewHeight: Int): VideoSize {
    val w = (width / 2 * 2).coerceAtLeast(2)
    if (viewWidth <= 0 || viewHeight <= 0) {
      return VideoSize(w, w)
    }
    val h = ((w.toDouble() * viewHeight / viewWidth / 2).roundToInt() * 2).coerceAtLeast(2)
    return VideoSize(w, h)
  }

  /**
   * The part of the window copied for a view at (`viewLeft`, `viewTop`) of `viewWidth` × `viewHeight`: all of it,
   * trimmed evenly on two sides to the video's proportions, which rounding can make slightly different from the view's.
   */
  fun sourceRegion(viewLeft: Int, viewTop: Int, viewWidth: Int, viewHeight: Int, video: VideoSize): Region {
    val aspect = video.width.toDouble() / video.height
    var width = viewWidth
    var height = viewHeight
    if (viewWidth.toDouble() / viewHeight > aspect) {
      width = (viewHeight * aspect).roundToInt()
    } else {
      height = (viewWidth / aspect).roundToInt()
    }
    return Region(viewLeft + (viewWidth - width) / 2, viewTop + (viewHeight - height) / 2, width, height)
  }

  /** How long to wait between frames at `fps` frames a second: at least a millisecond. */
  fun frameIntervalMs(fps: Int): Long = (1000L / fps.coerceAtLeast(1)).coerceAtLeast(1)

  /** Whether a recording of `durationMs` (0 or less: until it's stopped) is over after `elapsedMs`. */
  fun isFinished(elapsedMs: Long, durationMs: Long): Boolean = durationMs > 0 && elapsedMs >= durationMs

  /**
   * A frame's time in the video: encoders stamp frames with the device's clock, and the video starts at its first
   * frame.
   */
  fun videoTimeUs(frameTimeUs: Long, firstFrameTimeUs: Long): Long = frameTimeUs - firstFrameTimeUs
}
