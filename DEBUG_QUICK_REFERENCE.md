# Quick Reference - Debug Logging

## 🎯 What Changed

### ❌ Removed
```
💰 [ETH] Total: 9902.8835 = currentPrice(1980.5767) × quantity(5.0)
💰 [XRP] Total: 2959.1175936 = currentPrice(1.3598886) × quantity(2176.0)
```
These cluttered the console every time portfolio value was calculated.

### ✅ Added
Structured, controlled debug logging with categories and verbosity levels.

---

## 🎚️ Verbosity Levels Quick Guide

| Level | Output | Use Case |
|-------|--------|----------|
| **Silent** | Nothing | Production |
| **Errors** | Errors only | Normal use |
| **Important** | Major operations | Monitoring |
| **Detailed** | All operations | **Troubleshooting** ⭐ |
| **Verbose** | Everything | Development |

---

## 📋 Log Categories Quick Reference

| Emoji | Category | What It Logs |
|-------|----------|--------------|
| 🔄 | REFRESH | Portfolio refresh operations |
| 📡 | API | API calls to Marketstack |
| 💾 | CACHE | Cache hits/misses |
| ⏳ | COOLDOWN | Refresh timing/cooldown status |
| 📦 | BATCH | Batch processing progress |
| ❌ | ERROR | Error messages |
| ✅ | SUCCESS | Success messages |
| ⚠️ | WARNING | Warning messages |
| ⚡ | PERFORMANCE | Timing and metrics |

---

## 🔧 How to Use

### In Settings UI (DebugSettingsView)
1. Go to Settings → Debug Logging
2. Choose verbosity level
3. Enable/disable categories
4. Use presets (Normal, Troubleshooting, Development)

### In Code
```swift
// Log a message
await DebugLogger.shared.log(.refresh, "Message", verbosity: .detailed)

// Or use convenience functions
logRefresh("Starting operation")
logError("Failed", error: someError)
logSuccess("Completed")

// Change verbosity
await DebugLogger.shared.setVerbosity(.detailed)
```

---

## 📊 Example Output (Detailed Mode)

```
════════════════════════════════════════
🔄 REFRESH Starting portfolio refresh
🔄 REFRESH Assets to update: 12
🔄 REFRESH Bypass cooldown: true
════════════════════════════════════════
📦 BATCH Batch 1/3 - Processing 5 assets
✅ SUCCESS [SPY] Updated to $485.50
✅ SUCCESS [AAPL] Updated to $185.50
✅ SUCCESS [MSFT] Updated to $380.20
✅ SUCCESS [GOOGL] Updated to $140.50
✅ SUCCESS [TSLA] Updated to $245.30
📦 BATCH Batch 1/3 complete - ✅ 5 | ❌ 0
📦 BATCH Batch 2/3 - Processing 5 assets
...
════════════════════════════════════════
🔄 REFRESH Refresh complete in 2.34s
🔄 REFRESH Success: 12/12
🔄 REFRESH Failed: 0/12
════════════════════════════════════════
```

---

## 🐛 Common Troubleshooting

### Problem: Only half of assets updating

**Settings:**
- Verbosity: **Detailed**
- Enable: Refresh, Batch, Success, Error

**Look for:**
- How many batches ran? (Should be ceiling(assetCount / 5))
- Success count matches total assets?
- Any error messages?

**Expected:**
```
📦 BATCH Batch 1/3 with 5 assets
📦 BATCH Batch 2/3 with 5 assets
📦 BATCH Batch 3/3 with 2 assets  ← All 3 batches complete
🔄 REFRESH Success: 12/12  ← All assets updated
```

### Problem: Cooldown not working

**Settings:**
- Verbosity: **Detailed**
- Enable: Cooldown, Refresh

**Look for:**
```
🔄 REFRESH Bypass cooldown: true  ← Should be true for manual refresh
⏳ COOLDOWN Next refresh in 11h 58m  ← After first refresh
```

### Problem: Specific ticker fails

**Settings:**
- Verbosity: **Verbose**
- Enable: API, Error

**Look for:**
```
📡 API Fetching price for 'BADTICKER' (bypass: true)
❌ ERROR [BADTICKER] Failed to update
  └─ Ticker 'BADTICKER' not found
```

---

## 📈 Verification Checklist

After implementing the debug system:

- [ ] Console is clean by default (Silent/Errors mode)
- [ ] Can see detailed refresh logs (Detailed mode)
- [ ] Can see individual asset updates
- [ ] Can see batch processing (X/Y batches)
- [ ] Can see success/failure counts
- [ ] Can see duration measurements
- [ ] Diagnostic report appears on failures
- [ ] Can toggle categories on/off
- [ ] Settings UI works correctly

---

## 🎯 Quick Commands

### Enable Detailed Logging
```swift
await DebugLogger.shared.setVerbosity(.detailed)
await DebugLogger.shared.enableAllCategories()
```

### Disable All Logging
```swift
await DebugLogger.shared.setVerbosity(.silent)
await DebugLogger.shared.disableAllCategories()
```

### Log Refresh Operation
```swift
await DebugLogger.shared.logRefreshStart(assetCount: 12, bypassCooldown: true)
// ... do refresh ...
await DebugLogger.shared.logRefreshComplete(
    successCount: 12, 
    failCount: 0, 
    totalCount: 12, 
    duration: 2.34
)
```

---

## 📁 Files Added/Modified

### New Files
- ✅ `DebugLogger.swift` - Core logging system
- ✅ `DebugSettingsView.swift` - Settings UI
- ✅ `DEBUG_LOGGING_GUIDE.md` - Full documentation
- ✅ `DEBUG_SYSTEM_CHANGELOG.md` - Detailed changes
- ✅ `DEBUG_QUICK_REFERENCE.md` - This file

### Modified Files
- ✅ `asset_model.swift` - Removed print statements
- ✅ `portfolio_viewmodel.swift` - Integrated DebugLogger

### Files to Modify (Integration)
- [ ] `SettingsView.swift` - Add link to DebugSettingsView
- [ ] `MarketstackService.swift` - Optional: Add logging
- [ ] `AlternativePriceService.swift` - Optional: Add logging

---

## 🚀 Performance

| Mode | Overhead | Recommended For |
|------|----------|-----------------|
| Silent | 0% | Production |
| Errors | <1% | Normal use |
| Important | ~1% | Monitoring |
| Detailed | ~2% | Troubleshooting |
| Verbose | ~5% | Development |

---

## ✅ Benefits

Before this system:
- ❌ Console cluttered with crypto calculations
- ❌ Hard to see refresh progress
- ❌ Couldn't tell which assets updated
- ❌ No diagnostic information
- ❌ Manual print statements everywhere

After this system:
- ✅ Clean console by default
- ✅ Detailed logs when needed
- ✅ Clear batch processing
- ✅ Automatic diagnostics on failure
- ✅ Centralized logging control

---

## 🎓 Learn More

- Full documentation: `DEBUG_LOGGING_GUIDE.md`
- Detailed changes: `DEBUG_SYSTEM_CHANGELOG.md`
- Integration guide: See "Integration Checklist" in changelog
- Code examples: See `DebugLogger.swift` and `DebugSettingsView.swift`

---

## 🆘 Need Help?

### Can't see any logs?
- Check verbosity level (should be at least "Important")
- Check that categories are enabled
- Try "Enable All Categories" button

### Too many logs?
- Reduce verbosity to "Important" or "Errors"
- Disable specific categories
- Use "Normal Use" preset

### Want to diagnose specific issue?
- See troubleshooting scenarios in `DEBUG_LOGGING_GUIDE.md`
- Use appropriate preset (Troubleshooting for most cases)
- Enable only relevant categories

---

**Last Updated:** March 6, 2026
**Version:** 1.0
