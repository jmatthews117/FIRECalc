# Debug Logging System - User Guide

## Overview

FIRECalc now includes a comprehensive debug logging system to help troubleshoot issues with portfolio refresh, API calls, caching, and performance. This system provides detailed console output that can be controlled through the app's settings.

## Accessing Debug Settings

1. Open the app
2. Go to **Settings** tab
3. Tap **Debug Logging** (or add link to DebugSettingsView in your Settings)
4. Adjust verbosity and categories as needed

## Verbosity Levels

### Silent (0)
- **Use when:** Normal production use
- **Output:** Nothing
- **Best for:** End users who don't need console logs

### Errors Only (1)
- **Use when:** You want minimal logging
- **Output:** Only errors and critical warnings
- **Best for:** Production with basic error tracking

### Important (2) - **Recommended for most users**
- **Use when:** You want to monitor major operations
- **Output:** Errors, warnings, refresh start/complete, cooldown status
- **Best for:** General monitoring and basic troubleshooting

### Detailed (3) - **Recommended for troubleshooting**
- **Use when:** Debugging specific issues
- **Output:** All operations, batch processing, individual asset updates
- **Best for:** Investigating why refreshes fail or assets don't update

### Verbose (4)
- **Use when:** Deep debugging required
- **Output:** Everything including individual API calls, cache checks, calculations
- **Best for:** Development and detailed performance analysis

## Log Categories

### 🔄 REFRESH
- Portfolio refresh operations
- Start/complete messages
- Total asset counts
- Success/failure summaries

### 📡 API
- Individual API calls to Marketstack
- Request parameters
- Response data
- Cache vs fresh data indicators

### 💾 CACHE
- Cache hits and misses
- Cache age information
- Cache statistics

### ⏳ COOLDOWN
- Cooldown status checks
- Time remaining until next refresh
- Bypass notifications

### 📦 BATCH
- Batch processing progress
- Assets per batch
- Batch success/failure rates

### ❌ ERROR
- All error messages
- Error details and stack traces

### ✅ SUCCESS
- Successful operations
- Asset update confirmations
- Price values

### ⚠️ WARNING
- Non-critical warnings
- Potential issues

### ⚡ PERFORMANCE
- Operation timing
- Performance metrics
- Duration measurements

## Common Troubleshooting Scenarios

### Problem: Refresh Only Updates Half of Assets

**Symptoms:**
- Pull to refresh shows success
- But only some assets update
- Some timestamps remain old

**Debug Settings:**
1. Set verbosity to **Detailed**
2. Enable categories: Refresh, Batch, Success, Error
3. Pull to refresh
4. Check console output

**What to Look For:**
```
📦 BATCH Batch 1/3 - Processing 5 assets
✅ SUCCESS [SPY] Updated to $485.50
✅ SUCCESS [AAPL] Updated to $185.50
❌ ERROR [INVALID] Failed to update
```

**Expected Output:**
- Should see all batches processing (e.g., 1/3, 2/3, 3/3)
- Success count should match total asset count
- Each asset with ticker should show an update line

**If You See:**
- Fewer batches than expected → Some assets not being processed
- Many error lines → Check ticker symbols
- No "bypassCooldown: true" → Cooldown may be active

### Problem: Specific Ticker Won't Update

**Symptoms:**
- Most assets update successfully
- One or two specific tickers always fail
- Error message is unclear

**Debug Settings:**
1. Set verbosity to **Verbose**
2. Enable categories: API, Cache, Error
3. Pull to refresh
4. Search console for your ticker symbol

**What to Look For:**
```
📡 API Fetching price for 'TSLA' (bypass: true)
💾 CACHE Cache MISS for TSLA (not in cache)
📡 API [TSLA] Got $245.30 from API
✅ SUCCESS [TSLA] Updated to $245.30
```

**Common Issues:**
- Ticker not found → Verify symbol on Yahoo Finance
- Network error → Check internet connection
- "Invalid ticker" → Symbol may have changed or be delisted

### Problem: Cooldown Not Working Correctly

**Symptoms:**
- Can refresh more/less often than expected
- Cooldown message shows wrong time
- Bypass not working for single assets

**Debug Settings:**
1. Set verbosity to **Detailed**
2. Enable categories: Cooldown, API, Refresh
3. Try multiple refreshes

**What to Look For:**
```
⏳ COOLDOWN Next refresh in 11h 45m
🔄 REFRESH Bypass cooldown: true
⏳ COOLDOWN Refresh available now
```

**Expected Behavior:**
- Manual refresh (pull to refresh): Bypass = true
- Should see "Next refresh in" message after first refresh
- Second refresh within 12 hours should use cache only

### Problem: Too Many API Calls

**Symptoms:**
- API limit reached quickly
- Unexpected API usage
- Want to minimize calls

**Debug Settings:**
1. Set verbosity to **Verbose**
2. Enable categories: API, Cache, Performance
3. Use app normally
4. Monitor console

**What to Look For:**
```
💾 CACHE Returning cached data for SPY (age: 5m)
📡 API [AAPL] Got $185.50 from API  ← New API call
💾 CACHE Cache stats: 12 entries, 87.5% hit rate
```

**Optimization Tips:**
- High cache hit rate (>80%) = Good
- Multiple API calls for same ticker = Problem
- Check that 12-hour cooldown is enforced

## Diagnostic Reports

When a refresh completes with failures, the system automatically generates a diagnostic report:

```
════════════════════════════════════════════════════════════
📊 REFRESH DIAGNOSTIC REPORT
════════════════════════════════════════════════════════════

CONFIGURATION:
  • Total assets: 12
  • Bypass cooldown: true
  • Verbosity: detailed

RESULTS:
  • Duration: 2.34s
  • Success: 10/12 (83.3%)
  • Failed: 2/12

FAILED TICKERS:
  • INVALID1
  • BADTICKER

COOLDOWN STATUS:
  • Next refresh in: 11h 58m

RECOMMENDATIONS:
  ℹ️  Some assets failed to update
  → Review failed tickers above
  → Verify ticker symbols on Yahoo Finance

════════════════════════════════════════════════════════════
```

## Example Console Output

### Normal Refresh (Detailed Verbosity)

```
[12:34:56.789] 🔄 REFRESH ════════════════════════════════════════
[12:34:56.790] 🔄 REFRESH Starting portfolio refresh
[12:34:56.791] 🔄 REFRESH Assets to update: 12
[12:34:56.791] 🔄 REFRESH Bypass cooldown: true
[12:34:56.792] 🔄 REFRESH ════════════════════════════════════════
[12:34:56.793] 📦 BATCH ────────────────────────────────────────
[12:34:56.794] 📦 BATCH Batch 1/3 - Processing 5 assets
[12:34:57.123] ✅ SUCCESS [SPY] Updated to $485.50
[12:34:57.145] ✅ SUCCESS [AAPL] Updated to $185.50
[12:34:57.167] ✅ SUCCESS [MSFT] Updated to $380.20
[12:34:57.189] ✅ SUCCESS [GOOGL] Updated to $140.50
[12:34:57.211] ✅ SUCCESS [TSLA] Updated to $245.30
[12:34:57.212] 📦 BATCH Batch 1/3 complete - ✅ 5 | ❌ 0
[12:34:57.213] 📦 BATCH ────────────────────────────────────────
[12:34:57.414] 📦 BATCH ────────────────────────────────────────
[12:34:57.415] 📦 BATCH Batch 2/3 - Processing 5 assets
[12:34:57.756] ✅ SUCCESS [NVDA] Updated to $495.20
[12:34:57.778] ✅ SUCCESS [META] Updated to $425.60
[12:34:57.800] ✅ SUCCESS [AMZN] Updated to $155.80
[12:34:57.822] ✅ SUCCESS [BRK.B] Updated to $385.40
[12:34:57.844] ✅ SUCCESS [QQQ] Updated to $415.30
[12:34:57.845] 📦 BATCH Batch 2/3 complete - ✅ 5 | ❌ 0
[12:34:57.846] 📦 BATCH ────────────────────────────────────────
[12:34:58.047] 📦 BATCH ────────────────────────────────────────
[12:34:58.048] 📦 BATCH Batch 3/3 - Processing 2 assets
[12:34:58.267] ✅ SUCCESS [VTI] Updated to $338.19
[12:34:58.289] ✅ SUCCESS [DIA] Updated to $385.20
[12:34:58.290] 📦 BATCH Batch 3/3 complete - ✅ 2 | ❌ 0
[12:34:58.291] 📦 BATCH ────────────────────────────────────────
[12:34:58.292] 🔄 REFRESH ════════════════════════════════════════
[12:34:58.293] 🔄 REFRESH Refresh complete in 1.50s
[12:34:58.294] 🔄 REFRESH Success: 12/12
[12:34:58.295] 🔄 REFRESH Failed: 0/12
[12:34:58.296] 🔄 REFRESH ════════════════════════════════════════
```

### Verbose Refresh (With API Details)

Add these lines between success messages:
```
[12:34:56.890] 📡 API Fetching price for 'SPY' (bypass: true)
[12:34:56.891] 💾 CACHE Cache MISS for SPY (not in cache)
[12:34:57.120] 📡 API [SPY] Got $485.50 from API
```

## Best Practices

### For Development
- Use **Verbose** verbosity
- Enable all categories
- Monitor for performance issues
- Check API usage rates

### For Troubleshooting
- Use **Detailed** verbosity
- Enable relevant categories only
- Save console output to file
- Share logs when reporting bugs

### For Normal Use
- Use **Errors Only** verbosity
- Minimal performance impact
- Still captures critical issues

### For Performance Testing
- Use **Performance** category only
- Track operation durations
- Identify bottlenecks

## Controlling Debug Output Programmatically

From code, you can control logging:

```swift
// Change verbosity
await DebugLogger.shared.setVerbosity(.detailed)

// Enable/disable categories
await DebugLogger.shared.enableCategory(.refresh)
await DebugLogger.shared.disableCategory(.api)

// Log messages
await DebugLogger.shared.log(.refresh, "Custom message", verbosity: .important)

// Or use convenience functions
logRefresh("Starting custom operation")
logError("Something went wrong", error: someError)
logSuccess("Operation completed")
```

## Related Files

- `DebugLogger.swift` - Core logging system
- `DebugSettingsView.swift` - Settings UI
- `portfolio_viewmodel.swift` - Uses logger for refresh operations
- `MarketstackService.swift` - Uses logger for API calls
- `AlternativePriceService.swift` - Uses logger for price fetching

## Tips

1. **Start with Important level** - Good balance of detail and noise
2. **Enable Diagnostic Reports** - Automatically shown on refresh failures
3. **Search Console for Tickers** - Use Cmd+F to find specific assets
4. **Compare Batch Counts** - Should match expected number of assets / 5
5. **Check Timestamps** - Ensure they're recent after refresh
6. **Monitor Cache Hit Rate** - Should be >80% for good performance
7. **Export Logs** - Save console output when reporting bugs

## Summary

The debug logging system provides comprehensive visibility into:
- ✅ Which assets are being updated
- ✅ Why refreshes succeed or fail
- ✅ API vs cache data sources
- ✅ Cooldown timing and bypass behavior
- ✅ Performance metrics
- ✅ Batch processing flow

Use it to verify that:
- **All assets with tickers are processed** (no artificial limits)
- **12-hour cooldown is respected** (between refreshes, not during)
- **Manual refreshes bypass cooldown** (bypassCooldown: true)
- **Cache is working efficiently** (high hit rate)
- **API calls are minimized** (only when needed)
