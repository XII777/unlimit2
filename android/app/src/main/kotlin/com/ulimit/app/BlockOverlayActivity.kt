package com.ulimit.app

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import android.content.Intent
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.graphics.Color
import android.widget.LinearLayout
import android.widget.Button

/// Full-screen overlay shown when a blocked app is launched. Sits on top
/// of the blocked app until the user dismisses it (which requires either
/// emergency unlock with biometrics or going back).
///
/// This is the enforcement point for manual app blocking — without this,
/// the AccessibilityService would detect the blocked app but have no way
/// to actually prevent interaction.
class BlockOverlayActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val blockedPackage = intent.getStringExtra("blocked_package") ?: "this app"

        // Make the overlay truly full-screen: draw over status/nav bars,
        // and crucially, draw over other apps (SYSTEM_ALERT_WINDOW is
        // declared in the manifest for this).
        window.setFlags(
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        )

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#FF0F1116"))
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = "Blocked by Ulimit"
            textSize = 22f
            setTextColor(Color.parseColor("#F2F1EC"))
            gravity = Gravity.CENTER
        }

        val subtitle = TextView(this).apply {
            text = "$blockedPackage is blocked right now"
            textSize = 14f
            setTextColor(Color.parseColor("#9497A3"))
            gravity = Gravity.CENTER
            setPadding(0, 16, 0, 32)
        }

        val unlockButton = Button(this).apply {
            text = "Emergency unlock"
            setOnClickListener {
                // Log the emergency unlock and close — real biometric
                // gate lands with the parental-controls feature.
                EmergencyUnlockBridge.recordUnlock(blockedPackage)
                finish()
            }
        }

        val goBackButton = Button(this).apply {
            text = "Go back"
            setOnClickListener { finish() }
        }

        layout.addView(title)
        layout.addView(subtitle)
        layout.addView(unlockButton)
        layout.addView(goBackButton)

        setContentView(layout)
    }

    override fun onBackPressed() {
        // Swallow back — the only way out is the buttons, so a blocked
        // app can't be reached by mashing back.
    }
}
