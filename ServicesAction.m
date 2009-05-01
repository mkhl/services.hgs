//
//  ServicesAction.m
//
//  Copyright (c) 2009  Martin Kuehl <purl.org/net/mkhl>
//  Licensed under the MIT License.
//

#import <Vermilion/Vermilion.h>

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
- (BOOL) performWithInfo:(NSDictionary *)info;
@end

#pragma mark -
@implementation ServicesAction

- (void) writeObject:(id)object withType:(NSString *)type toPasteboard:(NSPasteboard *)pboard
{
    if ([type isEqual:NSURLPboardType]) {
        [object writeToPasteboard:pboard];
    } else if ([type isEqual:NSFilenamesPboardType]) {
        [pboard setPropertyList:object forType:type];
    } else if ([type isEqual:NSStringPboardType]) {
        [pboard setString:object forType:type];
    }
}

- (BOOL) performWithInfo:(NSDictionary *)info
{
    HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
    if (directObjects == nil)
        return NO;
    HGSResult *result = [directObjects lastObject];
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    NSDictionary *data = [result valueForKey:kServicesDataKey];
    if (data) {
        [pboard declareTypes:[data allKeys] owner:self];
        for (NSString *type in data) {
            [self writeObject:[data objectForKey:type] withType:type toPasteboard:pboard];
        }
    }
    // TODO(mkhl): Without explicit data, we should maybe get some from the
    //   active application (via AXUI)?
    if (!NSPerformService([result valueForKey:kServicesNameKey], pboard))
        return NO;
    // TODO(mkhl): We should handle the data our service might have produced.
    return YES;
}

@end
