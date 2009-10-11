#ifndef __CLASSES_SETTINGS__H
#define __CLASSES_SETTINGS__H

#define MAX_RECENT_ENTRIES  6

#import <Foundation/Foundation.h>

@interface SpotbrightSettings : NSObject {
    NSMutableDictionary *dict;
    BOOL isFirstRunAfterVersionChange;
    NSArray *allCategoriesInSortedOrder;
} 

+ (id) sharedInstance;
+ (NSString *) getVersion;

- (void) initWithCategories:(NSArray *)categories;
- (void) reload;
- (void) save;

- (void) recordRecentEntry:(NSString *)identifier type:(NSString *)type;
- (NSArray *) getRecentEntries;
- (BOOL) shouldIndexCategory:(NSString *)cat;
- (NSInteger) getSortOrderForCategory:(NSString *)cat;
- (NSArray *) getSearchCategories;

- (void) categoryIncludePreference:(NSString *)cat changedTo:(BOOL)newValue;
- (void) changeSortOrder:(NSArray *)rows;

- (BOOL) showRecentApps;
- (BOOL) isKeyboardTransparent;
- (void) keyboardTransparencyChangedTo:(BOOL)newValue;
- (void) showRecentAppsChangedTo:(BOOL)newValue;
- (BOOL) isBackgroundColorBlack;
- (void) backgroundColorChangedTo:(NSString *)newColor;
- (int) numResultsToShow;
- (void) numResultsToShowChangedTo:(int)newValue;

- (BOOL) isFirstRunAfterVersionChange;

@end 

#endif /* __CLASSES_SETTINGS__H */
// Local Variables:
// Mode: c++
// c-basic-offset: 4
// tab-width: 8
// indent-tabs-mode: t
// End:
