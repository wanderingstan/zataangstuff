//
//  QuickGold.h
//  QuickGold
//

#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>

void QuickGoldInject(const char *classname, const char *oldname, IMP newimp, const char *type);
void QuickGoldRename(bool instance, const char *classname, const char *oldname, IMP newimp);

@interface UIKeyboard : UIView { 
};

+ (id) automaticKeyboard;
- (void)orderInWithAnimation:(BOOL)fp8;
- (void)orderOutWithAnimation:(BOOL)fp8;

@end

NSBundle * myBundle;

@interface QuickGold : NSObject <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate> {
    UIWindow *browserWindow;
    bool isDisplaying;
    UISearchBar *searchBar;
    UITextField *searchField;
    UIView *searchBarAndTableView;
    UITableView *matchTable;
    BOOL isGrabbingOn;
}

@property BOOL isGrabbingOn;

- (void) didInjectIntoProgram;
- (void) indexApplications;
- (void) indexAddressBookEntries;
- (void) indexAllWebClips;
- (void) indexApp:(id) app withName:(NSString *)name;
- (void) indexWebClip:(NSString *) url withTitle:(NSString *) title;
- (void) removeWebClip:(NSString *) title;
- (void) removeApp:(NSString *)name;
- (void) removeAppOrWebClipByName:(NSString *) name;

- (void) hideBrowser;
- (void) displayBrowser;
- (void) toggleBrowser;
- (void) showKeyboard:(BOOL) show;
- (void) computeMatches:(NSString *) searchText;
- (void) customLaunch:(id)what withType:(NSString *)type;
- (BOOL) isNumber:(NSString *)text;
- (BOOL) isBookmarkIcon:(id) icon;
- (BOOL) isDownloadingIcon:(id) icon;

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar;
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;

- (void)onNewIconInstallation:(id) icon;
- (void)onIconUninstall:(id) icon;
@end
