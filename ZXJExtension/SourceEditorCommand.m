//
//  SourceEditorCommand.m
//  ZXJExtension
//
//  Created by zhuxingjian on 2017/5/26.
//  Copyright © 2017年 ZXJ. All rights reserved.
//

#import "SourceEditorCommand.h"

@implementation SourceEditorCommand

static inline BOOL VerifyInstanceMethod(NSString *string) {
    if ([string hasPrefix:@"-"]) {
        return YES;
    }
    return NO;
}

static inline NSString *FetchCls(NSString *string) {
    if ([string containsString:@"("]) {
        NSRange leftRange = [string rangeOfString:@"("];
        NSRange rightRange = [string rangeOfString:@")"];
        NSUInteger len = rightRange.location - leftRange.location - 1;//-1 是去掉右半边括号
        NSString *clsString = [string substringWithRange:NSMakeRange(leftRange.location+1, len)];//获取括号内的文本
        NSMutableString *mutableString = [[NSMutableString alloc] initWithString:clsString];
        [mutableString deleteCharactersInRange:[clsString rangeOfString:@"*"]];//删除＊
        clsString = [mutableString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        return clsString;
    }
    return nil;
}

static inline NSString *FetchProperty(NSString *string) {
    NSUInteger loc = [string rangeOfString:@")"].location;
    NSString *rightString = [string substringWithRange:NSMakeRange(loc+1, string.length - (loc + 1))];
    NSMutableString *mutableString = [[NSMutableString alloc] initWithString:rightString];
    if ([rightString containsString:@"{"]) {
        [mutableString deleteCharactersInRange:[rightString rangeOfString:@"{"]];//如果包含{，就删除
    }
    rightString = [mutableString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return rightString;
}

static inline BOOL ExistsWithPropertyAndLines(NSString *propertyName,NSArray *lines) {
    NSString *judgeString = [NSString stringWithFormat:@"if (!_%@)",propertyName];
    for (NSString *lineText in lines) {
        if ([lineText containsString:judgeString]) {
            return YES;
        }
    }
    return NO;
}

static inline NSArray *AutomatedCompletionWithClsAndProperty(NSString *clsName, NSString *propertyName) {
    NSMutableArray *array = @[].mutableCopy;
    NSString *methodString = [NSString stringWithFormat:@"- (%@ *)%@",clsName,propertyName];
    NSString *beginString = @"{";
    NSString *judgeString = [NSString stringWithFormat:@"    if (!_%@) {",propertyName];
    NSString *initString = [NSString stringWithFormat:@"        _%@ = [[%@ alloc] init];",propertyName,clsName];
    NSString *returnString = [NSString stringWithFormat:@"    return _%@;",propertyName];
    NSString *judgeEndString = @"    }";
    NSString *endString = @"}";
    
    [array addObject:methodString];
    [array addObject:beginString];
    [array addObject:judgeString];
    [array addObject:initString];
    
    if ([clsName isEqualToString:@"UIImageView"]) {
        NSString *contentModeString = [NSString stringWithFormat:@"        _%@.contentMode = UIViewContentModeScaleAspectFill;",propertyName];
        NSString *clipString = [NSString stringWithFormat:@"        _%@.clipsToBounds = YES;",propertyName];
        NSString *imageString = [NSString stringWithFormat:@"        _%@.image = [UIImage imageNamed:<#(nonnull NSString *)#>];",propertyName];
        [array addObject:contentModeString];
        [array addObject:clipString];
        [array addObject:imageString];
    } else if ([clsName isEqualToString:@"UIButton"]) {
        initString = [NSString stringWithFormat:@"        _%@ = [UIButton buttonWithType:UIButtonTypeCustom];",propertyName];
        [array replaceObjectAtIndex:3 withObject:initString];
        NSString *setFontString = [NSString stringWithFormat:@"        _%@.titleLabel.font = [UIFont systemFontOfSize:<#(CGFloat)#>];",propertyName];
        NSString *setTitleStirng = [NSString stringWithFormat:@"        [_%@ setTitle:<#(nonnull NSString *)#> forState:UIControlStateNormal];",propertyName];
        NSString *setTitleColorString = [NSString stringWithFormat:@"        [_%@ setTitleColor:[UIColor <#Color#>] forState:UIControlStateNormal];",propertyName];
        NSString *setTargetString = [NSString stringWithFormat:@"        [_%@ addTarget:self action:@selector(<#selector#>) forControlEvents:UIControlEventTouchUpInside];",propertyName];
        [array addObject:setFontString];
        [array addObject:setTitleStirng];
        [array addObject:setTitleColorString];
        [array addObject:setTargetString];
    } else if ([clsName isEqualToString:@"UITableView"]) {
        initString = [NSString stringWithFormat:@"        _%@ = [[UITableView alloc] initWithFrame:<#(CGRect)#> style:<#(UITableViewStyle)#>]",propertyName];
        NSString *footerViewString = [NSString stringWithFormat:@"        _%@.tableFooterView = [[UIView alloc] init];",propertyName];
        NSString *registerString = [NSString stringWithFormat:@"        [_%@ registerClass:<#(nullable Class)#> forCellReuseIdentifier:NSStringFromClass(self.class)];",propertyName];
        NSString *annotationString =@"        /** iPad 适配 */";
        NSString *adaperiPadLine1String = [NSString stringWithFormat:@"        if ([_%@ respondsToSelector:@selector(setCellLayoutMarginsFollowReadableWidth:)]) {",propertyName];
        NSString *adaperiPadLine2String = [NSString stringWithFormat:@"            _%@.cellLayoutMarginsFollowReadableWidth = NO;",propertyName];
        NSString *adaperiPadLine3String = [NSString stringWithFormat:@"        }"];
        [array removeLastObject];
        [array addObject:initString];
        [array addObject:BackgroundColorStringWithProperty(propertyName)];
        [array addObject:DatasourceStringWithProperty(propertyName)];
        [array addObject:DelegateStringWithProperty(propertyName)];
        [array addObject:footerViewString];
        [array addObject:registerString];
        [array addObject:annotationString];
        [array addObject:adaperiPadLine1String];
        [array addObject:adaperiPadLine2String];
        [array addObject:adaperiPadLine3String];
    } else if ([clsName isEqualToString:@"UIView"]) {
        [array addObject:BackgroundColorStringWithProperty(propertyName)];
    } else if ([clsName isEqualToString:@"UILabel"]) {
        NSString *textColor = [NSString stringWithFormat:@"        _%@.textColor = <#Color#>;",propertyName];
        [array addObject:FontStringWithProperty(propertyName)];
        [array addObject:textColor];
        [array addObject:BackgroundColorStringWithProperty(propertyName)];
    } else if ([clsName isEqualToString:@"UITextField"]) {
        NSString *returnKeyTypeString = [NSString stringWithFormat:@"        _%@.returnKeyType = <#UIReturnKeyType#>;",propertyName];
        NSString *keyboardAppearanceString = [NSString stringWithFormat:@"        _%@.keyboardAppearance = UIKeyboardAppearanceDefault;",propertyName];
        NSString *borderStyleString = [NSString stringWithFormat:@"        _%@.borderStyle = <#UITextBorderStyle#>;",propertyName];
        NSString *secureTextEntryString = [NSString stringWithFormat:@"        _%@.secureTextEntry = <#BOOL#>;",propertyName];
        NSString *clearButtonModeString = [NSString stringWithFormat:@"        _%@.clearButtonMode = UITextFieldViewModeWhileEditing;",propertyName];
        [array addObject:DelegateStringWithProperty(propertyName)];
        [array addObject:FontStringWithProperty(propertyName)];
        [array addObject:returnKeyTypeString];
        [array addObject:keyboardAppearanceString];
        [array addObject:borderStyleString];
        [array addObject:secureTextEntryString];
        [array addObject:clearButtonModeString];
    } else if ([clsName isEqualToString:@"UICollectionView"]) {
        NSString *flowLayoutInitString = [NSString stringWithFormat:@"        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];"];
        NSString *itemSizeString = [NSString stringWithFormat:@"        flowLayout.itemSize = <#CGSizeMake#>;"];
        NSString *minimumLineSpacingString = [NSString stringWithFormat:@"        flowLayout.minimumLineSpacing = <#lineSpacing#>;"];
        NSString *minimumInteritemSpacingString = [NSString stringWithFormat:@"        flowLayout.minimumInteritemSpacing = <#interitemSpacing#>;"];
        NSString *scrollDerectionString = @"        flowLayout.scrollDirection = <#UICollectionViewScrollDirection#>;";
        initString = [NSString stringWithFormat:@"        _%@ = [[UICollectionView alloc] initWithFrame:<#CGRect#> collectionViewLayout:flowLayout];",propertyName];
        NSString *registerString = [NSString stringWithFormat:@"        [_%@ registerClass:[<#className#> class] forCellWithReuseIdentifier:NSStringFromClass([<#className#> class])];",propertyName];
        [array removeLastObject];
        [array addObject:flowLayoutInitString];
        [array addObject:itemSizeString];
        [array addObject:minimumLineSpacingString];
        [array addObject:minimumInteritemSpacingString];
        [array addObject:scrollDerectionString];
        [array addObject:initString];
        [array addObject:BackgroundColorStringWithProperty(propertyName)];
        [array addObject:DelegateStringWithProperty(propertyName)];
        [array addObject:DatasourceStringWithProperty(propertyName)];
        [array addObject:registerString];
    }
    [array addObject:judgeEndString];
    [array addObject:returnString];
    [array addObject:endString];
    return array.copy;
}

static inline NSString *BackgroundColorStringWithProperty(NSString *propertyName) {
    return [NSString stringWithFormat:@"        _%@.backgroundColor = <#Color#>;",propertyName];
}

static inline NSString *DelegateStringWithProperty(NSString *propertyName) {
    return [NSString stringWithFormat:@"        _%@.delegate = self;",propertyName];
}

static inline NSString *DatasourceStringWithProperty(NSString *propertyName) {
    return [NSString stringWithFormat:@"        _%@.dataSource = self;",propertyName];
}

static inline NSString *FontStringWithProperty(NSString *propertyName) {
    return [NSString stringWithFormat:@"        _%@.font = [UIFont systemFontOfSize:<#(CGFloat)#>];",propertyName];
}

static inline NSString * PropertyString(NSString *key,id value) {
    return [NSString stringWithFormat:@"@property (nonatomic, strong) %@ *%@;",NSStringFromClass([value superclass]),key];
}


- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    if ([invocation.commandIdentifier isEqualToString:[self getAutoPropertyIdentifier]]) {
        [self autoPropertyCommandWithInvocation:invocation];
    }else if ([invocation.commandIdentifier isEqualToString:[self getAutoGetterIdentifier]]) {
        [self autoGetterCommandWithInvocation:invocation];
    }
    completionHandler(nil);
}

- (void)autoPropertyCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation
{
    NSInteger startIndex = [self getStartLineWithInvocation:invocation];
    NSString *json = [self getSelecttionContent:invocation];
    
    NSError *error = nil;
    id data = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];
    if ([data isKindOfClass:[NSDictionary class]]) {
        NSArray *keys = [data allKeys];
        for (int i = 0; i < [keys count]; i++) {
            NSString *key = keys[i];
            id value = data[key];
            [invocation.buffer.lines insertObject:PropertyString(key,value) atIndex:startIndex + 2 + i];
        }
    }
}

- (void)autoGetterCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation
{
    XCSourceTextRange *selection = invocation.buffer.selections.firstObject;
    NSInteger lineIndex = selection.start.line;//行
    NSString *lineText = invocation.buffer.lines[lineIndex];//行的文本
    NSArray *lines = invocation.buffer.lines;
    if (VerifyInstanceMethod(lineText)) {
        NSString *className = FetchCls(lineText);
        NSString *property = FetchProperty(lineText);
        if (!ExistsWithPropertyAndLines(property, lines)) {//这个getter不存在才执行
            [invocation.buffer.lines removeObjectAtIndex:lineIndex];//删除光标所在行，后面有自定义
            NSArray *array = AutomatedCompletionWithClsAndProperty(className, property);
            for (NSInteger index = 0; index <= array.count - 1; index++ ) {
                NSString *string = array[index];
                [invocation.buffer.lines insertObject:string atIndex:lineIndex + index];
            }
        }
    }
}

- (NSInteger)getStartLineWithInvocation:(XCSourceEditorCommandInvocation *)invocation
{
    NSMutableArray *lines = invocation.buffer.lines;
    for (int i = 0; i < lines.count; i++) {
        NSString *lineText = lines[i];
        NSPredicate *numberPre = [NSPredicate predicateWithFormat:@"SELF BEGINSWITH[c] '@interface '"];
        BOOL isFirst = [numberPre evaluateWithObject:lineText];
        if (isFirst) {
            return i;
        }
    }
    return 12;
}

- (NSString *)getSelecttionContent:(XCSourceEditorCommandInvocation *)invocation
{
    NSMutableString *content = [NSMutableString string];
    XCSourceTextRange *selection = invocation.buffer.selections.firstObject;
    NSInteger startLine = selection.start.line;//行
    for (NSInteger i = startLine; i < invocation.buffer.lines.count - 1; i++) {
        NSString *lineText = invocation.buffer.lines[i];
        lineText = [lineText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([lineText isEqualToString:@"@end"]) {
            break;
        }
        if (lineText) {
            [content appendString:lineText];
        }
    }
    return content;
}

- (NSString *)getAutoPropertyIdentifier
{
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    return infoDic[@"NSExtension"][@"NSExtensionAttributes"][@"XCSourceEditorCommandDefinitions"][0][@"XCSourceEditorCommandIdentifier"];
}

- (NSString *)getAutoGetterIdentifier
{
    NSDictionary *infoDic = [[NSBundle mainBundle] infoDictionary];
    return infoDic[@"NSExtension"][@"NSExtensionAttributes"][@"XCSourceEditorCommandDefinitions"][1][@"XCSourceEditorCommandIdentifier"];
}

@end
