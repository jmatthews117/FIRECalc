# 🔐 Remote API Key Configuration Setup

## ✅ What This Does

Your Marketstack API key is now **fetched from a remote URL** that you control. This allows you to:
- ✅ Rotate your API key anytime without app updates
- ✅ Keep your key out of your compiled app binary
- ✅ Instantly deactivate keys if compromised
- ✅ Update keys for all users immediately

---

## 🏗️ Setup Instructions

### Step 1: Create Your Remote Config File

Create a JSON file called `marketstack-config.json`:

```json
{
  "marketstackAPIKey": "f1d8fa1b993a683099be615d3c37f058",
  "version": 1,
  "active": true
}
```

### Step 2: Host It Somewhere

You have several options:

#### Option A: GitHub (Private Repo - Recommended)

1. Create a **private** GitHub repository (e.g., `myapp-config`)
2. Add `marketstack-config.json` to the repo
3. **Important:** Make the repo private!
4. Get the raw file URL:
   ```
   https://raw.githubusercontent.com/yourusername/myapp-config/main/marketstack-config.json
   ```
5. **Note:** You'll need a GitHub Personal Access Token to access private repos

#### Option B: GitHub Gist (Private)

1. Create a **secret** Gist at https://gist.github.com
2. Add your JSON content
3. Get the raw URL:
   ```
   https://gist.githubusercontent.com/yourusername/abc123.../raw/marketstack-config.json
   ```

#### Option C: Your Own Server

Host on your own web server:
```
https://yourserver.com/config/marketstack.json
```

#### Option D: Firebase Remote Config

Use Firebase Remote Config for enterprise-grade solution with analytics.

---

## 🔧 Step 3: Update Your Code

### In `MarketstackConfig.swift`:

Find this line:
```swift
private let remoteConfigURL = "YOUR_REMOTE_CONFIG_URL_HERE"
```

Replace with your actual URL:
```swift
private let remoteConfigURL = "https://raw.githubusercontent.com/yourusername/myapp-config/main/marketstack-config.json"
```

---

## 🔐 Security Considerations

### ✅ Good Practices:

1. **Use HTTPS** - Always use secure URLs
2. **Private Repository** - Keep your config repo private
3. **Access Tokens** - Use GitHub tokens for private repos
4. **Fallback Key** - Keep a fallback in case remote fails
5. **Cache Duration** - Config is cached for 1 hour to reduce requests

### ⚠️ What NOT to Do:

1. ❌ Don't use public GitHub repos for your API key
2. ❌ Don't commit your API key to your main app repo
3. ❌ Don't use HTTP (only HTTPS)
4. ❌ Don't share your config URL publicly

---

## 🔄 How to Rotate Your API Key

### When You Need to Change Keys:

1. **Get new API key** from Marketstack dashboard
2. **Update remote config file**:
   ```json
   {
     "marketstackAPIKey": "YOUR_NEW_KEY_HERE",
     "version": 2,
     "active": true
   }
   ```
3. **Commit/upload** the change
4. **Wait up to 1 hour** for all users to fetch new key (cache expires)
5. **Done!** No app update needed

### To Instantly Force Update:

Change the version number or add a timestamp to bust cache on client side.

---

## 🧪 Testing

### Test the Remote Config:

```swift
Task {
    do {
        let key = try await MarketstackConfig.shared.refreshAPIKey()
        print("✅ Got API key: \(key.prefix(10))...")
    } catch {
        print("❌ Failed: \(error)")
    }
}
```

### Test in Browser:

Visit your config URL in a browser - you should see your JSON.

---

## 🚨 Emergency: Deactivate API Key

### Option 1: Change the Key

Update your remote config with a blank or dummy key:
```json
{
  "marketstackAPIKey": "",
  "active": false
}
```

### Option 2: Delete the Config File

Remove the file from your server/repo - app will fall back to hardcoded key.

### Option 3: Revoke on Marketstack

Go to Marketstack dashboard and deactivate the key there.

---

## 🔐 GitHub Private Repo Access

If using a private GitHub repo, you'll need to authenticate:

### Add Personal Access Token:

```swift
private func fetchRemoteAPIKey() async throws -> String {
    guard let url = URL(string: remoteConfigURL) else {
        throw ConfigError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.timeoutInterval = 10
    
    // Add GitHub token for private repos
    if let githubToken = ProcessInfo.processInfo.environment["GITHUB_TOKEN"] {
        request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
    }
    
    // ... rest of code
}
```

---

## 📊 Benefits vs Risks

### ✅ Benefits:

1. **Key Rotation** - Change keys without app updates
2. **Security** - Key not in compiled binary
3. **Control** - Instant deactivation if needed
4. **Flexibility** - Update config for all users instantly
5. **Monitoring** - Can track config fetches

### ⚠️ Risks:

1. **Network Dependency** - Requires internet on first launch
2. **Config Availability** - If server/repo is down, uses fallback
3. **Exposure** - If config URL is found, key could be exposed
4. **Complexity** - More moving parts than hardcoded key

---

## 🎯 Alternative: Store in App (More Secure)

If you want maximum security, consider:

### Option: Use Environment Variables at Build Time

1. Store key in environment variable on your Mac
2. Inject at build time (not runtime)
3. Key is in binary but not in source code

**In Xcode:**
1. Project Settings → Build Settings
2. Add User-Defined Setting: `MARKETSTACK_API_KEY`
3. In code:
   ```swift
   let apiKey = ProcessInfo.processInfo.environment["MARKETSTACK_API_KEY"] ?? "fallback"
   ```

**Pros:** Key not in git, but still in compiled app  
**Cons:** Need app update to rotate key

---

## 🔍 Current Implementation

### What We Built:

1. **`MarketstackConfig.swift`**
   - Fetches API key from remote URL
   - Caches for 1 hour
   - Falls back to hardcoded key if fetch fails

2. **Updated `MarketstackService.swift`**
   - Calls `getAPIKey()` before each API request
   - Uses cached key when available
   - Seamless integration

### How It Works:

```
App Launch
└─ Portfolio Refresh
    └─ MarketstackService.fetchQuote()
        └─ getAPIKey()
            ├─ Check cache (valid for 1 hour)
            │   └─ Return cached key ✅
            │
            └─ Cache expired or empty
                └─ MarketstackConfig.fetchRemoteAPIKey()
                    ├─ HTTP GET to your config URL
                    ├─ Parse JSON response
                    ├─ Cache key for 1 hour
                    └─ Return key ✅
                    
                └─ On Error: Use fallback key
```

---

## 🎯 Recommended Setup

For your use case, I recommend:

### Best Option: Private GitHub Repo

1. **Create private repo:** `myapp-secrets`
2. **Add config file:** `marketstack-config.json`
3. **Use raw URL** (with token if needed)
4. **Keep fallback key** in code as backup

**Why this is best:**
- Free
- Easy to update (just edit file on GitHub)
- Version controlled
- Instant updates
- No server hosting needed

---

## 🚀 Next Steps

1. **Choose your hosting method** (GitHub, Gist, or your server)
2. **Create your config JSON file**
3. **Upload it** to your chosen location
4. **Get the URL** to the raw JSON
5. **Update `MarketstackConfig.swift`** with your URL
6. **Test it** with the test code above
7. **Remove hardcoded key** from fallback if desired

---

## 📝 Example Complete Setup

### Your Private GitHub Repo: `myapp-config`

**File: marketstack-config.json**
```json
{
  "marketstackAPIKey": "f1d8fa1b993a683099be615d3c37f058",
  "version": 1,
  "active": true,
  "notes": "Updated 2026-03-02"
}
```

**In MarketstackConfig.swift:**
```swift
private let remoteConfigURL = "https://raw.githubusercontent.com/yourusername/myapp-config/main/marketstack-config.json"
```

**To Rotate Key:**
1. Get new key from Marketstack
2. Edit file on GitHub
3. Commit change
4. Done! Users get new key within 1 hour

---

## ✅ Summary

**What you asked for:** Store API key remotely, can reset at will  
**What we built:** Remote config system with 1-hour caching  
**How to use:** Host JSON file somewhere, update URL in code  
**How to rotate:** Just edit the remote JSON file!

**Your API key is now rotatable without app updates!** 🎉
