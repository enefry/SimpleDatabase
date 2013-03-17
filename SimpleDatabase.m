//
//  DBFormatter.m
//  DownloadManager
//
//  Created by renwei on 13-3-17.
//  Copyright (c) 2013年 renwei. All rights reserved.
//

#import "SimpleDatabase.h"
#import <sqlite3.h>
#define  kDataBase_openError_notificationKey @""
@implementation SimpleDatabase


- (id)initWithFile:(NSString *)path initTableSql:(NSString*)sql
{
    self = [super init];
    if (self) {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir = NO;
        BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
        if(isDir){
            [[NSNotificationCenter defaultCenter] postNotificationName:kDataBase_openError_notificationKey object:@{@"name":@"DatabaseOpenFail",@"reason":@"path is a Directory !",@"description":[NSString stringWithFormat:@"%@ 是文件夹 !",path]}];
            self = nil;
        }else{
            sqlite3_open_v2([path UTF8String], &_db, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE, NULL);
            if (!_db) {
                [[NSNotificationCenter defaultCenter] postNotificationName:kDataBase_openError_notificationKey object:@{@"name":@"DatabaseOpenFail",@"reason":@"open fail",@"description":@"无法为 database 指针分配空间!"}];
                self  = nil;
            }else{
                if (!exists) {
                    char*pointer = NULL;
                    if(!sqlite3_exec(_db, [sql UTF8String], NULL, NULL,&pointer) == SQLITE_OK){
                        NSLog(@"创建数据库表出错: %s",pointer);
                        [[NSNotificationCenter defaultCenter]postNotificationName:kDataBase_openError_notificationKey object:@{@"name":@"DatabaseCreateTablesFail",@"reason":@"execute sql fail",@"description":[NSString stringWithFormat:@"%s",pointer]}];
                    }
                }
            }
        }
    }
    return self;
}
- (void)dealloc
{
    sqlite3_close(_db);
    [super dealloc];
}


-(NSArray*)executeSQL:(NSString *)sql bindBlock:(bind_sqlite_data_action)bindsql objectClass:(Class)class  error:(NSError **)error{
    
    __block int count;
    __block bind_data_action* actions = NULL;
    __block BOOL firstTime = YES;
    __block NSMutableArray *array =[[NSMutableArray alloc]initWithCapacity:32];
    [self executeSQL:sql bindBlock:bindsql actionBlock:^(sqlite3_stmt *stmt) {
        if (firstTime) {
            count = sqlite3_column_count(stmt);
            actions = ( bind_data_action*)malloc(sizeof(bind_data_action)*count);
            int type ;
            const char*columnName;
            for (int i=0; i<count; i++) {
                type = sqlite3_column_type(stmt, i);
                columnName = sqlite3_column_name(stmt, i);
                switch (type) {
                    case SQLITE_INTEGER:
                        actions[i] = Block_copy( ^(sqlite3_stmt*stmt,int row,id obj){
                            [obj setValue:[NSNumber numberWithInt:sqlite3_column_int(stmt, row)] forKey:[NSString stringWithFormat:@"%s",columnName]];
                        });
                        break;
                    case SQLITE_FLOAT:
                        actions[i] = Block_copy(^(sqlite3_stmt*stmt,int row,id obj){
                            [obj setValue:[NSNumber numberWithInt:sqlite3_column_int(stmt, row)] forKey:[NSString stringWithFormat:@"%s",columnName]];
                        });
                        break;
                    case SQLITE_TEXT:
                        actions[i] =Block_copy( ^(sqlite3_stmt*stmt,int row,id obj){
                            [obj setValue:[NSString stringWithFormat:@"%s",sqlite3_column_text(stmt, row)] forKey:[NSString stringWithFormat:@"%s",columnName]];
                        });
                        break;
                    case SQLITE_BLOB:
                        actions[i] = Block_copy(^(sqlite3_stmt*stmt,int row,id obj){
                            [obj setValue:[NSData dataWithBytes:sqlite3_column_blob(stmt, row) length:sqlite3_column_bytes(stmt, row)] forKey:[NSString stringWithFormat:@"%s",columnName]];
                        });
                        break;
                    default:
                        actions[i] = Block_copy(^(sqlite3_stmt*stmt,int row,id obj){});
                        break;
                }
            }
            firstTime = NO;
        }// end of first time init
        
        
        id obj = [[class alloc]init];
        [array addObject:obj];
        [obj release];
        for (int i=0; i<count; i++) {
            actions[i](stmt,i,obj);
        }
    } error:error];
    if (actions) {
        for (int i=0; i<count; i++) {
            Block_release(actions[i]);
        }
        free(actions);
    }
    NSArray *result = [NSArray arrayWithArray:array];
    [array release];
    array = nil;
    return  result;
    
}
-(NSArray*)executeSQL:(NSString*)sql bindObjects:(NSArray*)objs objectClass:(Class)class error:(NSError**)error{
    return [self executeSQL:sql bindBlock:^BOOL(sqlite3_stmt *stmt) {
        for (int i=0; i<objs.count;) {
            id obj = [objs objectAtIndex:i];
            if ([obj isKindOfClass:[NSData class]]){
                // blob
                NSData *data = (NSData *)obj;
                sqlite3_bind_blob(stmt, ++i, data.bytes, (int)(data.length&0x7FFFFFFF), NULL);
            }else if([obj isKindOfClass:[NSNumber class]]){
                switch ([obj objCType][0]) {
                    case 'B'://C++ bool or C99 _Bool
                    case 'c'://char
                    case 'i'://int
                    case 's'://short
                    case 'l'://long
                    case 'C'://unsigned char
                    case 'I'://unsigned int
                    case 'S'://unsigned short
                    case 'L'://unsigned long
                        sqlite3_bind_int(stmt, ++i, [obj intValue]);
                        break;
                    case 'q'://long long
                    case 'Q'://unsigned long long
                        sqlite3_bind_int64(stmt,++i, [obj longLongValue]);
                        break;
                    case 'f'://float
                    case 'd'://double
                        sqlite3_bind_double(stmt, ++i, [obj doubleValue]);
                        break;
                    case 'v'://void
                    case '*'://char *
                    case '@'://An object
                    case '#'://a Class object
                    case ':'://a method selector (SEL)
                    default:
                        //这些都是空
                        sqlite3_bind_null(stmt, ++i);
                        break;
                }
            }else if ([obj isKindOfClass:[NSNull class]]){
                sqlite3_bind_null(stmt, ++i);
            }else{
                NSString *text = [obj description];
                sqlite3_bind_text(stmt, ++i, [text UTF8String], -1, NULL);
            }
        }
        return YES;
    } objectClass:class error:error];
}

-(void)executeSQL:(NSString *)sql bindBlock:(bind_sqlite_data_action)bindsql actionBlock:(readBlock)block error:(NSError *__autoreleasing *)error{
    sqlite3_stmt *stmt = NULL;
    if (( SQLITE_OK == sqlite3_prepare_v2(_db, [sql UTF8String], -1, &stmt, NULL) ) ){
        if(bindsql == NULL || bindsql(stmt)){
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                block(stmt);
            }// end while
        }
    }else{
        const char *p = sqlite3_errmsg(_db);
        NSLog(@"数据库查询错误: %s ",p);
        if (error) {
            *error = [[[NSError alloc]initWithDomain:[NSString stringWithUTF8String:p] code:-1 userInfo:nil]autorelease];
        }
    }
    //关闭stmt
    if( stmt != NULL ){
        sqlite3_finalize(stmt);
    }
}


@end
