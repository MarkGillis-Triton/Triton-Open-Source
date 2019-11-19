ECHO	---------------------------------------------------	;
ECHO		Create views of system catalogues				;
ECHO	---------------------------------------------------	;
set schema mgillis;

CREATE OR REPLACE VIEW RI_Status AS
(
Select	
	Char(R.CONSTNAME,20) 		FK
	,DATE(R.Create_Time)		FK_CR8_Date
	,Char(R.TABSCHEMA,10) 		Child_Schema
	,Char(R.TABNAME,25) 		Child_Table
	,Char(R.REFKEYNAME,20) 		PK
	,Char(R.REFTABSCHEMA,10) 	Parent_Schema
	,Char(R.REFTABNAME,25) 		Parent_Table
	,Card
	,ENFORCED
	,CASE SUBSTR(CONST_CHECKED,1,1)	
	WHEN 'N' THEN 'Integrity OFF'
	WHEN 'U' THEN 'UnChecked'
	WHEN 'W' THEN 'UnChecked set integrity pending'
	WHEN 'Y' THEN 'Checked by system'
	End							FK_Status
	,Status
	,CASE Status
	WHEN 'C' THEN 'Set integrity pending'
	WHEN 'N' THEN 'Normal'
	WHEN 'X' THEN 'Inoperative'
	End							Table_Status
	,Access_Mode
	,CASE Access_Mode
	WHEN 'D' THEN 'No data movement'
	WHEN 'F' THEN 'Full access'
	WHEN 'N' THEN 'No access'
	WHEN 'R' THEN 'Read-only'
	End							Access_Mode_Lit
	,Trusted
	,CHECKEXISTINGDATA	 	
	,CASE CHECKEXISTINGDATA
	WHEN  'D' Then 'Defer checking'
	WHEN  'I' Then 'Immediately check'
	WHEN  'N' Then 'Never check'
	End							Existing_Data
	,ENABLEQUERYOPT 	
	,CASE ENABLEQUERYOPT 	
	WHEN  'N' Then 'disabled'
	WHEN  'Y' Then 'enabled'
	End							Q_optimization
	from 	SYSCAT.REFERENCES R
		inner join
		SYSCAT.TABCONST  T	
		ON R.CONSTNAME = T.CONSTNAME
		AND T.TABSCHEMA = R.TABSCHEMA
		AND T.TABNAME = R.TABNAME
		inner join
		Syscat.TABLES	Tab
		ON T.TABSCHEMA = Tab.TABSCHEMA
		AND T.TABNAME = Tab.TABNAME
);

CREATE or REPLACE VIEW RI_Test_View AS (
SELECT
	PARENT_SCHEMA ,
	PARENT_TABLE  ,            
	PK,                   
	CHILD_TABLE,               
	FK,         
	-- FK_CR8_Date,
	-- CHILD_SCHEMA, 
	-- CARD          ,       
	ENFORCED ,
	TRUSTED ,
	FK_STATUS ,                                          
	-- STATUS ,
	TABLE_STATUS          ,
	-- ACCESS_MODE ,
	ACCESS_MODE_LIT , 
	-- CHECKEXISTINGDATA ,
	EXISTING_DATA,
	-- ENABLEQUERYOPT ,
	Q_OPTIMIZATION
FROM RI_Status
)
;

ECHO	---------------------------------------------------	;
ECHO		Set up test tables and data 					;
ECHO	---------------------------------------------------	;
-- !read -p "Press [Enter] key to continue" ;
!pause;

-- DROP TABLE Child ;
-- DROP TABLE Child_Exceptions ;
-- DROP TABLE Parent ;

CREATE TABLE Child (
	Child_Key	INTEGER NOT NULL,
	Parent_Key	INTEGER NOT NULL,
	Name		VarChar(12) NOT NULL
);
CREATE UNIQUE INDEX Child_PK ON Child (Child_Key) INCLUDE (Name) ;
ALTER TABLE Child ADD CONSTRAINT Child_PK PRIMARY KEY (Child_Key ) ;
CREATE TABLE Child_Exceptions LIKE Child ;

CREATE TABLE Parent (
	Key		INTEGER NOT NULL,
	Name	VarChar(50) NOT NULL
);
CREATE UNIQUE INDEX Parent_PK ON Parent (Key) INCLUDE (Name) ;
ALTER TABLE Parent ADD CONSTRAINT Parent_PK PRIMARY KEY ( Key ) ;

ALTER TABLE Child 
	ADD CONSTRAINT Child_FK FOREIGN KEY ( Parent_Key )
	REFERENCES Parent ( Key )
	ON DELETE RESTRICT
	ON UPDATE NO ACTION
	ENFORCED
	ENABLE QUERY OPTIMIZATION;


INSERT INTO Parent VALUES (1,'Philip'),(2,'Elizabeth') ;
INSERT INTO Child VALUES 
(1,1,'Charles'),
(2,2,'Anne') ,
(3,1,'Andrew'), 
(4,2,'Edward') 
;

SELECT * FROM Parent ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
SELECT * FROM RI_Test_View WHERE Child_Table='CHILD';
-- select tabname, SUBSTR(CONST_CHECKED,1,1) from syscat.tables where tabname in ('PARENT','CHILD') ;

CALL SYSPROC.ADMIN_CMD ('RUNSTATS ON TABLE MGILLIS.Parent and indexes all') ;
CALL SYSPROC.ADMIN_CMD ('RUNSTATS ON TABLE MGILLIS.Child and indexes all') ;
runstats on table MGILLIS.Parent and indexes all ;
runstats on table MGILLIS.Child and indexes all ;
select CHAR(tabname,20) Table, card, stats_time from syscat.tables where tabname IN ('PARENT','CHILD') ;
select CHAR(tabname,20) Table, CHAR(Indname,20) Index, fullkeycard, stats_time from syscat.indexes where tabname IN ('PARENT','CHILD') ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		INFORMATIONAL CONSTRAINTS						;
ECHO	---------------------------------------------------	;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		set FK to NOT enforced: 						;
ECHO	---------------------------------------------------	;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK NOT ENFORCED ;

ECHO	---------------------------------------------------	;
ECHO			puts Check Existing Data into 'Never check'	;
ECHO			FK becomes informational only				;
ECHO	---------------------------------------------------	;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
!pause;
ECHO	---------------------------------------------------	;
ECHO		insert invalid data         					;
ECHO	---------------------------------------------------	;
INSERT INTO Child VALUES (5,3,'Monty') ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
!pause;
ECHO	---------------------------------------------------	;
ECHO		set FK to enforced: (fails due to orphan data)	;
ECHO	---------------------------------------------------	;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK ENFORCED ;
ECHO	---------------------------------------------------	;
ECHO			data access is OK as still not enforced		;
ECHO	---------------------------------------------------	;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
!pause;

-- ECHO	---------------------------------------------------	;
-- ECHO		set INTEGRITY off: no data access				;
-- ECHO	---------------------------------------------------	;
-- SET INTEGRITY FOR Child OFF ;
-- SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
ECHO	---------------------------------------------------	;
ECHO		set INTEGRITY off READ access					;
ECHO			(SQL20209N) if SET INTEGRITY is already off	;
ECHO			data IS accessible but orphans still there	;
ECHO	---------------------------------------------------	;
SET INTEGRITY FOR Child OFF read ACCESS ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
INSERT INTO Child VALUES (6,3,'Bunty') ;
DELETE FROM Child WHERE name='Monty' ;
UPDATE Child set Name='Arbuthnot' WHERE Child_Key=4 ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		set FK to enforced (successful) BUT				;
ECHO		No access because:								;
ECHO			FK is Integrity OFF and 					;
ECHO			Table is Integrity Pending					;
ECHO	---------------------------------------------------	;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK ENFORCED ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT Name FROM Child ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		UNCHECKED										;
ECHO		this will take the table out of check pending	;
ECHO		but will leave the orphan data 					;
ECHO	---------------------------------------------------	;
-- !read -p "Press [Enter] key to continue" ;
!pause;

SET INTEGRITY FOR Child all IMMEDIATE UNCHECKED ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		Attempting to insert further invalid data fails	;
ECHO		because FK is Immediately Check					;
ECHO		BUT the existing orphan remains					;
ECHO	---------------------------------------------------	;
INSERT INTO Child VALUES (6,3,'Bunty') ;
-- SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
-- !read -p "Press [Enter] key to continue" ;
!pause;


ECHO	---------------------------------------------------	;
ECHO		CLEAN UP INVALID DATA         					;
-- incremental-options
-- INCREMENTAL
-- Specifies the application of integrity processing on the appended portion (if any) of the table. If such a request cannot be satisfied (that is, the system detects that the whole table needs to be checked for data integrity), an error is returned (SQLSTATE 55019).
-- NOT INCREMENTAL
-- Specifies the application of integrity processing on the whole table. If the table is a materialized query table, the materialized query table definition is recomputed. If the table has at least one constraint defined on it, this option causes full processing of descendent foreign key tables and descendent immediate materialized query tables. If the table is a staging table, it is set to an inconsistent state.
-- If the incremental-options clause is not specified, the system determines whether incremental processing is possible; if not, the whole table is checked.
ECHO	---------------------------------------------------	;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		Integrity Off: 									;
ECHO			FK in 'UnChecked set integrity pending'		;
ECHO			no Data acccess 							;
ECHO	---------------------------------------------------	;
SET INTEGRITY FOR Child OFF ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		CHECKED	INCREMENTAL								;
ECHO			SQL1594W  Integrity of non-incremental data remains unverified	;
ECHO			Orphan data remains							;
ECHO	---------------------------------------------------	;
SET INTEGRITY FOR Child IMMEDIATE CHECKED INCREMENTAL FOR EXCEPTION IN Child USE Child_Exceptions ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
INSERT INTO Child VALUES (7,3,'Binty') ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		CHECKED	NOT INCREMENTAL								;
ECHO			SQL3602W  Check data processing found constraint violations and moved them to exception tables.	;
ECHO			all access and flags restored				;
ECHO			orphan data in EXCEPTION table				;
ECHO	---------------------------------------------------	;
SET INTEGRITY FOR Child OFF ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SET INTEGRITY FOR Child IMMEDIATE CHECKED NOT INCREMENTAL FOR EXCEPTION IN Child USE Child_Exceptions ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
SELECT * FROM Child_Exceptions ;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		Q_OPTIMIZATION								 	;
ECHO		Optimization can be enabled and Enforced disabled !!?! ;
ECHO		If a constraint is NOT TRUSTED and enabled for query optimization, ;
ECHO		then it will not be used to perform optimizations that depend on the; 
ECHO		data conforming completely to the constraint. 	;
ECHO	---------------------------------------------------	;
-- !read -p "Press [Enter] key to continue" ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		enabled for Query Optimization					;
ECHO		should IXSCAN Child_PK							;
ECHO	---------------------------------------------------	;
!pause;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
set CURRENT explain MODE = explain ;

SELECT C.Name from Child C 
WHERE parent_key in 
	(SELECT key from Parent) 
;

set CURRENT explain MODE = NO ;
!db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_enabled_enforced_trusted#1.explain ;
!more Q_OPT_enabled_enforced_trusted#1.explain ;

EXPLAIN ALL set queryno=99 FOR 
SELECT C.Name from Child C 
WHERE parent_key in 
	(SELECT key from Parent) 
;
select total_cost from db2in113.explain_statement where queryno=99 and date(explain_time) = current date ;

!pause;

ECHO	---------------------------------------------------	;
ECHO		not enabled for Query Optimization				;
ECHO		TBSCAN on child, HSJOIN to IXSCAN on Parent_PK	;
ECHO		Orphan INSERT fails								;
ECHO	---------------------------------------------------	;
!pause;

ALTER TABLE Child ALTER FOREIGN KEY Child_FK DISABLE query optimization ;

SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
set CURRENT explain MODE = explain ;
select C.Name from mgillis.Child C where parent_key in (select key from mgillis.Parent) ;
set CURRENT explain MODE = NO ;
!db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_disabled#2.explain ;
!more Q_OPT_disabled#2.explain ;
!pause;
INSERT INTO Child VALUES (8,3,'Marmaduke') ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
!pause;

-- ALTER TABLE Child ALTER FOREIGN KEY Child_FK NOT ENFORCED ;
-- SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
-- set CURRENT explain MODE = explain ;
-- select C.Name from mgillis.Child C where parent_key in (select key from mgillis.Parent) ;
-- set CURRENT explain MODE = NO ;
-- !db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_disabled_and_not_enforced#3.explain ;
-- !pause;

-- ALTER TABLE Child ALTER FOREIGN KEY Child_FK ENABLE query optimization ;
-- SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
-- set CURRENT explain MODE = explain ;
-- select C.Name from mgillis.Child C where parent_key in (select key from mgillis.Parent) ;
-- set CURRENT explain MODE = NO ;
-- !db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_enabled_and_not_enforced#4.explain ;
-- !pause;

ECHO	---------------------------------------------------	;
ECHO		enabled for Query Optimization BUT not trusted	;
ECHO		TBSCAN on child, HSJOIN to IXSCAN on Parent_PK	;
ECHO		Orphan INSERT fails								;
ECHO	---------------------------------------------------	;
!pause;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK ENABLE query optimization ;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK NOT ENFORCED NOT trusted ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
set CURRENT explain MODE = explain ;
select C.Name from mgillis.Child C where parent_key in (select key from mgillis.Parent) ;
set CURRENT explain MODE = NO ;
!db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_enabled_and_not_enforced_not_trusted#5.explain ;
!more Q_OPT_enabled_and_not_enforced_not_trusted#5.explain ;
!pause;
INSERT INTO Child VALUES (7,3,'Binty') ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		enabled for Query Optimization, trusted but NOT enforced ;
ECHO		TBSCAN on child, HSJOIN to IXSCAN on Parent_PK	;
ECHO		Orphan INSERT fails								;
ECHO	---------------------------------------------------	;
!pause;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK ENABLE query optimization ;
ALTER TABLE Child ALTER FOREIGN KEY Child_FK NOT ENFORCED trusted ;
SELECT CHILD_TABLE, FK, ENFORCED, TRUSTED, FK_STATUS, TABLE_STATUS, ACCESS_MODE_LIT, EXISTING_DATA, Q_OPTIMIZATION FROM RI_Test_View WHERE Child_Table='CHILD' ;
set CURRENT explain MODE = explain ;
select C.Name from mgillis.Child C where parent_key in (select key from mgillis.Parent) ;
set CURRENT explain MODE = NO ;
!db2exfmt -d contract -e db2in113 -g TIC -w -1 -n % -s % -# 0 -o Q_OPT_enabled_and_trusted_but_not_enforced#6.explain ;
!more Q_OPT_enabled_and_trusted_but_not_enforced#6.explain ;
!pause;
INSERT INTO Child VALUES (7,3,'Binty') ;
SELECT *, case when parent_key not in (select key from parent) then '<== Orphan' else null end FROM Child ;
!pause;

ECHO	---------------------------------------------------	;
ECHO		Clean Up									 	;
ECHO	---------------------------------------------------	;
DROP TABLE Child ;
DROP TABLE Child_Exceptions ;
DROP TABLE Parent ;
