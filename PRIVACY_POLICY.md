# Privacy Policy for FICalc

**Last Updated: March 7, 2026**

## Introduction

This Privacy Policy describes how FICalc ("we," "our," or "the App") collects, uses, and protects information when you use our mobile application. FICalc is a financial independence and retirement calculator designed to help users plan their path to financial independence through portfolio tracking and Monte Carlo simulations.

We are committed to protecting your privacy and being transparent about our data practices. This policy explains what information we collect, how we use it, and your rights regarding your data.

## Information We Collect

### Information You Provide Directly

When you use FICalc, you may provide the following types of information:

#### Portfolio and Financial Data
- **Asset holdings**: Investment ticker symbols, asset names, quantities, purchase prices, current values, and asset types (stocks, bonds, real estate, cryptocurrency, cash, commodities)
- **Asset allocation preferences**: Your target allocation percentages across different asset classes
- **Expected returns and volatility**: Your estimates for investment performance
- **Cost basis information**: Purchase dates and original investment amounts

#### Retirement Planning Data
- **Personal information**: Current age and planned retirement age
- **Financial goals**: Annual savings contributions, expected annual spending in retirement, safe withdrawal rate preferences, and retirement savings targets
- **Income sources**: Pension amounts, Social Security benefit estimates, start ages for fixed income sources, and pension plan names
- **Inflation assumptions**: Your preferred inflation rate for projections

#### Simulation Parameters
- **Simulation settings**: Number of Monte Carlo runs, time horizons, inflation rates, withdrawal strategies (4% rule, dynamic spending, guardrails, required minimum distributions, variable percentage withdrawal)
- **Historical data preferences**: Whether to use historical bootstrap sampling or parametric simulations

#### App Preferences
- **User settings**: Default simulation parameters, currency display preferences, auto-refresh settings for stock prices
- **Feature usage**: Saved simulation results and portfolio snapshots for performance tracking

### Information Collected Automatically

#### Technical Data
- **Device information**: We do not collect device identifiers, but iOS may use device information for iCloud sync functionality if you enable it
- **App usage**: The app stores locally which features you use, but this data never leaves your device
- **Performance data**: The app may log errors locally for debugging purposes

#### No Analytics or Tracking
FICalc does **NOT** collect:
- Device identifiers (IDFA, IDFV)
- IP addresses
- Location data
- Usage analytics
- Advertising identifiers
- Behavioral tracking data
- Cookies or similar tracking technologies

## How We Use Your Information

### Local Processing Only
All financial calculations, simulations, and portfolio analysis occur **entirely on your device**. Your financial data is processed locally and is never transmitted to our servers or any third party.

### Subscription Management
We use Apple's StoreKit framework to manage FICalc Pro subscriptions. Apple processes subscription transactions according to their privacy policy. We receive only:
- Subscription status (active, expired, in grace period)
- Product identifier (monthly or annual subscription)
- Transaction dates

We do NOT receive:
- Your name
- Email address
- Credit card information
- Billing address
- Any other personal payment information

### Stock Price Data
To provide real-time stock prices for your portfolio holdings (available in FICalc Pro), the app makes requests to Yahoo Finance's public API. These requests include:
- **Ticker symbols** you have added to your portfolio
- **HTTP request metadata** (user agent, request timestamp)

**Important**: Only the ticker symbols are sent—never your quantities, purchase prices, or portfolio values. Yahoo Finance may log these requests according to their own privacy policy. We recommend reviewing Yahoo Finance's privacy practices at https://legal.yahoo.com/us/en/yahoo/privacy/index.html

These API requests are made directly from your device. We do not operate a proxy server or intermediate service that would allow us to see your ticker symbols.

## Data Storage and Security

### Local Storage
All of your portfolio data, retirement plans, simulation results, and settings are stored locally on your device using:
- **iOS secure storage**: UserDefaults for preferences and settings
- **File system storage**: JSON files for portfolio data and simulation history in your app's sandboxed Documents directory
- **Encrypted storage**: iOS automatically encrypts data on devices with a passcode enabled

### iCloud Sync (Optional)
If you choose to enable iCloud sync in iOS Settings > [Your Name] > iCloud:
- Your portfolio data may be synchronized across your Apple devices signed in with the same Apple ID
- Data is transmitted through Apple's iCloud infrastructure with end-to-end encryption
- We do not have access to your iCloud data
- iCloud data handling is subject to Apple's privacy policy: https://www.apple.com/legal/privacy/

You can disable iCloud sync at any time through iOS Settings.

### Data Retention
- **Portfolio data**: Stored indefinitely until you delete it
- **Simulation history**: Automatically limited to the most recent 20 simulations to conserve storage; older simulations are automatically deleted
- **Settings**: Retained until you reset them or uninstall the app

### Security Measures
We implement the following security practices:
- All data remains on your device in iOS's sandboxed environment
- No server-side storage of your financial information
- No account creation or password management (reducing attack surface)
- No transmission of sensitive financial values over the network
- Compliance with iOS security best practices

## Third-Party Services

### Yahoo Finance API
- **Purpose**: Retrieve current stock prices for publicly traded securities
- **Data shared**: Only ticker symbols you add to your portfolio
- **Data NOT shared**: Your portfolio quantities, values, or personal information
- **Privacy policy**: https://legal.yahoo.com/us/en/yahoo/privacy/index.html

### Apple StoreKit (Subscriptions)
- **Purpose**: Process FICalc Pro subscription purchases
- **Data shared**: Subscription transaction data as managed by Apple
- **Data NOT shared**: Your portfolio or financial planning data
- **Privacy policy**: https://www.apple.com/legal/privacy/

### Apple iCloud (Optional)
- **Purpose**: Sync your portfolio data across your Apple devices
- **Data shared**: Portfolio data, settings, and simulation history (only if you enable iCloud for this app)
- **Encryption**: End-to-end encrypted by Apple
- **Privacy policy**: https://www.apple.com/legal/privacy/

We do not integrate any third-party analytics, advertising, or tracking services.

## Your Rights and Choices

### Access Your Data
All your data is stored locally on your device. You can:
- View all portfolio holdings in the Portfolio tab
- Review simulation history in the Simulations tab
- Check settings and retirement plans in the Settings tab
- Export your portfolio data using the "Export Portfolio" feature in Settings > Data Management

### Delete Your Data
You have complete control over your data:
- **Delete individual assets**: Swipe left on any asset in your portfolio
- **Clear simulation history**: Settings > Data Management > Clear Simulation History
- **Reset all data**: Settings > Data Management > Reset All Data (permanently deletes everything)
- **Uninstall the app**: Deleting FICalc from your device removes all locally stored data

### Modify Your Data
You can edit any information at any time:
- Tap any asset to edit its details
- Update retirement planning parameters in Settings
- Adjust simulation defaults in Settings

### Opt Out of Data Collection
- **Stock prices**: Use manual price entry instead of ticker symbols to avoid API requests
- **iCloud sync**: Disable iCloud for FICalc in iOS Settings > [Your Name] > iCloud

### Cancel Subscription
- Manage or cancel your FICalc Pro subscription at any time through:
  - Settings > Subscription > Manage Subscription, or
  - iOS Settings > [Your Name] > Subscriptions

Canceling your subscription does not delete your data. Your portfolio and settings remain on your device.

## Children's Privacy

FICalc is not directed to individuals under the age of 13. We do not knowingly collect personal information from children under 13. If you are a parent or guardian and believe your child has provided information to us, please contact us, and we will delete such information.

The app is rated 4+ in the App Store and contains no age-restricted content. However, financial planning apps are generally intended for adult users.

## Data Sharing and Disclosure

### We Do Not Sell Your Data
We do not sell, rent, trade, or otherwise transfer your personal or financial information to third parties for monetary or other valuable consideration.

### We Do Not Share Your Data
Because all your financial data remains on your device, we never receive it and therefore cannot share it. The only information that leaves your device is:
- Ticker symbols sent to Yahoo Finance API for price lookups (FICalc Pro feature)
- Subscription transaction data processed by Apple's StoreKit

### Legal Obligations
We may disclose information if required to do so by law or in response to valid requests by public authorities (e.g., a court or government agency). However, because we do not collect or store your financial data on our servers, we would have no such data to disclose.

## International Users

FICalc is available worldwide through the Apple App Store. However, please note:
- All data processing occurs on your device
- Stock price data is retrieved from Yahoo Finance, which may have geographic restrictions
- Currency formatting defaults to USD but can be adjusted in settings
- Historical market data is based primarily on U.S. market history (1926-2024)

### GDPR Compliance (European Users)
If you are located in the European Economic Area (EEA), you have certain rights under the General Data Protection Regulation (GDPR):
- **Right of access**: You can access all your data within the app
- **Right to rectification**: You can edit any incorrect data
- **Right to erasure**: You can delete all your data using the "Reset All Data" feature
- **Right to data portability**: You can export your data as JSON
- **Right to object**: You can choose not to use ticker symbols to avoid API requests

Because we do not collect your data on our servers, most GDPR obligations related to data controllers do not apply. Your data remains under your exclusive control on your device.

### CCPA Compliance (California Users)
Under the California Consumer Privacy Act (CCPA), California residents have the right to:
- Know what personal information is collected
- Know whether personal information is sold or disclosed
- Opt out of the sale of personal information
- Access personal information
- Request deletion of personal information

**FICalc's CCPA Compliance**:
- We collect only the financial data you input, stored locally on your device
- We do NOT sell your personal information
- We do NOT share your portfolio or financial data with third parties
- You can access all your data within the app at any time
- You can delete all your data using the "Reset All Data" feature

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect changes in our practices, technology, legal requirements, or other factors. When we make changes:
- We will update the "Last Updated" date at the top of this policy
- For material changes, we will provide notice through the app or via an App Store update description
- Your continued use of FICalc after changes constitutes acceptance of the updated policy

We encourage you to review this Privacy Policy periodically.

## Data Breach Notification

In the unlikely event of a data breach affecting user information:
- Because your financial data is stored only on your device and not on our servers, a breach of our systems would not compromise your portfolio or planning data
- If we become aware of any security issue affecting the app itself, we will promptly release an update and notify users through the App Store

## No Warranty Regarding Calculations

While not strictly a privacy matter, it is important to note:
- FICalc provides estimates and projections for educational purposes only
- All calculations are performed locally on your device using the data and assumptions you provide
- We do not guarantee the accuracy of calculations, simulations, or projections
- This app does not constitute financial advice

See the Legal Disclaimer section in the app's Settings for full terms.

## Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:

**Email**: [YOUR EMAIL ADDRESS HERE]

**Response Time**: We strive to respond to all inquiries within 48 hours.

**App Version**: This privacy policy applies to FICalc version 1.0 and later.

## Your Consent

By using FICalc, you consent to this Privacy Policy and our data practices as described herein.

---

## Summary (Plain Language)

**What data do we collect?**
- Only the financial data you enter into the app (portfolio holdings, retirement goals, etc.)
- This data stays on your device—we never receive it

**Do you track me?**
- No. We don't use analytics, advertising, or tracking technologies

**Do you sell my data?**
- No. We don't receive your data, so we can't sell it

**What leaves my device?**
- Only ticker symbols (like "AAPL") when fetching stock prices
- Subscription information processed by Apple

**Can I delete my data?**
- Yes, anytime. Use "Reset All Data" in Settings, or just delete the app

**Do I need to create an account?**
- No. The app works entirely offline (except for optional stock price updates)

**Is my data encrypted?**
- Yes, by iOS automatically when your device has a passcode

**Questions?**
- Contact us at [YOUR EMAIL ADDRESS HERE]

---

## Version History

- **v1.0 (March 7, 2026)**: Initial privacy policy for FICalc launch

---

**Effective Date**: This Privacy Policy is effective as of March 7, 2026.

© 2026 FICalc. All rights reserved.
