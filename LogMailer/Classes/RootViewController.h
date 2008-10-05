//
//  RootViewController.h
//  LogMailer
//
//  Created by Ashwin Bharambe on 10/4/08.
//  Copyright Buxfer, Inc. 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@class UIImageView, UILabel, UIProgressIndicator, UIWindow;

@interface UIProgressHUD : UIView
{
    UIProgressIndicator *_progressIndicator;
    UILabel *_progressMessage;
    UIImageView *_doneView;
    UIWindow *_parentWindow;
    struct {
        unsigned int isShowing:1;
        unsigned int isShowingText:1;
        unsigned int fixedFrame:1;
        unsigned int reserved:30;
    } _progressHUDFlags;
}

- (id)_progressIndicator;
- (id)initWithFrame:(struct CGRect)fp8;
- (void)setText:(id)fp8;
- (void)setShowsText:(BOOL)fp8;
- (void)setFontSize:(int)fp8;
- (void)drawRect:(struct CGRect)fp8;
- (void)layoutSubviews;
- (void)showInView:(id)fp8;
- (void)hide;
- (void)done;
- (void)dealloc;

@end

@interface RootViewController : UIViewController<UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    UITextField *emailTextField;
    UIProgressHUD *progress;
}

+ (UIButton *)buttonWithTitle:	(NSString *)title
                       target:(id)target
                     selector:(SEL)selector
                        frame:(CGRect)frame
                        image:(UIImage *)image
                 imagePressed:(UIImage *)imagePressed
                darkTextColor:(BOOL)darkTextColor;

@end
