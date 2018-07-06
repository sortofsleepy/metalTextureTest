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
@end

// ========= Implement the renderer ========= //
@implementation MetalCamRenderer

// returns the MTKView object
- (MetalCamView*) getView {
    return _view;
}

// sets the viewport 
- (void)setViewport:(CGRect)_viewport{
    self->_viewport = _viewport;
}
-(instancetype)setup:(ARSession*) session {
    self = [super init];
    
    if(self){
        _session = session;
        _device = MTLCreateSystemDefaultDevice();
        
        //_view = [[MetalCamView alloc] init];
        //_view.device = _device;
        _view = [[MetalCamView alloc] initWithFrame:CGRectMake(0, 0, 100, 100) device:_device];
        _view.enableSetNeedsDisplay = NO;
        _view.paused = YES;
        
        [self loadMetal];
    }
    
    return self;
}


- (void) draw{
    [_view draw];
}

-(void) loadMetal {
    
    _inFlightSemaphore = dispatch_semaphore_create(kMaxBuffersInFlight);
    
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    _view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    _view.sampleCount = 1;
    
    // Create a vertex buffer with our image plane vertex data.
    _imagePlaneVertexBuffer = [_device newBufferWithBytes:&kImagePlaneVertexData length:sizeof(kImagePlaneVertexData) options:MTLResourceCPUCacheModeDefaultCache];
    
    _imagePlaneVertexBuffer.label = @"ImagePlaneVertexBuffer";
    
    // Load all the shader files with a metal file extension in the project
    // NOTE - this line will throw an exception if you don't have a .metal file as part of your compiled sources.
    id <MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    
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
     _capturedImagePipelineState = [_device newRenderPipelineStateWithDescriptor:capturedImagePipelineStateDescriptor error:&error];
    if (!_capturedImagePipelineState) {
        NSLog(@"Failed to created captured image pipeline state, error %@", error);
    }
    
    // do stencil setup
    // TODO this might not be needed in this case.
    MTLDepthStencilDescriptor *capturedImageDepthStateDescriptor = [[MTLDepthStencilDescriptor alloc] init];
    capturedImageDepthStateDescriptor.depthCompareFunction = MTLCompareFunctionAlways;
    capturedImageDepthStateDescriptor.depthWriteEnabled = NO;
    _capturedImageDepthState = [_device newDepthStencilStateWithDescriptor:capturedImageDepthStateDescriptor];
 
    // initialize image cache
    CVMetalTextureCacheCreate(NULL, NULL, _device, NULL, &_capturedImageTextureCache);
    
    // Create the command queue
    _commandQueue = [_device newCommandQueue];
}
@end

