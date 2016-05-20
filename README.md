# s3_ftp_example

## セットアップ


config.rbを作成して下さい。

```
$ touch config.rb
```

内容は以下です。

```
require 's3ftp'

AWS_KEY = 'XXXXXXXXXXXXXXXXXXXXXX'
AWS_SECRET = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'
AWS_BUCKET = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'

driver S3FTP::Driver
driver_args AWS_KEY, AWS_SECRET, AWS_BUCKET
```

XXXXXXXXXXXXXXXXXXXX部分はご自身の物を入力下さい。

## 起動

```
$ sudo bundle exec em-ftpd config.rb
```
