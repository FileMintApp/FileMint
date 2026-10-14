# P0.5 isolated metadata probe source

Evidence attachment for [the P0.5 report](2026-10-14-batch-rename-p05.md), not a product classifier or registered QA application.

The following source is the exact one-shot Objective-C CLI used on 2026-10-14.
SHA-256 of the extracted UTF-8 source, including its final newline:
`8747fa4021a439acf18ecb78fefbd5dcc1a4a09c07cc0d44d6cbcce30d10d414`.

Only execute against newly created isolated fixtures. The caller creates an empty
`ordinary-file`, an empty `ordinary-directory`, and `symlink-control` pointing to
`ordinary-file`; `missing-control` must not exist. The observed run used an owned
0700 directory under `/private/tmp`. No cloud, NAS or user-content input was used.

Compile the extracted source as `probe.m` with:

```sh
xcrun clang -fobjc-arc -fblocks -Wall -Wextra -Werror -mmacosx-version-min=13.0 -framework Foundation -framework FileProvider probe.m -o probe
./probe /absolute/path/to/owned-fixture-directory
```

The deployment flag is not macOS 13 runtime evidence. This CLI has no App Sandbox
entitlement or File Provider identity; the first recorded run used Codex's command
sandbox and the second a command-scoped approved host execution. Neither is a
signed FileMint sandbox test. Materialization policy is changed only for this
process and restored at exit. No global policy or TCC state is changed.

`app_sandbox_entitlement`, `metadata_only` and `unmanaged_classification` are
source labels, not runtime detections or classifier assertions. The other JSON
values are API observations. `identity_and_size_unchanged` compares only device,
inode, size and flags. Five-second callback deadlines do not bound synchronous
Foundation/kernel calls; the observed local calls completed, but managed-input
responsiveness and side effects remain untested.

```objective-c
#import <Foundation/Foundation.h>
#import <FileProvider/FileProvider.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/attr.h>
#include <sys/resource.h>
#include <errno.h>

static NSDictionary *ErrorCode(NSError *error) {
    return error ? @{ @"domain": error.domain, @"code": @(error.code) } : @{};
}

static NSDictionary *Await(void (^start)(void (^)(NSDictionary *))) {
    NSLock *lock = [NSLock new];
    __block NSDictionary *result = nil;
    start(^(NSDictionary *value) {
        [lock lock]; result = [value copy]; [lock unlock];
    });
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
    while ([deadline timeIntervalSinceNow] > 0) {
        [lock lock]; NSDictionary *snapshot = result; [lock unlock];
        if (snapshot) return snapshot;
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                               beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
    return @{ @"status": @"timeout" };
}

static NSDictionary *Probe(NSURL *url, NSString *label) {
    NSMutableDictionary *row = [@{ @"fixture": label } mutableCopy];
    struct stat before = {0};
    int rc = lstat(url.fileSystemRepresentation, &before);
    row[@"lstat"] = rc ? @{ @"errno": @(errno) } : @{
        @"mode_type": @(before.st_mode & S_IFMT), @"dataless": @((before.st_flags & SF_DATALESS) != 0),
        @"flags": @(before.st_flags), @"size": @(before.st_size)
    };
    if (rc || !(S_ISREG(before.st_mode) || S_ISDIR(before.st_mode))) {
        row[@"eligibility"] = @"rejected-before-provider-query";
        return row;
    }
    NSArray<NSURLResourceKey> *keys = @[
        NSURLIsRegularFileKey, NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey,
        NSURLIsAliasFileKey, NSURLIsPackageKey, NSURLIsWritableKey,
        NSURLIsUbiquitousItemKey, NSURLUbiquitousItemDownloadingStatusKey,
        NSURLUbiquitousItemIsExcludedFromSyncKey,
        NSURLVolumeIsLocalKey, NSURLVolumeIsReadOnlyKey,
        NSURLVolumeSupportsCaseSensitiveNamesKey, NSURLVolumeSupportsExclusiveRenamingKey,
        NSURLVolumeSupportsPersistentIDsKey
    ];
    NSMutableDictionary *resources = [NSMutableDictionary new];
    for (NSURLResourceKey key in keys) {
        id value = nil; NSError *error = nil;
        BOOL ok = [url getResourceValue:&value forKey:key error:&error];
        resources[key] = @{ @"ok": @(ok), @"value": value ?: [NSNull null], @"error": ErrorCode(error) };
    }
    row[@"resources"] = resources;
    struct statfs fs = {0};
    rc = statfs(url.fileSystemRepresentation, &fs);
    row[@"statfs"] = rc ? @{ @"errno": @(errno) } : @{
        @"type": @(fs.f_fstypename), @"local": @((fs.f_flags & MNT_LOCAL) != 0),
        @"readonly": @((fs.f_flags & MNT_RDONLY) != 0)
    };
    struct attrlist attrs = {0};
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = ATTR_CMN_RETURNED_ATTRS;
    attrs.forkattr = ATTR_CMNEXT_EXT_FLAGS;
    struct { uint32_t length; attribute_set_t returned; uint64_t flags; } output = {0};
    rc = getattrlist(url.fileSystemRepresentation, &attrs, &output, sizeof(output),
                     FSOPT_NOFOLLOW | FSOPT_ATTR_CMN_EXTENDED);
    BOOL valid = !rc && output.length >= sizeof(output) && (output.returned.forkattr & ATTR_CMNEXT_EXT_FLAGS);
    row[@"extended_flags"] = @{ @"rc": @(rc), @"errno": rc ? @(errno) : @0,
        @"returned": @(valid), @"value": valid ? @(output.flags) : [NSNull null],
        @"sync_root": valid ? @((output.flags & EF_IS_SYNC_ROOT) != 0) : [NSNull null] };
    row[@"services"] = Await(^(void (^done)(NSDictionary *)) {
        [[NSFileManager defaultManager] getFileProviderServicesForItemAtURL:url
            completionHandler:^(NSDictionary<NSFileProviderServiceName, NSFileProviderService *> *services, NSError *error) {
                done(@{ @"status": @"callback", @"dictionary_present": @(services != nil),
                        @"count": @(services.count), @"error": ErrorCode(error) });
            }];
    });
    row[@"own_provider_lookup"] = Await(^(void (^done)(NSDictionary *)) {
        [NSFileProviderManager getIdentifierForUserVisibleFileAtURL:url
            completionHandler:^(NSFileProviderItemIdentifier item, NSFileProviderDomainIdentifier domain, NSError *error) {
                done(@{ @"status": @"callback", @"item_present": @(item != nil),
                        @"domain_present": @(domain != nil), @"error": ErrorCode(error) });
            }];
    });
    struct stat after = {0};
    rc = lstat(url.fileSystemRepresentation, &after);
    row[@"identity_and_size_unchanged"] = @(!rc && before.st_dev == after.st_dev &&
        before.st_ino == after.st_ino && before.st_size == after.st_size && before.st_flags == after.st_flags);
    row[@"unmanaged_classification"] = @"unknown: no proven cross-provider predicate";
    return row;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) return 64;
        int originalPolicy = getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS);
        int policyRC = setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS,
                                     IOPOL_MATERIALIZE_DATALESS_FILES_OFF);
        int policyError = policyRC ? errno : 0;
        NSMutableDictionary *report = [@{
            @"schema": @1, @"runtime": NSProcessInfo.processInfo.operatingSystemVersionString,
            @"app_sandbox_entitlement": @NO, @"metadata_only": @YES,
            @"materialization_policy": @{ @"original": @(originalPolicy), @"set_rc": @(policyRC),
                @"errno": @(policyError), @"observed": @(getiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES, IOPOL_SCOPE_PROCESS)) }
        } mutableCopy];
        if (policyRC) {
            report[@"probe_status"] = @"blocked: cannot disable materialization";
        } else {
            NSURL *root = [NSURL fileURLWithFileSystemRepresentation:argv[1] isDirectory:YES relativeToURL:nil];
            NSMutableArray *rows = [NSMutableArray new];
            for (NSString *name in @[@"ordinary-file", @"ordinary-directory", @"missing-control", @"symlink-control"])
                [rows addObject:Probe([root URLByAppendingPathComponent:name], name)];
            report[@"samples"] = rows;
            report[@"probe_status"] = @"completed";
        }
        int restoreRC = originalPolicy >= 0 ? setiopolicy_np(IOPOL_TYPE_VFS_MATERIALIZE_DATALESS_FILES,
            IOPOL_SCOPE_PROCESS, originalPolicy) : -1;
        report[@"policy_restore_rc"] = @(restoreRC);
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:&error];
        if (!data) return 70;
        fwrite(data.bytes, 1, data.length, stdout); fputc('\n', stdout);
        return policyRC ? 2 : 0;
    }
}
```
