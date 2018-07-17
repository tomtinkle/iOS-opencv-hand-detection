// Put OpenCV include files at the top. Otherwise an error happens.
#import <vector>
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>

#include <opencv2/imgproc/imgproc_c.h>
#include <opencv2/highgui/highgui_c.h>

#import <Foundation/Foundation.h>
#import "OpenCV.h"
#import "OpenCVHelper.h"

#define VIDEO_FILE    "video.avi"
#define VIDEO_FORMAT    CV_FOURCC('M', 'J', 'P', 'G')
#define NUM_FINGERS    5
#define NUM_DEFECTS    8

#define RED     CV_RGB(255, 0, 0)
#define GREEN   CV_RGB(0, 255, 0)
#define BLUE    CV_RGB(0, 0, 255)
#define YELLOW  CV_RGB(255, 255, 0)
#define PURPLE  CV_RGB(255, 0, 255)
#define GREY    CV_RGB(200, 200, 200)

#pragma mark -

@implementation OpenCV

typedef NS_ENUM(NSUInteger, CVFeatureDetectorType) {
    CVFeatureDetectorTypeSURF,
    CVFeatureDetectorTypeSIFT,
    CVFeatureDetectorTypeORB,
    CVFeatureDetectorTypeAKAZE,
};

/**
 OpenCVのバージョンを返す

 @return OpenCVのバージョン情報
 */
+(NSString *) openCVVersionString
{
    return [NSString stringWithFormat: @"openCV Version %s", CV_VERSION];
}


/**
 グレースケール化

 @param image 入力画像
 @return グレースケール化した画像
 */
+(UIImage * ) makeGrayFromImage:(UIImage *)image
{
    // transform UIImagge to cv::Mat
    cv::Mat imageMat = [OpenCVHelper cvMatFromUIImage:image];
    
    // if the image already grayscale, return it
    if(imageMat.channels() == 1)return image;
    
    // transform the cv::Mat color image to gray
    cv::Mat grayMat;
    cv::cvtColor (imageMat, grayMat, CV_BGR2GRAY);
    
    return [OpenCVHelper UIImageFromCVMat:grayMat];
}

/**
テンプレートマッチング
テンプレートで渡した画像とマッチングする位置を抽出
 
 @param srcImage 入力画像
 @param templateImage マッチングさせたいテンプレート画像
 @return マッチング部分を矩形選択した画像
 */
+ (UIImage *)match :(UIImage *)srcImage templateImage:(UIImage *)templateImage {
    
    cv::Mat srcMat = [OpenCVHelper cvMatFromUIImage:srcImage];
    cv::Mat tmpMat = [OpenCVHelper cvMatFromUIImage:templateImage];
    
    // 入力画像をコピー
    cv::Mat dst = srcMat.clone();
    
    // マッチング
    cv::matchTemplate(srcMat, tmpMat, dst, cv::TM_CCOEFF);
    
    double min_val, max_val;
    cv::Point min_loc, max_loc;
    cv::minMaxLoc(dst, &min_val, &max_val, &min_loc, &max_loc);
    
    // 結果の描画
    cv::rectangle(srcMat, max_loc, cv::Point(max_loc.x + tmpMat.cols, max_loc.y + tmpMat.rows), CV_RGB(0, 255, 0), 2);
    
    return [OpenCVHelper UIImageFromCVMat:srcMat];
}

/**
 特徴点抽出
 入力画像から特徴点を抽出する

 @param srcImage 入力画像
 @return 特徴点部分に円を表示
 */
+ (UIImage *)detectKeypoints:(UIImage *)srcImage
{
    cv::Mat srcMat = [OpenCVHelper cvMatFromUIImage:srcImage];

    // detector 生成 A-KAZE　KAZEの高速処理版　端末がめっちゃ熱くなる
//    cv::Ptr<cv::FeatureDetector> detector = cv::AKAZE::create();
    // detector 生成 KAZE　正確だが遅い
//    cv::Ptr<cv::FeatureDetector> detector = cv::KAZE::create();
    // detector 生成 ORB　早いが結構情報量がばらけてる
    cv::Ptr<cv::FeatureDetector> detector = cv::ORB::create();
    
    // 特徴点抽出
    std::vector<cv::KeyPoint> keypoints;
    detector->detect(srcMat, keypoints);
    
    printf("%lu keypoints are detected.\n", keypoints.size());
    
    // 特徴点を描画
    cv::Mat dstMat;
    
    dstMat = srcMat.clone();
    for(int i = 0; i < keypoints.size(); i++) {
        
        cv::KeyPoint *point = &(keypoints[i]);
        cv::Point center;
        int radius;
        center.x = cvRound(point->pt.x);
        center.y = cvRound(point->pt.y);
        radius = cvRound(point->size*0.25);
        
        cv::circle(dstMat, center, radius, cvScalar(255,255,0));
    }
    return [OpenCVHelper UIImageFromCVMat:dstMat];
}

/**
 手検出
 入力画像から手指情報を抽出する
 
 @param srcImage 入力画像
 @return 手指を描画
 */
+ (UIImage *)handDetection:(UIImage *)srcImage
{
    struct ctx ctx = { };
    
    ctx.image = [OpenCVHelper createIplImageFromUIImage:srcImage];
    
    init_ctx(&ctx);
    
    filter_and_threshold(&ctx);
    find_contour(&ctx);
    find_convex_hull(&ctx);
    find_fingers(&ctx);
    
    display(&ctx);
    
    return [OpenCVHelper UIImageFromIplImage:ctx.image];
}

// https://github.com/bengal/opencv-hand-detection
struct ctx {
    CvCapture    *capture;    /* Capture handle */
    CvVideoWriter    *writer;    /* File recording handle */
    
    IplImage    *image;        /* Input image */
    IplImage    *thr_image;    /* After filtering and thresholding */
    IplImage    *temp_image1;    /* Temporary image (1 channel) */
    IplImage    *temp_image3;    /* Temporary image (3 channels) */
    
    CvSeq        *contour;    /* Hand contour */
    CvSeq        *hull;        /* Hand convex hull */
    
    CvPoint        hand_center;
    CvPoint        *fingers;    /* Detected fingers positions */
    CvPoint        *defects;    /* Convexity defects depth points */
    
    CvMemStorage    *hull_st;
    CvMemStorage    *contour_st;
    CvMemStorage    *temp_st;
    CvMemStorage    *defects_st;
    
    IplConvKernel    *kernel;    /* Kernel for morph operations */
    
    int        num_fingers;
    int        hand_radius;
    int        num_defects;
};


void init_ctx(struct ctx *ctx)
{
    ctx->thr_image = cvCreateImage(cvGetSize(ctx->image), 8, 1);
    ctx->temp_image1 = cvCreateImage(cvGetSize(ctx->image), 8, 1);
    ctx->temp_image3 = cvCreateImage(cvGetSize(ctx->image), 8, 3);
    ctx->kernel = cvCreateStructuringElementEx(9, 9, 4, 4, CV_SHAPE_RECT,
                                               NULL);
    ctx->contour_st = cvCreateMemStorage(0);
    ctx->hull_st = cvCreateMemStorage(0);
    ctx->temp_st = cvCreateMemStorage(0);
    ctx->fingers = static_cast<CvPoint*>(calloc(NUM_FINGERS + 1, sizeof(CvPoint)));
    ctx->defects = static_cast<CvPoint*>(calloc(NUM_DEFECTS, sizeof(CvPoint)));
}

void filter_and_threshold(struct ctx *ctx)
{
    
    /* Soften image */
    cvSmooth(ctx->image, ctx->temp_image3, CV_GAUSSIAN, 11, 11, 0, 0);
    /* Remove some impulsive noise */
    cvSmooth(ctx->temp_image3, ctx->temp_image3, CV_MEDIAN, 11, 11, 0, 0);
    
    cvCvtColor(ctx->temp_image3, ctx->temp_image3, CV_BGR2HSV);
    
    /*
     * Apply threshold on HSV values to detect skin color
     */
    cvInRangeS(ctx->temp_image3,
               cvScalar(0, 55, 90, 255),
               cvScalar(28, 175, 230, 255),
               ctx->thr_image);
    
    /* Apply morphological opening */
    cvMorphologyEx(ctx->thr_image, ctx->thr_image, NULL, ctx->kernel,
                   CV_MOP_OPEN, 1);
    cvSmooth(ctx->thr_image, ctx->thr_image, CV_GAUSSIAN, 3, 3, 0, 0);
}

void find_contour(struct ctx *ctx)
{
    double area, max_area = 0.0;
    CvSeq *contours, *tmp, *contour = NULL;
    
    /* cvFindContours modifies input image, so make a copy */
    cvCopy(ctx->thr_image, ctx->temp_image1, NULL);
    cvFindContours(ctx->temp_image1, ctx->temp_st, &contours,
                   sizeof(CvContour), CV_RETR_EXTERNAL,
                   CV_CHAIN_APPROX_SIMPLE, cvPoint(0, 0));
    
    /* Select contour having greatest area */
    for (tmp = contours; tmp; tmp = tmp->h_next) {
        area = fabs(cvContourArea(tmp, CV_WHOLE_SEQ, 0));
        if (area > max_area) {
            max_area = area;
            contour = tmp;
        }
    }
    
    /* Approximate contour with poly-line */
    if (contour) {
        contour = cvApproxPoly(contour, sizeof(CvContour),
                               ctx->contour_st, CV_POLY_APPROX_DP, 2,
                               1);
        ctx->contour = contour;
    }
}

void find_convex_hull(struct ctx *ctx)
{
    CvSeq *defects;
    CvConvexityDefect *defect_array;
    int i;
    int x = 0, y = 0;
    int dist = 0;
    
    ctx->hull = NULL;
    
    if (!ctx->contour)
        return;
    
    ctx->hull = cvConvexHull2(ctx->contour, ctx->hull_st, CV_CLOCKWISE, 0);
    
    if (ctx->hull) {
        
        /* Get convexity defects of contour w.r.t. the convex hull */
        defects = cvConvexityDefects(ctx->contour, ctx->hull,
                                     ctx->defects_st);
        
        if (defects && defects->total) {
            defect_array = static_cast<CvConvexityDefect*>(calloc(defects->total,
                                  sizeof(CvConvexityDefect)));
            cvCvtSeqToArray(defects, defect_array, CV_WHOLE_SEQ);
            
            /* Average depth points to get hand center */
            for (i = 0; i < defects->total && i < NUM_DEFECTS; i++) {
                x += defect_array[i].depth_point->x;
                y += defect_array[i].depth_point->y;
                
                ctx->defects[i] = cvPoint(defect_array[i].depth_point->x,
                                          defect_array[i].depth_point->y);
            }
            
            x /= defects->total;
            y /= defects->total;
            
            ctx->num_defects = defects->total;
            ctx->hand_center = cvPoint(x, y);
            
            /* Compute hand radius as mean of distances of
             defects' depth point to hand center */
            for (i = 0; i < defects->total; i++) {
                int d = (x - defect_array[i].depth_point->x) *
                (x - defect_array[i].depth_point->x) +
                (y - defect_array[i].depth_point->y) *
                (y - defect_array[i].depth_point->y);
                
                dist += sqrt(d);
            }
            
            ctx->hand_radius = dist / defects->total;
            free(defect_array);
        }
    }
}

void find_fingers(struct ctx *ctx)
{
    int n;
    int i;
    CvPoint *points;
    CvPoint max_point;
    int dist1 = 0, dist2 = 0;
    
    ctx->num_fingers = 0;
    
    if (!ctx->contour || !ctx->hull)
        return;
    
    n = ctx->contour->total;
    points = static_cast<CvPoint*>(calloc(n, sizeof(CvPoint)));
    
    cvCvtSeqToArray(ctx->contour, points, CV_WHOLE_SEQ);
    
    /*
     * Fingers are detected as points where the distance to the center
     * is a local maximum
     */
    for (i = 0; i < n; i++) {
        int dist;
        int cx = ctx->hand_center.x;
        int cy = ctx->hand_center.y;
        
        dist = (cx - points[i].x) * (cx - points[i].x) +
        (cy - points[i].y) * (cy - points[i].y);
        
        if (dist < dist1 && dist1 > dist2 && max_point.x != 0
            && max_point.y < cvGetSize(ctx->image).height - 10) {
            
            ctx->fingers[ctx->num_fingers++] = max_point;
            if (ctx->num_fingers >= NUM_FINGERS + 1)
                break;
        }
        
        dist2 = dist1;
        dist1 = dist;
        max_point = points[i];
    }
    
    free(points);
}

void display(struct ctx *ctx)
{
    int i;
    
    if (ctx->num_fingers == NUM_FINGERS) {
        
#if defined(SHOW_HAND_CONTOUR)
        cvDrawContours(ctx->image, ctx->contour, BLUE, GREEN, 0, 1,
                       CV_AA, cvPoint(0, 0));
#endif
        cvCircle(ctx->image, ctx->hand_center, 5, PURPLE, 1, CV_AA, 0);
        cvCircle(ctx->image, ctx->hand_center, ctx->hand_radius,
                 RED, 1, CV_AA, 0);
        
        for (i = 0; i < ctx->num_fingers; i++) {
            
            cvCircle(ctx->image, ctx->fingers[i], 10,
                     GREEN, 3, CV_AA, 0);
            
            cvLine(ctx->image, ctx->hand_center, ctx->fingers[i],
                   YELLOW, 1, CV_AA, 0);
        }
        
        for (i = 0; i < ctx->num_defects; i++) {
            cvCircle(ctx->image, ctx->defects[i], 2,
                     GREY, 2, CV_AA, 0);
        }
    }
}

@end
