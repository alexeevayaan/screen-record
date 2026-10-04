package com.screenrecord

import android.net.Uri
import android.os.Build
import android.view.View
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.UiThreadUtil
import com.facebook.react.uimanager.UIManagerHelper
import java.io.File

class ScreenRecordModule(reactContext: ReactApplicationContext) :
  NativeScreenRecordSpec(reactContext) {

  /** The recording in progress, touched on the UI thread only. One at a time: they'd compete for the encoder. */
  @Volatile private var recorder: ViewRecorder? = null

  override fun startRecording(
    viewTag: Double,
    durationMs: Double,
    width: Double,
    fps: Double,
    bitRate: Double,
    promise: Promise
  ) {
    UiThreadUtil.runOnUiThread {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
        promise.reject("E_UNSUPPORTED", "Recording needs Android 8 or newer")
        return@runOnUiThread
      }
      if (recorder != null) {
        promise.reject("E_BUSY", "A recording is already in progress")
        return@runOnUiThread
      }
      val window = reactApplicationContext.currentActivity?.window
      if (window == null) {
        promise.reject("E_NO_VIEW", "There's no window to record")
        return@runOnUiThread
      }
      val tag = viewTag.toInt()
      val view: View? = if (tag == WINDOW_TAG) {
        window.decorView
      } else {
        UIManagerHelper.getUIManagerForReactTag(reactApplicationContext, tag)?.resolveView(tag)
      }
      if (view == null) {
        promise.reject("E_NO_VIEW", "No view with tag $tag")
        return@runOnUiThread
      }
      val file = File(reactApplicationContext.cacheDir, "screen-record-${System.currentTimeMillis()}.mp4")
      val next = ViewRecorder(view, window, file, durationMs.toLong(), width.toInt(), fps.toInt(), bitRate.toInt())
      recorder = next
      next.start { result ->
        recorder = null
        result.fold(
          { promise.resolve(Uri.fromFile(it).toString()) },
          { promise.reject("E_RECORDING", it.message ?: "Could not record the video", it) }
        )
      }
    }
  }

  override fun stopRecording() {
    UiThreadUtil.runOnUiThread { recorder?.stop() }
  }

  override fun isRecording(): Boolean = recorder != null

  companion object {
    const val NAME = NativeScreenRecordSpec.NAME

    /** The tag JS passes to record the whole window. */
    private const val WINDOW_TAG = -1
  }
}
