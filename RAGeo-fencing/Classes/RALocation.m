//
//  RALocation.m
//  Pods
//
//  Created by Rashed Al Lahaseh on 1/28/17.
//
//

#import "RALocation.h"

@implementation RALocation

#define iOS_version_greater_than_or_equal(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

static NSString *const kLogIdentifier = @"kLocationManagerGeofenceLocations";
static NSString *const kNotifierIdentifier = @"getDeviceLocation";

@synthesize userLocation;

+ (RALocation *)sharedData
{
    static dispatch_once_t onceToken;
    static RALocation *sharedData = nil;
    dispatch_once(&onceToken, ^{
        sharedData = [[super alloc] initUniqueInstance];
    });
    return sharedData;
}

- (RALocation *)initUniqueInstance {
    self = [super init];
    if (self) {
        userDefaults = [NSUserDefaults standardUserDefaults];
        
        // Initialize Location Manager
        locationManager = [[CLLocationManager alloc] init];
        // Configure Location Manager
        [locationManager setDelegate:self];
        // Filters
        [locationManager setDesiredAccuracy: kCLLocationAccuracyBestForNavigation];
        [locationManager setDistanceFilter: kCLLocationAccuracyNearestTenMeters];
        [locationManager setActivityType: CLActivityTypeAutomotiveNavigation];
        // Background
        [locationManager startMonitoringSignificantLocationChanges];
        
        /*
         if (iOS_version_greater_than_or_equal(@"10.1")) {
         [locationManager setAllowsBackgroundLocationUpdates:YES];
         [locationManager setPausesLocationUpdatesAutomatically: NO];
         }
         */
        
        // NSNotifications
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(locationSetup)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(locationSetup)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(locationSetup)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        
        if ([CLLocationManager locationServicesEnabled]) {
            if(iOS_version_greater_than_or_equal(@"8.0") &&
               [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied)
            {
                // Will open an confirm dialog to get user's approval
                [locationManager requestAlwaysAuthorization];
            }
            else {
                //Will update location immediately
                [locationManager startUpdatingLocation];
            }
        }
        else {
            NSLog(@"Location services are not enabled");
        }
        
        [self reloadDefaultsData];
        
        if ([locationsLog count]) {
            for(CLCircularRegion *region in [locationManager.monitoredRegions allObjects]) {
                [locationManager requestStateForRegion:region];
            }
        }
    }
    return self;
}

#pragma mark - Setup CLLocationManager [Background/Terminate/BecomeActive]
- (void)locationSetup {
    if ([locationManager respondsToSelector:@selector(startUpdatingHeading)])
        [locationManager startUpdatingHeading];
    [locationManager startUpdatingLocation];
    [locationManager startMonitoringSignificantLocationChanges];
}

#pragma mark - Calculate Distance [Current Location ===To===> Destination]
-(float)calculateDistanceFrom:(CLLocationCoordinate2D)from toDestination:(CLLocationCoordinate2D)to
{
    CLLocation *currentLocation = [[CLLocation alloc]initWithLatitude:from.latitude longitude:from.longitude];
    CLLocation *destination = [[CLLocation alloc]initWithLatitude:to.latitude longitude:to.longitude];
    CLLocationDistance distance = [currentLocation distanceFromLocation:destination];
    return [[NSString stringWithFormat:@"%f",distance] floatValue];
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Get Current Location
    CLLocation *currentLocation = [locations lastObject];
    
    userLocation = [[NSDictionary alloc] initWithObjectsAndKeys:
                    [NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude], @"latitude",
                    [NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude], @"longitude", nil];
    
    if (currentLocation.horizontalAccuracy < 0 || currentLocation.verticalAccuracy < 0) {
        NSLog(@"Invalid Accuracy - Horizontal: %f, Vertical: %f", currentLocation.horizontalAccuracy, currentLocation.verticalAccuracy);
    }
    else if (currentLocation.horizontalAccuracy > 100 || currentLocation.verticalAccuracy > 50) {
        NSLog(@"Accuracy Radius Large - Horizontal: %f, Vertical: %f", currentLocation.horizontalAccuracy, currentLocation.verticalAccuracy);
    }
    else {
        NSLog(@"Accuracy Radius In-Range - Horizontal: %f, Vertical: %f", currentLocation.horizontalAccuracy, currentLocation.verticalAccuracy);
    }
    
    // Update User Location Coordinates
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotifierIdentifier object:userLocation];
    
    // Check API data
    [self getLocationsFromAPI];
}

#pragma mark - Geofence Location
- (CLCircularRegion*)dictionaryToCLRegion:(NSDictionary*)dictionary
{
    NSString *identifier = [dictionary valueForKey:@"identifier"];
    CLLocationDegrees longitude =[[dictionary valueForKey:@"longitude"] doubleValue];
    CLLocationDegrees latitude = [[dictionary valueForKey:@"latitude"] doubleValue];
    CLLocationDistance regionRadius = [[dictionary valueForKey:@"radius"] doubleValue];
    CLLocationCoordinate2D centerCoordinate = CLLocationCoordinate2DMake(latitude, longitude);
    
    if( regionRadius > locationManager.maximumRegionMonitoringDistance ) {
        regionRadius = locationManager.maximumRegionMonitoringDistance;
    }
    
    CLCircularRegion * region =nil;
    region =  [[CLCircularRegion alloc] initWithCenter:centerCoordinate radius:regionRadius identifier:identifier];
    [region setNotifyOnEntry:YES];
    [region setNotifyOnExit: YES];
    
    return  region;
}

#pragma mark - CLRegion Delegate
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    NSLog(@"Started Monitoring %@ Region", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    NSLog(@"Monitoring Failed for Region: %@. Reason: %@", region.identifier, error.localizedDescription);
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"Entered Region - %@", region.identifier);
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"Exited Region - %@", region.identifier);
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager*)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusDenied:
            NSLog(@"User Denied");
            break;
        case kCLAuthorizationStatusNotDetermined:
            NSLog(@"User Didn't Determined");
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            NSLog(@"User Determined requestWhenInUseAuthorization");
            [locationManager requestWhenInUseAuthorization];
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            NSLog(@"User Determined startUpdatingLocationAllways");
            [locationManager startUpdatingLocation];
            break;
        default:
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLCircularRegion *)region

{
    float distance = [self calculateDistanceFrom:region.center toDestination:locationManager.location.coordinate];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *date = [formatter stringFromDate:[NSDate date]];
    // Region Identifier
    NSArray *identifierComponents = [region.identifier componentsSeparatedByString:@"-"];
    if ([identifierComponents count] > 4) {
        NSString* regionName = [NSString stringWithFormat:@"%@", [identifierComponents objectAtIndex:0]];
        NSString* regionLocationID = [NSString stringWithFormat:@"%@", [identifierComponents objectAtIndex:2]];
        NSString* regionStatus = [NSString stringWithFormat:@"%@", [identifierComponents objectAtIndex:3]];
        switch (state) {
            case CLRegionStateInside: {
                NSLog(@"User Entered Region - %@", region.identifier);
                BOOL found=NO;
                for (int i = 0; i < [locationsLog count]; i++) {
                    NSMutableDictionary *tempDictionary = [[NSMutableDictionary alloc]
                                                           initWithDictionary: [locationsLog objectAtIndex:i]];
                    if([[tempDictionary objectForKey:@"location_id"] isEqualToString:regionLocationID]) {
                        found = YES;
                        break;
                    }
                }
                if (!found) {
                    NSMutableDictionary* temp = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                                 date,@"time_in",
                                                 regionLocationID, @"location_id", nil];
                    [locationsLog addObject: temp];
                    [self setNotification: [NSString stringWithFormat:
                                            @"[Name:%@, Location-ID:%@, Time-In:%@ Distance:%f]",
                                            [NSString stringWithFormat:@"%@", regionName],
                                            [NSString stringWithFormat:@"%@", regionLocationID],
                                            date,
                                            distance]];
                }
            }
                break;
            case CLRegionStateOutside: {
                NSLog(@"User Exited Region - %@", region.identifier);
                for (int i = 0; i < [locationsLog count]; i++) {
                    NSMutableDictionary *tempDictionary = [[NSMutableDictionary alloc]
                                                           initWithDictionary: [locationsLog objectAtIndex:i]];
                    if ([tempDictionary[@"location_id"] isEqualToString: regionLocationID] && !tempDictionary[@"time_out"]) {
                        [tempDictionary setObject:date forKey:@"time_out"];
                        [locationsLog replaceObjectAtIndex:i withObject:tempDictionary];
                        [self setNotification: [NSString stringWithFormat:
                                                @"[Name:%@, Location-ID:%@, Time-Out:%@ Distance:%f]",
                                                [NSString stringWithFormat:@"%@", regionName],
                                                [NSString stringWithFormat:@"%@", regionLocationID],
                                                date,
                                                distance]];
                        break;
                    }
                }
                if ([regionStatus isEqualToString:@"lastObject"]) {
                    NSLog(@"Exited lastObject");
                    [self getLocationsFromAPI];
                }
            }
                break;
            case CLRegionStateUnknown:
                NSLog(@"User Entered Unknown State  Region - %@", region.identifier);
                break;
            default:
                break;
        }
        [self resetDefaultsData];
    }
}

#pragma mark - User Location Delegate
- (NSDictionary *) returnLocation {
    return userLocation;
}

#pragma mark - Geofence Delegate
- (void) addGeofenceLocation:(NSDictionary*) dictionary {
    CLCircularRegion * region = [self dictionaryToCLRegion: dictionary];
    [locationManager startMonitoringForRegion:region];
}

- (void) findCurrentGeofenceLocation {
    NSLog(@"findCurrentGeofenceLocation %lu",(unsigned long)[[locationManager.monitoredRegions allObjects] count]);
    for(CLCircularRegion *region in [locationManager.monitoredRegions allObjects]) {
        [locationManager requestStateForRegion:region];
    }
}

- (void) removeGeofenceLocation:(NSDictionary*) dictionary {
    CLCircularRegion * region = [self dictionaryToCLRegion: dictionary];
    [locationManager stopMonitoringForRegion:region];
}

- (void) clearGeofencesLocations {
    for(CLCircularRegion *region in [locationManager.monitoredRegions allObjects]) {
        [locationManager stopMonitoringForRegion:region];
    }
    NSLog(@"clearGeofencesLocations %lu",(unsigned long)[[locationManager.monitoredRegions allObjects] count]);
}


#pragma mark - Get Data from API
- (void) getLocationsFromAPI {
    // Set your API which keep your locations data updated every 19 locations
    NSURL *url = [[NSURL alloc] initWithString: @""];
    [NSURLConnection sendAsynchronousRequest:[[NSURLRequest alloc] initWithURL:url]
                                       queue:[[NSOperationQueue alloc] init]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error)
     {
         if (error) {
             NSLog(@"Error %@", error);
         }
         else {
             // After that we need to setup the ideftifiers for each region you want to add
             NSError *error;
             id returnedData = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
             if ([returnedData count])
                 [self getNewLocations: returnedData];
             else
                 NSLog(@"Empty");
         }
     }];
}

#pragma mark - Get Locations
- (void) getNewLocations:(id)result {
    [self clearGeofencesLocations];
    for (NSMutableDictionary* getBusinessLocations in result)
    {
        NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithDictionary: getBusinessLocations];
        [dictionary setValue:[NSString stringWithFormat:@"%@-%@-%@-%@",
                              dictionary[@"businessName"],
                              dictionary[@"id"],
                              dictionary[@"location_id"],
                              @"normalLocation"] forKey:@"identifier"];
        [self addGeofenceLocation:dictionary];
    }
    
    NSMutableDictionary* dataDictionary = [[NSMutableDictionary alloc] init];
    [dataDictionary setValue:[[self returnLocation] objectForKey:@"longitude"] forKey:@"longitude"];
    [dataDictionary setValue:[[self returnLocation] objectForKey:@"latitude"] forKey:@"latitude"];
    [dataDictionary setValue:[NSString stringWithFormat:@"%@-%@-lastObject",
                              [[self returnLocation] objectForKey:@"latitude"],
                              [[self returnLocation] objectForKey:@"longitude"]] forKey:@"identifier"];
    CLLocationCoordinate2D userCoordinate = CLLocationCoordinate2DMake([[[self returnLocation] objectForKey:@"latitude"] floatValue], [[[self returnLocation] objectForKey:@"longitude"] floatValue]);
    CLLocationCoordinate2D lastCoordinate = CLLocationCoordinate2DMake([[[result objectAtIndex:[result count]-1] objectForKey:@"latitude"] floatValue], [[[result objectAtIndex:[result count]-1] objectForKey:@"longitude"] floatValue]);
    float radiusValue = [self calculateDistanceFrom:userCoordinate toDestination:lastCoordinate];
    [dataDictionary setValue:[NSString stringWithFormat:@"%f",radiusValue] forKey:@"radius"];
    
    // Add-lastObject-Geofence
    [self addGeofenceLocation:dataDictionary];
    
    // Find-Current-Geofence
    [self findCurrentGeofenceLocation];
    
    /*****************************************/
    NSMutableArray* nearbyLog = [[NSMutableArray alloc] init];
    for (NSMutableDictionary* getBusinessLocations in result)
    {
        [nearbyLog addObject: [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                               getBusinessLocations[@"businessName"], @"Name",
                               getBusinessLocations[@"distance"], @"Distance",
                               getBusinessLocations[@"radius"], @"Radius",
                               getBusinessLocations[@"location_id"], @"Location-ID", nil]];
    }
    [nearbyLog addObject:dataDictionary];
    
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Geofence Locations"
                                                     message:[nearbyLog componentsJoinedByString:@"\n"]
                                                    delegate:nil
                                           cancelButtonTitle:@"Close"
                                           otherButtonTitles:nil, nil];
    [alert show];
    /*****************************************/
}

#pragma mark - Set Notifications
- (void)setNotification:(NSString *)str {
    // Request Authorization for LocalNotification
    [self registerNotificationSettingsCompletionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (!error) {
            NSLog(@"request authorization succeeded!");
        }
    }];
    if (iOS_version_greater_than_or_equal(@"10.0")) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        [content setBody: str];
        [content setSound: [UNNotificationSound defaultSound]];
        [content setCategoryIdentifier: str];
        [content setBadge: @([[UIApplication sharedApplication] applicationIconBadgeNumber] + 1)];
        [content setLaunchImageName: @"LaunchImage"];
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1.0f repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:str content:content trigger:trigger];
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
            if (!error) {
                NSLog(@"Add %@ Succeeded!", request.identifier);
            }
            else {
                NSLog(@"%@", error);
            }
        }];
    }
    else {
        UILocalNotification* localNotification = [[UILocalNotification alloc] init];
        [localNotification setFireDate: [NSDate dateWithTimeIntervalSinceNow:1]];
        [localNotification setTimeZone: [NSTimeZone defaultTimeZone]];
        [localNotification setSoundName: UILocalNotificationDefaultSoundName];
        [localNotification setAlertAction: @"Alert"];
        [localNotification setAlertBody: str];
        [localNotification setCategory: str];
        [localNotification setApplicationIconBadgeNumber: [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1];
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
    }
}

- (void)registerNotificationSettingsCompletionHandler:(void (^)(BOOL granted, NSError *__nullable error))completionHandler; {
    /// Request authorization for localNotification
    if (iOS_version_greater_than_or_equal(@"10.0")) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionBadge | UNAuthorizationOptionSound | UNAuthorizationOptionAlert)
                              completionHandler:completionHandler];
    }
    else if (iOS_version_greater_than_or_equal(@"8.0"))  {
        UIUserNotificationSettings *userNotificationSettings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeAlert | UIUserNotificationTypeSound | UIUserNotificationTypeBadge)
                                                                                                 categories:nil];
        UIApplication *application = [UIApplication sharedApplication];
        [application registerUserNotificationSettings:userNotificationSettings];
    }
}

#pragma mark - User Defaults
- (void)reloadDefaultsData {
    if ([userDefaults objectForKey:kLogIdentifier]) {
        locationsLog = [[NSMutableArray alloc] initWithArray: [userDefaults objectForKey:kLogIdentifier]];
    }
    else {
        locationsLog = [NSMutableArray new];
    }
}

- (void)resetDefaultsData {
    [userDefaults setObject:locationsLog forKey:kLogIdentifier];
    [userDefaults synchronize];
    [self reloadDefaultsData];
}

@end
