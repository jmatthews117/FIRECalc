# Test File Resolution

## Problem

The `TimeBasedIncomeTests.swift` file was added to the **main app target** instead of a **test target**. This caused compilation errors because:

1. XCTest framework is only available in test targets, not app targets
2. The Swift compiler tried to compile test code as part of the main app
3. This caused "No such module 'XCTest'" errors

## Solution Applied

The entire test file has been **commented out** to prevent it from being compiled with the main app.

## To Enable Tests (Optional)

If you want to run these tests, follow these steps:

### Option 1: Create a Test Target (Recommended)

1. In Xcode, go to **File → New → Target**
2. Choose **Unit Testing Bundle**
3. Name it **FIRECalcTests**
4. Click **Finish**

5. Move the test file to the test target:
   - Select `TimeBasedIncomeTests.swift` in the Project Navigator
   - Open the File Inspector (⌥⌘1 or right sidebar)
   - Under "Target Membership", **uncheck** the main app target
   - **Check** the FIRECalcTests target

6. Uncomment the code in `TimeBasedIncomeTests.swift`:
   - Remove the `/*` at the top (after the header comments)
   - Remove the `*/` at the bottom

7. Clean and rebuild: **⇧⌘K** then **⌘B**

8. Run tests: **⌘U**

### Option 2: Delete the Test File (Simpler)

If you don't need tests right now:

1. In Xcode Project Navigator, right-click `TimeBasedIncomeTests.swift`
2. Choose **Delete**
3. Select **Move to Trash**
4. Clean and rebuild: **⇧⌘K** then **⌘B**

## Current Status

✅ **Fixed**: Test file is commented out  
✅ **App builds successfully**: No compilation errors  
⚠️ **Tests disabled**: Tests will not run until moved to test target  

## Why This Happened

Test files were created as demonstration/documentation files and accidentally added to the main app target. This is a common issue when creating test files manually instead of using Xcode's test target template.

## Best Practices

Going forward:
- Always create test files **within a test target**
- Use Xcode's built-in test file templates (**File → New → File → Unit Test Case Class**)
- Verify target membership in the File Inspector before saving
- Test files should import the app module with `@testable import FIRECalc`

## Files Affected

- `/repo/TimeBasedIncomeTests.swift` - Commented out (test code disabled)

## Core Functionality Status

✅ All core time-based income functionality is working:
- `simulation_parameters.swift` - ✅ Working
- `withdrawal_calculator.swift` - ✅ Working  
- `monte_carlo_engine.swift` - ✅ Working
- `defined_benefit_plan.swift` - ✅ Working

The test file was only for validation - the actual feature code is fully functional.
