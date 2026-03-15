# Duplicate Asset Name Validation - Complete Implementation

## Overview

The app now **fully prevents** users from adding assets with duplicate names across **all entry points**, while still allowing multiple assets to use the same stock ticker. This ensures each asset has a unique identifier (its name) while supporting common scenarios like tracking the same stock across multiple accounts.

**Status**: ✅ Fully Implemented Across All Entry Points

## What Was Fixed

Previously, the validation was only partially implemented. Now it's comprehensive:

### Before (Issues)
- ❌ No validation in `AddAssetView` (primary entry point)
- ❌ No validation in `QuickAddTickerView`  
- ❌ Partial validation in `BulkAssetUploadView`
- ❌ No real-time visual feedback
- ❌ Add button still enabled for duplicates
- ❌ API calls still made for duplicate names

### After (Fixed) ✅
- ✅ Full validation in `AddAssetView` with real-time feedback
- ✅ Full validation in `QuickAddTickerView`
- ✅ Enhanced validation in `BulkAssetUploadView`
- ✅ Orange warning icons appear as user types
- ✅ Add button disabled when duplicate detected
- ✅ API calls prevented for duplicate names

## Implementation Summary

### Files Modified

1. **`portfolio_viewmodel.swift`**
   - Added `assetExists(withName:)` method
   - Added `existingAsset(withName:)` method

2. **`add_asset_view.swift`** ⭐ Main Fix
   - Added `hasDuplicateName` computed property
   - Added `duplicateWarningMessage` computed property  
   - Updated `isValid` to check for duplicates
   - Added validation in `loadPrice()`
   - Added validation in `addAsset()`
   - Added visual warnings in UI

3. **`bulk_asset_upload_view.swift`**
   - Enhanced `loadPrice()` validation
   - Enhanced `addAllAssets()` validation
   - Added `hasDuplicateName` to `AssetEntryCard`
   - Added visual warnings on cards

4. **`quick_add_ticker_view.swift`**
   - Added validation in `selectAsset()`
   - Added validation in `addAsset()`

## Business Rules

### ✅ Allowed
1. **Multiple assets with same ticker, different names**
   - "Apple 401k" + "Apple Taxable" (both AAPL) ✅
   - "FXAIX" + "S&P 500 ETF" (both use VOO pricing) ✅

2. **Case-insensitive uniqueness**
   - Only one of: "Apple Stock", "apple stock", "APPLE STOCK" ✅

### ❌ Not Allowed
1. **Exact duplicate names** (case-insensitive)
2. **Duplicates within batch uploads**

## User Experience by Entry Point

### 1. AddAssetView (Main Entry)

**When typing duplicate name:**
```
⚠️ An asset named 'Apple Stock' already exists
```

**Behaviors:**
- Orange warning appears immediately while typing
- "Load Price" button shows error if clicked
- "Add" button becomes disabled
- Cannot submit form until name is changed

**Example Flow:**
1. User types "AAPL" in ticker field
2. User sees duplicate warning if "AAPL" exists
3. "Add" button is gray/disabled
4. User must change name to proceed

### 2. BulkAssetUploadView (Batch Entry)

**On each card with duplicate:**
```
⚠️ An asset with this name already exists
```

**Behaviors:**
- Warning appears on individual asset cards
- Price lookup blocked for that card
- Batch submission blocked if any duplicates
- Shows which assets are duplicates

**Example Flow:**
1. User enters "Apple Stock" in card 1
2. Orange warning appears
3. User clicks "Load Price" → Error shown
4. User clicks "Add All Assets" → Error with full list
5. Must fix duplicates to proceed

### 3. QuickAddTickerView (Quick Add)

**When selecting duplicate:**
```
❌ An asset named 'S&P 500 ETF' already exists. 
    Please edit the existing asset or use a different name.
```

**Behaviors:**
- Error section appears immediately
- Price fetch cancelled before API call
- Cannot add to portfolio

**Example Flow:**
1. User clicks "S&P 500 ETF"
2. System checks for duplicate instantly
3. Error message appears
4. No price fetch occurs

## Technical Details

### Core Validation Methods

```swift
// In PortfolioViewModel
func assetExists(withName name: String) -> Bool {
    portfolio.assets.contains { $0.name.lowercased() == name.lowercased() }
}

func existingAsset(withName name: String) -> Asset? {
    portfolio.assets.first { $0.name.lowercased() == name.lowercased() }
}
```

### AddAssetView Implementation

```swift
// Real-time duplicate checking
private var hasDuplicateName: Bool {
    let nameToCheck = !assetName.isEmpty ? assetName : (!ticker.isEmpty ? ticker.uppercased() : "")
    return !nameToCheck.isEmpty && portfolioVM.assetExists(withName: nameToCheck)
}

// Updated validation
private var isValid: Bool {
    // Check duplicate first
    if hasDuplicateName {
        return false
    }
    // Check value
    if let total = totalValue, total > 0 {
        return true
    }
    return false
}

// Validation before price lookup
private func loadPrice() {
    guard !ticker.isEmpty else { return }
    let cleanTicker = ticker.uppercased().trimmingCharacters(in: .whitespaces)
    
    // NEW: Check for duplicates
    let nameToCheck = !assetName.isEmpty ? assetName : cleanTicker
    if portfolioVM.assetExists(withName: nameToCheck) {
        priceError = "An asset named '\(nameToCheck)' already exists..."
        return
    }
    
    // Continue with price fetch...
}

// Validation before adding
private func addAsset() {
    focusedField = nil
    let finalName = !assetName.isEmpty ? assetName : (!ticker.isEmpty ? ticker.uppercased() : displayName)
    
    // NEW: Check for duplicates
    if portfolioVM.assetExists(withName: finalName) {
        priceError = "An asset named '\(finalName)' already exists..."
        return
    }
    
    // Continue with add...
}
```

### Visual Feedback in UI

```swift
// Duplicate warning UI
if hasDuplicateName {
    HStack(spacing: 4) {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
        Text(duplicateWarningMessage)
            .font(.caption)
            .foregroundColor(.orange)
    }
}
```

## Testing Scenarios

### ✅ Scenario 1: Basic Duplicate
1. Add "Apple Stock" → Success
2. Try to add "Apple Stock" → Blocked with warning

### ✅ Scenario 2: Case Insensitive
1. Add "Apple Stock" → Success  
2. Try to add "apple stock" → Blocked (case-insensitive match)

### ✅ Scenario 3: Same Ticker, Different Names (Allowed)
1. Add "Apple 401k" (AAPL) → Success
2. Add "Apple Taxable" (AAPL) → Success ✅

### ✅ Scenario 4: Ticker Mapping
1. Add "FXAIX" (uses VOO) → Success
2. Add "My S&P 500" (uses VOO) → Success ✅
3. Try to add "FXAIX" again → Blocked

### ✅ Scenario 5: Bulk Upload
1. Create batch with "Apple Stock" twice
2. System shows: "You have duplicate names in your batch"
3. No assets added until fixed

### ✅ Scenario 6: Quick Add
1. Add "S&P 500 ETF" via quick add → Success
2. Try to add "S&P 500 ETF" again → Error immediately, no API call

## Benefits

### User Benefits
- ✅ **Immediate feedback** - Know instantly if name is taken
- ✅ **No confusion** - Can't create duplicate assets
- ✅ **Flexibility** - Same ticker, different accounts works
- ✅ **Clear guidance** - Specific error messages explain what to do

### System Benefits  
- ✅ **API efficiency** - No wasted price fetches for duplicates
- ✅ **Data integrity** - Unique asset names guaranteed
- ✅ **Better UX** - Consistent behavior across all entry points
- ✅ **Prevents bugs** - No duplicate data issues

## Error Messages

### Short Form (Visual Warning)
```
⚠️ An asset named 'Apple Stock' already exists
```

### Long Form (On Action)
```
An asset named 'Apple Stock' already exists. 
Please edit the existing asset or use a different name.
```

### Batch Form (Multiple)
```
The following assets already exist: Apple Stock, Microsoft Stock. 
Please edit the existing assets or use different names.
```

### Internal Duplicates (Within Batch)
```
You have duplicate names in your batch: Apple Stock. 
Each asset must have a unique name.
```

## Performance

- **O(n) validation** where n = number of assets
- Acceptable for typical portfolios (10-100 assets)
- Instant feedback on modern devices
- Could be optimized with Set<String> if needed for large portfolios (>1000 assets)

## Future Enhancements

Possible additions:
1. Suggest alternative names automatically
2. "Jump to existing" button to edit instead
3. Bulk rename functionality  
4. Show existing asset value in error
5. Smart name suggestions based on context

---

**Status**: ✅ Complete and Tested  
**Last Updated**: March 13, 2026  
**Priority**: High - Core data integrity feature  
**Coverage**: 100% of entry points (AddAssetView, BulkAssetUploadView, QuickAddTickerView)
