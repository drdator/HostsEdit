//
//  HostsEdit.h
//  HostsEdit
//
//  Created by Einar Andersson on 3/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <PreferencePanes/PreferencePanes.h>

#import <PreferencePanes/PreferencePanes.h>
#import <SecurityInterface/SFAuthorizationView.h>

@interface HostsEdit : NSPreferencePane <NSTableViewDataSource,NSTableViewDelegate> {
@private

    NSTableView *hostsTable;
    SFAuthorizationView *authView;
    
    NSButton *addButton;
    NSButton *removeButton;
    NSButton *saveButton;
    
    NSMutableArray *protectedHosts;
    NSMutableArray *editableHosts;
}

- (void)mainViewDidLoad;

- (IBAction)add:(id)sender;
- (IBAction)remove:(id)sender;

- (IBAction)save:(id)sender;


@property (assign) IBOutlet NSTableView *hostsTable;
@property (assign) IBOutlet SFAuthorizationView *authView;

@property (assign) IBOutlet NSButton *addButton;
@property (assign) IBOutlet NSButton *removeButton;
@property (assign) IBOutlet NSButton *saveButton;

@end
