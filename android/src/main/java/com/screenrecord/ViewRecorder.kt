package com.screenrecord

import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.Rect
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import android.annotation.TargetApi
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.view.PixelCopy
import android.view.Surface
import android.view.View
import android.view.Window
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Records a view into an H.264 MP4. About `fps` times a second, the part of the window the view covers is copied
 * (`PixelCopy`, which includes what GPU-backed views such as Skia, maps and video draw, and anything on top of the
 * view) and drawn onto the encoder's input surface, which stamps each frame with the time it arrives.
 *
 * `durationMs` of 0 or less records until [stop].
 */
@TargetApi(Build.VERSION_CODES.O)
class ViewRecorder(
  private val view: View,
  private val window: Window,
  private val file: File,
  private val durationMs: Long,
  private val requestedWidth: Int,
  fps: Int,
  bitRate: Int
) {
  private val fps = fps.coerceAtLeast(1)
  private val bitRate = bitRate.coerceAtLeast(100_000)
  private val frameIntervalMs = RecordingGeometry.frameIntervalMs(this.fps)

  private val main = Handler(Looper.getMainLooper())
  private val thread = HandlerThread("ScreenRecord").apply { start() }
  private val background = Handler(thread.looper)

  private lateinit var source: Rect
  private lateinit var bitmap: Bitmap
  private lateinit var codec: MediaCodec
  private lateinit var surface: Surface
  private lateinit var muxer: MediaMuxer
  private var width = 0
  private var height = 0
  private var track = -1
  private var muxerStarted = false
  private var firstTimeUs = -1L
  private var startedAt = 0L

  private val copying = AtomicBoolean(false)
  private val stopped = AtomicBoolean(false)
  private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
  private var completion: ((Result<File>) -> Unit)? = null

  /** Starts recording; `completion` gets the file once it's written, on the main thread. Call on the main thread. */
  fun start(completion: (Result<File>) -> Unit) {
    this.completion = completion
    try {
      setUp()
    } catch (error: Throwable) {
      release()
      completion(Result.failure(error))
      return
    }
    startedAt = SystemClock.uptimeMillis()
    main.post(::capture)
  }

  private fun setUp() {
    val location = IntArray(2)
    view.getLocationInWindow(location)
    if (view.width <= 0 || view.height <= 0) {
      throw IllegalStateException("the view has no size")
    }
    val video = videoSize(view.width, view.height)
    width = video.width
    height = video.height
    val region = RecordingGeometry.sourceRegion(location[0], location[1], view.width, view.height, video)
    source = Rect(region.left, region.top, region.right, region.bottom)
    bitmap = Bitmap.createBitmap(region.width, region.height, Bitmap.Config.ARGB_8888)

    val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height).apply {
      setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
      setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
      setInteger(MediaFormat.KEY_FRAME_RATE, fps)
      setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
    }
    codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    surface = codec.createInputSurface()
    codec.start()
    file.delete()
    muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
  }

  /** The requested size if an encoder takes it, else the fallback width's: even dimensions, in the view's proportions. */
  private fun videoSize(viewWidth: Int, viewHeight: Int): VideoSize {
    val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos.filter { info ->
      info.isEncoder && info.supportedTypes.any { it.equals(MediaFormat.MIMETYPE_VIDEO_AVC, ignoreCase = true) }
    }
    for (candidate in RecordingGeometry.widthsToTry(requestedWidth)) {
      val size = RecordingGeometry.videoSize(candidate, viewWidth, viewHeight)
      val supported = codecs.any { info ->
        info.getCapabilitiesForType(MediaFormat.MIMETYPE_VIDEO_AVC)
          .videoCapabilities?.isSizeSupported(size.width, size.height) == true
      }
      if (supported) {
        return size
      }
    }
    throw IllegalStateException("no encoder takes a video this size")
  }

  /** Copies the next frame unless the last one is still on its way, until the time is up. */
  private fun capture() {
    if (stopped.get()) {
      return
    }
    if (RecordingGeometry.isFinished(SystemClock.uptimeMillis() - startedAt, durationMs)) {
      stop()
      return
    }
    if (copying.compareAndSet(false, true)) {
      try {
        PixelCopy.request(window, source, bitmap, { result ->
          if (result == PixelCopy.SUCCESS && !stopped.get()) {
            encodeFrame()
          }
          copying.set(false)
        }, background)
      } catch (error: Throwable) {
        copying.set(false)
      }
    }
    main.postDelayed(::capture, frameIntervalMs)
  }

  /** On the background thread: draws the copied frame onto the encoder and writes out what it has encoded so far. */
  private fun encodeFrame() {
    try {
      val canvas = surface.lockHardwareCanvas()
      canvas.drawBitmap(bitmap, null, Rect(0, 0, width, height), paint)
      surface.unlockCanvasAndPost(canvas)
      drain(endOfStream = false)
    } catch (error: Throwable) {
      fail(error)
    }
  }

  /** Ends the recording; the completion gets the file once the encoder has finished. Call on the main thread. */
  fun stop() {
    if (!stopped.compareAndSet(false, true)) {
      return
    }
    background.post {
      try {
        codec.signalEndOfInputStream()
        drain(endOfStream = true)
        val wroteFrames = muxerStarted
        release()
        if (wroteFrames) {
          finish(Result.success(file))
        } else {
          finish(Result.failure(IllegalStateException("no frames were recorded")))
        }
      } catch (error: Throwable) {
        release()
        finish(Result.failure(error))
      }
    }
  }

  private fun fail(error: Throwable) {
    if (stopped.compareAndSet(false, true)) {
      release()
      finish(Result.failure(error))
    }
  }

  /** Moves the encoded frames into the file. At the end, waits for the encoder to finish (two seconds at most). */
  private fun drain(endOfStream: Boolean) {
    val info = MediaCodec.BufferInfo()
    var waits = 0
    while (true) {
      val index = codec.dequeueOutputBuffer(info, if (endOfStream) 10_000L else 0L)
      when {
        index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
          if (!endOfStream || ++waits > 200) {
            return
          }
        }
        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          track = muxer.addTrack(codec.outputFormat)
          muxer.start()
          muxerStarted = true
        }
        index >= 0 -> {
          val buffer = codec.getOutputBuffer(index)
          if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
            info.size = 0
          }
          if (buffer != null && info.size > 0 && muxerStarted) {
            if (firstTimeUs < 0) {
              firstTimeUs = info.presentationTimeUs
            }
            info.presentationTimeUs = RecordingGeometry.videoTimeUs(info.presentationTimeUs, firstTimeUs)
            buffer.position(info.offset)
            buffer.limit(info.offset + info.size)
            muxer.writeSampleData(track, buffer, info)
          }
          codec.releaseOutputBuffer(index, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
            return
          }
        }
      }
    }
  }

  private fun release() {
    runCatching { codec.stop() }
    runCatching { codec.release() }
    runCatching { surface.release() }
    runCatching { if (muxerStarted) muxer.stop() }
    runCatching { muxer.release() }
    thread.quitSafely()
  }

  private fun finish(result: Result<File>) {
    main.post {
      completion?.invoke(result)
      completion = null
    }
  }
}
