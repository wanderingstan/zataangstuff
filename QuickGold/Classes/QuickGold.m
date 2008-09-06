//
//  QuickGold.m
//  QuickGold
//

#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#import "QuickGold.h"

bool Debug_ = true;
int numMatchesToShow = 8;
bool isGrabbingOn = false;
NSArray *allApps;
NSMutableArray *launchieNames;
NSMutableArray *matches;
NSMutableDictionary *matchLocations;
NSMutableDictionary *launchieDetailsByName;
QuickGold *quickgold;

@protocol QuickGoldMethods
// bag of all kinds of interfaces
- (NSString *) description;
- (NSString *) qk_displayName;
- (UIView *) superview;
- (Class) superclass;
- (NSString *) displayName;
- (NSString *) displayIdentifier;
- (NSDictionary *) infoDictionary;
- (NSString *) bundleIdentifier;
- (BOOL) enabled;
- (void) launch;
- (void) qk_launch;
- (void) qk_clickedMenuButton;
- (NSArray *) allApplications;
- (void) qk_loadApplications: (BOOL) b;
- (void) qk_activate;
- (void) qk_deactivate;
- (void) qk_setGrabbedIcon:(id) icon;
@end

@interface QGTableCell : UITableViewCell { 

}

@end

@implementation QGTableCell

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
        /*
        CGRect bounds = self.bounds;
        CGRect rect = bounds;
        
        float fraction = 0.65;
        rect.size.width *= fraction;
        rect.origin.x = bounds.size.width * (1 - fraction);
        UITextField *theTextField = [[UITextField alloc] initWithFrame:rect];
        self.textField = theTextField;
        textField.returnKeyType = UIReturnKeyGo;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        textField.textColor = [UIColor darkGrayColor];
        [self addSubview:textField];
        [theTextField release];
        */
    }
    return self;
}

- (void)dealloc {
    // Release allocated resources.
    [super dealloc];
}

@end

/* WinterBoard Backend {{{ */
#define WBPrefix "qk_"
void QuickGoldInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}

void QuickGoldRename(bool instance, const char *classname, const char *oldname, IMP newimp) {
    NSLog(@"Renaming %s::%s", classname, oldname);
    Class _class = objc_getClass(classname);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", classname);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    Method method = class_getInstanceMethod(_class, sel_getUid(oldname));
    if (method == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find method [%s %s]", classname, oldname);
        return;
    }
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    unsigned int index;
    for (index = 0; index != count; ++index)
        if (methods[index] == method)
            goto found;
    if (newimp != NULL)
        if (!class_addMethod(_class, sel_getUid(oldname), newimp, type))
            NSLog(@"WB:Error: failed to rename [%s %s]", classname, oldname);
    goto done;
found:
    if (newimp != NULL)
        method_setImplementation(method, newimp);
    NSLog(@"Rename success");
done:
    free(methods);
}

static void __sbapplicationcontroller_loadapplications(id<QuickGoldMethods> self, SEL sel, BOOL b) {
    [self qk_loadApplications: b];
    if (allApps) [allApps release];
    allApps = [[self allApplications] retain];
}

@class SBApplication;
@class SBUIController;
@class SBIconController;

static void __sbuicontroller_clickedMenuButton(SBUIController* self, SEL sel) { 
    if ([[NSClassFromString(@"SBAwayController") sharedAwayController] isLocked]) { 
        goto done;
    }

    Class SBUIController = objc_getClass("SBUIController");
    id uiController = [SBUIController sharedInstance];
    NSLog(@"menu button clicked! launch state = %d", [uiController launchState]);    
    if ([uiController launchState] > 0) { // not on the springboard
        goto done;
    }

    if (isGrabbingOn) { 
        NSLog ([NSString stringWithFormat:@" icon movement on - about to be turned off with menu click"]);
        isGrabbingOn = false;
        goto done;
    }

    [quickgold toggleBrowser];
done:
    [self qk_clickedMenuButton];
}

static void __sbiconcontroller_setGrabbedIcon(SBIconController *self, SEL sel, id icon) { 
    isGrabbingOn = true;
    [self qk_setGrabbedIcon:icon];
}
static void __sbiconcontroller_setIconToInstall(SBIconController *self, SEL sel, id icon) { 
    NSLog ([NSString stringWithFormat:@" icon to install %@" , icon]);
    [self qk_setIconToInstall:icon];
}

__attribute__((constructor))
static void QuickGoldInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"QuickGold.dylib: The main injection constructor called");
    
    quickgold = nil;
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];
    if ([appId hasSuffix: @"springboard"]) { 
        QuickGoldRename(YES, "SBUIController", "clickedMenuButton", (IMP)&__sbuicontroller_clickedMenuButton);
        QuickGoldRename(YES, "SBApplicationController", "loadApplications:", (IMP)&__sbapplicationcontroller_loadapplications);
        QuickGoldRename(YES, "SBIconController", "setGrabbedIcon:", (IMP)&__sbiconcontroller_setGrabbedIcon);
        QuickGoldRename(YES, "SBIconController", "setIconToInstall:", (IMP)&__sbiconcontroller_setIconToInstall);

        quickgold = [[QuickGold alloc] init];
        [quickgold performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    } else {
        NSLog(@"QuickGold is disabled for non-springboard / non-pandora apps");
    }
    
    [pool release]; 
}

@implementation QuickGold

NSInteger appSort(id num1, id num2, void *context) {
    return [num1 localizedCaseInsensitiveCompare: num2];
}

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

- (void) inject {
    NSLog([NSString stringWithFormat:@"QuickGold initializing %@", NSHomeDirectory()]);

    browserWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, 320, 480)];
    [browserWindow setUserInteractionEnabled: YES];
    [browserWindow setMultipleTouchEnabled: YES];
    [browserWindow setWindowLevel: 1];
    [browserWindow setAlpha: 0.01];
    [browserWindow setHidden: NO];
    [browserWindow setBackgroundColor: [UIColor colorWithWhite: 0 alpha: 0.7]];

    searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 20, 320, 50)];
    searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.placeholder = @"apps, contacts, phone#s, websites";
    searchField = [(NSArray *)[searchBar subviews] objectAtIndex:0];
    searchField.returnKeyType = UIReturnKeyGo;
    searchField.keyboardType = UIKeyboardTypeURL;

    searchField.delegate = self;
    searchBar.delegate = self;
    [browserWindow addSubview:searchBar];

    matchTable = [[[UITableView alloc] initWithFrame:CGRectMake(0, 70, 320, 200) style:UITableViewStylePlain] autorelease];
    matchTable.dataSource = self;
    matchTable.delegate = self;
    [browserWindow addSubview:matchTable];

    [self performSelector: @selector(hideBrowser) withObject: nil afterDelay: 0.1];

    launchieNames = [[NSMutableArray array] retain];
    matches = [[NSMutableArray array] retain];
    matchLocations = [[NSMutableDictionary dictionary] retain];
    launchieDetailsByName = [[NSMutableDictionary dictionary] retain];

    [self loadApplications];
    [self loadAddressBookEntries];
    [self loadWebClips];
}

- (void) loadApplications {
    NSLog(@"loading springboard apps");
    if (allApps) { 
        for (id<QuickGoldMethods> app in allApps) {
            NSString *name = [app displayName];
            NSString *bundle = [app bundleIdentifier];

            if ([bundle hasSuffix:@"springboard"] || [bundle hasSuffix:@"DemoApp"]) { 
                continue;
            }

            [launchieNames addObject:name];
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                app, @"appObject",
                @"app", @"type",
                nil];
            [launchieDetailsByName setObject:d forKey:name];
        }
    }
}

- (void) loadAddressBookEntries { 
    ABAddressBookRef addressBook = ABAddressBookCreate();
    NSLog([NSString stringWithFormat:@"loading address book entries %@", addressBook]);
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
    CFIndex nPeople = ABAddressBookGetPersonCount(addressBook);
    NSLog ([NSString stringWithFormat:@"npeople = %d", nPeople]);

    for (int i = 0; i < nPeople; i++) { 
        ABRecordRef ref = CFArrayGetValueAtIndex (people, i);
        CFStringRef firstName = ABRecordCopyValue(ref, kABPersonFirstNameProperty);
        CFStringRef lastName = ABRecordCopyValue(ref, kABPersonLastNameProperty);

        if (!firstName && !lastName)  // some entries are like that. WTF!
            continue;
        
        ABMutableMultiValueRef multi = ABRecordCopyValue(ref, kABPersonPhoneProperty);
        for (CFIndex i = 0; i < ABMultiValueGetCount(multi); i++) {
            CFStringRef number, label;
            label = ABMultiValueCopyLabelAtIndex(multi, i);
            number = ABMultiValueCopyValueAtIndex(multi, i);

            NSString *sLabel = (NSString *) label;
            sLabel = [sLabel stringByReplacingOccurrencesOfString:@"_$!<" withString:@""];
            sLabel = [sLabel stringByReplacingOccurrencesOfString:@">!$_" withString:@""];

            NSString *full = [NSString stringWithFormat:@""];
            if (firstName) {
                full = [full stringByAppendingString:(NSString *) firstName];
            }
            if (lastName) { 
                full = [full stringByAppendingFormat:@" %@", (NSString *) lastName];
            }
            full = [full stringByAppendingFormat:@" [%@]", sLabel];
            [launchieNames addObject:full];

            NSString *sNumber = (NSString *) number;
            sNumber = [sNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
            sNumber = [sNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
            sNumber = [sNumber stringByReplacingOccurrencesOfString:@" " withString:@"-"];
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       sNumber, @"number",
                                       @"phone", @"type",
                                       nil];
            [launchieDetailsByName setObject:d forKey:full];

            CFRelease(number);
            CFRelease(label);
        }

        CFRelease(multi);
        if (lastName) 
            CFRelease(lastName);
        if (firstName)
            CFRelease(firstName);
    }

    CFRelease(people);
    CFRelease(addressBook);
}

- (void) loadWebClips {
    NSLog(@"loading web clip entries");
    NSString *dir = [NSHomeDirectory() stringByAppendingString:@"/Library/WebClips"];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *clip in [manager contentsOfDirectoryAtPath:dir error:NULL]) {
        if ([clip hasSuffix:@".webclip"]) {
            NSString *file = [dir stringByAppendingFormat:@"/%@/Info.plist", clip];
            NSMutableDictionary *keys = [NSMutableDictionary dictionaryWithContentsOfFile: file];
            
            NSString *title = [keys objectForKey:@"Title"];
            [launchieNames addObject: title];
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                      [keys objectForKey:@"URL"], @"url",
                                      @"webclip", @"type",
                                      nil];
            
            [launchieDetailsByName setObject:d forKey:title];
        }
    }
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar { 
    [self showKeyboard:YES];
    return YES;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self computeMatches:searchText];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *text = textField.text;
    NSLog([NSString stringWithFormat:@"executing text: %@", text]);

    if ([text hasPrefix:@"http://"] || [text hasPrefix:@"https://"] || [text hasPrefix:@"tel://"]) { 
        [self customLaunch:text withType:@"url"];
    } else if ([text hasPrefix:@"www."] || [text hasSuffix:@".com"]
               || [text hasSuffix:@".org"] || [text hasSuffix:@".net"]) { 
        [self customLaunch:[NSString stringWithFormat:@"http://%@", text] withType:@"url"];
    } else { 
        if ([self isNumber:text]) { 
            [self customLaunch:[NSString stringWithFormat:@"tel://%@", text] withType:@"url"];
        }
    }
    return NO;
}

- (void) customLaunch:(id)what withType:(NSString *)type { 
    if (!what) 
        return;

    if ([type isEqual:@"app"]) { 
        Class SBUIController = objc_getClass("SBUIController");
        id uiController = [SBUIController sharedInstance];

        [self toggleBrowser]; 
        [uiController animateLaunchApplication: what];
    } else if ([type isEqual:@"url"]) { 
        [self toggleBrowser];  
        NSString *str = (NSString *) what;
        [[UIApplication sharedApplication] openURL: [NSURL URLWithString:str]];
    }
}

- (BOOL)isNumber:(NSString *)text { 
    const char *s = [text UTF8String];
    if (!s) 
        return NO;

    int len = strlen (s);
    for (int i = 0; i < len; i++) { 
        char c = s[i];
        if (c < 48 || c > 57)
            return NO;
    }
    return YES;
}

NSInteger sortMatchesByLocation (id name1, id name2, void *context) {
    NSNumber *loc1 = [matchLocations objectForKey:name1];
    NSNumber *loc2 = [matchLocations objectForKey:name2];
    return [loc1 intValue] - [loc2 intValue];
}

- (void)computeMatches:(NSString *)searchText { 
    // sort them by where they match
    [matches removeAllObjects];
    [matchLocations removeAllObjects];

    if (![searchText isEqual:@""]) { 
        for (NSString *name in launchieNames) { 
            NSRange range = [name rangeOfString:searchText options:NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                [matches addObject: name];
                [matchLocations setObject:[NSNumber numberWithInt:range.location] forKey:name];
            }
        }
    }

    [matches sortUsingFunction:sortMatchesByLocation context:NULL];
    [matchTable reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return numMatchesToShow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = (QGTableCell *) [tableView dequeueReusableCellWithIdentifier:@"MyIdentifier"];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"MyIdentifier"] autorelease];
    }
    
    int i = indexPath.row;
    int numMatches = [matches count];
    if (i >= numMatches) { 
        cell.text = @"";
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        cell.text = [matches objectAtIndex: i];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
    [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
    int i = newIndexPath.row;
    int count = [matches count];
    if (i >= count) { 
        return;
    }

    NSString *name = [matches objectAtIndex:i];
    NSLog([NSString stringWithFormat:@"selected something : %@", name]);
    
    NSMutableDictionary *d = [launchieDetailsByName objectForKey:name];
    NSString *type = [d objectForKey:@"type"];
    if ([type isEqual:@"app"]) { 
        [self customLaunch:[d objectForKey:@"appObject"] withType:@"app"];
    } else if ([type isEqual:@"phone"]) { 
        NSString *number = [d objectForKey:@"number"];
        NSLog ([NSString stringWithFormat:@"obtained number: %@", number]);
        [self customLaunch:[NSString stringWithFormat:@"tel://%@", number] withType:@"url"];
    } else if ([type isEqual:@"webclip"]) {
        [self customLaunch:[d objectForKey:@"url"] withType:@"url"];
    }
}

- (void) showKeyboard:(BOOL)show { 
    UIKeyboard *key = [UIKeyboard automaticKeyboard];
    if (!key) { 
        return;
    }
    if (show) { 
        [key orderInWithAnimation:YES];
    } else {
        [key orderOutWithAnimation:YES];
    }
}

void UIKeyboardEnableAutomaticAppearance(void);
void UIKeyboardDisableAutomaticAppearance(void);

- (void) hideBrowser {
    [UIView beginAnimations: nil context: nil];
    [UIView setAnimationDuration: 0.5];
    [UIView setAnimationDelegate: self];
    [UIView setAnimationDidStopSelector: @selector(fadeOutAnimationFinished:finished:context:)];
    [browserWindow setAlpha: 0];
    [UIView commitAnimations];

    // make sure you resign the responder first
    [searchField resignFirstResponder];
    [self showKeyboard:NO];

    searchBar.text = @"";
    [self computeMatches:@""];

    isDisplaying = NO;
}

- (void) displayBrowser {
    NSLog (@"showign browser window");
    [browserWindow setHidden: NO];
    [browserWindow setAlpha: 0];
    [UIView beginAnimations: nil context: nil];
    [UIView setAnimationDuration: 0.2];
    [browserWindow setAlpha: 0.95];
    [UIView commitAnimations];
    isDisplaying = YES;
    [browserWindow makeKeyAndVisible];

    // make sure you resign the responder first
    [searchField becomeFirstResponder];
    [self showKeyboard:YES];
}

- (void) toggleBrowser { 
    if (isDisplaying) { 
        [self hideBrowser];
    } else {
        [self displayBrowser];
    }
}

- (void) fadeOutAnimationFinished: (id) x finished: (BOOL) f context: (id) y {
    [browserWindow setHidden: YES];
}

@end

