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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
    UIImage *image = [UIImage imageNamed:@"sample.png"];
    cv::Mat destination = [self cvMatFromUIImage:image];
    cv::cvtColor(destination, destination, cv::COLOR_BGR2GRAY);
    cv::GaussianBlur(destination, destination, cv::Size(1,1), 1000);
    
    cv::threshold(destination, destination, 120, 255, cv::THRESH_BINARY);
    
    std::vector<std::vector<cv::Point> > contours;
    const cv::Scalar color = cv::Scalar(255, 0, 0);
    cv::findContours(destination, contours, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE);
    
    std::sort(contours.begin(),
              contours.end(),
              [](const std::vector<cv::Point>& lhs, const std::vector<cv::Point>& rhs) {
                  return cv::contourArea(lhs, true) < cv::contourArea(rhs, true);
              });
    
    
    cv::Mat contoursDestination = [self cvMatEmptyFromUIImage:image];
    for(int i=0; i<contours.size() && i<55; i++)
    {
        cv::drawContours(contoursDestination, contours, i, color, 3);
    }
    
    self.inputImageView.image = image;
    self.outputImageView.image = [self UIImageFromCVMat:contoursDestination];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
    
    
    
//    
//    cv::OutputArray dst;
//    GaussianBlur(mat->InputArray, dst, (1,1), );
//    
//    InputArray src,
//    OutputArray dst, Size ksize,
//    double sigmaX, double sigmaY=0,
//    int borderType=BORDER_DEFAULT
    
//    im = cv2.imread(filename)
//    gray = cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
//    blur = cv2.GaussianBlur(gray,(1,1),1000)
//    flag, thresh = cv2.threshold(blur, 120, 255, cv2.THRESH_BINARY)
//    
//    
//    contours, hierarchy = cv2.findContours(thresh,cv2.RETR_TREE,cv2.CHAIN_APPROX_SIMPLE)
//    contours = sorted(contours, key=cv2.contourArea,reverse=True)[:numcards]
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
