SimpleDatabase
==============

iOS 简单的 数据库封装

创建数据库 及 连接
SimpleDatabase *db = [[SimpleDatabase alloc]initWithFile:@"/users/renwei/desktop/test.db" initTableSql:@"CREATE TABLE IF NOT EXISTS DownloadTask (identifier varchar(1000),url varchar(1000) , name varchar(128), statue INTEGER , filePath varchar (1024)) ;"];

插入数据
[db executeSQL:@"insert or replace into  DownloadTask (identifier, url,name,filePath,statue)VALUES( ?,?,?,?,?) ;" bindObjects:@[[[NSDate date]description],[@"http://www.google.com.tw"stringByAppendingFormat:@"%d",i],[@"google" stringByAppendingFormat:@"%d %c",i,'A'+i],@"path",[NSNumber numberWithInt:100+i<<i]] objectClass:nil  error:&error];

查询数据
NSArray *array = [db executeSQL:@"select * from DownloadTask" bindObjects:nil  objectClass:[NODE class] error:&error];
