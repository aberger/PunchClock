//
//  PCAppDelegate.m
//  PunchClock
//
//  Created by James Moore on 11/25/13.
//  Copyright (c) 2013 Panic Inc. All rights reserved.
//

#import "PCAppDelegate.h"
#import <KeychainItemWrapper/KeychainItemWrapper.h>

@implementation PCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Logging
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	[DDLog addLogger:[DDASLLogger sharedInstance]];

	[[DDTTYLogger sharedInstance] setColorsEnabled:YES];
	[[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:0.714f green:0.729f blue:0.714f alpha:1.000] backgroundColor:nil forFlag:LOG_FLAG_DEBUG];
	[[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:0.624f green:0.635f blue:0.337f alpha:1.000] backgroundColor:nil forFlag:LOG_FLAG_INFO];
	[[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:0.839f green:0.631f blue:0.298f alpha:1.000] backgroundColor:nil forFlag:LOG_FLAG_WARN];
	[[DDTTYLogger sharedInstance] setForegroundColor:[UIColor colorWithRed:0.925f green:0.000f blue:0.000f alpha:1.000] backgroundColor:nil forFlag:LOG_FLAG_ERROR];

	PCFileFunctionLevelFormatter *formatter = [PCFileFunctionLevelFormatter new];
	[[DDTTYLogger sharedInstance] setLogFormatter:formatter];

	// Default Settings
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:1];
	settings[@"username"] = @"";

	[[NSUserDefaults standardUserDefaults] registerDefaults:settings];

	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"username" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:NULL];

	self.locationManager = [PCLocationManager sharedLocationManager];

	application.statusBarHidden = NO;
	application.statusBarStyle = UIStatusBarStyleLightContent;

	[application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];

	return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [NSUserDefaults standardUserDefaults]) {

		if ([keyPath isEqualToString:@"username"]) {
			[self syncPreferencesWithKeychain];
		}

	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)syncPreferencesWithKeychain
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *username = [defaults stringForKey:@"username"];

	NSString *serviceName = keychainID;

	KeychainItemWrapper *personKeychainItem = [[KeychainItemWrapper alloc] initWithIdentifier:@"Username" accessGroup:nil];

	[personKeychainItem setObject:@"pcUsername" forKey:(__bridge id) kSecAttrAccount];
	[personKeychainItem setObject:serviceName forKey:(__bridge id) kSecAttrService];
	NSString *kcUsername = [personKeychainItem objectForKey:((__bridge id) kSecValueData)];

	if (![username isEqualToString:@""] && ![username isEqualToString:kcUsername]) {
		// If it's in the Prefs and it's different from what's in the keychain
		DDLogDebug(@"Pushing username to keychain");
		[personKeychainItem setObject:username forKey:(__bridge id) kSecValueData];

	} else if ([username isEqualToString:@""] && kcUsername) {
		// If its in the keychain but not in the prefs
		DDLogDebug(@"Username missing from prefs, fetching from Keychain: %@", kcUsername);
		[defaults setObject:kcUsername forKey:@"username"];
	}

	[defaults synchronize];

}

#pragma mark - background fetch

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler
{
	DDLogDebug(@"I'm running in the background!");

	BOOL updated = [self.locationManager updateLocationStatusIfNeeded];
	UIBackgroundFetchResult result;

	if (updated) {
		result = UIBackgroundFetchResultNewData;
	} else {
		result = UIBackgroundFetchResultNoData;
	}

	dispatch_group_notify(self.locationManager.dispatchGroup, dispatch_get_main_queue(), ^{
		DDLogDebug(@"Background stuff finished. Result is %ld", (long) result);
		completionHandler(result);
	});

}

#pragma mark - Notifications

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
	// If the application is in the foreground, we will notify the user of the region's state via an alert.
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:notification.alertBody
																									message:nil
																								 delegate:nil
																				cancelButtonTitle:NSLocalizedString(@"OK", @"")
																				otherButtonTitles:nil];
	[alert show];

}


#pragma mark - basic stuff

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	[self.locationManager enterBackground];
	[[NSUserDefaults standardUserDefaults] synchronize];
	DDLogVerbose(@"<---");
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	DDLogVerbose(@"<---");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	DDLogVerbose(@"<---");
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

	// Called when the control center is dismissed
	[self.locationManager enterForeground];

	DDLogVerbose(@"<---");
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	DDLogVerbose(@"<---");
}

@end
