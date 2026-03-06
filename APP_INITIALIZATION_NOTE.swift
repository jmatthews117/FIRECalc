//
//  IMPORTANT: Add this to your main App struct
//
//  The SubscriptionManager needs to be initialized when the app launches
//  to start listening for transaction updates.
//

// In your @main App struct, add this to the init():

/*

@main
struct FIRECalcApp: App {
    
    init() {
        // Initialize subscription manager to start listening for transactions
        _ = SubscriptionManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

*/

// This ensures the subscription status is checked on every app launch
// and the transaction listener is active to handle purchases/renewals
