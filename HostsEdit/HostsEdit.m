//
//  HostsEdit.m
//  HostsEdit
//
//  Created by Einar Andersson on 3/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "HostsEdit.h"


@implementation HostsEdit

@synthesize hostsTable, authView, addButton, removeButton, saveButton;

- (BOOL)isUnlocked {
    return [authView authorizationState] == SFAuthorizationViewUnlockedState;
}


- (OSErr)runCommand:(NSString*)cmd {
    NSMutableArray *args = [NSMutableArray array];
    [args addObject:@"-c"];
    [args addObject:cmd];
    
    const char **argv = (const char **)malloc(sizeof(char *) * [args count] + 1);
    int argvIndex = 0;
    for (NSString *string in args) {
        argv[argvIndex] = [string UTF8String];
        argvIndex++;
    }
    argv[argvIndex] = nil;
    
    OSErr processError = AuthorizationExecuteWithPrivileges([[authView authorization] authorizationRef], [@"/bin/sh" UTF8String], kAuthorizationFlagDefaults, (char *const *)argv, nil);
    free(argv);
    
    return processError;
}

- (void)parseHostsFile {
    
    NSError *err;
    NSString *hostsFileData = [NSString stringWithContentsOfFile:@"/etc/hosts" encoding:NSUTF8StringEncoding error:&err];
    
    NSMutableCharacterSet *whitespaceAndNewlineAndNumberSignCharacterSet = [[NSMutableCharacterSet alloc] init];
    [whitespaceAndNewlineAndNumberSignCharacterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [whitespaceAndNewlineAndNumberSignCharacterSet formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"#"]];
    
    protectedHosts = [[NSMutableArray alloc] init];
    editableHosts = [[NSMutableArray alloc] init];
    
    
    for (NSString *row in [hostsFileData componentsSeparatedByString:@"\n"]) {
        NSScanner *scanner = [NSScanner scannerWithString:row];
        
        NSString *ip = NULL;
        NSString *host = NULL;
        
        [scanner scanUpToCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&ip];
        if ([scanner isAtEnd]) continue;
        [scanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:NULL];
        if ([scanner isAtEnd]) continue;
        [scanner scanUpToCharactersFromSet:whitespaceAndNewlineAndNumberSignCharacterSet intoString:&host];
        
        if([ip rangeOfString:@"#"].location != NSNotFound || [host rangeOfString:@"#"].location != NSNotFound) continue;
        if(ip == NULL || host == NULL) continue;
        
        if([host isEqualToString:@"localhost"] || [host isEqualToString:@"broadcasthost"]) {
            [protectedHosts addObject:[NSDictionary dictionaryWithObjectsAndKeys:ip,@"ip",host,@"host", nil]];
            continue;
        }
        
        [editableHosts addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:ip,@"ip",host,@"host",[NSNumber numberWithBool:YES],@"active", nil]];
        
    }
}

- (void)mainViewDidLoad {
    
    
    if([[NSUserDefaults standardUserDefaults] objectForKey:@"hosts_editable"]) {
        editableHosts = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"hosts_editable"]];
        protectedHosts = [[NSMutableArray alloc] initWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"hosts_protected"]];
        NSLog(@"ohyeah");
    } else {
        [self parseHostsFile];
    }
    
    
    AuthorizationItem items = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &items};
    [authView setAuthorizationRights:&rights];
    authView.delegate = self;
    [authView updateStatus:nil];
    
    [saveButton setEnabled:[self isUnlocked]];
    
    [hostsTable reloadData];
}

- (void)didUnselect {
    [[NSUserDefaults standardUserDefaults] setObject:editableHosts forKey:@"hosts_editable"];
    [[NSUserDefaults standardUserDefaults] setObject:protectedHosts forKey:@"hosts_protected"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"kewl");
}


- (IBAction)add:(id)sender {
    [editableHosts addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:@"127.0.0.1",@"ip",@"host",@"host", nil]];
    [hostsTable reloadData];
}

- (IBAction)remove:(id)sender {
    if(hostsTable.selectedRow == -1) return;
    [editableHosts removeObjectAtIndex:hostsTable.selectedRow];
    [hostsTable reloadData];
}

- (IBAction)save:(id)sender {
    NSMutableString *output = [[NSMutableString alloc] init];
    [output appendString:@"##\n"];
    [output appendString:@"# Host Database\n"];
    [output appendString:@"#\n"];
    [output appendString:@"# localhost is used to configure the loopback interface\n"];
    [output appendString:@"# when the system is booting.  Do not change this entry.\n"];
    [output appendString:@"##\n\n"];
    
    for (NSDictionary *entry in protectedHosts) {
        [output appendFormat:@"%@ %@\n",[entry objectForKey:@"ip"], [entry objectForKey:@"host"]];
    }
    
    [output appendString:@"\n"];
    
    for (NSDictionary *entry in editableHosts) {
        if([[entry objectForKey:@"active"] boolValue]) [output appendFormat:@"%@ %@\n",[entry objectForKey:@"ip"], [entry objectForKey:@"host"]];
    }
    
    NSError *err;
    
    
    // save temp file
    [output writeToFile:@"/var/tmp/hosts_file" atomically:NO encoding:NSUTF8StringEncoding error:&err];
    
    // back up old hosts file if needed
    if(![[NSFileManager defaultManager] fileExistsAtPath:@"/etc/hosts.bak"]) [self runCommand:@"cp /etc/hosts /etc/hosts.bak"];
    
    [self runCommand:@"mv -f /var/tmp/hosts_file /etc/hosts"];
    [self runCommand:@"chown root:wheel /etc/hosts"];
    
}


// SFAuthorizationView delegate

- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view {
    [saveButton setEnabled:[self isUnlocked]];
}

- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view {
    [saveButton setEnabled:[self isUnlocked]];
}


// Table view data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return editableHosts.count;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [[editableHosts objectAtIndex:row] valueForKey:tableColumn.identifier];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    [[editableHosts objectAtIndex:row] setObject:object forKey:tableColumn.identifier];
}


// Table view delegate

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return YES;
}


@end
