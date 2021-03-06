//
//  SSWAnimator.m
//
//  Created by Arkadiusz Holko http://holko.pl on 29-05-14.
//

#import "SSWAnimator.h"

UIViewAnimationOptions const SSWNavigationTransitionCurve = 7 << 16;

@interface SSWAnimator()
@property (weak, nonatomic) UIViewController *toViewController;
@property (strong, nonatomic) UIView *shadowView;
@end

@implementation SSWAnimator

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    // Approximated lengths of the default animations.
    return [transitionContext isInteractive] ? 0.25f : 0.5f;
}

// Tries to animate a pop transition similarly to the default iOS' pop transition.
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    BOOL isRTL = UIApplication.sharedApplication.userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    CGFloat directionFactor = isRTL ? -1 : 1;

    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UINavigationController *navigationController = fromViewController.navigationController;
    UINavigationBar *navigationBar = navigationController.navigationBar;
    BOOL toNavigationBarHidden = toViewController.navigationController.navigationBarHidden;
    [[transitionContext containerView] insertSubview:toViewController.view belowSubview:fromViewController.view];

    // parallax effect; the offset matches the one used in the pop animation in iOS 7.1
    CGFloat toViewControllerXTranslation = - CGRectGetWidth([transitionContext containerView].bounds) * 0.3f;
    if (toNavigationBarHidden) {
        toViewController.view.bounds = [transitionContext containerView].bounds;
        toViewController.view.center = [transitionContext containerView].center;
    } else {
        CGRect toFrame = toViewController.view.frame;
        toFrame.origin.y = CGRectGetMaxY(navigationBar.frame);
        toViewController.view.frame = toFrame;
    }

    toViewController.view.transform = CGAffineTransformMakeTranslation(toViewControllerXTranslation * directionFactor, 0);

    // add a shadow on the left side of the frontmost view controller
    CGFloat shadowWidth = 4.0f;
    CGFloat navbarHeight = CGRectGetMaxY(navigationBar.frame);
    CGFloat shadowHeight = fromViewController.view.bounds.size.height + navbarHeight;

    UIView *shadowView = [UIView new];
    [fromViewController.view insertSubview:shadowView atIndex:0];
    shadowView.frame = CGRectMake(isRTL ? CGRectGetWidth(fromViewController.view.frame) : -shadowWidth*10,
                                  -navbarHeight,
                                  shadowWidth*10,
                                  shadowHeight);
    shadowView.clipsToBounds = YES;

    CGRect shadowRect = CGRectMake(isRTL ? -shadowWidth : shadowWidth*10 - shadowWidth,
                                   0,
                                   shadowWidth*2,
                                   shadowHeight);
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRect:shadowRect];
    shadowView.layer.shadowPath = [shadowPath CGPath];
    shadowView.layer.shadowOpacity = 0.25f;
    shadowView.layer.shadowRadius = 3.f;

    self.shadowView = shadowView;

    BOOL previousClipsToBounds = fromViewController.view.clipsToBounds;
    fromViewController.view.clipsToBounds = NO;

    // in the default transition the view controller below is a little dimmer than the frontmost one
    UIView *dimmingView = [[UIView alloc] initWithFrame:toViewController.view.bounds];
    CGFloat dimAmount = [self.delegate animatorTransitionDimAmount:self];
    dimmingView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:dimAmount];
    [toViewController.view addSubview:dimmingView];

    // fix hidesBottomBarWhenPushed not animated properly
    UITabBarController *tabBarController = toViewController.tabBarController;
    UINavigationController *navController = toViewController.navigationController;
    UITabBar *tabBar = tabBarController.tabBar;
    BOOL shouldAddTabBarBackToTabBarController = NO;

    BOOL tabBarControllerContainsToViewController = [tabBarController.viewControllers containsObject:toViewController];
    BOOL tabBarControllerContainsNavController = [tabBarController.viewControllers containsObject:navController];
    BOOL isToViewControllerFirstInNavController = [navController.viewControllers firstObject] == toViewController;
    BOOL shouldAnimateTabBar = [self.delegate animatorShouldAnimateTabBar:self];
    if (shouldAnimateTabBar && tabBar && (tabBarControllerContainsToViewController || (isToViewControllerFirstInNavController && tabBarControllerContainsNavController))) {
        [tabBar.layer removeAllAnimations];

        CGRect tabBarRect = tabBar.frame;
        tabBarRect.origin.x = toViewController.view.bounds.origin.x;
        tabBar.frame = tabBarRect;

        [toViewController.view addSubview:tabBar];
        shouldAddTabBarBackToTabBarController = YES;
    }

    // Uses linear curve for an interactive transition, so the view follows the finger. Otherwise, uses a navigation transition curve.
    UIViewAnimationOptions curveOption = [transitionContext isInteractive] ? UIViewAnimationOptionCurveLinear : SSWNavigationTransitionCurve;

    if (toNavigationBarHidden) {
        navigationBar.alpha = 1;
    }

    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:UIViewAnimationOptionTransitionNone | curveOption animations:^{
        toViewController.view.transform = CGAffineTransformIdentity;
        fromViewController.view.transform = CGAffineTransformMakeTranslation(toViewController.view.frame.size.width * directionFactor, 0);
        dimmingView.alpha = 0.0f;

        if (toNavigationBarHidden) {
            navigationBar.transform = CGAffineTransformMakeTranslation(toViewController.view.frame.size.width * directionFactor, 0);
        }

        shadowView.alpha = 0;
    } completion:^(BOOL finished) {
        if (shouldAddTabBarBackToTabBarController) {
            [tabBarController.view addSubview:tabBar];

            CGRect tabBarRect = tabBar.frame;
            tabBarRect.origin.x = tabBarController.view.bounds.origin.x;
            tabBar.frame = tabBarRect;
        }

        [dimmingView removeFromSuperview];
        fromViewController.view.transform = CGAffineTransformIdentity;
        fromViewController.view.clipsToBounds = previousClipsToBounds;
        navigationBar.transform = CGAffineTransformIdentity;

        [shadowView removeFromSuperview];

        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];

    self.toViewController = toViewController;
}

- (void)animationEnded:(BOOL)transitionCompleted
{
    // restore the toViewController's transform if the animation was cancelled
    if (!transitionCompleted) {
        self.toViewController.view.transform = CGAffineTransformIdentity;
        [self.shadowView removeFromSuperview];
    }
}

@end
