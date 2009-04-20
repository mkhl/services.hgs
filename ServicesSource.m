//
//  ServicesSource.m
//  Services
//
//  Created by mkhl on 16.04.09.
//  Copyright Martin Kuehl 2009. All rights reserved.
//

#import <Vermilion/Vermilion.h>

#pragma mark ServiceEntry Keys
NSString *kServicesEntryNameKeyPath = @"NSMenuItem.default";
NSString *kServicesEntryBundleIdentifierKey = @"NSBundleIdentifier";
NSString *kServicesEntryBundlePathKey = @"NSBundlePath";
NSString *kServicesEntryReturnTypesKey = @"NSReturnTypes";
NSString *kServicesEntrySendTypesKey = @"NSSendTypes";

#pragma mark HGSResult Keys
NSString *kServicesDataKey = @"ServicesData";
NSString *kServicesItemKey = @"ServicesItem";
NSString *kServicesNameKey = @"ServicesName";

#pragma mark HGSResult Types
NSString *kServicesDataResultType = HGS_SUBTYPE(@"action", @"service");
NSString *kServicesItemResultType = HGS_SUBTYPE(@"script", @"service");

#pragma mark Static Data
static NSString *kServicesDataNameFormat = @"Perform service with %@";
static NSString *kServicesSnippetFormat = @"A service of %@";
static NSString *kServicesPerformAction = @"org.purl.net.mkhl.services.action.perform";
static NSString *kServicesURLFormat = @"qsb-service://%@";

#pragma mark -
#pragma mark Helper Functions
NSArray *CFServiceControllerCopyServicesEntries(void);

static NSSet *_ServicesPboardTypesForResult(const HGSResult *result)
{
    if ([result conformsToType:kHGSTypeWebpage])
        return [NSSet setWithObjects:NSStringPboardType, NSURLPboardType, nil];
    if ([result conformsToType:kHGSTypeFile])
        return [NSSet setWithObjects:NSStringPboardType, NSFilenamesPboardType, nil];
    return [NSSet setWithObject:NSStringPboardType];
}

static NSPredicate *_ServicesPredicateFromQuery(const HGSQuery *query)
{
    return [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForConstantValue:[query uniqueWords]]
                                              rightExpression:[NSExpression expressionForKeyPath:kServicesEntryNameKeyPath]
                                                     modifier:NSAllPredicateModifier
                                                         type:NSInPredicateOperatorType
                                                      options:(NSCaseInsensitivePredicateOption |
                                                               NSDiacriticInsensitivePredicateOption)];
}

static NSPredicate *_ServicesPredicateForResult(const HGSResult *result)
{
    return [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForConstantValue:_ServicesPboardTypesForResult(result)]
                                              rightExpression:[NSExpression expressionForKeyPath:kServicesEntrySendTypesKey]
                                                     modifier:NSAnyPredicateModifier
                                                         type:NSInPredicateOperatorType
                                                      options:0];
}

static HGSAction *_ServicesPerformAction(void)
{
    return [[HGSExtensionPoint actionsPoint] extensionWithIdentifier:kServicesPerformAction];
}

static NSURL *_ServicesURLForService(const NSString *name)
{
    return [NSURL URLWithString:[NSString stringWithFormat:kServicesURLFormat, [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

static NSURL *_ServicesURLForQuery(const NSString *name, const NSString *query)
{
    return [NSURL URLWithString:[query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] relativeToURL:_ServicesURLForService(name)];
}

#pragma mark -
@interface ServicesSource : HGSCallbackSearchSource
- (BOOL) isValidSourceForQuery:(HGSQuery *)query;
- (NSArray *) servicesForQuery:(HGSQuery *)query;
- (HGSResult *) resultForService:(NSDictionary *)service;
- (HGSResult *) resultForQuery:(HGSQuery *)query;
- (void) performSearchOperation:(HGSSearchOperation *)operation;
@end

#pragma mark -
@implementation ServicesSource

- (BOOL) isValidSourceForQuery:(HGSQuery *)query
{
    if (![super isValidSourceForQuery:query])
        return NO;
    HGSResult *pivot = [query pivotObject];
    if (pivot == nil)
        return YES;
    if ([pivot isOfType:kServicesItemResultType]) {
        if ([[query uniqueWords] count] == 0)
            return NO;
        if (![[[pivot valueForKey:kServicesItemKey] objectForKey:kServicesEntrySendTypesKey] containsObject:NSStringPboardType])
            return NO;
    }
    return YES;
}

- (NSArray *) servicesForQuery:(HGSQuery *)query
{
    NSArray *services = CFServiceControllerCopyServicesEntries();
    NSPredicate *byName = _ServicesPredicateFromQuery(query);
    HGSResult *pivot = [query pivotObject];
    if (pivot == nil)
        return [services filteredArrayUsingPredicate:byName];
    NSPredicate *byType = _ServicesPredicateForResult(pivot);
    return [services filteredArrayUsingPredicate:[NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:byName, byType, nil]]];
}

- (HGSResult *) resultForService:(NSDictionary *)service
{
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    NSString *name = [service valueForKeyPath:kServicesEntryNameKeyPath];
    NSString *path = [service valueForKey:kServicesEntryBundlePathKey];
    [attrs setObject:[NSString stringWithFormat:kServicesSnippetFormat, [[NSFileManager defaultManager] displayNameAtPath:path]]
              forKey:kHGSObjectAttributeSnippetKey];
    [attrs setObject:[[NSWorkspace sharedWorkspace] iconForFile:path]
              forKey:kHGSObjectAttributeIconKey];
    [attrs setObject:service forKey:kServicesItemKey];
    [attrs setObject:name forKey:kServicesNameKey];
    HGSAction *action = _ServicesPerformAction();
    if (action) {
        [attrs setObject:action forKey:kHGSObjectAttributeDefaultActionKey];
    }
    return [HGSResult resultWithURL:_ServicesURLForService(name)
                               name:[name lastPathComponent]
                               type:kServicesItemResultType
                             source:self
                         attributes:attrs];
}

- (HGSResult *) resultForQuery:(HGSQuery *)query
{
    NSString *queryString = [query rawQueryString];
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    HGSResult *pivot = [query pivotObject];
    NSString *name = [pivot valueForKey:kServicesNameKey];
    [attrs setObject:name forKey:kServicesNameKey];
    [attrs setObject:[pivot valueForKey:kServicesItemKey] forKey:kServicesItemKey];
    [attrs setObject:queryString forKey:kServicesDataKey];
    HGSAction *action = _ServicesPerformAction();
    if (action) {
        [attrs setObject:action forKey:kHGSObjectAttributeDefaultActionKey];
        [attrs setObject:[action icon] forKey:kHGSObjectAttributeIconKey];
    }
    return [HGSResult resultWithURL:_ServicesURLForQuery(name, queryString)
                               name:[NSString stringWithFormat:kServicesDataNameFormat, queryString]
                               type:kServicesDataResultType
                             source:self
                         attributes:attrs];
}

- (void) performSearchOperation:(HGSSearchOperation *)operation
{
    HGSQuery *query = [operation query];
    HGSResult *pivot = [query pivotObject];
    if (pivot && [pivot isOfType:kServicesItemResultType]) {
        [operation setResults:[NSArray arrayWithObject:[self resultForQuery:query]]];
        return;
    }
    NSArray *services = [self servicesForQuery:query];
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:[services count]];
    for (NSDictionary *service in services)
        [results addObject:[self resultForService:service]];
    [operation setResults:results];
}

@end
