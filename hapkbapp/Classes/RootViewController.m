#import "RootViewController.h"
#import "VibrusAppDelegate.h"

@implementation RootViewController

- (IBAction)enableVibrus:(id)sender
{
	UISwitch *sw = sender;
	NSMutableDictionary *prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
	switch ([sender tag]) {
		case 0: {
			if (sw.on) [prefsDict setObject:@"1" forKey:@"vibrusEnabled"];
			else [prefsDict setObject:@"0" forKey:@"vibrusEnabled"];
		} break;
		case 1: {
			if (sw.on) [prefsDict setObject:@"1" forKey:@"kbEnabled"];
			else [prefsDict setObject:@"0" forKey:@"kbEnabled"];
		} break;
		case 2: {
			if (sw.on) [prefsDict setObject:@"1" forKey:@"dialPadEnabled"];
			else [prefsDict setObject:@"0" forKey:@"dialPadEnabled"];
		} break;
		default: break;
	}
	[prefsDict writeToFile:@"/var/mobile/Library/Preferences/vibrus.plist" atomically:YES];
	[prefsDict release];
}
- (IBAction)setIntensity:(id)sender 
{
	UISlider *slider = sender;
	NSMutableDictionary *prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
	[prefsDict setObject:[NSString stringWithFormat:@"%i", lround(slider.value)] forKey:@"intensity"];
	[prefsDict writeToFile:@"/var/mobile/Library/Preferences/vibrus.plist" atomically:YES];
	[prefsDict release];
}
- (IBAction)setDuration:(id)sender 
{
	UISlider *dslider = sender;
	NSMutableDictionary *prefsDict = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
	durationLabel.text = [NSString stringWithFormat:@"%dms", lround(dslider.value)];
	[prefsDict setObject:[NSString stringWithFormat:@"%i", lround(dslider.value)*1000] forKey:@"duration"];
	[prefsDict writeToFile:@"/var/mobile/Library/Preferences/vibrus.plist" atomically:YES];
	[prefsDict release];
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
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)newIndexPath
{
	return;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return 44;
}

- (void)viewWillAppear:(BOOL)animated {
	NSDictionary *prefs;
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Preferences/vibrus.plist"])
	{
		prefs = [NSMutableDictionary dictionary];
		[prefs setValue:@"1" forKey:@"vibrusEnabled"];
		[prefs setValue:@"1" forKey:@"kbEnabled"];
		[prefs setValue:@"1" forKey:@"dialPadEnabled"];
		[prefs setValue:@"2" forKey:@"intensity"];
		[prefs setValue:@"45000" forKey:@"duration"];
		[prefs writeToFile:@"/var/mobile/Library/Preferences/vibrus.plist" atomically:YES];
	}
	else
	{
		prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/vibrus.plist"];
	}
	
	BOOL vibrusEnabled = [[prefs objectForKey:@"vibrusEnabled"] integerValue];
	BOOL kbEnabled = [[prefs objectForKey:@"kbEnabled"] integerValue];
	BOOL dialPadEnabled = [[prefs objectForKey:@"dialPadEnabled"] integerValue];
	int intensity = [[prefs objectForKey:@"intensity"] integerValue];
	int duration = [[prefs objectForKey:@"duration"] integerValue] / 1000;
	
	vibrusSwitch.on = vibrusEnabled;
	kbSwitch.on = kbEnabled;
	dialPadSwitch.on = dialPadEnabled;
	
	intensitySlider.value = intensity;
	durationSlider.value = duration;
	durationLabel.text = [NSString stringWithFormat:@"%dms", duration];
	
    [super viewWillAppear:animated];
}


//- (void)viewDidAppear:(BOOL)animated {	
//    [super viewDidAppear:animated];
//}

/*
- (void)viewWillDisappear:(BOOL)animated {
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
}
*/
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}
- (void)dealloc {
    [super dealloc];
}


@end

