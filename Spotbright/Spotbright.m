#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <substrate.h>
#include "Settings.h"
#include "Keys.h"

#define APP_DOMAIN 13

// the called should call a "retain" on the image
UIImage *GetScaledIcon (NSString *path) {
    UIImage *i = [UIImage imageWithContentsOfFile:path];
    UIImage *image = (UIImage *) [i _imageScaledToSize:CGSizeMake(32.0f, 32.0f) interpolationQuality:0];
    return image;
}

id GetApplication(NSString *displayId) {
    Class SBApplicationController = objc_getClass("SBApplicationController");
    id controller = [SBApplicationController sharedInstance];
    NSArray *apps = [controller applicationsWithBundleIdentifier:displayId];
    if ([apps count] == 0) {
        return nil;
    }

    return [apps objectAtIndex:0];
}

// main features to have in Spotbright
//
//  - enable better actions for contacts; better display for contacts as well
//  - search by phone numbers
//  - custom web search
//
@class SBApplication;
@class SBUIController;
@class SBIconController;
@class SBDownloadController;
@class SpringBoard;
@class SBSearchController;
@class SPSearchQuery;

bool Debug_ = false;
#define RenamePrefix "spotbright_"
void MyRename(bool instance, const char *classname, SEL sel, IMP newimp);

@protocol Blah

// SBSearchController
- (void) spotbright_searchBar:(id)fp8 textDidChange:(id)fp12;
- (void) spotbright_searchBarSearchButtonClicked:(id)fp8;
- (int) spotbright_numberOfSectionsInTableView:(id)fp8;
- (BOOL) spotbright__shouldDisplayApplicationSearchResults;
- (id) spotbright__groupForSection:(int)fp8;
- (id) spotbright__launchingURLForResult:(id)fp8 withDisplayIdentifier:(id)fp12;
- (void) spotbright_searchDaemonQuery:(id)fp8 addedResults:(id)fp12;
- (unsigned int)domain;
- (unsigned int)resultCount;

// SPSearchResultDeserializer
- (BOOL)spotbright_deserializeResultAtIndex:(unsigned int)fp8 toCursor:(id)fp12;
- (unsigned int) spotbright_resultCount;

// SBSearchView
- (id) spotbright_initWithFrame:(struct CGRect)fp8;

// SBUIController
- (void) spotbright_activateApplicationAnimated:(id)fp8;

// SPSearchQuery
- (id) spotbright_initWithSearchString:(id)fp8 forSearchDomains:(id)fp12;
- (id) spotbright_initWithSearchString:(id)fp8;
- (id) spotbright_init;
@end

@class SBSearchView;
@class SPSearchResult;
@class SPSearchResultDeserializer;
@class SPDaemonQueryToken;
@class SBApplicationController;

@class MahDeserializer;
@class MahController;
@class NewDomainsController;

struct {
    int numSectionsOriginal;
    MahDeserializer *results;
    NSMutableArray *matches;
    NSMutableArray *items;
    NSMutableDictionary *matchWeights;
    NSString *queryString;

    NewDomainsController *newDomainsController;

    MahController *controller;
} Globals;

@interface MahDeserializer : NSObject {
    NSString *title;
    NSString *identifier;
}

- (id) init;
- (BOOL)deserializeResultAtIndex:(unsigned int)index toCursor:(SPSearchResult *)cursor;

- (id)displayIdentifier;
- (unsigned int)domain;
- (unsigned int)resultCount;
@end

@implementation MahDeserializer

- (id) init {
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

- (void)setTitle:(NSString *)t displayId:(NSString *)i {
    title = t;
    identifier = i;
}

- (BOOL)deserializeResultAtIndex:(unsigned int)index toCursor:(SPSearchResult *)cursor {
    [cursor setTitle:title];
    [cursor setSubtitle:@"" atIndex:0];
    [cursor setSubtitle:@"" atIndex:1];
    [cursor setSubtitle:@"" atIndex:2];
    [cursor setDomain:[self domain]];
    return YES;
}

- (id)displayIdentifier {
    return identifier;
}

- (unsigned int)domain {
    return APP_DOMAIN;
}

- (unsigned int)resultCount {
    return 1;
}

@end

#define ENTRIES_PER_ROW    6
#define NUM_ROWS           1
#define IMAGE_SIZE         32.0

@interface MahController : NSObject {
    UIView *recentEntriesView;
    NSMutableArray *recentEntriesViewButtons;
}

- (id) init;
- (void) updateRecentEntriesView;
- (void) showRecentEntriesView:(BOOL)shouldShow;

@end

@implementation MahController
- (id) init {
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

- (UIView *) createRecentEntriesView {
    recentEntriesView = [[UIView alloc] initWithFrame:CGRectMake(0, 42, 320, 200)];
    recentEntriesViewButtons = [[NSMutableArray array] retain];

    int index = 0;
    for (int row = 0; row < NUM_ROWS; row++) {
        for (int col = 0; col < ENTRIES_PER_ROW; col++) {
            CGRect frame = CGRectMake(18 * (col + 1) + col * IMAGE_SIZE, 10 + 48 * row, IMAGE_SIZE, IMAGE_SIZE);
            UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            button.frame = frame;
            [button setHidden:YES];
            button.userInteractionEnabled = NO;

            // TODO: make sure targeting is proper
            [button addTarget:self action:@selector(launchRecentApp:) forControlEvents:UIControlEventTouchUpInside];
            [recentEntriesViewButtons addObject:button];
            [recentEntriesView addSubview:button];

            index++;
        }
    }

    recentEntriesView.backgroundColor = [UIColor blackColor];
    return recentEntriesView;
}

- (void) launchRecentApp:(UIButton *) sender {
    NSArray *recentEntries = [[SpotbrightSettings sharedInstance] getRecentEntries];
    int index = sender.tag;
    if (index >= [recentEntries count]) {
        return;
    }

    NSString *key = [[recentEntries objectAtIndex:index] objectForKey:@"key"];
    [self launchApp:key];
}

- (void) launchApp:(NSString *) name {
    id app = GetApplication(name);
    if (!app) {
        return;
    }

    Class SBUIController = objc_getClass("SBUIController");
    id uiController = [SBUIController sharedInstance];
    [uiController activateApplicationAnimated:app];

    [[SpotbrightSettings sharedInstance] recordRecentEntry:name type:@"app"];
    [self updateRecentEntriesView];
}

- (void) updateRecentEntriesView {
    NSArray *recentEntries = [[SpotbrightSettings sharedInstance] getRecentEntries];
    if ([recentEntries count] == 0) {
        return;
    }

    int index = 0;
    int nEntries = [recentEntries count];

    for (int row = 0; row < NUM_ROWS; row++) {
        for (int col = 0; col < ENTRIES_PER_ROW; col++) {
            UIButton *button = [recentEntriesViewButtons objectAtIndex:index];
            NSMutableDictionary *d = nil;
            if (index < nEntries) {
                d = [recentEntries objectAtIndex:index];
            }

            if (d && [[d objectForKey:@"type"] isEqual:@"app"]) {
                NSString *key = [d objectForKey:@"key"];

                id app = GetApplication(key);
                if (!app) {
                    continue;
                }
                UIImage *image = GetScaledIcon([app pathForIcon]);
                [button setBackgroundImage:image forState:UIControlStateNormal];
                button.userInteractionEnabled = YES;
                button.tag = index;
                [button setHidden:NO];
            } else {
                button.userInteractionEnabled = NO;
                [button setHidden:YES];
            }

            index++;
        }
    }
}

- (void) showRecentEntriesView:(BOOL)shouldShow {
    [recentEntriesView setHidden:!shouldShow];
}
@end

@interface NewDomainsController : NSObject {
    NSMutableArray *nd;
    NSMutableDictionary *ds;
}
- (id)init;
- (NSMutableArray *)getNewDomains;
- (BOOL)isNewDomain:(int)d;
- (int)getNumDeserializers;

@end

@implementation NewDomainsController

- (id) init {
    self = [super init];
    if (!self) {
        return nil;
    }

    nd = [[NSMutableArray array] retain];
    for (int i = 15; i < 50; i++) {
        [nd addObject:[NSNumber numberWithInteger:i]];
    }

    ds = [[NSMutableDictionary dictionary] retain];
}

- (NSMutableArray *)getNewDomains {
    return nd;
}

- (BOOL)isNewDomain:(int)d {
    return [nd containsObject:[NSNumber numberWithInteger:d]];
}

- (void)setDeserializer:(id)deser forDomain:(int)d {
    [ds setObject:deser forKey:[NSNumber numberWithInteger:d]];
}

- (void)clear {
    [ds removeAllObjects];
}

- (int)getNumDeserializers {
    return [ds count];
}

- (id)getDeserializerForSection:(int)section {
    int n = [self getNumDeserializers];
    if (section >= n) {
        return nil;  // OMG
    }

    // get all the deserializers, sort them by domains, and return the proper
    // index
}

@end

static NSInteger sortMatchesByWeight (id name1, id name2, void *context) {
    name1 = [name1 objectAtIndex:0];
    name2 = [name2 objectAtIndex:0];

    NSNumber *loc1 = [Globals.matchWeights objectForKey:name1];
    NSNumber *loc2 = [Globals.matchWeights objectForKey:name2];
    return [loc1 intValue] - [loc2 intValue];
}

@interface SBSearchController : NSObject<Blah>
{
    SBSearchView *_searchView;
    NSString *_queryString;
    NSDateFormatter *_dateFormatter;
    int _domainOrdering[12];
    NSArray *_querySearchDomains;
    BOOL _querySearchDomainsIncludesApplications;
    int _sectionToGroupMap[12];
    BOOL _sectionToGroupMapIsValid;
    int _resultSectionCount;
    int _applicationsSectionIndex;
    SPSearchResult *_cursor;
    SPSearchResultDeserializer *_resultGroups[12];
    SPSearchResultDeserializer *_accumulatingResultGroups[12];
    char _resultGroupsIsCurrent[12];
    SPDaemonQueryToken *_currentToken;
    NSMutableArray *_matchingLaunchingIcons;
    NSTimer *_clearSearchTimer;
    NSDate *_clearSearchDate;
    BOOL _reloadingTableContent;
}
@end

@interface SBSearchTableViewCell : NSObject<Blah>
{
    NSString *_title;
    UIFont *_titleFont;
    NSArray *_subtitleComponents;
    UIFont *_subtitleFont;
    BOOL _badged;
    BOOL _usesAlternateBackgroundColor;
    BOOL _isFirstInTableView;
    BOOL _isFirstInSection;
    float _sectionHeaderWidth;
    float _edgeInset;
}

@end

static int __SBSearchController_numberOfSectionsInTableView(SBSearchController *self, SEL sel, id fp8) {
    Globals.numSectionsOriginal = [self spotbright_numberOfSectionsInTableView:fp8];
    int n = [Globals.matches count];
    int o = [Globals.newDomainsController getNumDeserializers];
    return Globals.numSectionsOriginal + n + o;
}

static id __SBSearchController__groupForSection(SBSearchController *self,
                                                SEL sel, int section) {
    int napps = [Globals.matches count];
    // NSLog(@"_groupForSection called section=%d napps=%d others=%d", section, napps, [Globals.deserializers count]);
    if (section < napps) {
        int index = section;
        MahDeserializer *results = Globals.results;
        NSArray *stuff = [Globals.matches objectAtIndex:index];

        [results setTitle:[stuff objectAtIndex:0]
                displayId:[stuff objectAtIndex:1]];
        return results;
    }

    section -= napps;
    if (section >= Globals.numSectionsOriginal) {
        int index = section - Globals.numSectionsOriginal;
        return [Globals.newDomainsController getDeserializerForSection:index];
    }

    id g = [self spotbright__groupForSection:section];
    return g;
}

static id __SBSearchController__launchingURLForResult_withDisplayIdentifier
(SBSearchController *self, SEL sel, SPSearchResult *result, NSString *displayId) {
    if ([result domain] == APP_DOMAIN) {
        [Globals.controller launchApp:displayId];
        return nil;
    }

    id ret = [self spotbright__launchingURLForResult:result withDisplayIdentifier:displayId];
    return ret;
}

static BOOL __SBSearchController__shouldDisplayApplicationSearchResults(SBSearchController *self, SEL sel) {
    return NO;
}

static void __SBSearchController_searchBar_textDidChange
(SBSearchController *self, SEL sel, id fp8, id fp12) {
    Globals.queryString = fp12;

    [Globals.newDomainsController clear];
    [Globals.matches removeAllObjects];
    [Globals.matchWeights removeAllObjects];

    // send it over to the overlords first so the background searches can
    // start asap
    [self spotbright_searchBar:fp8 textDidChange:fp12];

    NSString *searchText = Globals.queryString;
    BOOL textExists = ![searchText isEqual:@""];
    [Globals.controller showRecentEntriesView:!textExists];

    if (textExists) {
        for (NSArray *info in Globals.items) {
            NSString *name = [info objectAtIndex:0];
            NSRange range = [name rangeOfString:searchText options:(NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch)];
            if (range.location != NSNotFound && range.location == 0) {
                [Globals.matches addObject:info];

                NSInteger weight = 10000 * range.location;
                NSInteger sortOrder = 0;
                weight += 1000 * (sortOrder + 1);
                [Globals.matchWeights setObject:[NSNumber numberWithInt:weight] forKey:name];
            }
        }

        [Globals.matches sortUsingFunction:sortMatchesByWeight context:self];
    }
}

static id __SBSearchView_initWithFrame(SBSearchView *self, SEL sel, struct CGRect fp8) {
    self = [self spotbright_initWithFrame:fp8];
    if (!self) {
        return nil;
    }


    [self addSubview:[Globals.controller createRecentEntriesView]];
    [Globals.controller performSelector:@selector(updateRecentEntriesView) withObject:nil afterDelay:1.0];

    return self;
}

static void __SBUIController_activateApplicationAnimated
(SBUIController *self, SEL sel, id app) {
    [self spotbright_activateApplicationAnimated:app];
    [[SpotbrightSettings sharedInstance] recordRecentEntry:[app bundleIdentifier] type:@"app"];
    [Globals.controller updateRecentEntriesView];
}

static void indexApplications(SBApplicationController *controller) {
    NSArray *allApps = [controller allApplications];
    if (!allApps)
        return;

    NSLog(@"indexing applications");
    for (id<Blah> app in allApps) {
        NSString *name = [app displayName];
        NSString *bundle = [app bundleIdentifier];

        if ([bundle hasSuffix:@"springboard"]
         || [bundle hasSuffix:@"DemoApp"]
         || [bundle hasSuffix:@"quickgold.settings"]
         || [bundle hasSuffix:@"WebSheet"]) {
            continue;
        }

        [Globals.items addObject:[NSArray arrayWithObjects:name, bundle, nil]];
    }
}

static id __SBApplicationController_init
(SBApplicationController *self, SEL sel) {
    self = [self spotbright_init];
    if (!self) {
        return nil;
    }

    indexApplications(self);
    return self;
}

static void __SBSearchController_searchDaemonQuery_addedResults
(SBSearchController *self, SEL sel, id fp8, id deserializer) {
    int domain = [deserializer domain];
    if ([Globals.newDomainsController isNewDomain:domain]) {
        [Globals.newDomainsController setDeserializer:deserializer forDomain:domain];
    } else {
        [self spotbright_searchDaemonQuery:fp8 addedResults:deserializer];
    }
}

static id __SPSearchQuery_initWithSearchString_forSearchDomains
(SPSearchQuery *self, SEL sel, NSString* searchString, NSArray *domains) {
    NSMutableArray *d2 = [NSMutableArray array];
    [d2 addObjectsFromArray:domains];
    [d2 addObjectsFromArray:[Globals.newDomainsController getNewDomains]];

    return [self spotbright_initWithSearchString:searchString forSearchDomains:d2];
}

static id __SPSearchQuery_initWithSearchString(SPSearchQuery *self, SEL sel, id fp8) {
    return [self spotbright_initWithSearchString:fp8];
}

__attribute__((constructor))
static void SpotbrightInitializer()
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    NSString *appId = [[NSBundle mainBundle] bundleIdentifier];

    if (![appId hasSuffix:@"springboard"]) {
        [pool release];
        return;
    }

    NSMutableArray *searchCategoriesSorted =
        [NSMutableArray arrayWithObjects:
                                   Spotbright_KEY_APPLICATIONS,
                                   Spotbright_KEY_CONTACTS,
                                   Spotbright_KEY_WEBCLIPS,
                                   Spotbright_KEY_BOOKMARKS,
                                   Spotbright_KEY_HISTORY,
                                   Spotbright_KEY_SMS,
                                   Spotbright_KEY_CALENDAR,
                                   nil];
    [[SpotbrightSettings sharedInstance] initWithCategories:searchCategoriesSorted];

    Globals.results = [[MahDeserializer alloc] init];

    Globals.items = [[NSMutableArray array] retain];
    Globals.newDomainsController = [[NewDomainsController alloc] init];

    Globals.matches = [[NSMutableArray array] retain];
    Globals.matchWeights = [[NSMutableDictionary dictionary] retain];
    Globals.controller = [[MahController alloc] init];

    MyRename(YES, "SBApplicationController", @selector(init), (IMP)&__SBApplicationController_init);
    MyRename(YES, "SBSearchController", @selector(numberOfSectionsInTableView:), (IMP)&__SBSearchController_numberOfSectionsInTableView);
    MyRename(YES, "SBSearchController", @selector(_groupForSection:), (IMP)&__SBSearchController__groupForSection);
    MyRename(YES, "SBSearchController", @selector(_launchingURLForResult:withDisplayIdentifier:), (IMP)&__SBSearchController__launchingURLForResult_withDisplayIdentifier);
    MyRename(YES, "SBSearchController", @selector(searchBar:textDidChange:), (IMP)&__SBSearchController_searchBar_textDidChange);
    MyRename(YES, "SBSearchController", @selector(_shouldDisplayApplicationSearchResults), (IMP)&__SBSearchController__shouldDisplayApplicationSearchResults);
    MyRename(YES, "SBSearchController", @selector(searchDaemonQuery:addedResults:), (IMP)&__SBSearchController_searchDaemonQuery_addedResults);

    MyRename(YES, "SBSearchView", @selector(initWithFrame:), (IMP)&__SBSearchView_initWithFrame);
    MyRename(YES, "SBUIController", @selector(activateApplicationAnimated:), (IMP)&__SBUIController_activateApplicationAnimated);

    MyRename(YES, "SPSearchQuery", @selector(initWithSearchString:forSearchDomains:), (IMP)&__SPSearchQuery_initWithSearchString_forSearchDomains);
    MyRename(YES, "SPSearchQuery", @selector(initWithSearchString:), (IMP)&__SPSearchQuery_initWithSearchString);

    [pool release];
}

void MyInject(const char *classname, const char *oldname, IMP newimp, const char *type) {
    Class _class = objc_getClass(classname);
    if (_class == nil)
        return;
    if (!class_addMethod(_class, sel_registerName(oldname), newimp, type))
        NSLog(@"WB:Error: failed to inject [%s %s]", classname, oldname);
}

void MyRename(bool instance, const char *name, SEL sel, IMP newimp) {
    if (Debug_) {
        NSLog(@"Renaming %s::%@", name, NSStringFromSelector(sel));
    }

    Class _class = objc_getClass(name);
    if (_class == nil) {
        if (Debug_)
            NSLog(@"WB:Warning: cannot find class [%s]", name);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    MSHookMessage(_class, sel, newimp, RenamePrefix);
}

