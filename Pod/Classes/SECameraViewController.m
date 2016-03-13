//
//  SECameraViewController.m
//  Pods
//
//  Created by Danil Tulin on 1/26/16.
//
//

#import "SECameraViewController.h"

#import <PBJVision/PBJVision.h>

#import "SEPreviewView.h"
#import "SEShutterView.h"
#import "SERoundButtonsContainer.h"

@interface SECameraViewController () <PBJVisionDelegate>

@property (nonatomic, strong) SEPreviewView *previewView;
@property (nonatomic, strong) SEShutterView *shutterView;

@property (nonatomic, strong) UIButton *closeButton;

@property (nonatomic, strong) PBJVision *vision;

@property (nonatomic, getter=isAppeared) BOOL appeared;

@property (nonatomic, strong) SERoundButtonsContainer *buttonsContainer;

@property (nonatomic, strong) UIButton *lightButton;

@end

@implementation SECameraViewController

#pragma mark - Life Cycle

- (instancetype)initWithDelegate:(id<SECameraViewControllerDelegate>)delegate {
	if (self = [super init]) {
		self.delegate = delegate;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.view.backgroundColor = MP_HEX_RGB([darkPrimaryColor copy]);
	
	[self.view addSubview:self.previewView];
	[self.view addSubview:self.closeButton];
//	[self.view addSubview:self.buttonsContainer];
	
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
			make.height.equalTo(self.previewView.mas_width);
		} else if (self.outputFormat == SEOutputFormatWidescreen) {
			make.top.left.right.equalTo(self.view);
			make.bottom.equalTo(self.closeButton.mas_top);
		}
	}];
	
	[self.shutterView mas_remakeConstraints:^(MASConstraintMaker *make) {
		make.edges.equalTo(self.previewView);
	}];
	
	[self.closeButton mas_remakeConstraints:^(MASConstraintMaker *make) {
		make.width.equalTo(self.view.mas_width);
		make.bottom.equalTo(self.view.mas_bottom);
		make.height.equalTo(@(50));
	}];
	
//	[self.buttonsContainer mas_remakeConstraints:^(MASConstraintMaker *make) {
//		make.bottom.equalTo(self.closeButton.mas_top).offset(-8);
//		make.centerX.equalTo(self.view.mas_centerX);
//	}];
	[super updateViewConstraints];
}

- (void)executeIfLandscape:(void(^)(void))landscapeBlock ifPortrait:(void(^)(void))portraitBlock {
	if (UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) && landscapeBlock != nil) {
		landscapeBlock();
	} else if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation) && portraitBlock != nil) {
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
	[self didChangeOrientation];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	
	RUN_IF_SIMULATOR([self visionDidStartVideoCapture:self.vision];)
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[self.vision stopPreview];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:UIDeviceOrientationDidChangeNotification
												  object:nil];
}

#pragma mark - Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (void)didChangeOrientation {
	UIDeviceOrientation orientation = [UIDevice currentDevice].orientation;
//	PBJVision *vision = self.vision;
	
	[UIView animateWithDuration:defaultAnimationDuration
					 animations:^{
		if (orientation == UIDeviceOrientationLandscapeLeft) {
			[self bringCloseButtonToLandscape];
		} else if (orientation == UIDeviceOrientationLandscapeRight) {
			[self bringCloseButtonToLandscape];
		} else if (orientation == UIDeviceOrientationPortrait) {
			[self bringCloseButtonToPortrait];
		}
	}];
}

#pragma mark - CloseButton

- (UIButton *)closeButton {
	if (_closeButton)
		return _closeButton;
	
	_closeButton = [[UIButton alloc] init];
	[_closeButton setBackgroundColor:MP_HEX_RGB([defaultPrimaryColor copy])];
	[_closeButton setTitle:[NSLocalizedString(@"Close", nil) uppercaseString]
				  forState:UIControlStateNormal];
	[_closeButton addTarget:self
					 action:@selector(didTapCloseButton:)
		   forControlEvents:UIControlEventTouchUpInside];
	
	return _closeButton;
}

- (void)bringCloseButtonToPortrait {
	[_closeButton setTitle:[NSLocalizedString(@"Close", nil) uppercaseString]
				  forState:UIControlStateNormal];
}

- (void)bringCloseButtonToLandscape {
	[_closeButton setTitle:@"x"
				  forState:UIControlStateNormal];
}

- (void)didTapCloseButton:(id)sender {
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - PreviewView

- (UIView *)previewView {
	if (_previewView)
		return _previewView;
	
	_previewView = [[SEPreviewView alloc] init];
	_previewView.backgroundColor = [UIColor blackColor];
	
	AVCaptureVideoPreviewLayer *previewLayer = self.vision.previewLayer;
	previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	[_previewView.layer addSublayer:previewLayer];
	
	_shutterView = [[SEShutterView alloc] init];
	[_previewView addSubview:_shutterView];
	
	return _previewView;
}

#pragma mark - Vision

- (PBJVision *)vision {
	if (_vision)
		return _vision;
	
	_vision = [PBJVision sharedInstance];
	_vision.delegate = self;
	
	_vision.cameraMode = PBJCameraModeVideo;
	_vision.cameraOrientation = PBJCameraOrientationPortrait;
	_vision.focusMode = PBJFocusModeContinuousAutoFocus;
	
	_vision.outputFormat = PBJOutputFormatSquare;
	
	return _vision;
}

#pragma mark - Vision Delegate

- (void)visionSessionDidStart:(PBJVision *)vision {
	[self.vision startVideoCapture];
}

- (void)visionDidStartVideoCapture:(PBJVision *)vision {
	[self.shutterView open];
}

- (void)vision:(PBJVision *)vision
didCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
	if ([self.delegate respondsToSelector:@selector(cameraViewController:didCaptureVideoSampleBuffer:)]) {
		[self.delegate cameraViewController:self
				didCaptureVideoSampleBuffer:sampleBuffer];
	} else {
		NSLog(@"SECameraViewController: no delegate class for capturing sample data");
	}
}

#pragma mark - OutputFormat

- (void)setOutputFormat:(SEOutputFormat)outputFormat {
	NSAssert(!self.isAppeared, @"Setting ouput format must be before loading view");
	_outputFormat = outputFormat;
	if (_outputFormat == SEOutputFormatSquare) {
		self.vision.outputFormat = PBJOutputFormatSquare;
	} else if (_outputFormat == SEOutputFormatWidescreen) {
		self.vision.outputFormat = PBJOutputFormatWidescreen;
	}
}

#pragma mark - Flash Enabled

- (void)setFlashEnabled:(BOOL)flashEnabled {
	NSAssert(!self.isAppeared, @"Setting flash avalaibality format must be before loading view");
	_flashEnabled = flashEnabled;
}

#pragma mark - Buttons Container

- (SERoundButtonsContainer *)buttonsContainer {
	if (_buttonsContainer) {
		return _buttonsContainer;
	}
	
	_buttonsContainer = [[SERoundButtonsContainer alloc] init];
	
	if (self.isFlashEnabled) {
		[_buttonsContainer addButton:self.lightButton];
	}
	
	return _buttonsContainer;
}

- (UIButton *)lightButton {
	if (_lightButton) {
		return _lightButton;
	}
	
	_lightButton = [[UIButton alloc] init];
	[_lightButton setTitle:@"Light" forState:UIControlStateNormal];
	[_lightButton sizeToFit];
	
	return _lightButton;
}

#pragma mark - UIViewController

- (void)viewWillTransitionToSize:(CGSize)size
	   withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator  {
	[super viewWillTransitionToSize:size
		  withTransitionCoordinator:coordinator];
	
}

- (BOOL)prefersStatusBarHidden {
	return YES;
}

- (void)dismissViewControllerAnimated:(BOOL)flag
						   completion:(void (^)(void))completion {
	if (self.shutterView.isOpen) {
		[super dismissViewControllerAnimated:flag
								  completion:completion];
		[self.shutterView close];
	} else {
		[super dismissViewControllerAnimated:flag
								  completion:completion];
	}
}

@end
