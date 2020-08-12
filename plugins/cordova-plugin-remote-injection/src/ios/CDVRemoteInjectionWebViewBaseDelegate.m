#import <Foundation/Foundation.h>

#import "CDVRemoteInjection.h"
#import "CDVRemoteInjectionWebViewBaseDelegate.h"

/*
 Objective-C wonkiness to create a property that can be accessed
 by subclasses but not on the exported public interface.
 */
@interface CDVRemoteInjectionWebViewBaseDelegate ()
@property (readwrite, weak) CDVRemoteInjectionPlugin *plugin;
@end

@interface CDVRemoteInjectionWebViewBaseDelegate ()
@end

@implementation WrappedDelegateProxy
- (BOOL)respondsToSelector:(SEL)aSelector
{
    if ([super respondsToSelector:aSelector] || [self.wrappedDelegate respondsToSelector:aSelector]) {
        return YES;
    }
    return NO;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    if ([self.wrappedDelegate respondsToSelector:[anInvocation selector]])
        [anInvocation invokeWithTarget:self.wrappedDelegate];
    else
        [super forwardInvocation:anInvocation];
}
@end

@implementation CDVRemoteInjectionWebViewBaseDelegate
{
    /*
     Last time a request was made to load the web view.  Can be NULL.
     */
    NSDate *lastRequestTime;
    
    /*
     Reference to the currently displayed alert view.  Can be NULL.
     */
    UIAlertController *alertController;
    
    /*
     True if the user forced a reload.
     */
    BOOL userRequestedReload;
}

- (void)initializeDelegate:(CDVRemoteInjectionPlugin *)plugin
{
  // TODO To placate the compiler.
}

/*
 Builds a string of JS to inject into the web view.
 */
- (NSString *) buildInjectionJS;
{
    NSArray *jsPaths = [self jsPathsToInject];
    
    NSString *path;
    NSMutableString *concatenatedJS = [[NSMutableString alloc] init];
    
    for (path in jsPaths) {
        NSString *jsFilePath = [[NSBundle mainBundle] pathForResource:path ofType:nil];
        
        NSURL *jsURL = [NSURL fileURLWithPath:jsFilePath];
        NSString *js = [NSString stringWithContentsOfFile:jsURL.path encoding:NSUTF8StringEncoding error:nil];
        NSLog(@"Concatenating JS found in path: '%@'", jsURL.path);
        
        [concatenatedJS appendString:js];
    }
    return concatenatedJS;
}

/*
 Returns an array of bundled javascript files to inject into the current page.
 */
- (NSArray *) jsPathsToInject
{
    // Array of paths that represent JS files to inject into the WebView.  Order is important.
    NSMutableArray *jsPaths = [NSMutableArray new];
    
    // Pre injection files.
    for (id path in self.plugin.injectFirstFiles) {
        [jsPaths addObject: path];
    }
    
    [jsPaths addObject:@"www/cordova.js"];
    
    // We load the plugin code manually rather than allow cordova to load them (via
    // cordova_plugins.js).  The reason for this is the WebView will attempt to load the
    // file in the origin of the page (e.g. https://example.com/plugins/plugin/plugin.js).
    // By loading them first cordova will skip the loading process altogether.
    NSDirectoryEnumerator *directoryEnumerator = [[NSFileManager defaultManager] enumeratorAtPath:[[NSBundle mainBundle] pathForResource:@"www/plugins" ofType:nil]];
    
    NSString *path;
    while (path = [directoryEnumerator nextObject])
    {
        if ([path hasSuffix: @".js"]) {
            [jsPaths addObject: [NSString stringWithFormat:@"%@/%@", @"www/plugins", path]];
        }
    }
    // Initialize cordova plugin registry.
    [jsPaths addObject:@"www/cordova_plugins.js"];
    
    return jsPaths;
}

/*
 * Returns YES if the URL scheme is supported for JS injection.
 *
 * TODO: possibly expand to check content type
 */
- (BOOL) isSupportedURLScheme:(NSString *) scheme
{
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return YES;
    }
    
    NSLog(@"Unsupported scheme for cordova injection: '%@'.  Skipping.", scheme);
    return NO;
}

/*
 * Begins a timer to track the progress of a request.
 */
-(void) startRequestTimer
{
    if (self.plugin.promptInterval > 0) {
        [self cancelRequestTimer];
        lastRequestTime = [NSDate date];
        
        // Schedule progress check.
        NSLog(@"Starting a timer to track page load time that will expire in '%ld' seconds.", (long)self.plugin.promptInterval);
        [self performSelector:@selector(loadProgressCheckCallback:) withObject:lastRequestTime afterDelay:self.plugin.promptInterval];
    }
}

/*
 * Determines if the user should be prompted because of a long running request.  Displays the prompt.
 */
-(void) loadProgressCheckCallback:(id)requestTime
{
    // Check equality of the request time to ensure we're still tracking the same request.  If not ignore.
    if (lastRequestTime != NULL && [(NSDate *)requestTime isEqualToDate:lastRequestTime]) {
        if ([self isLoading]) {
            NSLog(@"Request taking too long, displaying dialog.");
            [self displayRetryPromptWithMessage:@"The server is taking longer than expected to respond." withCancelText:@"Wait" retryable:YES];
            return;
        } else {
            NSLog(@"No request in progress.  Not displaying dialog.");
        }
    }
}

/*
 Prompts the user providing them a choice to retry the latest request or wait.
 */
-(void) displayRetryPromptWithMessage:(NSString*)message withCancelText:(NSString *)cancelText retryable:(BOOL) retry
{
    
    alertController = [UIAlertController
                    alertControllerWithTitle:@"Connection Error"
                    message:message
                    preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* cancelBtn = [UIAlertAction
                               actionWithTitle:cancelText
                               style:UIAlertActionStyleCancel
                                handler:^(UIAlertAction * action) {
                                    [self startRequestTimer];
                                }];

    [alertController addAction:cancelBtn];
    
    if (retry) {
        UIAlertAction* retryBtn = [UIAlertAction
                            actionWithTitle:@"Retry"
                            style:UIAlertActionStyleDefault
                            handler:^(UIAlertAction * action) {
                                userRequestedReload = YES;
                                NSLog(@"User initiated retry of current request");
                                [self retryCurrentRequest];
                                [self startRequestTimer];
                            }];
        [alertController addAction:retryBtn];
        
    }
        UIViewController* rootController = [UIApplication sharedApplication].delegate.window.rootViewController;
        
        [rootController presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Subclass callbacks

/*
 * Callback to inform the base base of the start of a page load.
 */
-(void) webViewRequestStart
{
    userRequestedReload = NO;
    [self startRequestTimer];
}

/*
 * Callback to inform the base of a page load failure.
 */
- (void)loadPageFailure:(NSError *)error
{
    NSLog(@"Error loading page: %@", [error description]);
    
    if ([error code] == NSURLErrorCancelled) { //ignore if page load didn't complete and user moved away to another page
        return;
    }
    
    if (userRequestedReload == NO && self.plugin.showConnectionErrorDialog == YES) {
        [self displayRetryPromptWithMessage:@"Unable to contact the site." withCancelText:@"Close" retryable:NO];
    }
}

/*
 * Resets the request timer state.  Hides the alert view if it is displayed.
 */
-(void) cancelRequestTimer
{
    if (alertController != NULL) {
        // Dismiss the alert view.  The assumption is the page finished loading while the view was displayed.
        [alertController dismissViewControllerAnimated:YES completion:nil];
        alertController = NULL;
    }
    
    if (lastRequestTime != NULL) {
        [NSObject cancelPreviousPerformRequestsWithTarget:(id)self selector:@selector(loadProgressCheckCallback:) object:lastRequestTime];
    }
    lastRequestTime = NULL;
}

#pragma mark - Must be implemented by subclass

/*
 * Has to be implemented by subclass to state when a request has been made without yet seeing a response.
 */
-(BOOL) isLoading
{
    NSException* myException = [NSException
                                exceptionWithName:@"MethodNotImplemented"
                                reason:@"Subclass must implement 'isLoading'."
                                userInfo:nil];
    @throw myException;
}

/*
 * Has to be implemented by the subclass to allow the user to retry a long running request.
 */
-(void) retryCurrentRequest
{
    NSException* myException = [NSException
                                exceptionWithName:@"MethodNotImplemented"
                                reason:@"Subclass must implement 'retryCurrentRequest'."
                                userInfo:nil];
    @throw myException;
}

@end
