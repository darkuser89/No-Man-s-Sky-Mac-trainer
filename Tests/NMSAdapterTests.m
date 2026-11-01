// SPDX-License-Identifier: GPL-3.0-only
#import <Foundation/Foundation.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <libkern/OSByteOrder.h>
#import "NMSAdapter.h"
#import "GameProfile.h"
#import "DemoAdapter.h"
#import "GameBridge.h"
@interface MTReadOnlyFixture : MTDemoAdapter
@end
@implementation MTReadOnlyFixture
- (MTGameContext *)captureContext {MTGameContext *c=[super captureContext];c.readOnly=YES;c.note=@"Nur lesen";return c;}
@end
#include <math.h>
static NSData *thin(cpu_type_t cpu,NSUUID *uuid){
    struct mach_header_64 h={.magic=MH_MAGIC_64,.cputype=cpu,.filetype=MH_EXECUTE,.ncmds=1,.sizeofcmds=sizeof(struct uuid_command)};
    struct uuid_command u={.cmd=LC_UUID,.cmdsize=sizeof(u)};[uuid getUUIDBytes:u.uuid];
    NSMutableData *d=[NSMutableData dataWithBytes:&h length:sizeof(h)];[d appendBytes:&u length:sizeof(u)];return d;
}
void MTNMSRunTests(void){
    // Own-byte fixtures exercise the native edit boundary without a game process.
    uint8_t edit[72]={0},originalEdit[72];uint64_t owner=0x10000;int32_t amount=3,maximum=100,index=-1,choice=3;uint32_t technology=1;
    memcpy(edit,&owner,8);memcpy(edit+8+0x18,&amount,4);memcpy(edit+8+0x20,&maximum,4);memcpy(edit+8+0x24,&technology,4);
    memcpy(edit+56,&owner,8);memcpy(edit+64,&choice,4);memcpy(edit+68,&index,4);memcpy(originalEdit,edit,sizeof(edit));
    NSCAssert(MTNMSPrepareRecharge(edit,sizeof(edit)),@"valid native technology edit accepted");
    int32_t charged=0;memcpy(&charged,edit+8+0x18,4);NSCAssert(charged==100 && !memcmp(edit,originalEdit,8+0x18) && !memcmp(edit+8+0x1c,originalEdit+8+0x1c,72-8-0x1c),@"charging changes only quantity, preserving native identity and handle");
    NSCAssert(!MTNMSPrepareRecharge(edit,71) && !MTNMSPrepareRecharge(NULL,72),@"truncated and missing native edit denied");
    for(int scenario=0;scenario<6;scenario++){
        memcpy(edit,originalEdit,sizeof(edit));
        if(scenario==0)memset(edit,0,8);
        if(scenario==1){float damaged=1;memcpy(edit+8+0x1c,&damaged,4);}
        if(scenario==2){float invalid=NAN;memcpy(edit+8+0x1c,&invalid,4);}
        if(scenario==3){int32_t invalid=101;memcpy(edit+8+0x18,&invalid,4);}
        if(scenario==4){uint32_t product=2;memcpy(edit+8+0x24,&product,4);}
        if(scenario==5){int32_t invalid=33;memcpy(edit+64,&invalid,4);}
        uint8_t before[72];memcpy(before,edit,72);
        NSCAssert(!MTNMSPrepareRecharge(edit,sizeof(edit)) && !memcmp(before,edit,72),@"invalid owner, damaged technology, bad amounts/types/handles do not mutate the edit");
    }
    for(NSInteger i=0;i<MTFeatureCount;i++){
        const MTFeatureInfo *a=MTFeatureInfoAt(i);
        NSCAssert(!(a->key==101 && a->modifiers==1),@"Shift F9 remains exclusively the stop command");
        for(NSInteger j=i+1;j<MTFeatureCount;j++){const MTFeatureInfo *b=MTFeatureInfoAt(j);NSCAssert(a->key!=b->key || a->modifiers!=b->modifiers,@"all feature hotkeys are unique");}
    }
    MTReadOnlyFixture *model=[MTReadOnlyFixture new];MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:model];
    [bridge poll];for(int i=0;i<16;i++)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    [bridge performFeature:MTFeatureHealth];[bridge performFeature:MTFeatureMoney];
    for(int i=0;i<16;i++)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
    NSCAssert(!bridge.state.ready && !bridge.state.features[0].active && [model.values[@0] intValue]==50 && [model.values[@4] intValue]==500,@"read-only context blocks both switches and one-shots through the UI bridge");
    uint8_t flag=0,one=1;MTNMSValue *value=[[MTNMSValue alloc]initWithAddress:&flag size:1];
    NSCAssert(![value applyBytes:&one readOnly:YES] && !flag && !value.ownsValue,@"read-only mode cannot acquire or change native data");
    NSCAssert([value applyBytes:&one readOnly:NO] && flag==1,@"real write is read back");
    NSCAssert([value applyBytes:&one readOnly:NO] && [value releaseValue] && flag==0,@"polling does not replace original baseline");
    float scalar=1,factor=2;MTNMSValue *speed=[[MTNMSValue alloc]initWithAddress:&scalar size:4];
    NSCAssert([speed applyBytes:&factor readOnly:NO] && scalar==2,@"native float representation preserved");
    factor=3;NSCAssert([speed applyBytes:&factor readOnly:NO] && scalar==3 && [speed releaseValue] && scalar==1,@"changing numeric target restores first baseline");
    [speed applyBytes:&factor readOnly:NO];scalar=4;NSCAssert(![speed applyBytes:&factor readOnly:NO] && [speed releaseValue] && scalar==4,@"foreign writes survive both polling and release");
    MTNMSValue *bad=[[MTNMSValue alloc]initWithAddress:(void *)1 size:1];NSCAssert(![bad applyBytes:&one readOnly:NO],@"unmapped data rejected");
    uint32_t sessions[3]={0};NSCAssert(MTNMSSessionKind(YES,NO,sessions)==MTSessionSolo,@"offline idle sessions classified as solo");
    NSCAssert(MTNMSSessionKind(NO,NO,sessions)==MTSessionLoading && MTNMSSessionKind(YES,YES,sessions)==MTSessionNetwork,@"loading is separate from a usable multiplayer-enabled context");
    for(int i=0;i<3;i++){sessions[i]=4;NSCAssert(MTNMSSessionKind(YES,NO,sessions)==MTSessionNetwork,@"every active native lobby remains a usable network context");sessions[i]=UINT32_MAX;NSCAssert(MTNMSSessionKind(YES,NO,sessions)==MTSessionLoading,@"unreadable session context waits rather than guessing ownership");sessions[i]=0;}
    MTNMSAdapter *adapter=[MTNMSAdapter new];
    NSCAssert(![adapter applyFeature:MTFeatureHealth wanted:YES value:0].active && !MTNMSProcessBuildMatches(),@"outside the exact game executable no native effect can be applied");
    NSString *path=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    @try {
        NSUUID *arm=[NSUUID UUID],*intel=[NSUUID UUID];NSData *a=thin(CPU_TYPE_ARM64,arm),*x=thin(CPU_TYPE_X86_64,intel);
        struct fat_header header={.magic=OSSwapHostToBigInt32(FAT_MAGIC),.nfat_arch=OSSwapHostToBigInt32(2)};
        struct fat_arch arch[2]={{.cputype=OSSwapHostToBigInt32(CPU_TYPE_X86_64),.offset=OSSwapHostToBigInt32(4096),.size=OSSwapHostToBigInt32((uint32_t)x.length),.align=OSSwapHostToBigInt32(12)},{.cputype=OSSwapHostToBigInt32(CPU_TYPE_ARM64),.offset=OSSwapHostToBigInt32(8192),.size=OSSwapHostToBigInt32((uint32_t)a.length),.align=OSSwapHostToBigInt32(12)}};
        NSMutableData *fat=[NSMutableData dataWithLength:8192+a.length];memcpy(fat.mutableBytes,&header,sizeof(header));memcpy((uint8_t *)fat.mutableBytes+sizeof(header),arch,sizeof(arch));memcpy((uint8_t *)fat.mutableBytes+4096,x.bytes,x.length);memcpy((uint8_t *)fat.mutableBytes+8192,a.bytes,a.length);[fat writeToFile:path atomically:YES];
        NSCAssert([MTReadExecutableIdentity(path)[@"uuid"] isEqual:arm.UUIDString],@"universal binary selects ARM UUID rather than first Intel UUID");
        arch[1].offset=arch[0].offset;memcpy((uint8_t *)fat.mutableBytes+sizeof(header),arch,sizeof(arch));[fat writeToFile:path atomically:YES];NSCAssert(!MTReadExecutableIdentity(path),@"overlapping universal slices rejected");
        arch[1].offset=OSSwapHostToBigInt32(8192);arch[0].cputype=arch[1].cputype;memcpy((uint8_t *)fat.mutableBytes+sizeof(header),arch,sizeof(arch));[fat writeToFile:path atomically:YES];NSCAssert(!MTReadExecutableIdentity(path),@"ambiguous arm64 identities rejected");
        [x writeToFile:path atomically:YES];NSCAssert(!MTReadExecutableIdentity(path),@"Intel executable cannot enable ARM adapter");
        [[a subdataWithRange:NSMakeRange(0,a.length-1)] writeToFile:path atomically:YES];NSCAssert(!MTReadExecutableIdentity(path),@"truncated slice rejected");
    }@finally{[NSFileManager.defaultManager removeItemAtPath:path error:NULL];}
    puts("NMS synthetic tests passed: read-only, native readback, restoration, foreign writes, session classification, universal ARM identity, malformed slices. No game values tested.");
}
