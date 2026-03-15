# Duplicate Asset Name Validation

## Overview

The app now prevents users from adding assets with duplicate names, while still allowing multiple assets to use the same stock ticker. This ensures each asset has a unique identifier (its name) while supporting common scenarios like tracking the same stock across multiple accounts.

## Business Rules

### ✅ Allowed
1. **Multiple assets with the same ticker but different names**
   - Example: "Apple 401k" and "Apple Taxable", both using ticker AAPL
   - Example: "FXAIX" and "S&P 500 ETF", both using ticker VOO for price lookups

2. **Case-insensitive uniqueness**
   - "Apple Stock", "apple stock", and "APPLE STOCK" are all considered the same name
   - Only one can exist in the portfolio

3. **Different asset classes with similar names**
   - As long as the exact name differs, they're allowed
   - Example: "Apple Stock" and "Apple Bond" are different names

### ❌ Not Allowed
1. **Exact duplicate names** (case-insensitive)
   - Trying to add "Apple Stock" when "Apple Stock" already exists
   - Trying to add "apple stock" when "Apple Stock" exists

2. **Duplicates within a batch upload**
   - Can't add multiple assets with the same name in a single bulk upload

## User Experience

### Single Asset Addition
When adding an asset with a duplicate name, the user will see:
- ⚠️ **Warning message**: "An asset named 'Apple Stock' already exists"
- 🚫 **Prevented action**: Price lookup is blocked
- 💡 **Helpful guidance**: "Please edit the existing asset or use a different name"

### Bulk Asset Upload
When uploading multiple assets:
- **Real-time validation**: Orange warning appears as user types duplicate name
- **Batch validation**: Checks for duplicates before adding any assets
- **Clear errors**: Shows which specific assets are duplicates

### Error Messages

#### Single Duplicate
```
An asset named 'Apple Stock' already exists. 
Please edit the existing asset or use a different name.
```

#### Multiple Duplicates
```
The following assets already exist: Apple Stock, Microsoft Stock. 
Please edit the existing assets or use different names.
```

#### Duplicates Within Batch
```
You have duplicate names in your batch: Apple Stock. 
Each asset must have a unique name.
```

## Technical Implementation

### PortfolioViewModel Methods

#### Check if Asset Exists
```swift
func assetExists(withName name: String) -> Bool
```
- Returns `true` if an asset with the given name exists (case-insensitive)
- Used for validation before adding new assets

#### Find Existing Asset
```swift
func existingAsset(withName name: String) -> Asset?
```
- Returns the existing asset if found, `nil` otherwise
- Useful for displaying details about the duplicate

### Validation Points

#### 1. Before Price Lookup (BulkAssetUploadView)
```swift
private func loadPrice(for asset: DraftAsset) {
    let assetNameToCheck = asset.name.isEmpty ? asset.ticker : asset.name
    if portfolioVM.assetExists(withName: assetNameToCheck) {
        // Show error, prevent API call
        return
    }
    // Proceed with price lookup
}
```

**Why**: Prevents wasting API calls on assets that can't be added

#### 2. Before Adding Assets (BulkAssetUploadView)
```swift
private func addAllAssets() {
    // Check against existing portfolio assets
    for draft in validAssets {
        if portfolioVM.assetExists(withName: draft.name) {
            duplicates.append(draft.name)
        }
    }
    
    // Check for internal duplicates within the batch
    var seenNames = Set<String>()
    for draft in validAssets {
        if seenNames.contains(draft.name.lowercased()) {
            internalDuplicates.append(draft.name)
        }
        seenNames.insert(draft.name.lowercased())
    }
    
    // Show error if any duplicates found
}
```

**Why**: Comprehensive validation before modifying the portfolio

#### 3. Real-time Feedback (AssetEntryCard)
```swift
private var hasDuplicateName: Bool {
    guard let vm = portfolioVM, !asset.name.isEmpty else { return false }
    return vm.assetExists(withName: asset.name)
}
```

**Why**: Immediate visual feedback as user types

## Use Cases

### Use Case 1: Same Stock in Multiple Accounts ✅

**Scenario**: User has Apple stock in both 401k and taxable account

**Action**:
1. Add "Apple 401k" with ticker AAPL ✅
2. Add "Apple Taxable" with ticker AAPL ✅

**Result**: Both assets added successfully (different names, same ticker allowed)

### Use Case 2: Ticker Mapping with Display Names ✅

**Scenario**: User tracks FXAIX mutual fund using VOO for pricing

**Action**:
1. Add "FXAIX" (displays as FXAIX, uses VOO for pricing) ✅
2. Add "My S&P 500" (also uses VOO for pricing) ✅

**Result**: Both assets added (different names, same lookup ticker allowed)

### Use Case 3: Exact Duplicate Prevention ❌

**Scenario**: User accidentally tries to add the same asset twice

**Action**:
1. Add "Apple Stock" ✅
2. Try to add "Apple Stock" again ❌

**Result**: Error message shown, asset not added

### Use Case 4: Case-Insensitive Detection ❌

**Scenario**: User tries to add with different casing

**Action**:
1. Add "Apple Stock" ✅
2. Try to add "apple stock" ❌

**Result**: Error message shown (detected as duplicate)

### Use Case 5: Bulk Upload Validation ❌

**Scenario**: User uploads CSV with duplicate names

**Action**:
1. Upload batch containing:
   - "Apple Stock" (row 1)
   - "Microsoft Stock" (row 2)
   - "Apple Stock" (row 3) ❌

**Result**: Error message: "You have duplicate names in your batch: Apple Stock"

### Use Case 6: Mixed Validation ❌

**Scenario**: Batch contains existing and internal duplicates

**Action**:
1. Portfolio already has "Tesla Stock"
2. Upload batch:
   - "Tesla Stock" (duplicate of existing) ❌
   - "Google Stock" (new) ✅
   - "Google Stock" (duplicate in batch) ❌

**Result**: Error message showing both types of duplicates

## Edge Cases

### Empty Names
- Empty string `""` does not match any asset
- Validation skipped if name is empty

### Whitespace
- Leading/trailing whitespace is preserved in asset names
- `"  Apple Stock  "` is different from `"Apple Stock"`
- Comparison is case-insensitive but whitespace-sensitive

### Special Characters
- Names with special characters are supported
- Example: "S&P 500 Index" is different from "S&P 500 Index Fund"

## Benefits

### For Users
1. **Clear Guidance**: Know immediately if a name is taken
2. **Prevent Confusion**: No duplicate assets in portfolio
3. **Flexibility**: Can track same stock in different accounts
4. **Efficiency**: No wasted price lookups for assets that can't be added

### For the System
1. **Data Integrity**: Each asset has a unique identifier
2. **API Efficiency**: No unnecessary price fetches
3. **Clear UX**: Consistent error messages
4. **Better Organization**: Easier to manage and edit assets

## Testing

### Test Coverage
- ✅ Case-insensitive duplicate detection
- ✅ Same ticker with different names allowed
- ✅ Finding existing assets by name
- ✅ Exact duplicate prevention
- ✅ Ticker mapping scenarios
- ✅ Empty name handling
- ✅ Whitespace handling
- ✅ Bulk upload duplicate detection
- ✅ Internal batch duplicates

### Manual Testing Checklist

#### Single Asset Flow
- [ ] Add "Apple Stock" - succeeds
- [ ] Try to add "Apple Stock" again - shows error
- [ ] Try to add "apple stock" - shows error (case-insensitive)
- [ ] Add "Apple Bonds" - succeeds (different name)
- [ ] Add "Apple IRA" with AAPL ticker - succeeds (same ticker, different name)

#### Bulk Upload Flow
- [ ] Upload batch with no duplicates - succeeds
- [ ] Upload batch with internal duplicate - shows error
- [ ] Upload batch with existing duplicate - shows error
- [ ] See orange warning when typing duplicate name
- [ ] Can correct name and proceed

#### Ticker Mapping Flow
- [ ] Add "FXAIX" (using VOO) - succeeds
- [ ] Try to add another "FXAIX" - shows error
- [ ] Add "My S&P Fund" (also using VOO) - succeeds

## Performance Considerations

### Lookup Efficiency
- Uses `contains` with closure for case-insensitive search
- O(n) complexity where n = number of assets in portfolio
- Acceptable for typical portfolios (10-100 assets)

### Potential Optimizations
If performance becomes an issue with very large portfolios:
1. **Index by lowercase name**: Build a Set<String> of lowercase names
2. **Cache validation results**: Store during batch processing
3. **Batch validation**: Check all at once instead of individually

## Future Enhancements

### Possible Improvements
1. **Suggest Alternative Names**: "Apple Stock (2)", "Apple Stock - 401k"
2. **Show Existing Asset Details**: Display quantity and value of duplicate
3. **Quick Edit Link**: Button to navigate directly to existing asset
4. **Bulk Rename**: Change multiple asset names at once
5. **Import with Auto-Rename**: Automatically append numbers to duplicates
6. **Smart Name Suggestions**: Based on ticker and account type

### Enhanced UX
1. **Visual Indicator**: Show duplicate assets highlighted in list
2. **Confirmation Dialog**: "Asset already exists. View existing or choose new name?"
3. **Inline Editing**: Fix duplicate name without leaving add flow
4. **Name History**: Show recently used names to avoid duplicates

## Related Files

- `portfolio_viewmodel.swift` - Validation methods
- `bulk_asset_upload_view.swift` - Bulk upload validation
- `DuplicateAssetValidationTests.swift` - Test coverage
- `asset_model.swift` - Asset structure

## Related Features

- Ticker mapping system (allows same ticker, different names)
- Asset editing (modify existing assets instead of adding duplicates)
- Bulk asset upload (batch validation)
- Price lookup optimization (skip API calls for duplicates)

---

**Feature Status**: ✅ Implemented  
**Last Updated**: March 13, 2026  
**Impact**: High - Prevents data quality issues and improves UX
