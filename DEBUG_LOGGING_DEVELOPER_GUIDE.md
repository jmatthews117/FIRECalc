# Debug Logging - Developer Guide

## Overview

Enhanced debug logging for portfolio refresh operations. **DEBUG builds only** - zero impact on production.

## What Changed

### ✅ Removed Cluttering Print Statements
From `asset_model.swift`:
- Removed `💰` emoji prints in `totalValue` (was printing on every portfolio value access)
- Removed debug prints in `updatedWithLivePrice()` (was printing on every price update)

These were cluttering the console constantly.

### ✅ Added Structured Refresh Logging  
In `portfolio_viewmodel.swift`:
- Clear start/complete messages with visual separators
- Batch-by-batch progress tracking
- Individual asset update confirmations
- Success/failure counts and rates
- Duration measurements
- Automatic diagnostic messages on failures

## Example Console Output (DEBUG builds only)

```
════════════════════════════════════════
🔄 REFRESH: Starting portfolio refresh
🔄 REFRESH: Assets to update: 12
🔄 REFRESH: Bypass cooldown: true
════════════════════════════════════════
📦 BATCH: Processing 3 batches of up to 5 assets each
📦 BATCH: [1/3] Processing 5 assets
   ✅ [SPY] Updated to $485.50
   ✅ [AAPL] Updated to $185.50
   ✅ [MSFT] Updated to $380.20
   ✅ [GOOGL] Updated to $140.50
   ✅ [TSLA] Updated to $245.30
📦 BATCH: [1/3] Complete - ✅ 5 | ❌ 0
📦 BATCH: [2/3] Processing 5 assets
   ✅ [NVDA] Updated to $495.20
   ✅ [META] Updated to $425.60
   ✅ [AMZN] Updated to $155.80
   ✅ [BRK.B] Updated to $385.40
   ✅ [QQQ] Updated to $415.30
📦 BATCH: [2/3] Complete - ✅ 5 | ❌ 0
📦 BATCH: [3/3] Processing 2 assets
   ✅ [VTI] Updated to $338.19
   ✅ [DIA] Updated to $385.20
📦 BATCH: [3/3] Complete - ✅ 2 | ❌ 0
════════════════════════════════════════
🔄 REFRESH: Complete in 2.34s
🔄 REFRESH: Success: 12/12
🔄 REFRESH: Failed: 0/12
🔄 REFRESH: Success rate: 100.0%
════════════════════════════════════════
```

## What This Verifies

### ✅ All Assets Are Being Processed
- "Assets to update: 12"
- "Processing 3 batches" (12 assets / 5 per batch = 3 batches)
- All batches complete
- Success count = 12/12

### ✅ Manual Refresh Bypasses Cooldown
- "Bypass cooldown: true" appears for user-initiated refreshes

### ✅ Individual Asset Success/Failure
- ✅ = successful update with price shown
- ❌ = failed update with error message

### ✅ Performance Tracking
- Duration in seconds
- Success rate percentage

## Diagnostic Messages

If assets fail to update:
```
⚠️ DIAGNOSTIC: 2 assets failed to update
⚠️ DIAGNOSTIC: Failed tickers: INVALID1, BADTICKER
```

If more than 50% fail:
```
⚠️ DIAGNOSTIC: More than 50% failed - check network/API
```

## Troubleshooting Common Issues

### Only Half of Portfolio Updates
**Look for:** Number of batches and success count
```
📦 BATCH: Processing 3 batches  ← Should be ceiling(assetCount / 5)
🔄 REFRESH: Success: 12/12  ← Should match total assets
```

If you see fewer batches or lower success count, some assets aren't being processed.

### Cooldown Not Bypassing
**Look for:** Bypass flag
```
🔄 REFRESH: Bypass cooldown: true  ← Should be true for manual refresh
```

If false, manual refreshes are incorrectly respecting cooldown.

### Specific Tickers Failing
**Look for:** Error messages
```
   ❌ [BADTICKER] Failed: Ticker 'BADTICKER' not found
```

Verify ticker symbols are correct.

### Performance Issues
**Look for:** Duration
```
🔄 REFRESH: Complete in 2.34s  ← Should be under 5s typically
```

Long duration indicates network issues or API problems.

## Using AppLogger

Uses the existing `AppLogger` system from `Logger.swift`:
- **DEBUG builds**: All logs appear (`AppLogger.debug`)
- **Release builds**: Only errors appear
- Zero performance overhead when disabled

Example usage elsewhere:
```swift
AppLogger.debug("Debug message")
AppLogger.info("Info message")
AppLogger.warning("Warning message")
AppLogger.error("Error message")
```

## Files Modified

- ✅ `portfolio_viewmodel.swift` - Added structured debug logging
- ✅ `asset_model.swift` - Removed cluttering print statements
- ✅ Uses existing `Logger.swift` infrastructure

## No User-Facing Changes

- ❌ No settings UI
- ❌ No user controls
- ✅ Only visible in Xcode console during development
- ✅ Automatically disabled in release builds
- ✅ Zero performance impact on production

## Summary

**Before:**
- ❌ Console cluttered with crypto calculations on every portfolio access
- ❌ Hard to see refresh progress
- ❌ Couldn't tell which assets updated
- ❌ No diagnostic information

**After:**
- ✅ Clean console (no crypto spam)
- ✅ Clear refresh progress tracking
- ✅ Individual asset confirmations
- ✅ Automatic diagnostics on failures
- ✅ Only in DEBUG builds

**Result:** Easy to verify all assets are updating and diagnose issues during development.
