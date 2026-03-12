# Quick Start: Testing the Value Conversion Feature

## 30-Second Test

1. **Open your app** in Xcode and run it (⌘ + R)

2. **Navigate to** "Portfolio" tab → "+" button

3. **Select** "Stocks" as asset type

4. **Enter** "VTSAX" as ticker

5. **Click** "Load Price for VTSAX"

6. **You should see** an orange card that says:
   ```
   ⚠️ Unsupported Ticker
   VTSAX cannot be tracked with live prices
   
   We'll track it using this equivalent ETF:
   VTI - Vanguard Total Stock Market ETF
   [Price loads automatically]
   ```

7. **Type** "50000" in the value field

8. **Watch** as it calculates:
   ```
   ➡️ Converts to:
   200.0000 shares
   of VTI @ $250.00
   ```

9. **Click** "Add as VTI"

10. **Result:** All fields populate:
    - Ticker: VTI
    - Quantity: 200.0000
    - Price: $250.00

11. **Click** "Add Asset"

12. **Done!** Check Portfolio tab to see your VTI holding

## Expected Behavior

### ✅ What Should Happen

- Card appears immediately when you try to load VTSAX price
- VTI price loads automatically (you'll see a spinner, then the price)
- As you type the value, shares calculate in real-time
- "Add as VTI" button is disabled until you enter a value
- When you click "Add as VTI", all fields populate correctly
- Asset is created with exact same total value you entered

### ❌ What Shouldn't Happen

- No errors in console about missing files
- No crashes when clicking "Load Price"
- No blank/empty suggestion card
- No "Use This" button (old design) - should say "Add as VTI"
- Button shouldn't say just "Use This" - should include ETF name

## Other Tickers to Test

### Mutual Funds
- **VTSAX** → VTI (Total Market)
- **VFIAX** → VOO (S&P 500)
- **FXAIX** → VOO (S&P 500)
- **SWTSX** → SCHB (Total Market)

### Crypto (Select "Crypto" asset type first!)
- **BTC** → IBIT (Bitcoin ETF)
- **ETH** → ETHA (Ethereum ETF)

### Regular Stocks (Should work normally, NO card)
- **AAPL** → Loads price directly
- **MSFT** → Loads price directly
- **GOOGL** → Loads price directly

## Troubleshooting

### Problem: "JSON not found" error

**Solution:**
1. Select `TickerMappings.json` in Xcode
2. File Inspector (⌥⌘1)
3. Check "Target Membership" for your app
4. Clean build (⇧⌘K)
5. Rebuild (⌘B)

### Problem: Card shows but no "Add as [ETF]" button

**Solution:**
- You're using old version of `TickerMappingSuggestionCard.swift`
- Make sure you replaced the entire file with the new version
- Clean and rebuild

### Problem: Clicking "Add as VTI" does nothing

**Solution:**
- Check that you updated `add_asset_view.swift` with new callback
- Look for this signature: `onUseAlternative: { quantity, unitPrice in`
- If it's `onUseAlternative: {` (no parameters), you need to update

### Problem: Price doesn't load

**Solution:**
- Check console for network errors
- Make sure your backend is running
- Verify you're logged in as a Pro subscriber (or bypassing subscription check)
- Try clicking "Retry" button if it appears

### Problem: Share calculation is wrong

**Solution:**
- This shouldn't happen, but verify:
- Formula: `shares = value / price`
- Example: $50,000 / $250 = 200 shares
- If wrong, check `calculatedShares` computed property

## Success Checklist

After testing, you should have:

- [ ] Seen the orange suggestion card for VTSAX
- [ ] VTI price loaded automatically
- [ ] Typed a value and seen shares calculate
- [ ] Clicked "Add as VTI" and fields populated
- [ ] Added the asset successfully
- [ ] Seen VTI in your portfolio with correct value

## Demo Script (For showing others)

**Say:** "Watch what happens when I try to add a mutual fund..."

1. Type "VTSAX"
2. Click "Load Price"
3. **Say:** "The app knows this is a mutual fund and suggests an equivalent ETF"
4. **Say:** "I just enter how much VTSAX I own..."
5. Type "50000"
6. **Say:** "And it automatically calculates the shares for me"
7. Point to "200.0000 shares"
8. Click "Add as VTI"
9. **Say:** "One click and it's ready to go"
10. Click "Add Asset"
11. **Say:** "Now I can track it with live prices!"

**Wow factor:** ✨ The automatic calculation and one-click conversion

## Next Steps

Once you've verified it works:

1. **Test edge cases:**
   - Try very small values ($10)
   - Try very large values ($1,000,000)
   - Try decimal values ($12,345.67)
   - Try different tickers from the mapping

2. **Add your own mappings:**
   - Edit `TickerMappings.json`
   - Add mutual funds you own
   - Test them

3. **Customize the UI:**
   - Adjust colors in `TickerMappingSuggestionCard.swift`
   - Change text if needed
   - Tweak spacing/fonts

## Questions to Ask Yourself

✅ **Is the flow smooth?**  
✅ **Is the calculation instant?**  
✅ **Is the button labeling clear?**  
✅ **Would your mom understand this?**  
✅ **Does it feel professional?**  

If yes to all, you're done! 🎉

## Getting Help

If something doesn't work:

1. Check console output (⌘+')
2. Look for error messages
3. Verify all files are in the project
4. Clean build folder (⇧⌘K)
5. Restart Xcode if needed

Common log messages to look for:

```
✅ Loaded ticker mappings: 18 mutual funds, 11 crypto
🔍 fetchQuote called for: 'VTSAX'
🚫 Mutual fund intercepted: VTSAX → suggest VTI
✅ Fetched crypto price: [IBIT] = $35.00
```

If you see these, everything is working! 🎉

---

**Time to complete test:** ~2 minutes  
**Expected result:** VTI asset added with 200 shares @ $250  
**Documentation:** See `ENHANCED_TICKER_MAPPING_SUMMARY.md` for full details
