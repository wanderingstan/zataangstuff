#import "Settings.h"
#import "Keys.h"
#include <time.h>

static NSString *spotbrightVersion = @"0.2";

static SpotbrightSettings *staticSharedSettings = nil;

static NSString *getPreferencesFile () { 
    return [@"/var/mobile" stringByAppendingString:@"/Library/Preferences/com.zataang.spotbright.plist"];
}

@interface SpotbrightSettings(Private)

- (NSMutableDictionary *) getCategoryDictionary:(NSString *)cat;

@end

@implementation SpotbrightSettings 

+ (id) sharedInstance {
    if (!staticSharedSettings) { 
        staticSharedSettings = [[SpotbrightSettings alloc] init];
    }
    
    return staticSharedSettings;
}

+ (void) initInstance {
    staticSharedSettings = [[SpotbrightSettings alloc] init];
}

+ (NSString *) getVersion { 
    return spotbrightVersion;
}

- (id) init { 
    self = [super init];
    if (!self) 
        return nil;
    
    isFirstRunAfterVersionChange = false;
    dict = [[NSMutableDictionary dictionaryWithContentsOfFile:getPreferencesFile()] retain];
    return self;
}

- (void) dealloc { 
    [dict release];
    [super dealloc];
}

- (BOOL) isFirstRunAfterVersionChange {
    return isFirstRunAfterVersionChange;
}

- (NSArray *)getRecentEntries {
    return [dict objectForKey:@"recentEntries"];
}

static NSInteger sortByLastUsed (id entry1, id entry2, void *context) {
    int time1 = [[entry1 objectForKey:@"timeUsed"] integerValue];
    int time2 = [[entry2 objectForKey:@"timeUsed"] integerValue];

    // greater timestamps => recently used => should be at the top
    return time2 - time1;
}

- (void) recordRecentEntry:(NSString *)identifier type:(NSString *)type {
    time_t now = time (NULL);
    NSMutableArray *recentEntries = [NSMutableArray arrayWithArray:[self getRecentEntries]];
    [recentEntries sortUsingFunction:sortByLastUsed context:self];

    BOOL found = NO;
    for (NSMutableDictionary *d in recentEntries) {  
        if ([[d objectForKey:@"key"] isEqual:identifier]) { 
            [d setObject:[NSNumber numberWithInt:now] forKey:@"timeUsed"];
            found = YES;
            break;
        }
    }

    if (!found) {
        if ([recentEntries count] >= MAX_RECENT_ENTRIES) { 
            [recentEntries removeLastObject];
        }
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
            type, @"type",
            identifier, @"key",
            [NSNumber numberWithInt:now], @"timeUsed",
            nil];
        [recentEntries insertObject:d atIndex:0];
    }

    [recentEntries sortUsingFunction:sortByLastUsed context:self];
    [dict setObject:recentEntries forKey:@"recentEntries"];
    [self save];
}

- (BOOL) isKeyboardTransparent { 
    return ([[dict objectForKey:@"transparentKeys"] integerValue] > 0);
}

- (BOOL) showRecentApps { 
    return ([[dict objectForKey:@"showRecentApps"] integerValue] > 0);
}

- (BOOL) isBackgroundColorBlack { 
    return [[dict objectForKey:@"backgroundColor"] isEqual:@"black"];
}

- (int) numResultsToShow { 
    return [[dict objectForKey:@"numResultsToShow"] integerValue];
}

- (void) keyboardTransparencyChangedTo:(BOOL)newValue {
    [dict setObject:[NSNumber numberWithInt:(newValue ? 1 : 0)] forKey:@"transparentKeys"];
    [self save];
}

- (void) showRecentAppsChangedTo:(BOOL)newValue { 
    [dict setObject:[NSNumber numberWithInt:(newValue ? 1 : 0)] forKey:@"showRecentApps"];
    [self save];
}

- (void) numResultsToShowChangedTo:(int)newValue {
    [dict setObject:[NSNumber numberWithInt:newValue] forKey:@"numResultsToShow"];
    [self save];
}

- (void) backgroundColorChangedTo:(NSString *)newColor {
    [dict setObject:newColor forKey:@"backgroundColor"];
    [self save];
}

- (void) initWithCategories:(NSArray *)categoriesSorted {
    allCategoriesInSortedOrder = categoriesSorted;
    if (!dict) { 
        isFirstRunAfterVersionChange = true;
        dict = [[NSMutableDictionary dictionary] retain];
    }

    NSString *oldVersion = [dict objectForKey:@"version"];
    if (![oldVersion isEqual:spotbrightVersion]) { 
        isFirstRunAfterVersionChange = true;
    }

    [dict setObject:spotbrightVersion forKey:@"version"];
    NSMutableDictionary *d = [dict objectForKey:@"searchCategories"];
    if (!d) { 
        d = [NSMutableDictionary dictionary];
    }

    NSArray *defaultOffCategories = [NSArray arrayWithObjects:Spotbright_KEY_SMS, Spotbright_KEY_CALENDAR, nil];
    for (int i = 0; i < [categoriesSorted count]; i++) {
        NSString *cat = [categoriesSorted objectAtIndex:i];
        if ([d objectForKey:cat]) { 
            continue;
        }

        int included = 1;
        if ([defaultOffCategories indexOfObject:cat] != NSNotFound) { 
            included = 0;
        }

        [d setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
                      [NSNumber numberWithInt:included], @"included",
                      [NSNumber numberWithInt:i], @"sortOrder", nil] forKey:cat];
    }
    
    [dict setObject:d forKey:@"searchCategories"];

    if (![dict objectForKey:@"recentEntries"]) { 
        [dict setObject:[NSArray array] forKey:@"recentEntries"];
    }
    if (![dict objectForKey:@"transparentKeys"]) {
        [dict setObject:[NSNumber numberWithInt:1] forKey:@"transparentKeys"];
    }
    if (![dict objectForKey:@"showRecentApps"]) {
        [dict setObject:[NSNumber numberWithInt:1] forKey:@"showRecentApps"];
    }
    if (![dict objectForKey:@"backgroundColor"]) { 
        [dict setObject:@"white" forKey:@"backgroundColor"];
    }
    if (![dict objectForKey:@"numResultsToShow"]) { 
        [dict setObject:[NSNumber numberWithInt:8] forKey:@"numResultsToShow"];
    }

    [self save];
}

- (NSArray *) getSearchCategories { 
    return [[dict objectForKey:@"searchCategories"] allKeys];
}

- (BOOL) shouldIndexCategory:(NSString *) cat { 
    NSMutableDictionary *d = [self getCategoryDictionary:cat];
    if (!d) 
        return NO;
    
    NSNumber *n = [d objectForKey:@"included"];
    return [n intValue] > 0;
}

- (NSInteger) getSortOrderForCategory:(NSString *)cat {
    NSMutableDictionary *d = [self getCategoryDictionary:cat];
    if (!d) 
        return 0;
    
    NSNumber *n = [d objectForKey:@"sortOrder"];
    return [n intValue];
}

- (NSMutableDictionary *) getCategoryDictionary:(NSString *) cat {
    NSMutableDictionary *d = [[dict objectForKey:@"searchCategories"] objectForKey:cat];
    if (!d) { 
        NSLog ([NSString stringWithFormat:@"WARNING: UNKNOWN CATEGORY (%@) SPECIFIED", cat]);
        return nil;;
    }
    
    return d;
}

- (void) categoryIncludePreference:(NSString *)cat changedTo:(BOOL)newValue {
    NSMutableDictionary *d = [self getCategoryDictionary:cat];
    if (!d) 
        return;
    
    [d setObject:[NSNumber numberWithInt:(newValue ? 1 : 0)] forKey:@"included"];
    [self save];
}

- (void) changeSortOrder:(NSArray *)rows {
    int count = [rows count];
    for (int i = 0; i < count; i++) { 
        NSString *cat = [rows objectAtIndex:i];
        NSMutableDictionary *d = [self getCategoryDictionary:cat];
        if (!d) 
            continue;
        
        [d setObject:[NSNumber numberWithInt:i] forKey:@"sortOrder"];
    }
    
    [self save];
}


- (void) reload {
    NSMutableDictionary * np = [[NSMutableDictionary dictionaryWithContentsOfFile:getPreferencesFile()] retain];
    if (!np) { 
        return;
    }
    
    if (dict) { 
        [dict release];
    }
    dict = np;
}

- (void) save {
    // NSLog ([NSString stringWithFormat:@"saving %@", getPreferencesFile()]);
    [dict writeToFile:getPreferencesFile () atomically:YES];
}

@end
