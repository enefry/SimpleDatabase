//
//  DBFormatter.h
//  DownloadManager
//
//  Created by renwei on 13-3-17.
//  Copyright (c) 2013年 renwei. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

typedef const void (^bind_data_action)(sqlite3_stmt *stmt,int row ,id obj );
typedef BOOL (^bind_sqlite_data_action)(sqlite3_stmt*stmt);
typedef void (^readBlock)(sqlite3_stmt*stmt);

@interface SimpleDatabase : NSObject
{
    sqlite3 *_db;
}

- (id)initWithFile:(NSString *)file initTableSql:(NSString*)sql;


-(NSArray*)executeSQL:(NSString*)sql bindObjects:(NSArray*)objs objectClass:(Class)class error:(NSError**)error;

-(NSArray*)executeSQL:(NSString*)sql bindBlock:(bind_sqlite_data_action)bindsql objectClass:(Class)class error:(NSError**)error;

-(void)executeSQL:(NSString *)sql bindBlock:(bind_sqlite_data_action)bindsql actionBlock:(readBlock)block error:(NSError *__autoreleasing *)error;


@end
