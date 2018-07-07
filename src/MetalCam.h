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

@interface MetalCamView : MTKView {
    ARSession * _session;

    // Metal objects
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
}
@property(nonatomic,retain)dispatch_semaphore_t _inFlightSemaphore;
@property(nonatomic,retain)ARSession * session;

- (void) _drawCapturedImageWithCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;
- (void) _updateImagePlaneWithFrame;
- (void) _updateCameraImage;
- (void) update;
- (void) setViewport:(CGRect) _viewport;
- (void) loadMetal;

@end



// ========= METAL RENDERER ======= //
@interface MetalCamRenderer : NSObject {
    
    ARSession * _session;
    MetalCamView * _view;

    // Metal objects
    id <MTLDevice> _device;
    
}
- (MetalCamView*) getView;
- (instancetype) setup:(ARSession*) session;
@end

NS_ASSUME_NONNULL_END
