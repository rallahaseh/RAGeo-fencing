//
//  RAViewController.h
//  RAGeo-fencing
//
//  Created by rashed on 01/28/2017.
//  Copyright (c) 2017 rashed. All rights reserved.
//

@import UIKit;

#import "RALocation.h"

@interface RAViewController : UIViewController{
    RALocation *deviceLocation;
    CLLocationCoordinate2D locationCoordinate;
    MKPolyline *routeLine;
    MKPolylineView *routeLineView;
    MKPointAnnotation *point;
}

@property (strong, nonatomic) IBOutlet MKMapView *mapKit;

@end
