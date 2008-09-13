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
- (void) qk_setGrabbedIcon:(id) icon;
- (void) qk_uninstallIcon:(id) icon;
- (void) qk_setIconToInstall:(id) icon;
@end

@interface QGTableCell : UITableViewCell { 
    
}

@end

@implementation QGTableCell

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(10,10,40,40)];
        [self.contentView addSubview:iv];
        [iv release];

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake (50, 0, 320, 40)];
        label.tag = 1;
        label.text = @"";
        label.font = [UIFont boldSystemFontOfSize:16.0];
        label.adjustsFontSizeToFitWidth = YES;
        label.highlightedTextColor = [UIColor whiteColor];
        [self.contentView addSubview:label];
        [label release];
        
        /*
         UITextField *theTextField = [[UITextField alloc] initWithFrame:rect];
         theTextField.returnKeyType = UIReturnKeyGo;
         theTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
         theTextField.autocorrectionType = UITextAutocorrectionTypeNo;
         theTextField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
         theTextField.textColor = [UIColor darkGrayColor];
         [self.contentView addSubview:theTextField];
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

static void __sbapplicationcontroller_loadapplications(id<QuickGoldMethods> self, SEL sel, BOOL b) {
    [self qk_loadApplications: b];
    if (allApps) [allApps release];
    allApps = [[self allApplications] retain];
    [quickgold indexApplications];
}

@class SBApplication;
@class SBUIController;
@class SBIconController;
@class SBDownloadController;

static void __sbuicontroller_clickedMenuButton(SBUIController* self, SEL sel) { 
    id awayController = [NSClassFromString(@"SBAwayController") sharedAwayController];
    if ([awayController isLocked]) { 
        [awayController unlockWithSound:YES];
        // goto done;
    }
    
    Class SBUIController = objc_getClass("SBUIController");
    int launchState = [[SBUIController sharedInstance] launchState];
    NSLog([NSString stringWithFormat:@"menu button clicked! launch state = %d", launchState]);
    if (launchState > 0 && launchState != 5) { // not on the springboard
        goto done;
    }
    
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:@"/var/mobile/Library/Preferences/.quickgold.wigglebug.ok"]
        && quickgold.isGrabbingOn) { 
        NSLog ([NSString stringWithFormat:@" icon movement on - about to be turned off with menu click"]);
        quickgold.isGrabbingOn = false;
        goto done;
    }
    
    [quickgold toggleBrowser];
done:
    [self qk_clickedMenuButton];
}

static void __sbiconcontroller_setGrabbedIcon(SBIconController *self, SEL sel, id icon) { 
    if (icon) {
        NSLog ([NSString stringWithFormat:@"set grabbed icon called, icon = %@", icon]);
        quickgold.isGrabbingOn = true;
    }
    [self qk_setGrabbedIcon:icon];
}

static void __sbiconcontroller_setIconToInstall(SBIconController *self, SEL sel, id icon) { 
    if (icon) { 
        NSLog ([NSString stringWithFormat:@" icon to install %@" , icon]);
        [quickgold onNewIconInstallation:icon];
    }
    [self qk_setIconToInstall:icon];
}

static void __sbiconcontroller_uninstallIcon(SBIconController *self, SEL sel, id icon) {
    if (icon) { 
        NSLog ([NSString stringWithFormat:@" uninstalling icon %@", icon]);
        [quickgold onIconUninstall:icon];
    }
    
    [self qk_uninstallIcon:icon];
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
        QuickGoldRename(YES, "SBIconController", "uninstallIcon:", (IMP)&__sbiconcontroller_uninstallIcon);
        
        quickgold = [[QuickGold alloc] init];
        [quickgold performSelectorOnMainThread: @selector(didInjectIntoProgram) withObject: nil waitUntilDone: NO];
    } else {
        NSLog(@"QuickGold is disabled for non-springboard / non-pandora apps");
    }
    
    [pool release];
}

@implementation QuickGold

@synthesize isGrabbingOn;

NSInteger appSort(id num1, id num2, void *context) {
    return [num1 localizedCaseInsensitiveCompare: num2];
}

- (void) didInjectIntoProgram {
    [self performSelector: @selector(inject) withObject: nil afterDelay: 0.1];
}

- (void) inject {
    NSLog([NSString stringWithFormat:@"QuickGold initializing %@", NSHomeDirectory()]);
    isGrabbingOn = false;
    
    browserWindow = [[UIWindow alloc] initWithFrame: CGRectMake(0, 0, 320, 480)];
    [browserWindow setUserInteractionEnabled: YES];
    [browserWindow setMultipleTouchEnabled: YES];
    [browserWindow setWindowLevel: 1];
    // [browserWindow setAlpha: 0.01];
    [browserWindow setHidden: NO];
    // [browserWindow setBackgroundColor: [UIColor colorWithWhite: 0 alpha: 0.7]];
    
    searchBarAndTableView = [[UIView alloc] initWithFrame:CGRectMake(0, 20, 320, 200)];
    searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
    searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.placeholder = @"apps, contacts, phone#s, websites";
    searchField = [(NSArray *)[searchBar subviews] objectAtIndex:0];
    searchField.returnKeyType = UIReturnKeyGo;
    searchField.enablesReturnKeyAutomatically = NO;
    searchField.keyboardType = UIKeyboardTypeEmailAddress;
    
    searchField.delegate = self;
    searchBar.delegate = self;
    [searchBarAndTableView addSubview:searchBar];
    
    matchTable = [[[UITableView alloc] initWithFrame:CGRectMake(0, 50, 320, 200) style:UITableViewStylePlain] autorelease];
    matchTable.dataSource = self;
    matchTable.delegate = self;
    [searchBarAndTableView addSubview:matchTable];
    [browserWindow addSubview:searchBarAndTableView];
    
    [self performSelector: @selector(hideBrowser) withObject: nil afterDelay: 0.1];
    
    launchieNames = [[NSMutableArray array] retain];
    matches = [[NSMutableArray array] retain];
    matchLocations = [[NSMutableDictionary dictionary] retain];
    launchieDetailsByName = [[NSMutableDictionary dictionary] retain];
    
    [self indexApplications];
    [self indexAddressBookEntries];
    [self indexAllWebClips];
}

- (void) indexApplications {
    if (allApps) { 
        NSLog(@"loading springboard apps");
        for (id<QuickGoldMethods> app in allApps) {
            NSString *name = [app displayName];
            NSString *bundle = [app bundleIdentifier];
            
            if ([bundle hasSuffix:@"springboard"] || [bundle hasSuffix:@"DemoApp"]) { 
                continue;
            }
            
            [self indexApp:app withName:name];
        }
    }
    
    // [self dumpIconInformation];
}

- (void) dumpIconInformation { 
    Class SBIconModel = objc_getClass("SBIconModel");
    id iconModel = [SBIconModel sharedInstance];
    
    for (id iconList in [iconModel iconLists]) {
        for (id icon in [iconList icons]) { 
            if ([self isBookmarkIcon: icon]) { 
                // NSDictionary *dict = [[icon bundle] infoDictionary];
                // NSLog ([NSString stringWithFormat:@" title = %@ url = %@", [dict objectForKey:@"Title"], [dict objectForKey:@"URL"]]);
            } else { 
                NSLog ([NSString stringWithFormat:@" name=%@ app=%@", [icon displayName], [icon application]]);
            }
        }
    }
}

- (void) onNewIconInstallation:(id)icon {
    NSLog ([NSString stringWithFormat:@" new icon being installed: %@", icon]);
    if ([self isBookmarkIcon:icon]) { 
        NSLog ([NSString stringWithFormat:@" adding a new bookmark"]);
        NSDictionary *dict = [[icon bundle] infoDictionary];
        [self indexWebClip:[dict objectForKey:@"URL"] withTitle:[dict objectForKey:@"Title"]]; 
    } 
}

- (void) onIconUninstall:(id) icon {
    if ([self isBookmarkIcon:icon]) {
        [self removeWebClip:[[[icon bundle] infoDictionary] objectForKey:@"Title"]];
    } else if ([self isDownloadingIcon:icon]) {
        
    } else {
        [self removeApp:[icon displayName]];
    }
}

- (BOOL) isBookmarkIcon:(id) icon {
    NSString *desc = [icon description];
    if ([desc rangeOfString:@"bookmark" options:NSCaseInsensitiveSearch].location != NSNotFound) { 
        return YES;
    } else {
        return NO;
    }
}

- (BOOL) isDownloadingIcon:(id) icon {
    NSString *desc = [icon description];
    if ([desc rangeOfString:@"download" options:NSCaseInsensitiveSearch].location != NSNotFound) { 
        return YES;
    } else {
        return NO;
    }
}

- (void) indexAddressBookEntries { 
    ABAddressBookRef addressBook = ABAddressBookCreate();
    NSLog([NSString stringWithFormat:@"loading address book entries %@", addressBook]);
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
    CFIndex nPeople = ABAddressBookGetPersonCount(addressBook);
    NSLog ([NSString stringWithFormat:@"npeople = %d", nPeople]);
    
    for (int i = 0; i < nPeople; i++) { 
        ABRecordRef ref = CFArrayGetValueAtIndex (people, i);
        CFStringRef firstName = ABRecordCopyValue(ref, kABPersonFirstNameProperty);
        CFStringRef lastName = ABRecordCopyValue(ref, kABPersonLastNameProperty);
        CFStringRef orgName = ABRecordCopyValue(ref, kABPersonOrganizationProperty);
        
        if (!firstName && !lastName && !orgName) // Ignore entries which have no name of any kind
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
            if (!firstName && !lastName && orgName) {
                full = [full stringByAppendingFormat:(NSString *) orgName];
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
        if (orgName)
            CFRelease(orgName);
    }
    
    CFRelease(people);
    CFRelease(addressBook);
}

- (void) indexAllWebClips {
    NSLog(@"loading web clip entries");
    NSString *dir = [NSHomeDirectory() stringByAppendingString:@"/Library/WebClips"];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *clip in [manager contentsOfDirectoryAtPath:dir error:NULL]) {
        if ([clip hasSuffix:@".webclip"]) {
            NSString *file = [dir stringByAppendingFormat:@"/%@/Info.plist", clip];
            NSMutableDictionary *keys = [NSMutableDictionary dictionaryWithContentsOfFile: file];
            [self indexWebClip:[keys objectForKey:@"URL"] withTitle:[keys objectForKey:@"Title"]];
        }
    }
}

- (void) indexApp:(id) app withName:(NSString *)name {
    [self removeApp:name];
    [launchieNames addObject:name];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              app, @"appObject",
                              @"app", @"type",
                              nil];
    [launchieDetailsByName setObject:d forKey:name];
}

- (void) indexWebClip:(NSString *) url withTitle:(NSString *) title { 
    [self removeWebClip:title];
    [launchieNames addObject: title];
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              url, @"url",
                              @"webclip", @"type",
                              nil];
    
    [launchieDetailsByName setObject:d forKey:title];
}

- (void) removeWebClip:(NSString *) name { 
    [self removeAppOrWebClipByName:name];
}

- (void) removeApp:(NSString *) name { 
    [self removeAppOrWebClipByName:name];
}

- (void) removeAppOrWebClipByName:(NSString *) name {
    [launchieNames removeObject:name];
    [launchieDetailsByName removeObjectForKey:name];
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
    
    if ([text isEqual:@""]) { 
        [self toggleBrowser];
        return YES;
    }
    
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
    [matchTable setContentOffset:CGPointZero animated:NO];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return numMatchesToShow;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    QGTableCell *cell = (QGTableCell *) [tableView dequeueReusableCellWithIdentifier:@"MyIdentifier"];
    if (cell == nil) {
        cell = [[[QGTableCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"MyIdentifier"] autorelease];
    }
    
    int i = indexPath.row;
    int numMatches = [matches count];
    UILabel *label = (UILabel *)[cell viewWithTag:1];
    
    if (i >= numMatches) { 
        label.text = @"";
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        label.text = [matches objectAtIndex: i];
        // cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.accessoryType = UITableViewCellAccessoryNone;
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
    [UIView setAnimationDuration: 0.3];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    searchBar.transform = CGAffineTransformMakeTranslation(0,-100);
    [matchTable setAlpha:0];
    [UIView setAnimationDelegate: self];
    [UIView setAnimationDidStopSelector: @selector(fadeOutAnimationFinished:finished:context:)];
    [UIView commitAnimations];
    // [browserWindow setAlpha: 0];
    
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
    //[browserWindow setAlpha: 0.95];
    searchBar.transform = CGAffineTransformMakeTranslation(0,-100);
    [matchTable setAlpha:0];
    [UIView beginAnimations: nil context: nil];
    [UIView setAnimationDuration: 0.3];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    searchBar.transform = CGAffineTransformIdentity;
    [matchTable setAlpha:0.95];
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

