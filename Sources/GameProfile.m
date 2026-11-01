// SPDX-License-Identifier: GPL-3.0-only
#import "GameProfile.h"
#import <Security/Security.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach-o/fat.h>
#import <libkern/OSByteOrder.h>
#import <mach/machine.h>
#include <limits.h>
#include <sys/stat.h>
static id fail(NSError **error,NSString *reason) {if(error)*error=[NSError errorWithDomain:@"local.mactrainer.profile" code:1 userInfo:@{NSLocalizedDescriptionKey:reason}];return nil;}
static BOOL string(id value) {return [value isKindOfClass:NSString.class] && [value length]>0;}
NSDictionary *MTLoadConfiguration(NSString *path,NSError **error) {
    if(!string(path))return fail(error,@"Konfigurationspfad fehlt.");
    NSData *data=[NSData dataWithContentsOfFile:path];
    if(!data || data.length>1024*1024)return fail(error,@"Konfiguration fehlt oder ist zu groß.");
    id root=[NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if(![root isKindOfClass:NSDictionary.class] || ![root[@"schemaVersion"] isEqual:@1] || ![root[@"app"] isKindOfClass:NSDictionary.class] || ![root[@"profiles"] isKindOfClass:NSArray.class])return fail(error,@"Ungültige Konfigurationsstruktur.");
    for(NSString *key in @[@"name",@"bundleIdentifier",@"version",@"build"])if(!string(root[@"app"][key]))return fail(error,@"App-Metadaten fehlen.");
    NSMutableSet *ids=[NSMutableSet new];
    for(id p in root[@"profiles"]){
        if(![p isKindOfClass:NSDictionary.class] || !string(p[@"id"]) || !string(p[@"name"]) || ![p[@"enabled"] isKindOfClass:NSNumber.class] || [ids containsObject:p[@"id"]])return fail(error,@"Profilkennung fehlt oder ist doppelt.");
        [ids addObject:p[@"id"]];
        if([p[@"enabled"] boolValue]){
            if(!string(p[@"bundleIdentifier"]) || !string(p[@"executable"]) || ![p[@"uuids"] isKindOfClass:NSArray.class] || ![p[@"uuids"] count])return fail(error,@"Aktive Profile benötigen Bundle-ID, Executable und geprüfte UUIDs.");
            if([p[@"executable"] containsString:@"/"])return fail(error,@"Executable muss ein Dateiname sein.");
            for(id uuid in p[@"uuids"])if(!string(uuid) || ![[NSUUID alloc]initWithUUIDString:uuid])return fail(error,@"Ungültige UUID im aktiven Profil.");
            for(NSString *key in @[@"teamIdentifier",@"version"])if(p[key] && ![p[key] isKindOfClass:NSString.class])return fail(error,@"Ungültige Profilmetadaten.");
        }
    }return root;
}
NSDictionary *MTFindProfile(NSDictionary *configuration,NSString *identifier) {for(NSDictionary *p in configuration[@"profiles"])if([p[@"id"] isEqual:identifier])return p;return nil;}
static NSString *uuidInCommands(const uint8_t *bytes,NSUInteger size,uint32_t count) {
    NSUInteger offset=0;NSString *result=nil;
    for(uint32_t i=0;i<count;i++){
        struct load_command c={0};if(offset>size || sizeof(c)>size-offset)return nil;memcpy(&c,bytes+offset,sizeof(c));
        if(c.cmdsize<sizeof(c) || c.cmdsize>size-offset)return nil;
        if(c.cmd==LC_UUID){if(c.cmdsize!=sizeof(struct uuid_command) || result)return nil;struct uuid_command u;memcpy(&u,bytes+offset,sizeof(u));result=[[NSUUID alloc]initWithUUIDBytes:u.uuid].UUIDString;}
        offset+=c.cmdsize;
    }return offset==size ? result : nil;
}
// Read the exact arm64 slice; never accept an x86 UUID as an arm64 identity.
NSDictionary *MTReadExecutableIdentity(NSString *path) {
    NSFileHandle *file=[NSFileHandle fileHandleForReadingFromURL:[NSURL fileURLWithPath:path] error:NULL];if(!file)return nil;
    NSDictionary *result=nil;
    @try {
        unsigned long long length=0;
        [file seekToEndReturningOffset:&length error:NULL];
        [file seekToOffset:0 error:NULL];
        NSData *prefix=[file readDataUpToLength:sizeof(struct mach_header_64) error:NULL];
        uint32_t magic=0;if(prefix.length>=4)memcpy(&magic,prefix.bytes,4);
        uint64_t sliceOffset=0,sliceLength=length;
        BOOL valid=YES;
        if(magic==FAT_CIGAM || magic==FAT_CIGAM_64){
            struct fat_header header={0};if(prefix.length<sizeof(header))valid=NO;
            else memcpy(&header,prefix.bytes,sizeof(header));
            uint32_t count=OSSwapBigToHostInt32(header.nfat_arch);
            BOOL wide=magic==FAT_CIGAM_64;
            NSUInteger stride=wide ? sizeof(struct fat_arch_64) : sizeof(struct fat_arch);
            uint64_t tableEnd=sizeof(header)+(uint64_t)count*stride;
            if(!count || count>32 || tableEnd>length)valid=NO;
            if(valid){
                [file seekToOffset:sizeof(header) error:NULL];
                NSData *table=[file readDataUpToLength:count*stride error:NULL];
                valid=table.length==count*stride;NSUInteger matches=0;
                uint64_t offsets[32]={0},sizes[32]={0};
                for(uint32_t i=0;valid && i<count;i++){
                    uint32_t cpu=0,subtype=0,align=0;uint64_t offset=0,size=0;
                    if(wide){struct fat_arch_64 arch;memcpy(&arch,(const uint8_t *)table.bytes+i*stride,stride);cpu=OSSwapBigToHostInt32(arch.cputype);subtype=OSSwapBigToHostInt32(arch.cpusubtype);offset=OSSwapBigToHostInt64(arch.offset);size=OSSwapBigToHostInt64(arch.size);align=OSSwapBigToHostInt32(arch.align);}
                    else {struct fat_arch arch;memcpy(&arch,(const uint8_t *)table.bytes+i*stride,stride);cpu=OSSwapBigToHostInt32(arch.cputype);subtype=OSSwapBigToHostInt32(arch.cpusubtype);offset=OSSwapBigToHostInt32(arch.offset);size=OSSwapBigToHostInt32(arch.size);align=OSSwapBigToHostInt32(arch.align);}
                    if(offset<tableEnd || size<sizeof(struct mach_header_64) || offset>length || size>length-offset || align>31 || (offset & ((UINT64_C(1)<<align)-1)))valid=NO;
                    for(uint32_t j=0;valid && j<i;j++)if(offset<offsets[j]+sizes[j] && offsets[j]<offset+size)valid=NO;
                    offsets[i]=offset;sizes[i]=size;
                    if(cpu==CPU_TYPE_ARM64){matches++;if(subtype!=CPU_SUBTYPE_ARM64_ALL)valid=NO;sliceOffset=offset;sliceLength=size;}
                }
                if(matches!=1)valid=NO;
            }
        }else if(magic!=MH_MAGIC_64)valid=NO;
        if(valid){
            [file seekToOffset:sliceOffset error:NULL];
            NSData *data=[file readDataUpToLength:sizeof(struct mach_header_64) error:NULL];struct mach_header_64 h={0};
            if(data.length==sizeof(h))memcpy(&h,data.bytes,sizeof(h));
            if(h.magic==MH_MAGIC_64 && h.cputype==CPU_TYPE_ARM64 && h.cpusubtype==CPU_SUBTYPE_ARM64_ALL && h.filetype==MH_EXECUTE && h.sizeofcmds<=1024*1024 && h.ncmds<=4096 && sliceLength>=sizeof(h) && h.sizeofcmds<=sliceLength-sizeof(h)){
                NSData *commands=[file readDataUpToLength:h.sizeofcmds error:NULL];
                NSString *uuid=commands.length==h.sizeofcmds ? uuidInCommands(commands.bytes,commands.length,h.ncmds) : nil;
                if(uuid)result=@{@"uuid":uuid,@"architecture":@"arm64"};
            }
        }
    } @catch(NSException *exception){(void)exception;}
    [file closeAndReturnError:NULL];return result;
}
NSDictionary *MTInspectGame(NSString *path,NSDictionary *profile,NSError **error) {
    if(![profile[@"enabled"] boolValue] || !path.isAbsolutePath)return fail(error,@"Profil ist nicht freigegeben oder Pfad fehlt.");
    NSString *canonical=path.stringByStandardizingPath.stringByResolvingSymlinksInPath;
    NSDictionary *info=[NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:[canonical stringByAppendingPathComponent:@"Contents/Info.plist"]] error:NULL];
    if(![info[@"CFBundleIdentifier"] isEqual:profile[@"bundleIdentifier"]] || ![info[@"CFBundleExecutable"] isEqual:profile[@"executable"]])return fail(error,@"Bundle-ID oder Executable passt nicht zum Profil.");
    NSString *executable=[canonical stringByAppendingPathComponent:[@"Contents/MacOS" stringByAppendingPathComponent:profile[@"executable"]]];
    NSDictionary *identity=MTReadExecutableIdentity(executable);
    if(!identity || ![profile[@"uuids"] containsObject:identity[@"uuid"]])return fail(error,@"Spiel-Build/Architektur nicht freigegeben. Nur der geprüfte arm64-Build ist erlaubt.");
    if([profile[@"version"] length] && ![info[@"CFBundleShortVersionString"] isEqual:profile[@"version"]])return fail(error,@"Spielversion weicht vom Profil ab.");
    SecStaticCodeRef code=NULL;OSStatus status=SecStaticCodeCreateWithPath((__bridge CFURLRef)[NSURL fileURLWithPath:canonical],kSecCSDefaultFlags,&code);
    if(!status)status=SecStaticCodeCheckValidity(code,kSecCSCheckAllArchitectures|kSecCSDoNotValidateResources,NULL);
    if(!status && [profile[@"teamIdentifier"] length]){
        CFDictionaryRef details=NULL;status=SecCodeCopySigningInformation(code,kSecCSSigningInformation,&details);
        NSDictionary *signing=CFBridgingRelease(details);
        if(!status && ![signing[(__bridge NSString *)kSecCodeInfoTeamIdentifier] isEqual:profile[@"teamIdentifier"]])status=errSecCSReqFailed;
    }
    if(code)CFRelease(code);
    if(status)return fail(error,[NSString stringWithFormat:@"Originalsignatur nicht bestätigt (%d).",(int)status]);
    return @{@"path":canonical,@"executable":executable,@"uuid":identity[@"uuid"]};
}
BOOL MTCurrentProcessMatches(NSDictionary *profile,NSString *target) {
    if(![profile[@"enabled"] boolValue] || !target.isAbsolutePath)return NO;
    if(![NSBundle.mainBundle.bundleIdentifier isEqual:profile[@"bundleIdentifier"]])return NO;
    uint32_t size=PATH_MAX;char raw[PATH_MAX],actual[PATH_MAX],expected[PATH_MAX];
    if(_NSGetExecutablePath(raw,&size) || !realpath(raw,actual) || !realpath(target.fileSystemRepresentation,expected))return NO;
    // Steam may spell the same path in uppercase on a case-insensitive volume.
    // Compare actual filesystem identity, never accept a different executable.
    struct stat actualInfo,expectedInfo;
    if(stat(actual,&actualInfo) || stat(expected,&expectedInfo) || actualInfo.st_dev!=expectedInfo.st_dev || actualInfo.st_ino!=expectedInfo.st_ino)return NO;
    if([[NSString stringWithUTF8String:actual].lastPathComponent caseInsensitiveCompare:profile[@"executable"]]!=NSOrderedSame)return NO;
    for(uint32_t i=0;i<_dyld_image_count();i++){
        const struct mach_header_64 *h=(const void *)_dyld_get_image_header(i);
        if(h && h->filetype==MH_EXECUTE){
            if(h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64 || h->sizeofcmds>1024*1024 || h->ncmds>4096)return NO;
            NSString *uuid=uuidInCommands((const uint8_t *)(h+1),h->sizeofcmds,h->ncmds);
            return uuid && [profile[@"uuids"] containsObject:uuid];
        }
    }return NO;
}
