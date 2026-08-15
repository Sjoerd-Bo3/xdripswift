import UIKit
import CoreData
import OSLog

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Properties
    
    var window: UIWindow?
    
    /// the quickActionsManager instance needed to process the shortcut items received
    private let quickActionsManager = QuickActionsManager()
    
    /// allow the orientation to be changed as per the settings for each individual view controller
    var restrictRotation:UIInterfaceOrientationMask = .all
    
    private var log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryAppDelegate)

    /// the app's root view controller, ie the tab bar controller in Main.storyboard
    ///
    /// this is deliberately owned by AppDelegate and not by SceneDelegate. The complete application stack, including
    /// BluetoothPeripheralManager and with it the CBCentralManager, gets built in RootViewController's viewDidLoad. When iOS relaunches
    /// the app in the background - which is exactly what happens for a CoreBluetooth state restoration event - it does not connect a
    /// UIWindowScene, so scene(_:willConnectTo:) never runs. If the view controller were created only there, no CBCentralManager would be
    /// recreated, CoreBluetooth restoration would time out, and the app would stop receiving readings until manually opened by the user.
    private var rootViewController: UIViewController?

    // MARK: - Application Life Cycle

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("*** in didFinishLaunchingWithOptions ***", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)
        trace("****************************************", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)

        // if the app is launched into the background then no scene will connect, so build the view controller stack here. This has to
        // happen before this function returns, because that's when CoreBluetooth expects the central manager to be recreated with its
        // restore identifier
        if application.applicationState == .background {
            trace("in didFinishLaunchingWithOptions, app launched into the background, creating rootViewController without waiting for a scene", log: log, category: ConstantsLog.categoryAppDelegate, type: .info)

            _ = rootViewControllerCreateIfNeeded()
        }

        return true
    }

    /// returns the root view controller, creating it first if it doesn't exist yet
    ///
    /// creating it forces viewDidLoad to run, which is what sets up the application data, including the bluetooth stack. There must only
    /// ever be one instance - a second one would create a second BluetoothPeripheralManager and with it a second CBCentralManager
    func rootViewControllerCreateIfNeeded() -> UIViewController? {

        if let rootViewController = rootViewController { return rootViewController }

        guard let newRootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() else {
            trace("in rootViewControllerCreateIfNeeded, failed to instantiate the initial view controller from the Main storyboard", log: log, category: ConstantsLog.categoryAppDelegate, type: .error)
            return nil
        }

        rootViewController = newRootViewController

        // force the view to load, this is what runs viewDidLoad
        newRootViewController.loadViewIfNeeded()

        // loading a UITabBarController's own view does not necessarily load the view of the tab that is selected, force it, because
        // RootViewController - the first tab - is where the application stack gets created
        if let tabBarController = newRootViewController as? UITabBarController {
            (tabBarController.selectedViewController ?? tabBarController.viewControllers?.first)?.loadViewIfNeeded()
        }

        return rootViewController
    }

    /// used to allow/prevent the specific views from changing orientation when rotating the device
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask
    {
        return self.restrictRotation
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
    }
  
    // Handle Quick Actions
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let quickActionType = QuickActionType(rawValue: shortcutItem.type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
        
        completionHandler(true)
    }
    
    // Configure a new scene and process any quick action used during scene creation
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Handle quick action invoked while creating this new scene
        if let type = options.shortcutItem?.type, let quickActionType = QuickActionType(rawValue: type) {
            quickActionsManager.handleQuickAction(quickActionType)
        }
        
        // Handle quick action invoked while creating this new scene
        let sceneConfiguration = UISceneConfiguration(name: "Default",sessionRole: connectingSceneSession.role)
        sceneConfiguration.delegateClass = SceneDelegate.self
        
        return sceneConfiguration
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Just acknowledge the URL so the system doesn't crash
        return true
    }
}

