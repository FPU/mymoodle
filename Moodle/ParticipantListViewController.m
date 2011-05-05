//
//  ParticipantListViewController.m
//  Moodle
//
//  Created by jerome Mouneyrac on 14/04/11.
//  Copyright 2011 Moodle. All rights reserved.
//

#import "ParticipantListViewController.h"
#import "WSClient.h"
#import "Config.h"


@implementation ParticipantListViewController
@synthesize fetchedResultsController=__fetchedResultsController;
@synthesize managedObjectContext=__managedObjectContext;
@synthesize course;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    
    //retrieve the participants by webservice
    BOOL offlineMode = [[NSUserDefaults standardUserDefaults] boolForKey:kSelectedOfflineModeKey];
    if (!offlineMode) {
        
        NSLog(@"The course is: %@", course);
        
        WSClient *client = [[WSClient alloc] init];
        NSNumber *courseid = [course valueForKey:@"id"];
        NSArray *paramvalues = [[NSArray alloc] initWithObjects:courseid, nil];
        NSArray *paramkeys = [[NSArray alloc] initWithObjects:@"courseid", nil];
        NSDictionary *params = [[NSDictionary alloc] initWithObjects:paramvalues forKeys:paramkeys];
        NSArray *result;
        @try {
            result = [client invoke: @"moodle_enrol_get_enrolled_users" withParams: (NSArray *)params];  
        }
        @catch (NSException *exception) {
            NSLog(@"%@", exception);
        }
        
        //retrieve all course participants that will need to be deleted from core data
        NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
        NSEntityDescription *entityDescription = [NSEntityDescription entityForName:@"Participant" inManagedObjectContext:self.managedObjectContext];
        [request setEntity:entityDescription];
        NSError *error = nil;
        //TODO: manage multiple userid for different course object (lis of participant should be retrieved for the course object only)
        NSArray *participantsToDelete = [self.managedObjectContext executeFetchRequest:request error:&error];
        NSMutableDictionary *participantsToNotDelete = [[NSMutableDictionary alloc] init];
        NSLog(@"Participants in core data: %@", participantsToDelete);
        NSLog(@"Number of participants in core data before web service call: %d", [participantsToDelete count]);
        
        //update core data participants with participants from web service call
        if (result != nil) {
            NSLog(@"Result: %@", result);
            for ( NSDictionary *participant in result) {
            
                    NSManagedObject *dbparticipant;
                    
                    //check if the user id is already in core data participants
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                                              @"(userid = %@)", [participant objectForKey:@"userid"]];
                    [request setPredicate:predicate];
                    NSArray *existingParticipants = [self.managedObjectContext executeFetchRequest:request error:&error];
                    if ([existingParticipants count] == 1) {
                        //retrieve the participant to update
                        dbparticipant = [existingParticipants lastObject];
                        
                    } else if ([existingParticipants count] ==0) {
                        //the participant is not in core data, we add it
                        dbparticipant = [NSEntityDescription insertNewObjectForEntityForName:[entityDescription name] inManagedObjectContext:self.managedObjectContext];
                        
                    } else { 
                        NSLog(@"Error !!!!!! There is more than one participant with id == %@", [participant objectForKey:@"userid"]);
                    }
                    
                    //set the course values
                    [dbparticipant setValue:[participant objectForKey:@"firstname"] forKey:@"firstname"];
                    [dbparticipant setValue:[participant objectForKey:@"userid"] forKey:@"userid"];
                    [dbparticipant setValue:[participant objectForKey:@"lastname"] forKey:@"lastname"];
                    [dbparticipant setValue:[participant objectForKey:@"username"] forKey:@"username"];
                    //add the course to the list of course of the participant
                    NSMutableSet *participantcourses;
                    if ([existingParticipants count] == 1) {
                        participantcourses = [[NSSet alloc] initWithObjects:course, nil];
                    } else {
                        participantcourses = [participant objectForKey:@"courses"];
                        [participantcourses addObject:course];
                        
                    }
                    [dbparticipant setValue:participantcourses forKey:@"courses"];
                    
                    //save the modification
                    if (![[dbparticipant managedObjectContext] save:&error]) {
                        NSLog(@"Error saving entity: %@", [error localizedDescription]);
                    }
                    
                    NSNumber *participantexist = [[NSNumber alloc] initWithBool:YES];
                    [participantsToNotDelete setObject:participantexist forKey:[participant objectForKey:@"userid"]];
                    [participantexist release];
            }
        }
        
        //delete the obsolete courses from core data
        NSLog(@" the course to no detele are %@", participantsToNotDelete);
        NSLog(@" the course to detele are %@", participantsToDelete);
        for (NSManagedObject *participantToDelete in participantsToDelete) {
            NSNumber *theparticipantexist = [participantsToNotDelete objectForKey:[participantToDelete valueForKey:@"userid"]];
            if ([theparticipantexist intValue] == 0) {
                NSLog(@"I'm deleting the course %@", participantToDelete);
                
                [self.managedObjectContext deleteObject:participantToDelete];
            }
        }
        
        //save the modifications
        if (![self.managedObjectContext save:&error]) {
            NSLog(@"Error saving entity: %@", [error localizedDescription]);
        }
        
        [participantsToNotDelete release];
    }
    
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ParticipantCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSManagedObject *oneParticipant = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    // Configure the cell...
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    UIImage *image = [UIImage imageNamed:@"Participants.png"];
    cell.imageView.image = image;
    
    CGRect participantNameRect = CGRectMake(50, 5, 200, 18);
    UILabel *participantName = [[UILabel alloc] initWithFrame:participantNameRect];
    participantName.text = [NSString stringWithFormat:@"%@ %@",[oneParticipant valueForKey:@"firstname"],
                            [oneParticipant valueForKey:@"lastname"]];
    participantName.font = [UIFont boldSystemFontOfSize:15];
    [cell.contentView addSubview:participantName];
    [participantName release];
    
    CGRect userNameRect = CGRectMake(50, 26, 200, 12);
    UILabel *userName = [[UILabel alloc] initWithFrame:userNameRect];
    userName.text = [oneParticipant valueForKey:@"username"];
    userName.font = [UIFont italicSystemFontOfSize:12];
    [cell.contentView addSubview:userName];
    [userName release];

    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     [detailViewController release];
     */
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (__fetchedResultsController != nil)
    {
        return __fetchedResultsController;
    }
    
    /*
     Set up the fetched results controller.
     */
    // Create the fetch request for the entity.
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Participant" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"lastname" ascending:NO];
    NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Root"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
    [aFetchedResultsController release];
    [fetchRequest release];
    [sortDescriptor release];
    [sortDescriptors release];
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error])
    {
	    /*
	     Replace this implementation with code to handle the error appropriately.
         
	     abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
	     */
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return __fetchedResultsController;
}   

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type)
    {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];       
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

@end
