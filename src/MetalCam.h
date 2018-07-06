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

@interface MetalCamView : MTKView
@end



// ========= METAL RENDERER ======= //
@interface MetalCamRenderer : NSObject {
    
    ARSession * _session;
    MetalCamView * _view;
    
    dispatch_semaphore_t _inFlightSemaphore;

    // Metal objects
    id <MTLDevice> _device;
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
    
    
    // The current viewport size
    //CGSize _viewportSize;
    
    // Flag for viewport size changes
    BOOL _viewportSizeDidChange;
    
    // current viewport settings - using CGRect cause
    // it's needed to allow things to render correctly.
    CGRect _viewport;
    
}
- (MetalCamView*) getView;
- (void) loadMetal;
- (void) setViewport:(CGRect) _viewport;
- (instancetype) setup:(ARSession*) session;
- (void) draw;
@end

NS_ASSUME_NONNULL_END
