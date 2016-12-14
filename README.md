# mysql_analyse_general_log.pl

`mysql_analyse_general_log.pl` allow to parse MySQL general log file (all queries) and identify all requests per transaction.

To use it you need to activate the general.log of MySQL. Activation of MySQL general.log can impact MySQL performance and will be disk intensive (write all requests including SELECTs) and will consume disk space.


## Usage cases

### MySQL crash analysis

In case you had a MySQL crash, and want to understand which query or transaction cause the crash.

You can display all unfinished transactions at the time of the crash.

#### Example
```
cat general.log | mysql_analyse_general_log.pl --end='161205 16:08:56' --only-at-end 
######## END ########
THREAD_DMP : Thread 892314 (partial duration:0):
THREAD_DMP : 161205 12:00:11 : Query :  START TRANSACTION;
THREAD_DMP : 161205 12:00:11 : Query :  INSERT INTO `fake` (`fake`, `fake`, `fake`, `fake`, `fake`, `fake`) VALUES ('fake', 'fake', 'fake', 'fake', 'fake', 'fake');
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake` FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.* FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake`, `fake`.`fake` FROM `fake` WHERE (store_id = 1) AND (is_system = 1) AND (category_id = 0 OR category_id IS NULL) AND (product_id IN('fake')) ORDER BY `fake` DESC;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake`, `fake`.* FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.`fake`, `fake`.`fake` FROM `fake` WHERE (product_id IN('fake')) AND (stock_id=1) AND (website_id=1);
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.* FROM `fake` WHERE (product_id IN ('fake'));
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.* FROM `fake` WHERE (product_id IN (6136));
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.* FROM `fake` WHERE (product_id IN (6136));
THREAD_DMP : 161205 12:00:11 : Query :  SELECT `fake`.* FROM `fake` WHERE (product_id IN (6136))
```

### Transactions locks

If some transactions are started, have locked lines/tables/keys, and are long to commit or rollback, theses requests cannot be seen in full processlist nor engine innodb status.

By analysing the general log you can group all requests by transaction, and :
- get a dump of all non commited transactions at a specific time,
```
cat general.log | mysql_analyse_general_log --end='140909 10:05:50'
```
- or only long running transactions.
```
cat general.log | mysql_analyse_general_log --min-duration=10
```

This allow to identify which requests of which transaction are blocking others, to search in your app the request you've find.

#### Example
```
cat general.log | mysql_analyse_general_log.pl --min-duration=1
TRANS_END  : Transaction END : type: Query / query:     COMMIT / duration: 1
THREAD_DMP : Thread 892283 (partial duration:1):
THREAD_DMP : 161205 12:00:03 : Query :  START TRANSACTION;
THREAD_DMP : 161205 12:00:03 : Query :  SELECT `fake`.* FROM `fake` AS `fake` WHERE (`fake` = 'fake');
THREAD_DMP : 161205 12:00:03 : Query :  UPDATE `fake` SET `fake` = 'fake', `fake` = NULL, `fake` = 'fake', `fake` = 'fake', `fake` = NULL, `fake` = 'fake', `fake` = 'fake' WHERE (entity_id='fake');
THREAD_DMP : 161205 12:00:03 : Query :  UPDATE `fake` SET `fake` = 'fake', `fake` = 'fake', `fake` = 'fake', `fake` = NULL, `fake` = 'fake', `fake` = 'fake', `fake` = 'fake' WHERE (entity_id='fake');
THREAD_DMP : 161205 12:00:03 : Query :  INSERT INTO `fake` (`fake`, `fake`, `fake`, `fake`, `fake`) VALUES ('fake', 'fake', 'fake', 'fake', 'fake');
THREAD_DMP : 161205 12:00:03 : Query :  SELECT `fake`.* FROM `fake` AS `fake`;
THREAD_DMP : 161205 12:00:04 : Query :  COMMIT

TRANS_END  : Transaction END : type: Query / query:     COMMIT / duration: 1
THREAD_DMP : Thread 892314 (partial duration:1):
THREAD_DMP : 161205 12:00:10 : Query :  START TRANSACTION;
THREAD_DMP : 161205 12:00:11 : Query :  INSERT INTO `fake` (`fake`, `fake`, `fake`, `fake`, `fake`) VALUES ('fake', 'fake', 'fake', 'fake', 'fake');
THREAD_DMP : 161205 12:00:11 : Query :  INSERT INTO `fake` (`fake`, `fake`, `fake`, `fake`, `fake`, `fake`, `fake`) VALUES ('fake', 'fake', 'fake', NULL, 'fake', 'fake', 'fake');
THREAD_DMP : 161205 12:00:11 : Query :  COMMIT
```

## Dependencies

Needs Perl module Time::Local :

```
apt-get install -y  libdatetime-locale-perl
```



