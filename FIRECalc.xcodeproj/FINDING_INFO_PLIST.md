# 📱 Simple Guide: Adding ATS Exception in Xcode

## 🎯 **Where You Are**

You need to allow HTTP connections to Marketstack. Here's the **easiest** way:

---

## ✅ **Method 1: Via Target Settings** (No Info.plist needed!)

### **Step-by-Step:**

1. **Click the blue project icon** at the very top of the left sidebar
   - It's the first item
   - Has your app's name
   - Blue icon

2. **Look at the center panel** - you'll see two sections:
   - PROJECT (your project name)
   - TARGETS (your app name) ← **Click this one**

3. **Click the "Info" tab** at the top of the center panel
   - You'll see tabs like: General, Signing & Capabilities, Resource Tags, **Info**, Build Settings, Build Phases, Build Rules

4. **Scroll down** until you see a table with properties
   - Might say "Custom iOS Target Properties" at the top
   - Or just show a list of properties

5. **Hover over any row** and you'll see a **"+"** button on the right

6. **Click "+"** to add a new property

7. **Start typing:** `App Transport`
   - It should auto-complete to "App Transport Security Settings"
   - Press Enter
   - Make sure Type is: **Dictionary**

8. **Click the triangle (▸)** next to "App Transport Security Settings" to expand it

9. **Click the "+"** that appears when you hover over this row

10. **Type:** `Exception Domains`
    - Press Enter
    - Type: **Dictionary**

11. **Expand and click "+"** again

12. **Type exactly:** `api.marketstack.com`
    - Press Enter
    - Type: **Dictionary**

13. **Expand and click "+" TWICE** to add two items:
    
    **First item:**
    - Key: `NSExceptionAllowsInsecureHTTPLoads`
    - Type: **Boolean**
    - Value: **YES** (check the checkbox)
    
    **Second item:**
    - Key: `NSIncludesSubdomains`  
    - Type: **Boolean**
    - Value: **YES** (check the checkbox)

14. **Save** (Cmd+S)

15. **Clean Build Folder** (Product menu → Clean Build Folder)

16. **Run your app**

---

## ✅ **Method 2: If You Can't Find Target Settings**

### **Create a file to paste this into:**

1. **Right-click** on your project folder in left sidebar
2. Select **"New File..."**
3. Scroll down and choose **"Configuration Settings File"** or **"Property List"**
4. Name it: **"ATS-Config.plist"**
5. Click **"Create"**

6. **Right-click the new file** → **"Open As"** → **"Source Code"**

7. **Delete everything** in the file

8. **Paste this:**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
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
</dict>
</plist>
```

9. **Save** (Cmd+S)

10. Now go back to **Target Settings** (blue icon → Info tab)

11. Find **"Info.plist File"** property

12. Set it to: **"ATS-Config.plist"**

---

## 🎯 **Method 3: Switch to Test Mode** (Temporary workaround)

While you figure out Info.plist, you can use test mode:

### In `portfolio_viewmodel.swift`, find this line:

```swift
AlternativePriceService.useMarketstackTest = false
```

### Change it to:

```swift
AlternativePriceService.useMarketstackTest = true
```

This uses **mock data** (no HTTP calls) so you can keep testing while we fix the ATS issue.

---

## 📸 **What You're Looking For**

### In Xcode, you want to see:

```
Left Sidebar (Project Navigator)
├─ 📘 YourProjectName (blue icon) ← Click this
│   └─ In center panel:
│       ├─ TARGETS
│       │   └─ YourAppName ← Click this
│       │       └─ Tabs: General | Signing & Capabilities | Info ← Click Info
│       │           └─ Custom iOS Target Properties (table view)
```

### The property table should eventually show:

```
Key                                          Type        Value
App Transport Security Settings              Dictionary  (2 items)
  └─ Exception Domains                       Dictionary  (1 item)
      └─ api.marketstack.com                 Dictionary  (2 items)
          ├─ NSExceptionAllowsInsecureHTTPLoads  Boolean     YES
          └─ NSIncludesSubdomains                Boolean     YES
```

---

## 🆘 **Still Stuck?**

### **Quick diagnostic:**

Run this command in Terminal:

```bash
find ~/Library/Developer/Xcode/DerivedData -name "Info.plist" | head -5
```

This shows where Xcode is storing your Info.plist files.

### **Or just use Test Mode for now:**

1. Open `portfolio_viewmodel.swift`
2. Change `useMarketstackTest = false` to `true`
3. Uses mock data (no ATS issues)
4. Fix Info.plist later

---

## ✅ **Verification**

After adding the ATS exception:

1. **Clean Build Folder**: Product → Clean Build Folder (Cmd+Shift+K)
2. **Quit Xcode completely**
3. **Reopen your project**
4. **Build and Run**
5. **Refresh portfolio**
6. **Check console** - should work now!

---

**Which method worked for you?** Or should we just use test mode for now? Let me know!
