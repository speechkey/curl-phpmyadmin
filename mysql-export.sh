#! /bin/sh

#set -x

# This program is free software published under the terms of the GNU GPL.
#
# Forked: http://picoforge.int-evry.fr/websvn/filedetails.php?repname=curlmyback&path=%2Ftrunk%2Fcurl-backup-phpmyadmin.sh&rev=0&sc=1 
# (C) Institut TELECOM + Olivier Berger <olivier.berger@it-sudparis.eu> 2007-2009
# $Id: curl-backup-phpmyadmin.sh 12 2011-12-12 16:02:44Z berger_o $

# Clean up and add parameter handling by Artem Grebenkin
# <speechkey@gmail.com> http://www.irepository.net
#
# This saves dumps of your Database using CURL and connecting to
# phpMyAdmin (via HTTPS), keeping the 10 latest backups by default
#
# Tested on phpMyAdmin 3.4.5
#
# For those interested in debugging/adapting this script, the firefox
# add-on LiveHttpHeaders is a very interesting extension to debug HTTP
# transactions and guess what's needed to develop such a CURL-based
# script.
#
# Arguments: mysql-export.sh [-h|--help] [--stdout] [--tables=<table_name>,<table_name>] [--add-drop] [--apache-user=<apache_http_user>] [--apache-password=<apache_http_password>] [--phpmyadmin-user=<phpmyadmin_user>] [--phpmyadmin-password=<phpmyadmin_password>] [--database=<database>] [--host=<phpmyadmin_host>] [--use-keychain]
#	-h, --help: Print help
# 	--stdout: Write SQL (gzipped) in stdout
#	--tables: Export only particular tables
#	--add-drop: add DROP TABLE IF EXISTS to every exporting table
#	--apache-user=<apache_http_user>: Apache HTTP autorization user
#	--apache-password=<apache_http_password>: Apache HTTP autorization password
#	--phpmyadmin-user=<phpmyadmin_user>: PhpMyAdmin user
#	--phpmyadmin-password=<phpmyadmin_password>: PhpMyAdmin password
#	--database=<database>: Database to be exported
#	--host=<phpmyadmin_host>: PhpMyAdmin host
#	--use-keychain: Use Mac OS X keychain to get passwords from. In that case --apache-password and --phpmyadmin-password will be used as account name for search in Mac Os X keychain. 
#
# Common uses: mysql-export.sh --stdin | gunzip | mysql -u root -p testtable
#	       exports and imports on the fly in local db

# Please adapt these values :

APACHE_USER=0
APACHE_PASSWD=0

PHPMYADMIN_USER=0
PHPMYADMIN_PASSWD=0

REMOTE_HOST=0
DATABASE=0
COMPRESSION=on
ADD_DROP=1
TMP_FOLDER="/tmp"
USE_KEYCHAIN=0

# End of customisations

stdin=0
export_tables=0
add_drop=0

for arg in $@
do
	if [ $arg == '-h' ] || [ $arg == '--help' ]
	then
		cat << EOF
mysql-export.sh [-h|--help][--stdout] [--tables=<table_name>,<table_name>] [--add-drop] [--apache-user=<apache_http_user>] [--apache-password=<apache_http_password>] [--phpmyadmin-user=<phpmyadmin_user>] [--phpmyadmin-password=<phpmyadmin_password>] [--database=<database>] [--host=<phpmyadmin_host>]

	-h, --help: Print this help
       --stdout: Write SQL (gzipped) in stdout
       --tables: Export only particular tables
       --add-drop: add DROP TABLE IF EXISTS to every exporting table
       --apache-user=<apache_http_user>: Apache HTTP autorization user
       --apache-password=<apache_http_password>: Apache HTTP autorization password
       --phpmyadmin-user=<phpmyadmin_user>: PhpMyAdmin user
       --phpmyadmin-password=<phpmyadmin_password>: PhpMyAdmin password
       --database=<database>: Database to be exported
       --host=<phpmyadmin_host>: PhpMyAdmin host

 Common uses: mysql-export.sh --stdin | gunzip | mysql -u root -p testtable
              exports and imports on the fly in local db
EOF
exit 0

	elif [ $arg == '--stdout' ]
	then
		stdin=1
	elif [[ $arg =~ --tables ]]
	then
		export_tables=1
		db_tables=$arg
	elif [ $arg == '--compression=off' ]
	then
		COMPRESSION=off
	elif [ $arg == '--add-drop' ]
	then
		add_drop=1
	elif [[ $arg =~ --apache-user ]] && [ $APACHE_USER -eq 0 ]
	then
		APACHE_USER=${arg:14}
	elif [[ $arg =~ --apache-password ]] && [ $APACHE_PASSWD -eq 0 ]
	then
		APACHE_PASSWD=${arg:18}
	elif [[ $arg =~ --phpmyadmin-user ]] && [ $PHPMYADMIN_USER -eq 0 ]
	then
		PHPMYADMIN_USER=${arg:18}
	elif [[ $arg =~ --phpmyadmin-password ]] && [ $PHPMYADMIN_PASSWD -eq 0 ]
	then
		PHPMYADMIN_PASSWD=${arg:22}
	elif [[ $arg =~ --database ]] && [ $DATABASE -eq 0 ]
	then
		DATABASE=${arg:11}
	elif [[ $arg =~ --host ]] && [ $REMOTE_HOST -eq 0 ]
	then
		REMOTE_HOST=${arg:7}
	elif [[ $arg == '--use-keychain' ]]
	then
		USE_KEYCHAIN=1
	fi
done

if [ $USE_KEYCHAIN -eq 1 ]
then
	APACHE_PASSWD=`security 2>&1 >/dev/null find-internet-password -gs $APACHE_PASSWD | sed -e 's/password: "\(.*\)"/\1/g'`
	PHPMYADMIN_PASSWD=`security 2>&1 >/dev/null find-internet-password -g -l $PHPMYADMIN_PASSWD | sed -e 's/password: "\(.*\)"/\1/g'`
fi

###############################################################
#
# First login and fetch the cookie which will be used later
#
###############################################################

MKTEMP=/bin/tempfile
if [ ! -x $MKTEMP ]; then
    MKTEMP=/usr/bin/mktemp
fi

result=$($MKTEMP "$TMP_FOLDER/phpmyadmin_export.$RANDOM.tmp")

apache_auth_params="--anyauth -u$APACHE_USER:$APACHE_PASSWD"

curl -s -k -D $TMP_FOLDER/curl.headers -L -c $TMP_FOLDER/cookies.txt $apache_auth_params $REMOTE_HOST/index.php > $result
    token=$(grep link $result | grep 'phpmyadmin.css.php' | grep token | sed "s/^.*token=//" | sed "s/&.*//" )

    cookie=$(cat $TMP_FOLDER/cookies.txt | cut  -f 6-7 | grep phpMyAdmin | cut -f 2)

    entry_params="-d \"phpMyAdmin=$cookie&phpMyAdmin=$cookie&pma_username=$PHPMYADMIN_USER&pma_password=$PHPMYADMIN_PASSWD&server=1&phpMyAdmin=$cookie&lang=en-utf-8&convcharset=utf-8&collation_connection=utf8_general_ci&token=$token&input_go=Go\""


curl -s -S -k -L  -D $TMP_FOLDER/curl.headers -b $TMP_FOLDER/cookies.txt -c $TMP_FOLDER/cookies.txt $apache_auth_params $entry_params $REMOTE_HOST/index.php > $result

if [ $? -ne 0 ]
then
     echo "Curl Error on : curl $entry_params -s -k -D $TMP_FOLDER/curl.headers -L -c $TMP_FOLDER/cookies.txt $REMOTE_HOST/index.php. Check contents of $result" >&2
     exit 1
fi
grep -q "HTTP/1.1 200 OK" $TMP_FOLDER/curl.headers
if [ $? -ne 0 ]
then
         echo -n "Error : couldn't login to phpMyadmin on $REMOTE_HOST/index.php" >&2
         grep "HTTP/1.1 " $TMP_FOLDER/curl.headers >&2
         exit 1
fi

md5cookie=$token

post_params="token=$md5cookie"
post_params="$post_params&export_type=server"
post_params="$post_params&export_method=quick"
post_params="$post_params&quick_or_custom=custom"
post_params="$post_params&db_select[]=$DATABASE"
post_params="$post_params&output_format=sendit"

post_params="$post_params&what=sql"
post_params="$post_params&codegen_structure_or_data=data"
# post_params="$post_params&codegen_format=0"
# post_params="$post_params&csv_separator=%3B"
# post_params="$post_params&csv_enclosed=%22"
# post_params="$post_params&csv_escaped=%5C"
# post_params="$post_params&csv_terminated=AUTO"
# post_params="$post_params&csv_null=NULL"
post_params="$post_params&csv_structure_or_data=data"
# post_params="$post_params&excel_null=NULL"
# post_params="$post_params&excel_edition=win"
post_params="$post_params&excel_structure_or_data=data"
# post_params="$post_params&htmlword_structure=something"
post_params="$post_params&htmlword_structure_or_data=structure_and_data"
# post_params="$post_params&htmlword_null=NULL"
# post_params="$post_params&latex_caption=something"
# post_params="$post_params&latex_structure=something"
# post_params="$post_params&latex_structure_caption=Structure+of+table+__TABLE__"
# post_params="$post_params&latex_structure_continued_caption=Structure+of+table+__TABLE__+%28continued%29"
# post_params="$post_params&latex_structure_label=tab%3A__TABLE__-structure"
# post_params="$post_params&latex_comments=something"
post_params="$post_params&latex_data=something"
# post_params="$post_params&latex_columns=something"
# post_params="$post_params&latex_data_caption=Content+of+table+__TABLE__"
# post_params="$post_params&latex_data_continued_caption=Content+of+table+__TABLE__+%28continued%29"
# post_params="$post_params&latex_data_label=tab%3A__TABLE__-data"
# post_params="$post_params&latex_null=%5Ctextit%7BNULL%7D"
post_params="$post_params&mediawiki_structure_or_data=data"
# post_params="$post_params&ods_null=NULL"
post_params="$post_params&ods_structure_or_data=data"
# post_params="$post_params&odt_structure=something"
# post_params="$post_params&odt_comments=something"
post_params="$post_params&odt_data=something"
# post_params="$post_params&odt_columns=something"
# post_params="$post_params&odt_null=NULL"
# post_params="$post_params&pdf_report_title="
post_params="$post_params&pdf_data=1"
post_params="$post_params&php_array_structure_or_data=data"
post_params="$post_params&sql_header_comment="
post_params="$post_params&sql_include_comments=something"
post_params="$post_params&sql_compatibility=NONE"
post_params="$post_params&sql_structure_or_data=structure_and_data"
post_params="$post_params&sql_if_not_exists=something"
post_params="$post_params&sql_auto_increment=something"
post_params="$post_params&sql_backquotes=something"
post_params="$post_params&sql_data=something"
post_params="$post_params&sql_columns=something"
post_params="$post_params&sql_extended=something"
post_params="$post_params&sql_max_query_size=50000"
post_params="$post_params&sql_hex_for_blob=something"
post_params="$post_params&sql_type=INSERT"
# post_params="$post_params&texytext_structure=something"
post_params="$post_params&texytext_data=something"
# post_params="$post_params&texytext_null=NULL"
# post_params="$post_params&xls_null=NULL"
post_params="$post_params&xls_structure_or_data=data"
# post_params="$post_params&xlsx_null=NULL"
post_params="$post_params&xlsx_structure_or_data=data"
post_params="$post_params&yaml_structure_or_data=data"
post_params="$post_params&asfile=sendit"
post_params="$post_params&filename_template=__SERVER__"
post_params="$post_params&remember_template=on"
post_params="$post_params&charset_of_file=utf-8"

if [ $add_drop -eq 1 ]
then
	post_params="$post_params&sql_drop_table=something"
	post_params="$post_params&sql_structure=data"
fi

if [ "$COMPRESSION" = "on" ]
then
    post_params="$post_params&compression=gzip"
else
    post_params="$post_params&compression=none"
fi
#&sql_hex_for_binary=something

#2.7.0-pl2
#post_params="$post_params&sql_structure=structure"
#post_params="$post_params&sql_auto_increment=1"
#post_params="$post_params&sql_compat=NONE"
#post_params="$post_params&use_backquotes=1"
#post_params="$post_params&sql_data=data"
#post_params="$post_params&hexforbinary=yes"
#post_params="$post_params&sql_type=insert"
#post_params="$post_params&lang=fr-utf-8&server=1&collation_connection=utf8_general_ci&buttonGo=Exécuter"

if [ $export_tables -eq 1 ]
then
	db_tables=${db_tables/=/table_select[]=}
	db_tables=${db_tables//,/&table_select[]=}
	db_tables=${db_tables:8}
	
	post_params="$post_params&db=$DATABASE&export_type=database&$db_tables&filename_template=__DB__"
	
fi

if [ $stdin -eq 1 ]
then
	curl -g -s -S -k -D $TMP_FOLDER/curl.headers -L -b $TMP_FOLDER/cookies.txt $apache_auth_params -d "$post_params" $REMOTE_HOST/export.php
else
	curl -g -s -S -O -k -D $TMP_FOLDER/curl.headers -L -b $TMP_FOLDER/cookies.txt $apache_auth_params -d "$post_params" $REMOTE_HOST/export.php
	
	grep -q "Content-Disposition: attachment" $TMP_FOLDER/curl.headers
	if [ $? -eq 0 ]
	then
		filename="$(echo $remote_host | sed 's/\./-/g')_${database}_$(date  +%Y%m%d%H%M).sql"

		if [ "$COMPRESSION" = "on" ]
    		then
        		filename="$filename.gz"
		        mv export.php backup_mysql_$filename
		        echo "Saved: backup_mysql_$filename"
		else
		        mv export.php backup_mysql_$filename
		        gzip backup_mysql_$filename
		        echo "Saved: backup_mysql_$filename.gz"
		fi
	fi
fi

# remove the old backups and keep the 10 younger ones.
#ls -1 backup_mysql_*${database}_*.gz | sort -u | head -n-10 | xargs -r rm -v
rm -f $result
rm -f $TMP_FOLDER/curl.headers
rm -f $TMP_FOLDER/cookies.txt
