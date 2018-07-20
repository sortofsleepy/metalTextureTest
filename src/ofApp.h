#pragma once

#include "ofxiOS.h"
#include "MetalCam.h"
#include "ofxARKit.h"
#import <ARKit/ARKit.h>
class ofApp : public ofxiOSApp {
	
    public:
    ARSession * session;
    
    ofApp (ARSession * session);
    ofApp();
    ~ofApp ();
        void setup();
        void update();
        void draw();
        void exit();
	
        void touchDown(ofTouchEventArgs & touch);
        void touchMoved(ofTouchEventArgs & touch);
        void touchUp(ofTouchEventArgs & touch);
        void touchDoubleTap(ofTouchEventArgs & touch);
        void touchCancelled(ofTouchEventArgs & touch);

        void lostFocus();
        void gotFocus();
        void gotMemoryWarning();
        void deviceOrientationChanged(int newOrientation);
    
        MetalCamRenderer * camera;
    
};


