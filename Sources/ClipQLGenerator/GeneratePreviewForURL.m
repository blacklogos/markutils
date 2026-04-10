#import <CoreFoundation/CoreFoundation.h>
#import <CoreFoundation/CFPlugInCOM.h>
#import <CoreServices/CoreServices.h>
#import <QuickLook/QuickLook.h>
#import <Foundation/Foundation.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// ============================================================================
// Clip Markdown Quick Look Generator
// Renders .md files as styled HTML when pressing Space in Finder.
// ============================================================================

// MARK: - Markdown → HTML (minimal, self-contained)

static NSString *parseInline(NSString *text) {
    NSMutableString *result = [text mutableCopy];

    // Links: [text](url)
    NSRegularExpression *linkRe = [NSRegularExpression regularExpressionWithPattern:@"\\[([^\\]]+)\\]\\(([^)]+)\\)" options:0 error:nil];
    [linkRe replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"<a href=\"$2\">$1</a>"];

    // Bold: **text**
    NSRegularExpression *boldRe = [NSRegularExpression regularExpressionWithPattern:@"\\*\\*(.+?)\\*\\*" options:0 error:nil];
    [boldRe replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"<strong>$1</strong>"];

    // Italic: *text*
    NSRegularExpression *italicRe = [NSRegularExpression regularExpressionWithPattern:@"(?<![\\w*])\\*([^*]+?)\\*(?![\\w*])" options:0 error:nil];
    [italicRe replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"<em>$1</em>"];

    // Code: `text`
    NSRegularExpression *codeRe = [NSRegularExpression regularExpressionWithPattern:@"`([^`]+)`" options:0 error:nil];
    [codeRe replaceMatchesInString:result options:0 range:NSMakeRange(0, result.length) withTemplate:@"<code>$1</code>"];

    return result;
}

static NSString *markdownToHTML(NSString *markdown) {
    NSMutableString *html = [NSMutableString string];
    NSArray *lines = [markdown componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    BOOL inParagraph = NO;
    BOOL inList = NO;

    for (NSString *rawLine in lines) {
        NSString *trimmed = [rawLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        // Empty line closes blocks
        if (trimmed.length == 0) {
            if (inParagraph) { [html appendString:@"</p>\n"]; inParagraph = NO; }
            if (inList) { [html appendString:@"</ul>\n"]; inList = NO; }
            continue;
        }

        // Horizontal rule
        if ([trimmed isEqualToString:@"---"] || [trimmed isEqualToString:@"***"] || [trimmed isEqualToString:@"___"]) {
            if (inParagraph) { [html appendString:@"</p>\n"]; inParagraph = NO; }
            if (inList) { [html appendString:@"</ul>\n"]; inList = NO; }
            [html appendString:@"<hr />\n"];
            continue;
        }

        // Headers
        if ([trimmed hasPrefix:@"#"]) {
            if (inParagraph) { [html appendString:@"</p>\n"]; inParagraph = NO; }
            if (inList) { [html appendString:@"</ul>\n"]; inList = NO; }
            int level = 0;
            while (level < (int)trimmed.length && [trimmed characterAtIndex:level] == '#') level++;
            NSString *content = [[trimmed substringFromIndex:level] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [html appendFormat:@"<h%d>%@</h%d>\n", level, parseInline(content), level];
            continue;
        }

        // Blockquote
        if ([trimmed hasPrefix:@">"]) {
            if (inParagraph) { [html appendString:@"</p>\n"]; inParagraph = NO; }
            if (inList) { [html appendString:@"</ul>\n"]; inList = NO; }
            NSString *content = [trimmed hasPrefix:@"> "] ? [trimmed substringFromIndex:2] : [trimmed substringFromIndex:1];
            [html appendFormat:@"<blockquote><p>%@</p></blockquote>\n", parseInline(content)];
            continue;
        }

        // List items
        if ([trimmed hasPrefix:@"- "] || [trimmed hasPrefix:@"* "]) {
            if (inParagraph) { [html appendString:@"</p>\n"]; inParagraph = NO; }
            if (!inList) { [html appendString:@"<ul>\n"]; inList = YES; }
            [html appendFormat:@"<li>%@</li>\n", parseInline([trimmed substringFromIndex:2])];
            continue;
        }

        // Paragraphs
        if (inList) { [html appendString:@"</ul>\n"]; inList = NO; }
        if (!inParagraph) { [html appendString:@"<p>"]; inParagraph = YES; } else { [html appendString:@" "]; }
        [html appendString:parseInline(trimmed)];
    }

    if (inParagraph) [html appendString:@"</p>"];
    if (inList) [html appendString:@"</ul>"];
    return html;
}

// MARK: - Quick Look Generator Entry Point

OSStatus GeneratePreviewForURL(void *thisInterface, QLPreviewRequestRef preview,
                                CFURLRef url, CFStringRef contentTypeUTI,
                                CFDictionaryRef options) {
    @autoreleasepool {
        if (QLPreviewRequestIsCancelled(preview)) return noErr;

        NSError *error = nil;
        NSString *markdown = [NSString stringWithContentsOfURL:(__bridge NSURL *)url
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
        if (!markdown) return noErr;

        NSString *bodyHTML = markdownToHTML(markdown);

        NSString *fullHTML = [NSString stringWithFormat:@
            "<!DOCTYPE html>"
            "<html><head><meta charset='utf-8'><style>"
            ":root { color-scheme: light dark; "
            "  --bg: #FAFAFA; --fg: #2C2C2C; --fg2: #8A8078; --accent: #C47D4E; "
            "  --border: rgba(160,140,120,0.2); --code-bg: rgba(160,140,120,0.12); "
            "  --th-bg: rgba(160,140,120,0.1); }"
            "@media (prefers-color-scheme: dark) { :root { "
            "  --bg: #1E1E1E; --fg: #E8E0D8; --fg2: #8A8078; --accent: #D4956A; "
            "  --border: rgba(160,140,120,0.18); --code-bg: rgba(160,140,120,0.1); "
            "  --th-bg: rgba(160,140,120,0.08); }}"
            "body { font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif; "
            "  font-size: 14px; line-height: 1.7; padding: 24px 32px; margin: 0; "
            "  color: var(--fg); background: var(--bg); }"
            "h1,h2,h3,h4 { font-weight: 600; color: var(--fg); }"
            "h1 { font-size: 1.75em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; }"
            "h2 { font-size: 1.35em; margin: 0.8em 0 0.4em; border-bottom: 1px solid var(--border); padding-bottom: 0.2em; }"
            "h3 { font-size: 1.1em; margin: 0.6em 0 0.3em; }"
            "p { margin: 0.5em 0; }"
            "ul,ol { padding-left: 1.5em; margin: 0.4em 0; }"
            "li { margin: 0.2em 0; }"
            "a { color: var(--accent); text-decoration: none; }"
            "code { font-family: 'SF Mono', Menlo, monospace; font-size: 0.88em; "
            "  padding: 0.15em 0.4em; border-radius: 3px; background: var(--code-bg); }"
            "pre { padding: 12px; border-radius: 6px; background: var(--code-bg); overflow-x: auto; }"
            "pre code { padding: 0; background: none; }"
            "blockquote { margin: 0.5em 0; padding: 0.3em 1em; "
            "  border-left: 3px solid var(--accent); color: var(--fg2); }"
            "hr { border: none; border-top: 1px solid var(--border); margin: 1em 0; }"
            "strong { font-weight: 700; }"
            "table { border-collapse: collapse; width: 100%%; margin: 0.6em 0; font-size: 0.94em; }"
            "th,td { border: 1px solid var(--border); padding: 6px 12px; text-align: left; }"
            "th { background: var(--th-bg); font-weight: 600; }"
            ".clip-footer { margin-top: 2em; padding-top: 0.8em; "
            "  border-top: 1px solid var(--border); text-align: center; "
            "  font-size: 0.75em; color: var(--fg2); }"
            "</style></head>"
            "<body>%@<div class='clip-footer'>MD Preview by Clip</div></body></html>",
            bodyHTML];

        CFDictionaryRef properties = (__bridge CFDictionaryRef)@{
            (__bridge NSString *)kQLPreviewPropertyTextEncodingNameKey: @"UTF-8",
            (__bridge NSString *)kQLPreviewPropertyMIMETypeKey: @"text/html",
        };

        QLPreviewRequestSetDataRepresentation(preview,
            (__bridge CFDataRef)[fullHTML dataUsingEncoding:NSUTF8StringEncoding],
            kUTTypeHTML, properties);
    }
    return noErr;
}

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail,
                                  CFURLRef url, CFStringRef contentTypeUTI,
                                  CFDictionaryRef options, CGSize maxSize) {
    return noErr; // No thumbnail generation
}

void CancelPreviewGeneration(void *thisInterface, QLPreviewRequestRef preview) {}
void CancelThumbnailGeneration(void *thisInterface, QLThumbnailRequestRef thumbnail) {}

// MARK: - CFPlugin Factory

// UUID for this factory (unique to Clip's QL generator)
#define PLUGIN_FACTORY_UUID CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("A1B2C3D4-E5F6-7890-ABCD-EF1234567890"))

typedef struct {
    void *_reserved;
    HRESULT (*QueryInterface)(void *, REFIID, LPVOID *);
    ULONG (*AddRef)(void *);
    ULONG (*Release)(void *);
    // QL Generator callbacks
    OSStatus (*GenerateThumbnailForURL)(void *, QLThumbnailRequestRef, CFURLRef, CFStringRef, CFDictionaryRef, CGSize);
    void (*CancelThumbnailGeneration)(void *, QLThumbnailRequestRef);
    OSStatus (*GeneratePreviewForURL)(void *, QLPreviewRequestRef, CFURLRef, CFStringRef, CFDictionaryRef);
    void (*CancelPreviewGeneration)(void *, QLPreviewRequestRef);
} QLGeneratorInterface;

static ULONG _refCount = 0;
static QLGeneratorInterface qlInterface;

static HRESULT myQueryInterface(void *thisInterface, REFIID iid, LPVOID *ppv) {
    CFUUIDRef requested = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    CFUUIDRef qlGeneratorIID = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("865AF5E0-6D30-4345-951B-D37105754F2D"));
    CFUUIDRef iunknown = CFUUIDGetConstantUUIDWithBytes(kCFAllocatorDefault,
        0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xC0,0x00,0x00,0x00,0x00,0x00,0x00,0x46);

    if (CFEqual(requested, iunknown) || CFEqual(requested, qlGeneratorIID)) {
        qlInterface.AddRef(thisInterface);
        *ppv = thisInterface;
        CFRelease(requested);
        CFRelease(qlGeneratorIID);
        return S_OK;
    }
    CFRelease(requested);
    CFRelease(qlGeneratorIID);
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG myAddRef(void *thisInterface) { return ++_refCount; }
static ULONG myRelease(void *thisInterface) {
    if (--_refCount == 0) {
        CFUUIDRef factoryUUID = PLUGIN_FACTORY_UUID;
        CFPlugInRemoveInstanceForFactory(factoryUUID);
        CFRelease(factoryUUID);
    }
    return _refCount;
}

void *QuickLookGeneratorPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeUUID) {
    CFUUIDRef qlGeneratorTypeUUID = CFUUIDCreateFromString(kCFAllocatorDefault, CFSTR("5E2D9680-5022-40FA-B806-43349622E5B9"));

    if (CFEqual(typeUUID, qlGeneratorTypeUUID)) {
        qlInterface._reserved = NULL;
        qlInterface.QueryInterface = myQueryInterface;
        qlInterface.AddRef = myAddRef;
        qlInterface.Release = myRelease;
        qlInterface.GenerateThumbnailForURL = GenerateThumbnailForURL;
        qlInterface.CancelThumbnailGeneration = CancelThumbnailGeneration;
        qlInterface.GeneratePreviewForURL = GeneratePreviewForURL;
        qlInterface.CancelPreviewGeneration = CancelPreviewGeneration;

        CFUUIDRef factoryUUID = PLUGIN_FACTORY_UUID;
        CFPlugInAddInstanceForFactory(factoryUUID);
        _refCount = 1;

        CFRelease(qlGeneratorTypeUUID);
        return &qlInterface;
    }
    CFRelease(qlGeneratorTypeUUID);
    return NULL;
}
