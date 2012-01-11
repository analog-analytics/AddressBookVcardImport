//
//  VcardImporter.h
//  AddressBookVcardImport
//
//  Created by Alan Harper on 20/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

@interface VcardImporter : NSObject {
    ABAddressBookRef addressBook;
    ABRecordRef personRecord;
    NSString *base64image;
    float version;
    BOOL parsingString;
}
- (ABRecordRef) parseWithString : (NSString *)infoStr;
- (void)parse;
- (void) parseLine:(NSString *)line;
- (void) parseName:(NSString *)line;
- (void) parseEmail:(NSString *)line;
- (void) parseImage;
- (void) emptyAddressBook;

@end

