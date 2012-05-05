curl-phpmyadmin
===============

Export MySQL data from phpmyadmin using curl.

Arguments: mysql-export.sh [-h|--help] [--stdout] [--tables=<table_name>,<table_name>] [--add-drop] [--apache-user=<apache_http_user>] [--apache-password=<apache_http_password>] [--phpmyadmin-user=<phpmyadmin_user>] [--phpmyadmin-password=<phpmyadmin_password>] [--database=<database>] [--host=<phpmyadmin_host>] [--use-keychain]
       -h, --help: Print help
       --stdout: Write SQL (gzipped) in stdout
       --tables: Export only particular tables
       --add-drop: add DROP TABLE IF EXISTS to every exporting table
       --apache-user=<apache_http_user>: Apache HTTP autorization user
       --apache-password=<apache_http_password>: Apache HTTP autorization password or keychain entry name if --use-keychain
       --phpmyadmin-user=<phpmyadmin_user>: PhpMyAdmin user
       --phpmyadmin-password=<phpmyadmin_password>: PhpMyAdmin password or keychain entry name if --use-keychain
       --database=<database>: Database to be exported
       --host=<phpmyadmin_host>: PhpMyAdmin host
       --use-keychain: Use Mac OS X keychain to get passwords from. In that case --apache-password and --phpmyadmin-password will be used as account name for search in Mac Os X keychain. 

 Common uses: mysql-export.sh --tables=hotel_content_provider --add-drop --database=hs --stdout --use-keychain --apache-user=betatester --phpmyadmin-user=hs --apache-password=www.example.com\ \(me\) --phpmyadmin-password=phpmyadmin.example.com --host=https://www.example.com/phpmyadmin | gunzip | mysql -u root -p testtable
        exports and imports on the fly in local db
