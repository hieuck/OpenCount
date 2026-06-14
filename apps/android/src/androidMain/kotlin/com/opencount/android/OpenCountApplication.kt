package com.opencount.android

import android.app.Application
import com.opencount.shared.service.PlatformStorage

class OpenCountApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PlatformStorage.init(this)
    }
}
