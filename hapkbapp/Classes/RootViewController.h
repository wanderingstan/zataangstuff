#import <UIKit/UIKit.h>
@class AdMobViewController;

@interface RootViewController : UITableViewController 
{
	IBOutlet	UITableViewCell		* vibrusEnabledCell;
	IBOutlet	UISwitch			* vibrusSwitch;
	
	IBOutlet	UITableViewCell		* kbEnabledCell;
	IBOutlet	UISwitch			* kbSwitch;

	IBOutlet	UITableViewCell		* dialPadEnabledCell;
	IBOutlet	UISwitch			* dialPadSwitch;
	
	IBOutlet	UITableViewCell		* intensityCell;
	IBOutlet	UISlider			* intensitySlider;

	IBOutlet	UITableViewCell		* durationCell;
	IBOutlet	UISlider			* durationSlider;
	IBOutlet	UILabel				* durationLabel;
    
    AdMobViewController *adController;
}
- (IBAction)enableVibrus:(id)sender;
- (IBAction)setIntensity:(id)sender;
- (IBAction)setDuration:(id)sender;
@end
