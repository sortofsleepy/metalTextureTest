//
//  MenuViewController.m
//  Created by lukasz karluk on 12/12/11.
//

#import "MyAppViewController.h"

#import "OFAppViewController.h"
#import "ofApp.h"

@interface MyAppViewController()
@property (nonatomic, strong) ARSession *session;
@end

@implementation MyAppViewController


- (void)loadView {
    [super loadView];
    
    ARCore::SFormat format;
    format.enableLighting();
    self.session = ARCore::generateNewSession(format);
    //camera = [[MetalCamRenderer alloc] setup:self.session];
    
  
    OFAppViewController *viewController;
    viewController = [[[OFAppViewController alloc] initWithFrame:[[UIScreen mainScreen] bounds]
                                                                 app:new ofApp(self.session)] autorelease];
    
    //viewController.view = [camera getView];
    //[viewController.view addSubview:[camera getView]];
    
    
    [self.navigationController setNavigationBarHidden:TRUE];
    [self.navigationController pushViewController:viewController animated:NO];
    self.navigationController.navigationBar.topItem.title = @"ofApp";
 
}


- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    BOOL bRotate = NO;
    bRotate = bRotate || (toInterfaceOrientation == UIInterfaceOrientationPortrait);
    bRotate = bRotate || (toInterfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
    bRotate = bRotate || (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft);
    bRotate = bRotate || (toInterfaceOrientation == UIInterfaceOrientationLandscapeRight);
    return bRotate;
}

@end
