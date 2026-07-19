package com.videomoney.app

import android.app.Application

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        GraviteAatkitManager.initialize(this)
    }
}
