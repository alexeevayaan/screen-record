package com.screenrecord

import com.facebook.react.bridge.ReactApplicationContext

class ScreenRecordModule(reactContext: ReactApplicationContext) :
  NativeScreenRecordSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeScreenRecordSpec.NAME
  }
}
