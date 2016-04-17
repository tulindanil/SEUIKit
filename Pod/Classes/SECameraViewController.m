//
//  SECameraViewController.m
//  Pods
//
//  Created by Danil Tulin on 1/26/16.
//
//

#import <Accelerate/Accelerate.h>

#import "SECameraViewController.h"

#import "SEVision.h"

#import "SEPreviewView.h"
#import "SEShutterView.h"
#import "SERoundButtonsContainer.h"

@interface SECameraViewController () <SEVisionDelegate>

@property (nonatomic, strong) SEPreviewView *previewView;
@property (nonatomic, strong) SEShutterView *shutterView;

@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) SEVision *vision;

@property (nonatomic, getter=isAppeared) BOOL appeared;

@property (nonatomic, strong) UIButton *lightButton;

@property (nonatomic, readwrite) UIDeviceOrientation orientation;

@end

@implementation SECameraViewController

#pragma mark - Life Cycle

- (instancetype)initWithDelegate:(id<SECameraViewControllerDelegate>)delegate {
	if (self = [self init]) {
		self.delegate = delegate;
	}
	return self;
}

- (instancetype)init {
	if (self = [super init]) {
		self.darkPrimaryColor = MP_HEX_RGB([darkPrimaryColor copy]);
		self.defaultPrimaryColor = MP_HEX_RGB([primaryColor copy]);
		self.accentColor = MP_HEX_RGB([accentColor copy]);
		
        self.closeButtonEnabled = YES;
        
		self.idleTime = 30;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.view.backgroundColor = self.defaultPrimaryColor;
	
	[self.view addSubview:self.previewView];
    
    if (self.closeButtonEnabled)
		[self.view addSubview:self.closeButton];
	
	[self.vision startPreview];
	[self.view setNeedsUpdateConstraints];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	self.vision.previewLayer.frame = self.previewView.bounds;
	[self.previewView bringSubviewToFront:self.shutterView];
}

- (void)updateViewConstraints {
	[self.previewView mas_remakeConstraints:^(MASConstraintMaker *make) {
		if (self.outputFormat == SEOutputFormatSquare) {
			make.center.equalTo(self.view);
			make.width.equalTo(self.view);
			make.height.equalTo(self.view.mas_width);
		} else if (self.outputFormat == SEOutputFormatWidescreen) {
			make.top.left.right.equalTo(self.view);
            if (self.closeButtonEnabled == NO)
                make.bottom.equalTo(self.view);
		}
	}];
	
	[self.shutterView mas_remakeConstraints:^(MASConstraintMaker *make) {
		make.edges.equalTo(self.previewView);
	}];
    
    if (self.closeButtonEnabled) {
        [self.closeButton mas_remakeConstraints:^(MASConstraintMaker *make) {
            if (self.outputFormat == SEOutputFormatWidescreen)
                make.top.equalTo(self.previewView.mas_bottom);
            make.width.equalTo(self.view.mas_width);
            make.bottom.equalTo(self.view.mas_bottom);
            make.height.equalTo(@(50));
        }];
    }
	
	[super updateViewConstraints];
}

- (void)executeIfLandscape:(void(^)(void))landscapeBlock
				ifPortrait:(void(^)(void))portraitBlock {
	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation)
		&& landscapeBlock != nil) {
		landscapeBlock();
	} else if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)
			   && portraitBlock != nil) {
		portraitBlock();
	}
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.appeared = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(didChangeOrientation)
												 name:UIDeviceOrientationDidChangeNotification
											   object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
    [self didChangeOrientation];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.shutterView close];
	self.appeared = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[self.vision stopPreview];
	[self.engine stopSession];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIDeviceOrientationDidChangeNotification
												  object:nil];
}

#pragma mark - Preview View offset

- (void)updateCornerView {
    CGFloat factor = 16 / 9;
    if ([self.delegate respondsToSelector:@selector(previewViewCornerFactor:)]) {
        factor = [self.delegate previewViewCornerFactor:self];
    }
    
    if (self.orientation != UIDeviceOrientationPortrait)
        factor = 1 / factor;
    
    [self setFactorCornerPreviewView:factor];
}

- (void)setFactorCornerPreviewView:(CGFloat)factor {
    CGFloat offset = predscriptionViewCornerViewOffset;
    CGFloat offsetY = MAX([self calculateYOffset:factor],
                          offset);
    CGFloat offsetX = MAX([self calculateXOffset:factor],
                          offset);
    CGPoint offsetPoint = CGPointMake(offsetX, offsetY);
    [self.previewView.predscriptionView setCornerViewOffset:offsetPoint];
}

- (CGFloat)calculateXOffset:(CGFloat)factor {
    CGFloat offset = predscriptionViewCornerViewOffset;
    
    CGFloat height = CGRectGetHeight(self.previewView.frame) - 2*offset;
    CGFloat width = factor * height;
    
    CGFloat xOffset = (CGRectGetWidth(self.previewView.frame) - width) / 2;
    return xOffset;
}

- (CGFloat)calculateYOffset:(CGFloat)factor {
    CGFloat offset = predscriptionViewCornerViewOffset;
    
    CGFloat width = CGRectGetWidth(self.previewView.frame) - 2*offset;
    CGFloat height = width / factor;
    
    CGFloat yOffset = (CGRectGetHeight(self.previewView.frame) - height) / 2;
    return yOffset;
}

#pragma mark - Draw Shape

- (SEShape *)convertShape:(SEShape *)shape
					 size:(CGSize)size {
	
	SEShape *convertedShape = [[SEShape alloc] initConvertedWithShape:shape
													      orientation:self.orientation
																 size:size];
	
	return convertedShape;
}

- (void)addShape:(SEShape *)shape {
	
	CGSize previewSize = self.previewView.frame.size;
	CGSize outputSize = self.vision.outputSize;
	
	CGFloat outputHeight = outputSize.width; // according to preview view's portrait size
	CGFloat outputWidth = outputSize.height;
	
	SEShape *convertedShape = [self convertShape:shape
											size:outputSize];
	
	CGFloat factor = previewSize.width / outputWidth;
	CGFloat offset = (outputHeight - previewSize.height / factor) / 2;
	
	[convertedShape transformXCoordinate:factor withOffset:.0f];
	[convertedShape transformYCoordinate:factor withOffset:-offset];
	
	[self.previewView addShape:convertedShape
					 withColor:self.accentColor];
}

- (void)clearShapes {
	[self.previewView clearShapes];
}

#pragma mark - Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (UIDeviceOrientation)orientation {
	UIDevice *device = [UIDevice currentDevice];
	UIDeviceOrientation orientation = device.orientation;
	
	if (orientation == UIDeviceOrientationFaceUp)
		return _orientation;
	
	_orientation = orientation;
	return _orientation;
}

- (void)didChangeOrientation {
    [self updateCornerView];
    
	[UIView animateWithDuration:defaultAnimationDuration animations:^{
		[self.previewView.predscriptionView
		 rotatePredscriptionLabelForOrientation:self.orientation];
	}];
}

#pragma mark - CloseButton

- (UIButton *)closeButton {
	if (_closeButton)
		return _closeButton;
	
	_closeButton = [[UIButton alloc] init];
	[_closeButton setBackgroundColor:self.darkPrimaryColor];
	[_closeButton setTitle:[NSLocalizedString(@"Close", nil) uppercaseString]
				  forState:UIControlStateNormal];
	[_closeButton addTarget:self
					 action:@selector(didTapCloseButton:)
		   forControlEvents:UIControlEventTouchUpInside];
	
	return _closeButton;
}

- (void)didTapCloseButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:^{
		if ([self.delegate
			 respondsToSelector:@selector(cameraViewControllerDidTapCloseButton:)]) {
			[self.delegate cameraViewControllerDidTapCloseButton:self];
		}
	}];
}

#pragma mark - Label

- (void)showLabel {
	[self.previewView.predscriptionView showPredscriptionLabel:YES];
}

- (void)hideLabel {
	[self.previewView.predscriptionView hidePredscriptionLabel:YES];
}

#pragma mark - PreviewView

- (UIView *)previewView {
	if (_previewView)
		return _previewView;
	
	_previewView = [[SEPreviewView alloc] init];
	_previewView.backgroundColor = [UIColor blackColor];
	_previewView.predscriptionView.predscription = [self.label uppercaseString];
	
	AVCaptureVideoPreviewLayer *previewLayer = self.vision.previewLayer;
	[_previewView.layer addSublayer:previewLayer];
	
	_shutterView = [[SEShutterView alloc] init];
	[_previewView addSubview:_shutterView];
	
	return _previewView;
}

#pragma mark - Vision

- (SEVision *)vision {
	if (_vision)
		return _vision;
	
	_vision = [SEVision sharedInstance];
	_vision.delegate = self;
	
	return _vision;
}

#pragma mark - Vision Delegate

- (void)visionSessionDidStartPreview:(SEVision *)vision {
	
	[self.shutterView openWithCompletion:^{
		[self.previewView.predscriptionView showPredscriptionLabel:YES];
		[self.engine startSession];
	}];
	
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
		[NSThread sleepForTimeInterval:self.idleTime];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.isAppeared)
				[self dismissViewControllerAnimated:YES
										 completion:nil];
		});
	});
}

- (void)vision:(SEVision *)vision
didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
	
	CVImageBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
	CVPixelBufferLockBaseAddress(imageBufferRef, 0);
	
	NSUInteger width = 0, height = 0;
	
	NSData *data = [self rotateBuffer:imageBufferRef
								width:&width
							   height:&height];
	
	[self.engine feedBGRAImageData:data
							 width:width
							height:height];
	
	if ([self.delegate respondsToSelector:@selector(cameraViewController:
													didCaptureBGRASampleData:
													width:
													height:)]) {
		[self.delegate cameraViewController:self
				   didCaptureBGRASampleData:data
									  width:width
									 height:height];
	}
	
	if ([self.delegate respondsToSelector:@selector(cameraViewController:
													didCaptureVideoSampleBuffer:)]) {
		[self.delegate cameraViewController:self
				didCaptureVideoSampleBuffer:sampleBuffer];
	}
}

- (NSData *)rotateBuffer:(const CVImageBufferRef)imageBufferRef
				   width:(NSUInteger *)width
				  height:(NSUInteger *)height {
	
	*width = CVPixelBufferGetWidth(imageBufferRef);
	*height = CVPixelBufferGetHeight(imageBufferRef);
	size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBufferRef);
	size_t currSize = bytesPerRow * *height;
	size_t bytesPerRowOut = bytesPerRow;

	void *srcBuff = CVPixelBufferGetBaseAddress(imageBufferRef);
	
	NSUInteger rotationConstant = [self getOrientationConstant];
	unsigned char *outBuff = (unsigned char*)malloc(currSize);
	
	vImage_Buffer ibuff = {srcBuff, *height, *width, bytesPerRow};

	if (rotationConstant % 2 != 0) {
		NSUInteger tmp = *width;
		*width = *height;
		*height = tmp;
		bytesPerRowOut = 4 * *width;
	}
	
	vImage_Buffer ubuff = {outBuff, *height, *width, bytesPerRowOut};
	
	Pixel_8888 backColor = {0, 0, 0, 0};
	vImage_Error err = vImageRotate90_ARGB8888(&ibuff,
											   &ubuff,
											   rotationConstant,
											   backColor,
											   0);
	if (err != kvImageNoError)
		NSLog(@"%ld", err);

	return [NSData dataWithBytesNoCopy:outBuff
								length:currSize
								freeWhenDone:YES];
}

- (NSUInteger)getOrientationConstant {
	switch (self.orientation) {
		case UIDeviceOrientationPortrait:
			return 3;
			break;
		case UIDeviceOrientationLandscapeRight:
			return 2;
			break;
		case UIDeviceOrientationPortraitUpsideDown:
			return 1;
			break;
		case UIDeviceOrientationLandscapeLeft:
			return 0;
			break;
  		default:
			break;
	}
	return 0;
}

#pragma mark - OutputFormat

- (void)setOutputFormat:(SEOutputFormat)outputFormat {
	NSAssert(!self.isAppeared, @"Setting ouput format "
			 					"must be before loading view");
	_outputFormat = outputFormat;
}

#pragma mark - Flash Enabled

- (void)setFlashEnabled:(BOOL)flashEnabled {
	NSAssert(!self.isAppeared, @"Setting flash avalaibality"
			 					"format must be before loading view");
	_flashEnabled = flashEnabled;
}

#pragma mark - UIViewController

- (BOOL)prefersStatusBarHidden {
	return YES;
}

@end
