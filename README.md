curl-phpmyadmin
===============

Export MySQL data from phpmyadmin using curl.

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

