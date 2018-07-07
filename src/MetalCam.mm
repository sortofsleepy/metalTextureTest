//
//  MetalCam.m
//  metalTextureTest
//
//  Created by Joseph Chow on 6/28/18.
//

#import <simd/simd.h>
#import <ModelIO/ModelIO.h>
#import <MetalKit/MetalKit.h>
#import "MetalCam.h"
#include "ofMain.h"
// Include header shared between C code here, which executes Metal API commands, and .metal files
#import "ShaderTypes.h"

// The max number of command buffers in flight
static const NSUInteger kMaxBuffersInFlight = 3;
static const float kImagePlaneVertexData[16] = {
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
};
@implementation MetalCamView
- (void) _setSemaphore:(dispatch_semaphore_t) inFlightSemaphore{
    _inFlightSemaphore = inFlightSemaphore;
}
- (void) _setSession:(ARSession*) session{
    _session = session;
}

-(void)drawRect:(CGRect)rect{
    if(!self.currentDrawable || !self.currentRenderPassDescriptor){
        NSLog(@"unable to render");
        return;
    }
    
    [self update];
}


// sets the viewport
- (void)setViewport:(CGRect)_viewport{
    self->_viewport = _viewport;
}
- (void)dealloc {
    [super dealloc];
    CVBufferRelease(_capturedImageTextureYRef);
    CVBufferRelease(_capturedImageTextureCbCrRef);
}
- (void) update {

    if (!_session) {
        return;
    }
    

    // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
    //   pipeline (App, Metal, Drivers, GPU, etc)
    dispatch_semaphore_wait(_inFlightSemaphore, DISPATCH_TIME_FOREVER);
    
    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
    //   finished proccssing the commands we're encoding this frame.  This indicates when the
    //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
    //   and the GPU.
    __block dispatch_semaphore_t block_sema = _inFlightSemaphore;
    // Retain our CVMetalTextureRefs for the duration of the rendering cycle. The MTLTextures
    //   we use from the CVMetalTextureRefs are not valid unless their parent CVMetalTextureRefs
    //   are retained. Since we may release our CVMetalTextureRef ivars during the rendering
    //   cycle, we must retain them separately here.
    CVBufferRef capturedImageTextureYRef = CVBufferRetain(_capturedImageTextureYRef);
    CVBufferRef capturedImageTextureCbCrRef = CVBufferRetain(_capturedImageTextureCbCrRef);
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        dispatch_semaphore_signal(block_sema);
        CVBufferRelease(capturedImageTextureYRef);
        CVBufferRelease(capturedImageTextureCbCrRef);
    }];
    
    // update camera image
    [self _updateCameraImage];
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor* renderPassDescriptor = self.currentRenderPassDescriptor;
    
    // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll skip
    //   any rendering this frame because we have no drawable to draw to
    if (renderPassDescriptor != nil) {
        //NSLog(@"Got render pass descriptor - we can render!");
        // Create a render command encoder so we can render into something
        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = @"MyRenderEncoder";
        
        // DRAW PRIMATIVE
        
        //[self _drawCapturedImageWithCommandEncoder:renderEncoder];
        //[self _drawAnchorGeometryWithCommandEncoder:renderEncoder];
        
        // We're done encoding commands
        [renderEncoder endEncoding];
    }else{
        //NSLog(@"Error - do not have render pass descriptor");
    }
    
}



- (CVMetalTextureRef)_createTextureFromPixelBuffer:(CVPixelBufferRef)pixelBuffer pixelFormat:(MTLPixelFormat)pixelFormat planeIndex:(NSInteger)planeIndex {
    
    const size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex);
    const size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex);
    
    CVMetalTextureRef mtlTextureRef = nil;
    CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, _capturedImageTextureCache, pixelBuffer, NULL, pixelFormat, width, height, planeIndex, &mtlTextureRef);
    if (status != kCVReturnSuccess) {
        CVBufferRelease(mtlTextureRef);
        mtlTextureRef = nil;
    }
    
    return mtlTextureRef;
}

- (void) _updateImagePlaneWithFrame{
    // Update the texture coordinates of our image plane to aspect fill the viewport
    CGAffineTransform displayToCameraTransform = CGAffineTransformInvert([_session.currentFrame displayTransformForOrientation:UIInterfaceOrientationLandscapeRight viewportSize:_viewport.size]);
    

    // TODO - example code is fine but here I have to cast? :/
    float *vertexData = (float*)[_imagePlaneVertexBuffer contents];
    
    for (NSInteger index = 0; index < 4; index++) {
        NSInteger textureCoordIndex = 4 * index + 2;
        CGPoint textureCoord = CGPointMake(kImagePlaneVertexData[textureCoordIndex], kImagePlaneVertexData[textureCoordIndex + 1]);
        CGPoint transformedCoord = CGPointApplyAffineTransform(textureCoord, displayToCameraTransform);
        vertexData[textureCoordIndex] = transformedCoord.x;
        vertexData[textureCoordIndex + 1] = transformedCoord.y;
    }
}

- (void) _updateCameraImage {
    // Create two textures (Y and CbCr) from the provided frame's captured image
    CVPixelBufferRef pixelBuffer = _session.currentFrame.capturedImage;
    
    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
        return;
    }
    
    CVBufferRelease(_capturedImageTextureYRef);
    CVBufferRelease(_capturedImageTextureCbCrRef);
    _capturedImageTextureYRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatR8Unorm planeIndex:0];
    _capturedImageTextureCbCrRef = [self _createTextureFromPixelBuffer:pixelBuffer pixelFormat:MTLPixelFormatRG8Unorm planeIndex:1];
    
    
}

-(void) _loadMetal {
    
    _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
    
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _view.sampleCount = 1;
    
    // Create a vertex buffer with our image plane vertex data.
    _imagePlaneVertexBuffer = [self.device newBufferWithBytes:&kImagePlaneVertexData length:sizeof(kImagePlaneVertexData) options:MTLResourceCPUCacheModeDefaultCache];
    
    _imagePlaneVertexBuffer.label = @"ImagePlaneVertexBuffer";
    
    // Load all the shader files with a metal file extension in the project
    // NOTE - this line will throw an exception if you don't have a .metal file as part of your compiled sources.
    id <MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];
    
    id <MTLFunction> capturedImageVertexFunction = [defaultLibrary newFunctionWithName:@"capturedImageVertexTransform"];
    id <MTLFunction> capturedImageFragmentFunction = [defaultLibrary newFunctionWithName:@"capturedImageFragmentShader"];
    
    // Create a vertex descriptor for our image plane vertex buffer
    MTLVertexDescriptor *imagePlaneVertexDescriptor = [[MTLVertexDescriptor alloc] init];
    
    // build camera image plane
    // Positions.
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].offset = 0;
    imagePlaneVertexDescriptor.attributes[kVertexAttributePosition].bufferIndex = kBufferIndexMeshPositions;
    
    // Texture coordinates.
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].format = MTLVertexFormatFloat2;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].offset = 8;
    imagePlaneVertexDescriptor.attributes[kVertexAttributeTexcoord].bufferIndex = kBufferIndexMeshPositions;
    
    // Position Buffer Layout
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stride = 16;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepRate = 1;
    imagePlaneVertexDescriptor.layouts[kBufferIndexMeshPositions].stepFunction = MTLVertexStepFunctionPerVertex;
    
    
    // Create a pipeline state for rendering the captured image
    MTLRenderPipelineDescriptor *capturedImagePipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    capturedImagePipelineStateDescriptor.label = @"MyCapturedImagePipeline";
    capturedImagePipelineStateDescriptor.sampleCount = _view.sampleCount;
    capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction;
    capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction;
    capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor;
    capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = _view.depthStencilPixelFormat;
    capturedImagePipelineStateDescriptor.stencilAttachmentPixelFormat = _view.depthStencilPixelFormat;
    
    NSError *error = nil;
    _capturedImagePipelineState = [self.device newRenderPipelineStateWithDescriptor:capturedImagePipelineStateDescriptor error:&error];
    if (!_capturedImagePipelineState) {
        NSLog(@"Failed to created captured image pipeline state, error %@", error);
    }
    
    // do stencil setup
    // TODO this might not be needed in this case.
    MTLDepthStencilDescriptor *capturedImageDepthStateDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    capturedImageDepthStateDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    capturedImageDepthStateDescriptor.depthWriteEnabled = NO;
    _capturedImageDepthState = [self.device newDepthStencilStateWithDescriptor:capturedImageDepthStateDescriptor];
    
    // initialize image cache
    CVMetalTextureCacheCreate(NULL, NULL, self.device, NULL, &_capturedImageTextureCache);
    
    // Create the command queue
    _commandQueue = [self.device newCommandQueue];
}
@end

// ========= Implement the renderer ========= //
@implementation MetalCamRenderer
- (instancetype) setupWithViewport:(ARSession*)session second:(CGRect) _viewport{
    
    _session = session;
    _view = [[MetalCamView alloc] initWithFrame:_viewport device:MTLCreateSystemDefaultDevice()];
    return self;
}

// returns the MTKView object
- (MetalCamView*) getView {
    return _view;
}

- (instancetype) setup:(ARSession*) session{
    self = [super init];
    
    if(self){
        _session = session;
        _view = [[MetalCamView alloc] init];
        [_view _setSession:session];
        
        // TODO this should be mutable value
        [_view _setSemaphore:dispatch_semaphore_create(kMaxBuffersInFlight)];
        
        _view.device = MTLCreateSystemDefaultDevice();
    }

    return self;
}

@end

