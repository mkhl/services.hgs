//
//  ServicesSource.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>
#import "Macros.h"

#pragma mark ServiceEntry Keys
NSString *const kServicesEntryNameKeyPath = @"NSMenuItem.default";
NSString *const kServicesEntryBundleIdentifierKey = @"NSBundleIdentifier";
NSString *const kServicesEntryBundlePathKey = @"NSBundlePath";
NSString *const kServicesEntryReturnTypesKey = @"NSReturnTypes";
NSString *const kServicesEntrySendTypesKey = @"NSSendTypes";

#pragma mark HGSResult Keys
NSString *const kServicesDataKey = @"ServicesData";
NSString *const kServicesItemKey = @"ServicesItem";
NSString *const kServicesNameKey = @"ServicesName";

#pragma mark HGSResult Types
NSString *const kServicesItemResultType = @"service";

#pragma mark Static Data
static NSString *const kServicesURLFormat = @"qsb-service://%@";
static NSString *const kServicesSnippetFormat = @"A service of %@";
static NSString *const kServicesPerformAction
  = @"org.purl.net.mkhl.services.action.perform";

#pragma mark -
#pragma mark List of Services
NSArray *CFServiceControllerCopyServicesEntries(void);

static NSArray *_ServicesList(void)
{
  return [CFServiceControllerCopyServicesEntries() autorelease];
}

#pragma mark -
#pragma mark Result representing the Service
static NSString *_ServicesSnippetForName(const NSString *name)
{
  return [NSString stringWithFormat:kServicesSnippetFormat, name];
}

static NSURL *_ServicesURLForName(const NSString *name)
{
  NSString *escaped
    = [name stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  NSString *uri = [NSString stringWithFormat:kServicesURLFormat, escaped];
  return [NSURL URLWithString:uri];
}

static HGSAction *_ServicesDefaultAction(void)
{
  HGSExtensionPoint *actions = [HGSExtensionPoint actionsPoint];
  return [actions extensionWithIdentifier:kServicesPerformAction];
}

static HGSResult *_ServicesResultWithAttributes(HGSResult *result, NSDictionary *attrs)
{
  // TODO: For compatibility with old Release.
  return [HGSResult resultWithURL:[result url]
                             name:[result displayName]
                             type:[result type]
                           source:[result source]
                       attributes:attrs];
}

#pragma mark -
#pragma mark Map Pboard types to data
static NSArray *_ServicesPboardTypesForResult(const HGSResult *result)
{
  if ([result conformsToType:kHGSTypeWebpage])
    return NSARRAY(NSURLPboardType);
  if ([result conformsToType:kHGSTypeFile])
    return NSARRAY(NSFilenamesPboardType);
  if ([result conformsToType:kHGSTypeText])
    return NSARRAY(NSStringPboardType);
  return nil;
}

static id _ServicesObjectForType(const NSString *type, const HGSResult *result)
{
  if ([type isEqual:NSURLPboardType])
    return [result url];
  if ([type isEqual:NSFilenamesPboardType])
    return NSARRAY([result filePath]);
  if ([type isEqual:NSStringPboardType])
    return [result displayName];
  return nil;
}

static NSDictionary *_ServicesDataForResult(const HGSResult *result)
{
  NSMutableDictionary *data = [NSMutableDictionary dictionary];
  for (NSString *type in _ServicesPboardTypesForResult(result))
    [data setObject:_ServicesObjectForType(type, result) forKey:type];
  return data;
}

#pragma mark -
#pragma mark Predicate for compatibility with the Pivot
static NSExpression *_ServicesExpressionSendTypes(void) {
  NSString *keyPath= [NSString stringWithFormat:@"%@.%@",
                      kServicesItemKey, kServicesEntrySendTypesKey];
  return [NSExpression expressionForKeyPath:keyPath];
}

static NSPredicate *_ServicesPredicateAcceptsNil(void)
{
  NSExpression *empty = [NSExpression expressionForConstantValue:nil];
  NSExpression *sendTypes = _ServicesExpressionSendTypes();
  return [NSComparisonPredicate
          predicateWithLeftExpression:empty
          rightExpression:sendTypes
          modifier:NSDirectPredicateModifier
          type:NSEqualToPredicateOperatorType
          options:0];
}

static NSPredicate *_ServicesPredicateAcceptsAny(const NSArray *types)
{
  NSExpression *givenTypes = [NSExpression expressionForConstantValue:types];
  NSExpression *sendTypes = _ServicesExpressionSendTypes();
  return [NSComparisonPredicate
          predicateWithLeftExpression:givenTypes
          rightExpression:sendTypes
          modifier:NSAnyPredicateModifier
          type:NSInPredicateOperatorType
          options:0];
}

static NSPredicate *_ServicesPredicateForPivot(const HGSResult *pivot)
{
  if (pivot == nil)
    return _ServicesPredicateAcceptsNil();
  return _ServicesPredicateAcceptsAny(_ServicesPboardTypesForResult(pivot));
}

#pragma mark -
@interface ServicesSource : HGSMemorySearchSource
- (void)recacheContents;
- (void)recacheContentsAfterDelay:(NSTimeInterval)delay;
- (void)indexResultForService:(NSDictionary *)service;
- (BOOL)isValidSourceForQuery:(HGSQuery *)query;
- (void)processMatchingResults:(NSMutableArray*)results
                      forQuery:(HGSQuery *)query;
@end

#pragma mark -
@implementation ServicesSource

- (id)initWithConfiguration:(NSDictionary *)configuration
{
  self = [super initWithConfiguration:configuration];
  if (self == nil)
    return nil;
  if ([self loadResultsCache])
    [self recacheContentsAfterDelay:10.0];
  else
    [self recacheContents];
  return self;
}

#pragma mark -
#pragma mark Indexing Results
- (void)recacheContentsAfterDelay:(NSTimeInterval)delay
{
  [self performSelector:@selector(recacheContents)
             withObject:nil
             afterDelay:delay];
}

- (void)recacheContents
{
  [self clearResultIndex];
  for (NSDictionary *service in _ServicesList())
    [self indexResultForService:service];
  [self recacheContentsAfterDelay:60.0];
}

- (void)indexResultForService:(NSDictionary *)service
{
  NSString *name = [service valueForKeyPath:kServicesEntryNameKeyPath];
  if (isEmpty(name)) {
    HGSLogDebug(@"%@: Skipping unnamed Service: %@", self, service);
    return;
  }
  NSString *path = [service valueForKey:kServicesEntryBundlePathKey];
  NSString *snip = [[NSFileManager defaultManager] displayNameAtPath:path];
  NSMutableDictionary *attrs = [NSMutableDictionary dictionary];
  [attrs setObject:_ServicesSnippetForName(snip)
            forKey:kHGSObjectAttributeSnippetKey];
  [attrs setObject:[[NSWorkspace sharedWorkspace] iconForFile:path]
            forKey:kHGSObjectAttributeIconKey];
  [attrs setObject:_ServicesDefaultAction()
            forKey:kHGSObjectAttributeDefaultActionKey];
  [attrs setObject:service forKey:kServicesItemKey];
  [attrs setObject:name forKey:kServicesNameKey];
  [self indexResult:[HGSResult resultWithURL:_ServicesURLForName(name)
                                        name:[name lastPathComponent]
                                        type:kServicesItemResultType
                                      source:self
                                  attributes:attrs]];
}

#pragma mark -
#pragma mark Procesing Queries
- (BOOL)isValidSourceForQuery:(HGSQuery *)query
{
  if (![super isValidSourceForQuery:query])
    return NO;
  if (isEmpty([query normalizedQueryString]))
    return NO;
  return YES;
}

- (void)processMatchingResults:(NSMutableArray*)results
                      forQuery:(HGSQuery *)query
{
  HGSResult *pivot = [query pivotObject];
  [results filterUsingPredicate:_ServicesPredicateForPivot(pivot)];
  if (pivot) {
    NSMutableArray *filtered = [NSMutableArray array];
    NSDictionary *data = _ServicesDataForResult(pivot);
    NSDictionary *attrs = NSDICT(data, kServicesDataKey);
    for (HGSResult *result in results)
      [filtered addObject:_ServicesResultWithAttributes(result, attrs)];
    [results setArray:filtered];
  }
}

@end
