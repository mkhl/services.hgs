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
extern NSString *kServicesDataResultType;
extern NSString *kServicesItemResultType;

#pragma mark -
@interface ServicesAction : HGSAction
- (BOOL) performWithInfo:(NSDictionary *)info;
@end

#pragma mark -
@implementation ServicesAction

- (BOOL) performWithInfo:(NSDictionary *)info
{
    HGSResultArray *directObjects = [info objectForKey:kHGSActionDirectObjectsKey];
    if (directObjects == nil)
        return NO;
    HGSResult *result = [directObjects lastObject];
    NSString *name = [result valueForKey:kServicesNameKey];
    NSString *data = [result valueForKey:kServicesDataKey];
    NSPasteboard *pboard = [NSPasteboard pasteboardWithUniqueName];
    // TODO(mkhl): None of this handles other data types yet.
    //   Maybe wait for NSPasteboard handling to be finished?
    if ([[result type] isEqual:kServicesDataResultType]) {
        [pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
        [pboard setString:data forType:NSStringPboardType];
    }
    // TODO(mkhl): Without explicit data, we should maybe get some from the
    //   active application (via AXUI)?
    if (!NSPerformService(name, pboard))
        return NO;
    // TODO(mkhl): We should handle the data our service might have produced.
    return YES;
}

@end
