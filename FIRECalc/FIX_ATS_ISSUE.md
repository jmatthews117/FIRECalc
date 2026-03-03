# 🔒 Fix: App Transport Security (ATS) Blocking Marketstack

## ❌ The Error

```
Unknown error for EPI: The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.
```

## 🎯 The Issue

**Marketstack's free tier uses HTTP, not HTTPS.**

- Free tier: `http://api.marketstack.com` ❌ Blocked by iOS
- Paid tier: `https://api.marketstack.com` ✅ Allowed

iOS blocks HTTP connections by default for security. We need to configure an exception for Marketstack.

---

## ✅ Solution: Configure Info.plist

You need to add an exception to your app's `Info.plist` file to allow HTTP connections to Marketstack.

### Step 1: Open Info.plist

1. In Xcode, find your project's `Info.plist` file
2. Right-click on it and select **"Open As" → "Source Code"**

### Step 2: Add This Configuration

Add this section inside the `<dict>` tag:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.marketstack.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### Complete Example

Your Info.plist should look something like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Your existing keys -->
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    
    <!-- Add this section -->
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSExceptionDomains</key>
        <dict>
            <key>api.marketstack.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <true/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
    
    <!-- Rest of your existing keys -->
</dict>
</plist>
```

### Step 3: Clean and Rebuild

1. **Clean build folder:** Product → Clean Build Folder (Cmd+Shift+K)
2. **Rebuild:** Product → Build (Cmd+B)
3. **Run your app**

---

## 🖥️ Alternative: Use Property List Editor

If you prefer the visual editor:

### Step 1: Open Info.plist normally (property list view)

### Step 2: Add entries

1. Click the **+** button next to "Information Property List"
2. Add key: **App Transport Security Settings** (type: Dictionary)
3. Expand it, click **+**
4. Add key: **Exception Domains** (type: Dictionary)
5. Expand it, click **+**
6. Add key: **api.marketstack.com** (type: Dictionary)
7. Expand it, click **+** twice to add:
   - Key: **NSExceptionAllowsInsecureHTTPLoads** (type: Boolean) → Value: **YES**
   - Key: **NSIncludesSubdomains** (type: Boolean) → Value: **YES**

Should look like:
```
App Transport Security Settings (Dictionary)
  └─ Exception Domains (Dictionary)
      └─ api.marketstack.com (Dictionary)
          ├─ NSExceptionAllowsInsecureHTTPLoads (Boolean): YES
          └─ NSIncludesSubdomains (Boolean): YES
```

---

## 🔒 Security Note

**Is this safe?**

✅ **Yes!** This configuration:
- Only allows HTTP for `api.marketstack.com`
- All other connections still require HTTPS
- Your app remains secure
- This is a standard practice for APIs that only offer HTTP

**Why does Marketstack use HTTP on free tier?**
- To differentiate free vs paid tiers
- HTTPS costs money for the provider
- Encourages upgrades to paid plans

---

## 📱 What Happens After

Once you add this configuration:

### Before (Error):
```
❌ Unknown error for EPI: The resource could not be loaded because the App Transport Security policy requires the use of a secure connection.
```

### After (Success):
```
📡 Batch API call for 5 tickers: AAPL, MSFT, GOOGL, TSLA, EPI
📡 Marketstack batch response: HTTP 200
✅ Got data for: AAPL, MSFT, GOOGL, TSLA, EPI
✅ Updated 5 assets, 0 failed
📊 API Calls: 1/100 this month
```

---

## 🎯 Quick Copy-Paste

**If your Info.plist already has NSAppTransportSecurity:**

Just add the exception domain:

```xml
<key>NSExceptionDomains</key>
<dict>
    <key>api.marketstack.com</key>
    <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key>
        <true/>
        <key>NSIncludesSubdomains</key>
        <true/>
    </dict>
</dict>
```

**If you don't have NSAppTransportSecurity at all:**

Add the complete block from the "Complete Example" above.

---

## ✅ Verification Steps

After adding the configuration:

1. **Clean Build Folder** (Cmd+Shift+K)
2. **Build** (Cmd+B)
3. **Run the app**
4. **Refresh portfolio**
5. **Check console** - should see successful Marketstack calls

---

## 🚀 When You Upgrade to Paid Tier

When you upgrade to Marketstack's paid tier:

1. You'll get HTTPS access
2. Update the base URL in `MarketstackService.swift`:
   ```swift
   // Change from:
   private let baseURL = "http://api.marketstack.com/v1"
   
   // To:
   private let baseURL = "https://api.marketstack.com/v1"
   ```
3. You can optionally remove the ATS exception from Info.plist (but it won't hurt to leave it)

---

## 📋 Summary

**Problem:** iOS blocks HTTP connections by default  
**Cause:** Marketstack free tier uses HTTP only  
**Solution:** Add ATS exception in Info.plist  
**Result:** Marketstack API calls work! ✅

---

## 🆘 Troubleshooting

### If it still doesn't work after adding:

1. **Check the key name carefully** - must be exactly `api.marketstack.com`
2. **Make sure it's in the right place** - under NSAppTransportSecurity → NSExceptionDomains
3. **Clean build folder** - Product → Clean Build Folder
4. **Restart Xcode** - Sometimes needed for Info.plist changes
5. **Check for typos** - XML is case-sensitive

### Still having issues?

Check the console for:
- Any new error messages
- Verify the URL being called starts with `http://` (not `https://`)
- Make sure Info.plist was saved

---

## ✅ Next Steps

1. Add the ATS exception to Info.plist
2. Clean and rebuild
3. Refresh your portfolio
4. Check console for success messages

**Your Marketstack integration will now work!** 🎉
