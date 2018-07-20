//
//  MetalCam.h
//  metalTextureTest
//
//  Created by Joseph Chow on 6/28/18.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol RenderDestinationProvider
@property (nonatomic, readonly, nullable) MTLRenderPassDescriptor *currentRenderPassDescriptor;
@property (nonatomic, readonly, nullable) id<MTLDrawable> currentDrawable;

@property (nonatomic) MTLPixelFormat colorPixelFormat;
@property (nonatomic) MTLPixelFormat depthStencilPixelFormat;
@property (nonatomic) NSUInteger sampleCount;
@end

typedef struct {
    int                 cvPixelFormat;
    MTLPixelFormat      mtlFormat;
    GLuint              glInternalFormat;
    GLuint              glFormat;
    GLuint              glType;
} AAPLTextureFormatInfo;



@interface MetalCamView : MTKView {
    
    // Reference to the current session
    ARSession * _session;

    // maintains knowledge of the current orientation of the device
    UIInterfaceOrientation orientation;
    
    // Metal objects
    id <MTLTexture> _renderTarget;
    id <MTLCommandQueue> _commandQueue;
    id <MTLBuffer> _sharedUniformBuffer;
    id <MTLBuffer> _anchorUniformBuffer;
    id <MTLBuffer> _imagePlaneVertexBuffer;
    id <MTLRenderPipelineState> _capturedImagePipelineState;
    id <MTLDepthStencilState> _capturedImageDepthState;
    id <MTLRenderPipelineState> _anchorPipelineState;
    id <MTLDepthStencilState> _anchorDepthState;
    
    CVMetalTextureRef _capturedImageTextureYRef;
    CVMetalTextureRef _capturedImageTextureCbCrRef;
    
    // Captured image texture cache
    CVMetalTextureCacheRef _capturedImageTextureCache;
    
    // Flag for viewport size changes
    BOOL _viewportSizeDidChange;
    
    // current viewport settings - using CGRect cause
    // it's needed to allow things to render correctly.
    CGRect _viewport;
    
    // stores formating info that allows interop between OpenGL / Metal
    AAPLTextureFormatInfo formatInfo;
    
    // ======= STUFF FOR OPENGL COMPATIBILITY ========= //
    CVOpenGLESTextureCacheRef _videoTextureCache;
    
    CVPixelBufferRef _sharedPixelBuffer;
    BOOL pixelBufferBuilt;
    
    BOOL openglMode;
}
@property(nonatomic,retain)dispatch_semaphore_t _inFlightSemaphore;
@property(nonatomic,retain)ARSession * session;

- (void) setupOpenGLCompatibility:(CVEAGLContext) eaglContext;
- (CVPixelBufferRef) getSharedPixelbuffer;
- (CVOpenGLESTextureRef) convertToOpenGLTexture:(CVPixelBufferRef) pixelBuffer;
- (void) _updateSharedPixelbuffer;
- (void) _drawCapturedImageWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;
- (void) _updateImagePlaneWithFrame;
- (void) _updateCameraImage;
- (void) update;
- (void) setViewport:(CGRect) _viewport;
- (void) loadMetal;

@end

// ========= Implement the renderer ========= //
class MetalCamRenderer {
    
    MetalCamView * _view;
    ARSession * session;
    CGRect viewport;
    CVEAGLContext context;
public:
    MetalCamRenderer(){}
    ~MetalCamRenderer(){}
    
    MetalCamView* getView(){
        return _view;
    }
    
    void draw(){
        [_view draw];
    }
    
    void setup(ARSession * session, CGRect viewport, CVEAGLContext context){
        
        this->session = session;
        this->viewport = viewport;
        this->context = context;
        
        _view = [[MetalCamView alloc] initWithFrame:viewport device:MTLCreateSystemDefaultDevice()];
        _view.session = session;
        _view.framebufferOnly = false;
        _view.paused = YES;
        _view.enableSetNeedsDisplay = NO;
        
        
        [_view loadMetal];
        [_view setupOpenGLCompatibility:context];
    }
};



NS_ASSUME_NONNULL_END
