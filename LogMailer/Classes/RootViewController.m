//
//  RootViewController.m
//  LogMailer
//
//  Created by Ashwin Bharambe on 10/4/08.
//  Copyright Buxfer, Inc. 2008. All rights reserved.
//

#import "RootViewController.h"
#import "LogMailerAppDelegate.h"

#define LOG_PATH  @"/var/log/syslog"
#define SYSLOG_BYTES_TO_SEND    (60 * 1024)

@implementation RootViewController

- (void) loadView {
    UITableView *v = [[[UITableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStyleGrouped] autorelease];
    v.delegate = self;
    v.dataSource = self;
    
    self.view = v;
    
    UIImage *buttonBackground = [UIImage imageNamed:@"whiteButton.png"];
    UIImage *buttonBackgroundPressed = [UIImage imageNamed:@"blueButton.png"];
    
    CGRect frame = CGRectMake(15.0, 180.0, 280.0, 44.0);
    UIButton *grayButton = [RootViewController buttonWithTitle:@"Send report"
                                                        target:self
                                                      selector:@selector(submitReport:)
                                                         frame:frame
                                                         image:buttonBackground
                                                  imagePressed:buttonBackgroundPressed
                                                 darkTextColor:YES];
    
    
    [self.view addSubview:grayButton];
}

- (NSString *)urlEncodeValue:(NSString *)str {
	NSString *result = (NSString *) CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)str, NULL, CFSTR("?=&+;"), kCFStringEncodingUTF8);
    //	NSString *result = [str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]; //CFString method above gives us more control than this NSString method
	return [result autorelease];
}

- (NSData*) generateFormData:(NSDictionary*) dict {
    NSMutableData* result = [[NSMutableData alloc] initWithCapacity:100];
    
    int i = 0;
    for (NSString *key in dict) {
        NSString *value = [self urlEncodeValue:[dict objectForKey:key]];
        if (i > 0) {
            [result appendData:[@"&" dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [result appendData:[[NSString stringWithFormat:@"%@=%@", key, value] dataUsingEncoding:NSUTF8StringEncoding]];
        i++;
    }
    
    return [result autorelease];
}

- (NSString *) getTextFromFile:(NSString *) path {    
    NSFileManager *manager = [NSFileManager defaultManager];
    if (![manager fileExistsAtPath:path]) { 
        return nil;
    }
    
    NSMutableData* result = [[[NSMutableData alloc] initWithCapacity:100] autorelease];
    FILE *fp = fopen ([path UTF8String], "r");
    
    if (fp) { 
        NSDictionary* dict = [manager fileAttributesAtPath:path traverseLink:YES];
        int size = [[dict objectForKey:@"NSFileSize"] integerValue];
        int position = size - SYSLOG_BYTES_TO_SEND;
        char buffer [1024];
        
        while (fgets (buffer, sizeof (buffer), fp)) {
            if (ftell (fp) < position)
                continue;
            
            if (strstr (buffer, "SCHelper") || strstr (buffer, "localhost kernel")) 
                continue;
            
            [result appendData:[NSData dataWithBytes:buffer length:strlen(buffer)]];
        }
        
        fclose (fp);
    }
    
    NSString *s = [[[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding] autorelease];
    return s;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection
             willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)redirectResponse
{
    NSString *redirectString = [[request URL] absoluteString];
    if ([redirectString hasPrefix:@"http://pastie.org/private"]) { 
        NSLog(@"Obtained pastie link: %@", redirectString);
        NSString *mailtoURL = [[NSString 
                               stringWithFormat:@"mailto:%@?subject=Syslog for debugging&body=Hi,\n\nPlease find the last %d kbytes of the syslog at the following url:\n\n%@\n\nThanks!\n",
                               @"developer-email-here",
                               (int) (SYSLOG_BYTES_TO_SEND / 1024.0),
                               redirectString] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [progress done];
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:mailtoURL]];
        return nil;
    }
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed: %@", error);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    // NSLog(@"Connection did receive response");
}

- (void) showAlert:(NSString *)body {
    UIAlertView *v = [[[UIAlertView alloc] initWithTitle:@"Error!" message:body delegate:self 
                                       cancelButtonTitle:@"Dismiss" otherButtonTitles:nil] autorelease];
    [v show];
}

- (void) submitReport:(id) sender {
    if (![[NSFileManager defaultManager] fileExistsAtPath:LOG_PATH]) { 
        [self showAlert:@"Log file not found"];
        return;
    }
    
    /*
    if (!emailTextField.text || [emailTextField.text isEqual:@""]) {
        [self showAlert:@"Please enter an email address before clicking Submit"];
        return;
    }
     */
        
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://pastie.caboo.se/pastes/create"]];
    [req setHTTPMethod:@"POST"];
    
    NSMutableDictionary *dict = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  @"", @"key",
                                  @"burger", @"paste[authorization]",
                                  @"plain_text", @"paste[parser]",
                                  @"1", @"paste[restricted]",
                                  [self getTextFromFile:LOG_PATH], @"paste[body]",
                                  @"27", @"x",
                                  @"27", @"y",
                                  nil] retain];
    // NSLog(@"%@", [[[NSString alloc] initWithData:[self generateFormData:dict] encoding:NSASCIIStringEncoding] autorelease]);
    [req setHTTPBody:[self generateFormData:dict]];
    
    progress = [[UIProgressHUD alloc] initWithFrame:CGRectMake(20, 100, 280, 140)];
    [progress setText:@"Submitting to pastie.org"];
    [progress showInView:self.view];
    
    [NSURLConnection connectionWithRequest:req delegate:self];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField { 
    [emailTextField resignFirstResponder];
    [self submitReport:textField];
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	switch (section)
	{
		case 0: return @"Clicking send will paste the last few lines of your syslog to pastie.org and open Mail.app to send the pastie link to the developer"; break;
		default: return nil; break;
	}
	return nil;
}

+ (UIButton *)buttonWithTitle:	(NSString *)title
                       target:(id)target
                     selector:(SEL)selector
                        frame:(CGRect)frame
                        image:(UIImage *)image
                 imagePressed:(UIImage *)imagePressed
                darkTextColor:(BOOL)darkTextColor
{	
	UIButton *button = [[UIButton alloc] initWithFrame:frame];
	// or you can do this:
	//		UIButton *button = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	//		button.frame = frame;
	
	button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
	button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
	
	[button setTitle:title forState:UIControlStateNormal];	
	if (darkTextColor) {
        [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
	} else {
		[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	}
	
    button.font = [UIFont boldSystemFontOfSize:20.0];
    
	UIImage *newImage = [image stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	[button setBackgroundImage:newImage forState:UIControlStateNormal];
	
	UIImage *newPressedImage = [imagePressed stretchableImageWithLeftCapWidth:12.0 topCapHeight:0.0];
	[button setBackgroundImage:newPressedImage forState:UIControlStateHighlighted];
	
	[button addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
	
    // in case the parent view draws with a custom color or gradient, use a transparent color
	button.backgroundColor = [UIColor clearColor];
    
	return button;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
        case 0: return @"Log file to send:"; break;
        case 1: return @"Email it to:"; break;
		default: return nil; break;
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:CellIdentifier] autorelease];
        switch (indexPath.section) { 
            case 0:
            {
                switch (indexPath.row) { 
                    case 0: {
                        cell.text = LOG_PATH;
                        // cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                        break; 
                    }
                    default: break;
                }
                break;
            }
            case 1:
            {
                switch (indexPath.row) {
                    case 0:
                    {
                        emailTextField = [[[UITextField alloc] initWithFrame:CGRectMake(8, 8, 280, 26)] autorelease];
                        emailTextField.placeholder = @"email address of developer";
                        emailTextField.autocorrectionType = UITextAutocorrectionTypeNo;
                        emailTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                        emailTextField.keyboardType = UIKeyboardTypeEmailAddress;
                        emailTextField.returnKeyType = UIReturnKeyGo;
                        
                        emailTextField.delegate = self;
                        [cell.contentView addSubview:emailTextField];
                        break;
                    }
                    default:
                        break;
                }
                break;
            }
            default:
            {
                break;
            }
        }
    }
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic -- create and push a new view controller
}


/*
 - (void)viewDidLoad {
 [super viewDidLoad];
 // Uncomment the following line to add the Edit button to the navigation bar.
 // self.navigationItem.rightBarButtonItem = self.editButtonItem;
 }
 */


/*
 // Override to support editing the list
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
 }   
 if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }   
 }
 */


/*
 // Override to support conditional editing of the list
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */


/*
 // Override to support rearranging the list
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */


/*
 // Override to support conditional rearranging of the list
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

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

