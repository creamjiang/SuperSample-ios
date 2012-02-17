//
//  LoginViewController.m
//  SuperSample
//
//  Created by Igor Khomenko on 04.10.11.
//  Copyright 2011 QuickBlox. All rights reserved.
//

#import "LoginViewController.h"
#import "UsersProvider.h"
#import "SuperSampleAppDelegate.h"
#import "Users.h"

@implementation LoginViewController
@synthesize login;
@synthesize password;
@synthesize activityIndicator;
@synthesize fbLoginButton;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc{
    [login release];
    [password release];
    [activityIndicator release];
    [super dealloc];
}


#pragma mark
#pragma mark - View lifecycle
#pragma mark

- (void) viewDidLoad{
    [super viewDidLoad];
    [FlurryAPI logEvent:@"LoginViewController, viewDidLoad"];
    
    // Login Button
    [fbLoginButton setImage:[UIImage imageNamed:@"FBConnect.bundle/images/LoginNormal@2x.png"]
                 forState:UIControlStateNormal];
    [fbLoginButton setImage:[UIImage imageNamed:@"FBConnect.bundle/images/LoginPressed@2x.png"]
                 forState:UIControlStateHighlighted];
    [fbLoginButton sizeToFit];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(fbDidLogin:) 
                                                 name:nFBDidLogin object:nil];
}

- (void)viewDidUnload{
    [self setLogin:nil];
    [self setPassword:nil];
    [self setActivityIndicator:nil];
    self.fbLoginButton = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nFBDidLogin object:nil];
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)next:(id)sender {
	if (isBusy) {
		return;
	}
    
    QBUUser *qbUser = [[QBUUser alloc] init];
    qbUser.ownerID = ownerID;        
    qbUser.login = login.text;
	qbUser.password = password.text;
    
    // authenticate
    [QBUsersService authenticateUser:qbUser delegate:self context:nil];
    
    [qbUser release];
    
    [self busy:YES];
}

- (IBAction)back:(id)sender {
	if (isBusy) {
		return;
	}

    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)authViaFacebook:(id)sender{
    
    SuperSampleAppDelegate *delegate = ((SuperSampleAppDelegate *)[[UIApplication sharedApplication] delegate]);
    
    if (![[delegate facebook] isSessionValid]) {
        [[delegate facebook] authorize:nil];
    } 
}

- (void)fbDidLogin:(NSNotification *)notification{
    SuperSampleAppDelegate *delegate = ((SuperSampleAppDelegate *)[[UIApplication sharedApplication] delegate]);
    NSLog(@"fbDidLogin, %@", [delegate facebook]);
    
    // get information about the currently logged in user
    [[delegate facebook] requestWithGraphPath:@"me" andDelegate:self];
}


#pragma mark -
#pragma mark FBRequestDelegate

- (void)request:(FBRequest *)request didLoad:(id)result{
    NSLog(@"result=%@", result);
}

#pragma mark -
#pragma mark ActionStatusDelegate

-(void)completedWithResult:(Result *)result{
	[self completedWithResult:result context:nil];
}

-(void)completedWithResult:(Result *)result context:(void*)contextInfo{

	if([result isKindOfClass:[QBUUserAuthenticateResult class]]){
		QBUUserAuthenticateResult *res = (QBUUserAuthenticateResult *)result;
        [res user];
		if(res.success){

			QBUUserAuthenticateAnswer *answer = (QBUUserAuthenticateAnswer *)res.answer;
            
            // fix issue with sign in
            if(answer.user.ownerID != ownerID){
                [self showMessage:NSLocalizedString(@"Not registered!", "") message:nil delegate:nil];
                return;
            }
            
            // current user
            [[UsersProvider sharedProvider] currentUserWithQBUser:answer.user];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:nRefreshAnnotationDetails object:nil];
            
			[self showMessage:NSLocalizedString(@"Authentication successful", "") 
					  message:[NSString stringWithFormat:NSLocalizedString(@"%@ was authenticated", ""), answer.user.login] delegate:self];

		}else if(401 == result.status){
			[self showMessage:NSLocalizedString(@"Not registered!", "") message:nil delegate:nil];
		}else{
            [self processErrors:result.errors];
        }
    }
    
    [self busy:NO];
}


#pragma mark -
#pragma mark UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)_textField{
    [_textField resignFirstResponder];
    [self next:nil];
    return YES;
}


#pragma mark -
#pragma mark Private

-(void)busy:(BOOL) _isBusy{	
	isBusy = _isBusy;
	
	if (isBusy) {
		[activityIndicator startAnimating];
	}else {
		[activityIndicator stopAnimating];		
	}	
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    [password resignFirstResponder];
    [login resignFirstResponder];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    // register subscriber
    QBUUser *user = [[UsersProvider sharedProvider] currentUser].qbUser;
    QBCDevice *device = [[QBCDevice alloc] initWithCurrentDevice];
    [QBMessagesService TRegisterSubscriberForUser:user device:device delegate:self];

    [(SuperSampleAppDelegate *)[[UIApplication sharedApplication] delegate] startTrackOwnLocation];
    [self dismissModalViewControllerAnimated:YES];
}

@end