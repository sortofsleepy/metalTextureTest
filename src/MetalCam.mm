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


-(void)drawRect:(CGRect)rect{
    if(!self.currentDrawable || !self.currentRenderPassDescriptor){
        NSLog(@"unable to render");
        return;
    }
    
    NSLog(@"Rendering");
}


// sets the viewport
- (void)setViewport:(CGRect)_viewport{
    self->_viewport = _viewport;
}

- (void) update {
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


- (void)dealloc {
    [super dealloc];
    CVBufferRelease(_capturedImageTextureYRef);
    CVBufferRelease(_capturedImageTextureCbCrRef);
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

-(void) loadMetal {
    
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
        _view.device = MTLCreateSystemDefaultDevice();
    }

    return self;
}

@end

