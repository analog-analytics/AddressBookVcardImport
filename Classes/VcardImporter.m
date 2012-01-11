//
//  VcardImporter.m
//  AddressBookVcardImport
//
//  Created by Alan Harper on 20/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "VcardImporter.h"
#import "BaseSixtyFour.h"

@implementation VcardImporter

- (id) init {
    if (self = [super init]) {
        addressBook = ABAddressBookCreate();
        parsingString = NO;
    }
    
    return self;
}

- (void) dealloc {
    CFRelease(addressBook);
    [super dealloc];
}


- (ABRecordRef) parseWithString : (NSString *)infoStr
{
    NSArray *lines = [infoStr componentsSeparatedByString:@"\n"];
    parsingString = YES;
    
    for(NSString* line in lines) {
        [self parseLine:line];
    }
    
    return personRecord;
}

- (void)parse {
    [self emptyAddressBook];
    
    NSString *filename = [[NSBundle mainBundle] pathForResource:@"vCards" ofType:@"vcf"];
    NSLog(@"opening file %@", filename);
    NSData *stringData = [NSData dataWithContentsOfFile:filename];
    
    if (stringData == nil)
    {
        // NO data available.
    }
    NSString *vcardString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    
    
    NSArray *lines = [vcardString componentsSeparatedByString:@"\n"];
    
    for(NSString* line in lines) {
        [self parseLine:line];
    }
    
    ABAddressBookSave(addressBook, NULL);

    [vcardString release];
}

- (void) parseItem: (ABPropertyID) propID : (NSString *)line {
    NSArray *upperComponents = [line componentsSeparatedByString:@":"];
    ABRecordSetValue (personRecord, propID,[upperComponents objectAtIndex:1], NULL);
}

- (void) parseVersion: (NSString *)line {
    NSArray *upperComponents = [line componentsSeparatedByString:@":"];
    version = [[upperComponents objectAtIndex:1] floatValue];
}

// Each version is different:
// 2.1   TEL;WORK;VOICE:(111) 555-1212
// 3.0   TEL;TYPE=WORK,VOICE:(111) 555-1212
// 4.0   TEL;TYPE="work,voice";VALUE=uri:tel:+1-111-555-1212
//
// 
- (void) parsePhone:(NSString *)line {
    NSArray *mainComponents = [line componentsSeparatedByString:@":"];
    NSString *phoneNumber = [mainComponents lastObject];
    CFStringRef label;
    ABMutableMultiValueRef multiPhone;
    
    if ([line rangeOfString:@"WORK"].location != NSNotFound) {
        label = kABWorkLabel;
    } else if ([line rangeOfString:@"HOME"].location != NSNotFound) {
        label = kABHomeLabel;
    } else {
        label = kABPersonPhoneMainLabel;
    }
    
    ABMultiValueRef immutableMultiPhone = ABRecordCopyValue(personRecord, kABPersonPhoneProperty);
    if (immutableMultiPhone) {
        multiPhone = ABMultiValueCreateMutableCopy(immutableMultiPhone);
    } else {
        multiPhone = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    }
    ABMultiValueAddValueAndLabel(multiPhone, phoneNumber, label, NULL);
    ABRecordSetValue(personRecord, kABPersonPhoneProperty, multiPhone,nil);
    
    CFRelease(multiPhone);
    if (immutableMultiPhone) {
        CFRelease(immutableMultiPhone);
    }
    
}

- (void) parseURL:(NSString *)line {
    NSArray *mainComponents = [line componentsSeparatedByString:@":"];
    // Everything but the first components
    NSString *firstPart = [mainComponents objectAtIndex:0];
    NSString *urlAddr = [line substringFromIndex:firstPart.length+1];
    
    ABMutableMultiValueRef multiValue;
    
    ABMultiValueRef immutableMultiURL = ABRecordCopyValue(personRecord, kABPersonURLProperty);
    if (immutableMultiURL) {
        multiValue = ABMultiValueCreateMutableCopy(immutableMultiURL);
    } else {
        multiValue = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    }
    ABMultiValueAddValueAndLabel(multiValue, urlAddr, kABPersonHomePageLabel, NULL);
    ABRecordSetValue(personRecord, kABPersonURLProperty, multiValue, nil);
    
    CFRelease(multiValue);
    if (immutableMultiURL) {
        CFRelease(immutableMultiURL);
    }
    
}


- (void) parseLine:(NSString *)line {
    if (base64image && [line hasPrefix:@"  "]) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        base64image = [base64image stringByAppendingString:trimmedLine];
    } else if (base64image) {
        // finished contatenating image string
        [self parseImage];
    } else if ([line hasPrefix:@"BEGIN"]) {
        personRecord = ABPersonCreate();
    } else if ([line hasPrefix:@"END"]) {
        if (parsingString == NO)
            ABAddressBookAddRecord(addressBook, personRecord, NULL);
    } else if ([line hasPrefix:@"VERSION:"]) {
        [self parseVersion:line];
    } else if ([line hasPrefix:@"N:"]) {
        [self parseName:line];
        
        
    } else if ([line hasPrefix:@"ORG:"]) {
        [self parseItem: kABPersonOrganizationProperty :line];
    } else if ([line hasPrefix:@"TITLE:"]) {
        [self parseItem: kABPersonJobTitleProperty :line];
        
    } else if ([line hasPrefix:@"URL:"]) {
        [self parseURL :line];
        
        
    } else if ([line hasPrefix:@"TEL;"]) {
        [self parsePhone:line];
    } else if ([line hasPrefix:@"EMAIL;"]) {
        [self parseEmail:line];
    } else if ([line hasPrefix:@"PHOTO;BASE64"]) {
        base64image = [NSString string];
    }
}


- (void) parseName:(NSString *)line {
    NSArray *upperComponents = [line componentsSeparatedByString:@":"];
    NSArray *components = [[upperComponents objectAtIndex:1] componentsSeparatedByString:@";"];
    if (components.count==1)
    {
        components = [[upperComponents objectAtIndex:1] componentsSeparatedByString:@" "];
    }
    
    ABRecordSetValue (personRecord, kABPersonLastNameProperty,[components objectAtIndex:0], NULL);
    if (components.count>1)
    ABRecordSetValue (personRecord, kABPersonFirstNameProperty,[components objectAtIndex:1], NULL);
    if (components.count>3)
    ABRecordSetValue (personRecord, kABPersonPrefixProperty,[components objectAtIndex:3], NULL);
}

- (void) parseEmail:(NSString *)line {
    NSArray *mainComponents = [line componentsSeparatedByString:@":"];
    NSString *emailAddress = [mainComponents objectAtIndex:1];
    CFStringRef label;
    ABMutableMultiValueRef multiEmail;
    
    if ([line rangeOfString:@"WORK"].location != NSNotFound) {
        label = kABWorkLabel;
    } else if ([line rangeOfString:@"HOME"].location != NSNotFound) {
        label = kABHomeLabel;
    } else {
        label = kABOtherLabel;
    }

    ABMultiValueRef immutableMultiEmail = ABRecordCopyValue(personRecord, kABPersonEmailProperty);
    if (immutableMultiEmail) {
        multiEmail = ABMultiValueCreateMutableCopy(immutableMultiEmail);
    } else {
        multiEmail = ABMultiValueCreateMutable(kABMultiStringPropertyType);
    }
    ABMultiValueAddValueAndLabel(multiEmail, emailAddress, label, NULL);
    ABRecordSetValue(personRecord, kABPersonEmailProperty, multiEmail,nil);
    
    CFRelease(multiEmail);
    if (immutableMultiEmail) {
        CFRelease(immutableMultiEmail);
    }
}

- (void) parseImage {
    NSData *imageData = [BaseSixtyFour decode:base64image];
    base64image = nil;
    ABPersonSetImageData(personRecord, (CFDataRef)imageData, NULL);
    
}
- (void) emptyAddressBook {
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(addressBook);
    int arrayCount = CFArrayGetCount(people);
    ABRecordRef abrecord;
    
    for (int i = 0; i < arrayCount; i++) {
        abrecord = CFArrayGetValueAtIndex(people, i);
        ABAddressBookRemoveRecord(addressBook,abrecord, NULL);
    }
    CFRelease(people);
}
@end
