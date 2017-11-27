//
//  ViewController.m
//  CardMe
//
//  Created by Eric on 25/10/2015.
//  Copyright © 2015 Eric. All rights reserved.
//

#import "ViewController.h"

#import <opencv2/opencv.hpp>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *inputImageView;
@property (weak, nonatomic) IBOutlet UIImageView *outputImageView;
@property (weak, nonatomic) IBOutlet UIStepper *stepper;
@property (weak, nonatomic) IBOutlet UILabel *stepperLabel;
@property (weak, nonatomic) IBOutlet UIImageView *selectedCardImageView;
@property (assign, nonatomic) std::vector<std::vector<cv::Point> > contours;
@property (weak, nonatomic) IBOutlet UIImageView *recognizedCardImageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    UIImage *image = [UIImage imageNamed:@"sample.png"];
    cv::Mat destination = [self _preprocess:image];
    
    std::vector<std::vector<cv::Point> > contours;
    cv::findContours(destination, contours, cv::RETR_LIST, cv::CHAIN_APPROX_SIMPLE);
    
    std::sort(contours.begin(),
              contours.end(),
              [](const std::vector<cv::Point>& lhs, const std::vector<cv::Point>& rhs) {
                  double area1 = cv::contourArea(lhs, true);
                  double area2 = cv::contourArea(rhs, true);
                  return area1 < area2;
              });
    
    
    self.contours = contours;
    
    
    self.inputImageView.image = image;
    self.stepper.minimumValue = 1;
    self.stepper.maximumValue = 55;
    [self _extractCardAtIndex:1];
}


- (IBAction)_stepperHandler:(id)sender
{
    [self _extractCardAtIndex:(int)self.stepper.value];
}

- (void) _extractCardAtIndex:(NSInteger)index
{
    self.stepper.value = index;
    self.stepperLabel.text = [NSString stringWithFormat:@"%d", (int)index];
    
    UIImage *image = [UIImage imageNamed:@"sample.png"];
    
    
    std::vector<cv::Point> contour = self.contours[index];
    
    std::vector<cv::Point> approx;
    cv::approxPolyDP(cv::Mat(contour), approx, arcLength(cv::Mat(contour), NO)*0.02, NO);
    
    
    cv::RotatedRect minRect = minAreaRect(cv::Mat(contour));
    cv::Point2f rect_points[4];
    minRect.points( rect_points );
    std::vector<cv::Point2f> approx2;
    for ( int j = 0; j < 4; j++ ) {
        approx2.push_back(rect_points[j]);
    }
    
    std::vector<cv::Point2f> ordered = [self _order:approx2];
    
    std::vector<cv::Point2f> output;
    output.push_back(cv::Point2f(0.0f, 0.0f));
    output.push_back(cv::Point2f(71.0f, 0.0f));
    output.push_back(cv::Point2f(71.0f, 96.0f));
    output.push_back(cv::Point2f(0.0f, 96.0f));
    
    cv::Mat trans_mat33 = cv::getPerspectiveTransform(ordered, output);
    cv::Mat warpImage;
    cv::Mat src_img = [self cvMatFromUIImage:image];
    cv::warpPerspective(src_img, warpImage, trans_mat33, src_img.size(), cv::INTER_LINEAR);

    UIImage *warImage = [self UIImageFromCVMat:warpImage];
    CGImageRef imageRef = CGImageCreateWithImageInRect([warImage CGImage], CGRectMake(0, 0, 71, 96));
    self.selectedCardImageView.image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    [self _recognizeImage:self.selectedCardImageView.image];
    [self _drawContoursWitSelectedCard:index];
    
}

- (std::vector<cv::Point2f>) _order:(std::vector<cv::Point2f>)input
{
    
    double pt0s = input[0].x + input[0].y;
    double pt1s = input[1].x + input[1].y;
    double pt2s = input[2].x + input[2].y;
    double pt3s = input[3].x + input[3].y;
    
    NSArray *sumArray = @[@(pt0s), @(pt1s), @(pt2s), @(pt3s)];
    NSNumber *sumMax = [sumArray valueForKeyPath:@"@max.floatValue"];
    NSNumber *sumMin = [sumArray valueForKeyPath:@"@min.floatValue"];
    
    cv::Point2f outputPt0, outputPt1, outputPt2, outputPt3;
    
    NSMutableArray *finalSumArray = [NSMutableArray new];
    for(int i=0; i<sumArray.count; i++)
    {
        NSNumber *value = sumArray[i];
        if(value.floatValue == sumMin.floatValue) outputPt0 = input[i];
        else if(value.floatValue == sumMax.floatValue) outputPt2 = input[i];
        else [finalSumArray addObject:value];
    }
    
    NSNumber *finalSumMax = [finalSumArray valueForKeyPath:@"@max.floatValue"];
    NSNumber *finalSumMin = [finalSumArray valueForKeyPath:@"@min.floatValue"];
    for(int i=0; i<sumArray.count; i++)
    {
        NSNumber *value = sumArray[i];
        if(value.floatValue == finalSumMax.floatValue) outputPt3 = input[i];
        else if(value.floatValue == finalSumMin.floatValue) outputPt1 = input[i];
    }
    
    std::vector<cv::Point2f> output;
    output.push_back(outputPt0);
    output.push_back(outputPt1);
    output.push_back(outputPt2);
    output.push_back(outputPt3);
    
    return output;
}

- (void) _drawContoursWitSelectedCard:(NSInteger)slectedCardIndex
{
    
    UIImage *image = [UIImage imageNamed:@"sample.png"];
    cv::Mat contoursDestination = [self cvMatEmptyFromUIImage:image];
    
    for(int i=0; i<self.contours.size() && i<55; i++)
    {
        std::vector<cv::Point> contour = self.contours[i];
        
        std::vector<cv::Point> approx;
        cv::approxPolyDP(cv::Mat(contour), approx, arcLength(cv::Mat(contour), NO)*0.02, NO);
        
        
        cv::RotatedRect minRect = minAreaRect(cv::Mat(contour));
        cv::Point2f rect_points[4];
        minRect.points( rect_points );
        std::vector<cv::Point2f> approx2;
        
        cv::Scalar color = (slectedCardIndex == i)?(cv::Scalar(255,0,0)):(cv::Scalar(0,255,0));
        
        for ( int j = 0; j < 4; j++ ) {
            cv::line( contoursDestination, rect_points[j], rect_points[(j+1)%4], color, 2, 8 );
        }
    }
    
    self.outputImageView.image = [self UIImageFromCVMat:contoursDestination];
    
}

- (void) _recognizeImage:(UIImage*)inputImage
{
    double bestMatchValue = MAXFLOAT;
    NSString *bestMatchName = @"";
    
    cv::Mat preprocessInputImage = [self cvMatFromUIImage:inputImage];
    
    NSArray *deckImageNameArray = [self _deckImageNameArray];
    for(NSString *imageName in deckImageNameArray)
    {
        cv::Mat preprocessCardImage = [self cvMatFromUIImage:[UIImage imageNamed:imageName]];

        double pnsr = [self getPSNRFromM1:preprocessInputImage andM2:preprocessCardImage];
        if(pnsr < bestMatchValue)
        {
            bestMatchValue = pnsr;
            bestMatchName = imageName;
        }
    }
    
    self.recognizedCardImageView.image = [UIImage imageNamed:bestMatchName];
}

// from https://docs.opencv.org/2.4/doc/tutorials/highgui/video-input-psnr-ssim/video-input-psnr-ssim.html#videoinputpsnrmssim
- (double) getPSNRFromM1:(cv::Mat)I1 andM2:(cv::Mat)I2 {
    cv::Mat s1;
    absdiff(I1, I2, s1);       // |I1 - I2|
    s1.convertTo(s1, CV_32F);  // cannot make a square on 8 bits
    s1 = s1.mul(s1);           // |I1 - I2|^2
    
    cv::Scalar s = sum(s1);        // sum elements per channel
    
    double sse = s.val[0] + s.val[1] + s.val[2]; // sum channels
    
    if( sse <= 1e-10) // for small values return zero
        return 0;
    else
    {
        double mse  = sse / (double)(I1.channels() * I1.total());
        double psnr = 10.0 * log10((255 * 255) / mse);
        return psnr;
    }
}

- (cv::Mat) _preprocess:(UIImage*)inputImage
{
    cv::Mat destination = [self cvMatFromUIImage:inputImage];
    cv::cvtColor(destination, destination, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(destination, destination, cv::Size(1,1), 1000);
    cv::threshold(destination, destination, 120, 255, cv::THRESH_BINARY);
    
    return destination;
}

- (NSArray*) _deckImageNameArray
{
    NSMutableArray *deckImageNameArray = [NSMutableArray new];
    for(NSString *prefix in @[@"c", @"d", @"h", @"s"]) {
        for(int i=1; i<=10; i++) {
            [deckImageNameArray addObject:[NSString stringWithFormat:@"%@%d", prefix, i]];
        }
        for(NSString *sufix in @[@"j", @"k", @"q"]) {
            [deckImageNameArray addObject:[NSString stringWithFormat:@"%@%@", prefix, sufix]];
        }
    }
    return deckImageNameArray;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}



- (cv::Mat)cvMatEmptyFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    [[UIColor blackColor] setFill];
    CGContextFillRect(contextRef, CGRectMake(0, 0, image.size.width, image.size.height));
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}


-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}


@end
