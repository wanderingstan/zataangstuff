#import "RootViewController.h"
#import "VibrusAppDelegate.h"

@implementation RootViewController

- (IBAction)enableVibrus:(id)sender
{
	UISwitch *sw = sender;
	switch ([sender tag]) {
		case 0: {
			if (sw.on) [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"vibrusEnabled"];
			else [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"vibrusEnabled"];
		} break;
		case 1: {
			if (sw.on) [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"kbEnabled"];
			else [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"kbEnabled"];
		} break;
		case 2: {
			if (sw.on) [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"dialPadEnabled"];
			else [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"dialPadEnabled"];
		} break;
		default: break;
	}
}
- (IBAction)setIntensity:(id)sender 
{
	UISlider *slider = sender;
	[[NSUserDefaults standardUserDefaults] setInteger:lround(slider.value) forKey:@"intensity"];
}
- (IBAction)setDuration:(id)sender 
{
	UISlider *dslider = sender;
	durationLabel.text = [NSString stringWithFormat:@"%dms", lround(dslider.value)];
	[[NSUserDefaults standardUserDefaults] setInteger:(lround(dslider.value)*1000) forKey:@"duration"];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
		case 0: return @"General"; break;
		case 1: return @"Modules"; break;
		case 2: return @"Preferences"; break;
		default: return nil; break;
	}
	return nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section)
	{
		case 2: return @"Vibrus v1.0 by zataang and francis"; break;
		default: return nil; break;
	}
	return nil;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 3;	
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
		case 0: return 1;
		case 1: return 2;
		case 2: return 2;
		default: break;
	}
	return 0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	switch (indexPath.section)
	{
		case 0:
		{
			switch (indexPath.row)
			{
				case 0: return vibrusEnabledCell;
				default: return nil;
			}
		}
		case 1:
		{
			switch (indexPath.row)
			{
				case 0: return kbEnabledCell;
				case 1: return dialPadEnabledCell;
				default: return nil;
			}
		}
		case 2:
		{
			switch (indexPath.row)
			{
				case 0: return intensityCell;
				case 1: return durationCell;
				default: return nil;
			}
		}
	}
	return 0;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath {
	return;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 44;
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [super dealloc];
}


@end

