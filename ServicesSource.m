//
//  ServicesSource.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>
#import <Vermilion/HGSTokenizer.h>

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
NSString *kServicesItemResultType = HGS_SUBTYPE(@"script", @"service");

#pragma mark Static Data
static NSString *kServicesSnippetFormat = @"A service of %@";
static NSString *kServicesPerformAction = @"org.purl.net.mkhl.services.action.perform";
static NSString *kServicesURLFormat = @"qsb-service://%@";

#pragma mark -
#pragma mark Helper Functions
NSArray *CFServiceControllerCopyServicesEntries(void);

static NSArray *_ServicesPboardTypesForResult(const HGSResult *result)
{
    if ([result conformsToType:kHGSTypeWebpage])
        return [NSArray arrayWithObject:NSURLPboardType];
    if ([result conformsToType:kHGSTypeFile])
        return [NSArray arrayWithObject:NSFilenamesPboardType];
    if ([result conformsToType:kHGSTypeText])
        return [NSArray arrayWithObject:NSStringPboardType];
    return nil;
}

static id _ServicesObjectForType(const NSString *type, const HGSResult *result)
{
    if ([type isEqual:NSURLPboardType])
        return [result url];
    if ([type isEqual:NSFilenamesPboardType])
        return [NSArray arrayWithObject:[[result url] path]];
    if ([type isEqual:NSStringPboardType])
        return [[result url] absoluteString];
    return nil;
}

static NSDictionary *_ServicesDataForResult(const HGSResult *result)
{
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    for (NSString *type in _ServicesPboardTypesForResult(result))
        [data setObject:_ServicesObjectForType(type, result) forKey:type];
    return data;
}

static CGFloat _ServicesScoreForQuery(const NSDictionary *service, const HGSQuery *query)
{
    return HGSScoreForAbbreviation([HGSTokenizer tokenizeString:[service valueForKeyPath:kServicesEntryNameKeyPath]], [query normalizedQueryString], NULL);
}

static NSString *_ServicesSnippetForName(const NSString *name)
{
    return [NSString stringWithFormat:kServicesSnippetFormat, name];
}

static NSURL *_ServicesURLForName(const NSString *name)
{
    return [NSURL URLWithString:[NSString stringWithFormat:kServicesURLFormat, [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

static HGSAction *_ServicesDefaultAction(void)
{
    return [[HGSExtensionPoint actionsPoint] extensionWithIdentifier:kServicesPerformAction];
}

static NSPredicate *_ServicesPredicateIsNil(void)
{
    return [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForConstantValue:nil]
                                              rightExpression:[NSExpression expressionForKeyPath:kServicesEntrySendTypesKey]
                                                     modifier:NSDirectPredicateModifier
                                                         type:NSEqualToPredicateOperatorType
                                                      options:0];
}

static NSPredicate *_ServicesPredicateAnyIn(const HGSResult *result)
{
    return [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForConstantValue:_ServicesPboardTypesForResult(result)]
                                              rightExpression:[NSExpression expressionForKeyPath:kServicesEntrySendTypesKey]
                                                     modifier:NSAnyPredicateModifier
                                                         type:NSInPredicateOperatorType
                                                      options:0];
}

static NSPredicate *_ServicesPredicateForResult(const HGSResult *result)
{
    if (result == nil) {
        return _ServicesPredicateIsNil();
    }
    return _ServicesPredicateAnyIn(result);
}

static NSArray *_ServicesListForQuery(const HGSQuery *query)
{
    return [CFServiceControllerCopyServicesEntries() filteredArrayUsingPredicate:_ServicesPredicateForResult([query pivotObject])];
}

#pragma mark -
@interface ServicesSource : HGSCallbackSearchSource
- (BOOL) isValidSourceForQuery:(HGSQuery *)query;
- (HGSResult *) resultForService:(NSDictionary *)service pivot:(HGSResult *)pivot score:(CGFloat)score;
- (void) performSearchOperation:(HGSSearchOperation *)operation;
@end

#pragma mark -
@implementation ServicesSource

- (BOOL) isValidSourceForQuery:(HGSQuery *)query
{
    if (![super isValidSourceForQuery:query])
        return NO;
    if ([[query normalizedQueryString] length] == 0)
        return NO;
    return YES;
}

- (HGSResult *) resultForService:(NSDictionary *)service pivot:(HGSResult *)pivot score:(CGFloat)score
{
    NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
    NSString *name = [service valueForKeyPath:kServicesEntryNameKeyPath];
    NSString *path = [service valueForKey:kServicesEntryBundlePathKey];
    [attrs setObject:_ServicesSnippetForName([[NSFileManager defaultManager] displayNameAtPath:path])
              forKey:kHGSObjectAttributeSnippetKey];
    [attrs setObject:[[NSWorkspace sharedWorkspace] iconForFile:path]
              forKey:kHGSObjectAttributeIconKey];
    [attrs setObject:[NSNumber numberWithFloat:score]
              forKey:kHGSObjectAttributeRankKey];
    [attrs setObject:_ServicesDefaultAction()
              forKey:kHGSObjectAttributeDefaultActionKey];
    [attrs setObject:service forKey:kServicesItemKey];
    [attrs setObject:name forKey:kServicesNameKey];
    if (pivot) {
        [attrs setObject:_ServicesDataForResult(pivot) forKey:kServicesDataKey];
    }
    return [HGSResult resultWithURL:_ServicesURLForName(name)
                               name:[name lastPathComponent]
                               type:kServicesItemResultType
                             source:self
                         attributes:attrs];
}

- (void) performSearchOperation:(HGSSearchOperation *)operation
{
    HGSQuery *query = [operation query];
    HGSResult *pivot = [query pivotObject];
    NSMutableArray *results = [NSMutableArray array];
    for (NSDictionary *service in _ServicesListForQuery(query)) {
        CGFloat score = _ServicesScoreForQuery(service, query);
        if (score > 0) {
            [results addObject:[self resultForService:service pivot:pivot score:score]];
        }
    }
    [operation setResults:results];
}

@end
