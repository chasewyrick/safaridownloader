/**
 * This header is generated by class-dump-z 0.1-11p.
 * class-dump-z is Copyright (C) 2009 by KennyTM~, licensed under GPLv3.
 */

#import "WebUI-Structs.h"
#import <Foundation/NSObject.h>


@interface CertificateUtilities : NSObject {
}
+(SecPolicyRef)createSSLPolicyForHost:(id)host client:(BOOL)client;
+(id)identitiesWithPolicy:(SecPolicyRef)policy;
@end
