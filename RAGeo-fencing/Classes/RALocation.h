//
//  RALocation.h
//  Pods
//
//  Created by Rashed Al Lahaseh on 1/28/17.
//
//

@import Foundation;
@import UIKit;
@import QuartzCore;
@import CoreLocation;
@import MapKit;
@import UserNotifications;

@interface RALocation : NSObject <CLLocationManagerDelegate> {
    NSDictionary* identifierType;
    NSMutableArray* locationsLog;
    
    NSUserDefaults *userDefaults;
    CLLocationManager *locationManager;
}

@property NSDictionary* userLocation;

+ (RALocation*)sharedData;

- (NSDictionary *) returnLocation;

@end
