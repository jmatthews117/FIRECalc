# Quick Reference: Adding New Ticker Mappings

## Template for New Mutual Fund

```json
"TICKER": {
  "name": "Fund Full Name",
  "etfAlternative": "ETF_TICKER",
  "etfName": "ETF Full Name",
  "reason": "Brief explanation of equivalence"
}
```

## Template for New Crypto

```json
"SYMBOL": {
  "name": "Cryptocurrency Name",
  "etfAlternative": "ETF_TICKER",
  "etfName": "ETF Full Name",
  "reason": "Why this ETF provides similar exposure"
}
```

## Popular Additions You Might Want

### More Vanguard Funds

```json
"VWAHX": {
  "name": "Vanguard High Yield Corporate Fund",
  "etfAlternative": "HYG",
  "etfName": "iShares iBoxx High Yield Corporate Bond ETF",
  "reason": "Similar high-yield corporate bond exposure"
},
"VWITX": {
  "name": "Vanguard International Explorer Fund",
  "etfAlternative": "VSS",
  "etfName": "Vanguard FTSE All-World ex-US Small-Cap ETF",
  "reason": "International small-cap stock exposure"
},
"VMMXX": {
  "name": "Vanguard Prime Money Market Fund",
  "etfAlternative": "SHV",
  "etfName": "iShares Short Treasury Bond ETF",
  "reason": "Ultra-short-term, cash-like stability"
}
```

### More Fidelity Funds

```json
"FZROX": {
  "name": "Fidelity ZERO Total Market Index Fund",
  "etfAlternative": "VTI",
  "etfName": "Vanguard Total Stock Market ETF",
  "reason": "Total US stock market coverage"
},
"FZILX": {
  "name": "Fidelity ZERO International Index Fund",
  "etfAlternative": "VXUS",
  "etfName": "Vanguard Total International Stock ETF",
  "reason": "Comprehensive international equity exposure"
},
"FDKLX": {
  "name": "Fidelity Blue Chip Growth Fund",
  "etfAlternative": "VUG",
  "etfName": "Vanguard Growth ETF",
  "reason": "Large-cap growth stock focus"
}
```

### More Schwab Funds

```json
"SCHA": {
  "name": "Schwab Small-Cap Index Fund",
  "etfAlternative": "VB",
  "etfName": "Vanguard Small-Cap ETF",
  "reason": "Small-cap equity exposure"
},
"SCHD": {
  "name": "Schwab US Dividend Equity Fund",
  "etfAlternative": "VYM",
  "etfName": "Vanguard High Dividend Yield ETF",
  "reason": "Dividend-focused equity strategy"
}
```

### Target Date Funds

```json
"VFIFX": {
  "name": "Vanguard Target Retirement 2050 Fund",
  "etfAlternative": "VASGX",
  "etfName": "Vanguard LifeStrategy Growth Fund (or build with VTI/BND/VXUS)",
  "reason": "Age-appropriate asset allocation"
},
"FFFDX": {
  "name": "Fidelity Freedom 2050 Fund",
  "etfAlternative": "VTTVX",
  "etfName": "Vanguard Target Retirement 2050 (or build custom portfolio)",
  "reason": "Target date diversification"
}
```

### Additional Cryptocurrencies

```json
"AVAX": {
  "name": "Avalanche",
  "etfAlternative": "BITQ",
  "etfName": "Bitwise Crypto Industry Innovators ETF",
  "reason": "Diversified crypto industry exposure"
},
"LINK": {
  "name": "Chainlink",
  "etfAlternative": "BITQ",
  "etfName": "Bitwise Crypto Industry Innovators ETF",
  "reason": "Crypto infrastructure and innovation"
},
"UNI": {
  "name": "Uniswap",
  "etfAlternative": "BITQ",
  "etfName": "Bitwise Crypto Industry Innovators ETF",
  "reason": "DeFi and crypto innovation exposure"
}
```

### International Funds

```json
"VEIEX": {
  "name": "Vanguard European Stock Index Fund",
  "etfAlternative": "VGK",
  "etfName": "Vanguard FTSE Europe ETF",
  "reason": "European equity market exposure"
},
"VPACX": {
  "name": "Vanguard Pacific Stock Index Fund",
  "etfAlternative": "VPL",
  "etfName": "Vanguard FTSE Pacific ETF",
  "reason": "Asia-Pacific market exposure"
}
```

### Bond Funds

```json
"VIPSX": {
  "name": "Vanguard Inflation-Protected Securities Fund",
  "etfAlternative": "VTIP",
  "etfName": "Vanguard Short-Term Inflation-Protected Securities ETF",
  "reason": "TIPS inflation protection"
},
"VWEHX": {
  "name": "Vanguard High-Yield Corporate Fund",
  "etfAlternative": "HYG",
  "etfName": "iShares iBoxx High Yield Corporate Bond ETF",
  "reason": "High-yield corporate bond exposure"
}
```

## Finding Good Mappings

### Step 1: Identify Fund Type
- Total Market → VTI, SCHB, ITOT
- S&P 500 → VOO, SPY, IVV
- International → VXUS, IXUS, SCHF
- Bonds → BND, AGG, SCHZ
- REITs → VNQ, SCHH, IYR
- Small Cap → VB, IJR, SCHA
- Mid Cap → VO, IJH, SCHM

### Step 2: Match Characteristics
- Index tracked
- Market cap focus
- Geographic exposure
- Sector focus
- Dividend strategy

### Step 3: Verify Similarity
- Check holdings overlap (>80% similar is good)
- Compare expense ratios
- Review tracking error
- Confirm liquidity

### Step 4: Write Clear Reason
Good: "Nearly identical holdings and performance"
Better: "Tracks the same S&P 500 index with similar weighting"
Best: "Tracks the same S&P 500 index, both use market-cap weighting, >99% holdings overlap"

## Crypto ETF Options (as of 2026)

### Bitcoin ETFs
- IBIT - iShares Bitcoin Trust (BlackRock)
- FBTC - Fidelity Wise Origin Bitcoin Fund
- GBTC - Grayscale Bitcoin Trust
- BTCO - Invesco Galaxy Bitcoin ETF
- ARKB - ARK 21Shares Bitcoin ETF

### Ethereum ETFs
- ETHA - iShares Ethereum Trust
- FETH - Fidelity Ethereum Fund
- ETHE - Grayscale Ethereum Trust
- ETHW - Bitwise Ethereum ETF

### Diversified Crypto
- BITQ - Bitwise Crypto Industry Innovators ETF
- BKCH - Global X Blockchain ETF
- BLOK - Amplify Transformational Data Sharing ETF

### Stablecoin Alternatives
- BIL - SPDR Bloomberg 1-3 Month T-Bill ETF
- SHV - iShares Short Treasury Bond ETF
- SGOV - iShares 0-3 Month Treasury Bond ETF

## JSON Validation

Before adding, validate your JSON:
1. Use JSONLint.com
2. Check for trailing commas
3. Verify quote matching
4. Test locally first

## Common Mistakes to Avoid

❌ **Missing comma after entry**
```json
"VTSAX": { ... }  // Missing comma!
"VFIAX": { ... }
```

✅ **Correct:**
```json
"VTSAX": { ... },
"VFIAX": { ... }
```

❌ **Trailing comma on last entry**
```json
"VTSAX": { ... },
"VFIAX": { ... },  // Remove this comma!
```

✅ **Correct:**
```json
"VTSAX": { ... },
"VFIAX": { ... }
```

❌ **Inconsistent quote types**
```json
"name": 'Fund Name'  // Wrong quotes!
```

✅ **Correct:**
```json
"name": "Fund Name"
```

## Testing Your Additions

After adding a new mapping:

1. **Validate JSON** - Use online validator
2. **Clean build** - ⇧⌘K in Xcode
3. **Rebuild** - ⌘B
4. **Test ticker** - Try loading price
5. **Verify card** - Check suggestion appears
6. **Test button** - Click "Use This"
7. **Verify load** - ETF price should load

## Quick Add Checklist

- [ ] Found equivalent ETF
- [ ] Verified similar holdings
- [ ] Added to correct category (mutualFunds/crypto)
- [ ] Used uppercase ticker
- [ ] Included all 4 fields (name, etfAlternative, etfName, reason)
- [ ] Validated JSON syntax
- [ ] Tested in app
- [ ] Verified suggestion card displays
- [ ] Confirmed "Use This" works

## Resources

- **Compare ETFs:** etfdb.com, etf.com
- **Validate JSON:** jsonlint.com
- **Check holdings:** etf.com/stock-comparison
- **Expense ratios:** morningstar.com

## Need Help?

Common questions:

**Q: What if there's no perfect ETF match?**
A: Choose the closest alternative and explain the difference in "reason"

**Q: Can I suggest multiple alternatives?**
A: Put the best one in etfAlternative, mention others in etfName in parentheses

**Q: Should I map index funds to ETFs from the same company?**
A: Prefer same-company ETFs when available (e.g., Vanguard fund → Vanguard ETF)

**Q: What about actively managed funds?**
A: Map to similar passive ETFs, explain difference in reason

**Q: How detailed should the reason be?**
A: 1 sentence is ideal. Be clear but concise.

## Example: Complete Addition

Let's add VIGAX (Vanguard Growth Index Fund):

1. **Research:** VIGAX tracks large-cap growth stocks
2. **Find ETF:** VUG also tracks large-cap growth
3. **Verify:** Both track CRSP US Large Cap Growth Index
4. **Add to JSON:**

```json
"VIGAX": {
  "name": "Vanguard Growth Index Fund",
  "etfAlternative": "VUG",
  "etfName": "Vanguard Growth ETF",
  "reason": "Tracks the same CRSP US Large Cap Growth Index"
}
```

5. **Validate JSON** ✓
6. **Rebuild app** ✓
7. **Test with "VIGAX"** ✓
8. **See VUG suggestion** ✓
9. **Click "Use This"** ✓
10. **VUG price loads** ✓

Done! 🎉
