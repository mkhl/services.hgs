//
//  ServicesAction.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>
#import "Macros.h"

#pragma mark ServiceEntry Keys
extern NSString *kServicesEntryNameKeyPath;
extern NSString *kServicesEntryBundleIdentifierKey;
extern NSString *kServicesEntryBundlePathKey;
extern NSString *kServicesEntryReturnTypesKey;
extern NSString *kServicesEntrySendTypesKey;

#pragma mark HGSResult Keys
extern NSString *kServicesDataKey;
extern NSString *kServicesItemKey;
extern NSString *kServicesNameKey;

#pragma mark HGSResult Types
extern NSString *kServicesItemResultType;

#pragma mark -
@interface ServicesAction : HGSAction
- (BOOL)performWithInfo:(NSDictionary *)info;
@end

#pragma mark -
@implementation ServicesAction

- (void)writeObject:(id)object
           withType:(NSString *)type
       toPasteboard:(NSPasteboard *)pboard
{
  if ([type isEqual:NSURLPboardType]) {
    [object writeToPasteboard:pboard];
  } else if ([type isEqual:NSFilenamesPboardType]) {
    [pboard setPropertyList:object forType:type];
  } else if ([type isEqual:NSStringPboardType]) {
    [pboard setString:object forType:type];
  }
}

- (BOOL)performWithInfo:(NSDictionary *)info
{
  HGSResultArray *objects = [info objectForKey:kHGSActionDirectObjectsKey];
  if (isEmpty(objects))
    return NO;
  NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
  HGSResult *result = [objects lastObject];
  NSDictionary *data = [result valueForKey:kServicesDataKey];
  if (!isEmpty(data)) {
    [pboard declareTypes:[data allKeys] owner:self];
    for (NSString *type in data) {
      [self writeObject:[data objectForKey:type]
               withType:type
           toPasteboard:pboard];
    }
  }
  // TODO(mkhl): We should try to get data form the active application.
  if (!NSPerformService([result valueForKey:kServicesNameKey], pboard))
    return NO;
  // TODO(mkhl): We should handle the data our service might have produced.
  return YES;
}

@end
