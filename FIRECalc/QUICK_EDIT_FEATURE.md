# Quick Edit Quantities Feature

## Overview
Added a quick edit feature to the Portfolio tab that allows users to efficiently update quantities for multiple assets in a single sheet view.

## Implementation Details

### UI Components

#### 1. Quick Edit Button
- **Location**: Bottom overlay on the Portfolio tab
- **Appearance**: Blue button with "Quick Edit Quantities" text
- **Visibility**: Only shown when portfolio has assets
- **Icon**: `slider.horizontal.3`

#### 2. Quick Edit Sheet (`QuickEditQuantitiesView`)
A full-screen modal sheet displaying all portfolio assets in an editable table format.

### Features

#### Asset Display
Each asset shows:
- **Asset name** with icon (color-coded by asset class)
- **Ticker symbol** (if available, shown in blue)
- **Type**: Asset class name
- **Price**: Current live price (with "Live" indicator) or unit value
- **Quantity**: Editable text field
- **Total Value**: Automatically calculated based on quantity changes

#### User Experience
- **Visual Feedback**: Total value turns orange when quantity is modified
- **Save Button**: Only enabled when changes are detected
- **Cancel Button**: Dismisses sheet without saving
- **Grouped Layout**: Uses `.insetGrouped` list style for clean appearance
- **Decimal Keyboard**: Numeric pad for easy quantity input

#### Data Management
- **State Tracking**: Uses dictionary to track edited quantities by asset ID
- **Change Detection**: Monitors if any quantity differs from original
- **Batch Updates**: All changes saved together when "Save" is tapped
- **Price Priority**: Uses live price if available, falls back to unit value

## Code Changes

### ContentView.swift

#### Modified `PortfolioTabView`
```swift
@State private var showingQuickEdit = false

// Added bottom overlay with Quick Edit button
.overlay(alignment: .bottom) {
    if portfolioVM.hasAssets {
        Button(action: { showingQuickEdit = true }) {
            // ... button content
        }
    }
}

// Added sheet presentation
.sheet(isPresented: $showingQuickEdit) {
    QuickEditQuantitiesView(portfolioVM: portfolioVM)
}
```

#### Added `QuickEditQuantitiesView`
A new SwiftUI view with:
- List-based layout with custom row design
- State management for edited quantities
- Helper functions for bindings and calculations
- Save logic that updates all modified assets

## Usage

1. Navigate to the Portfolio tab
2. Scroll to see the "Quick Edit Quantities" button at the bottom
3. Tap the button to open the edit sheet
4. Update any asset quantities using the text fields
5. Watch total values update in real-time (highlighted in orange)
6. Tap "Save" to apply changes or "Cancel" to discard

## Benefits

- **Efficiency**: Edit multiple asset quantities without navigating between detail views
- **Visibility**: See all assets and their key information in one place
- **Safety**: Changes only applied when explicitly saved
- **Clarity**: Visual feedback shows which assets have been modified
- **Accuracy**: Auto-calculated totals prevent manual calculation errors

## Technical Notes

- Uses SwiftUI's `@State` for local edit tracking
- Leverages existing `portfolioVM.updateAsset()` method
- Maintains separation between view state and model
- Follows SwiftUI best practices for form input and validation
- Compatible with both live-priced and manually-valued assets
