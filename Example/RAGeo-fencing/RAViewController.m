//
//  RAViewController.m
//  RAGeo-fencing
//
//  Created by rashed on 01/28/2017.
//  Copyright (c) 2017 rashed. All rights reserved.
//

#import "RAViewController.h"

@interface RAViewController ()

@end

@implementation RAViewController


static NSString *const kDefaultPinIdentifier = @"Destination";
static NSString *const kNotifierIdentifier = @"getDeviceLocation";

#define METERS_PER_MILE 1609.344

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    deviceLocation = [RALocation sharedData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceLocationNotifier:)
                                                 name:kNotifierIdentifier
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotifierIdentifier object:nil];
}

#pragma mark - Get User Location
- (void) deviceLocationNotifier:(NSNotification *) notification {
    CLLocationDegrees longitude =[[[deviceLocation returnLocation] objectForKey:@"longitude"] doubleValue];
    CLLocationDegrees latitude =[[[deviceLocation returnLocation] objectForKey:@"latitude"] doubleValue];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(longitude, latitude);
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(coordinate, 0.5 * METERS_PER_MILE,
                                                                       0.5 * METERS_PER_MILE);
    // Add an annotation
    point = [[MKPointAnnotation alloc] init];
    [point setCoordinate: coordinate];
    [point setTitle: @"I am here !"];
    [point setSubtitle: @"Testing"];
    
    [self.mapKit addAnnotation:point];
    [self.mapKit selectAnnotation:point animated:YES];
    [self.mapKit setRegion:viewRegion animated:YES];
}

-(void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    MKCoordinateRegion viewRegion = MKCoordinateRegionMakeWithDistance(mapView.userLocation.coordinate,
                                                                       0.5 * METERS_PER_MILE,
                                                                       0.5 * METERS_PER_MILE);
    [mapView setRegion:viewRegion animated: YES];
}

- (void)mapView:(MKMapView *)myMapView regionDidChangeAnimated:(BOOL)animated
{
    NSLog(@"Center: %f %f", myMapView.region.center.latitude,myMapView.region.center.longitude);
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithOverlay:overlay];
        [renderer setStrokeColor:[UIColor redColor]];
        [renderer setLineWidth:4.0];
        return renderer;
    }
    return nil;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    MKPinAnnotationView *pinAnnotation = nil;
    if(annotation != (self.mapKit.userLocation)) {
        pinAnnotation = (MKPinAnnotationView *)[self.mapKit dequeueReusableAnnotationViewWithIdentifier:kDefaultPinIdentifier];
        if ( pinAnnotation == nil )
            pinAnnotation = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kDefaultPinIdentifier];
        pinAnnotation.canShowCallout = YES;
        // Route to Google Maps
        UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        [pinAnnotation setRightCalloutAccessoryView: infoButton];
        //        [infoButton addTarget:self action:@selector(showOnGMaps) forControlEvents:UIControlEventTouchUpInside];
    }
    return pinAnnotation;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
