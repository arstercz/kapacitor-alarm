
kapacitor-alarm
===============

`kapacitor-alarm` is a notify manager for kapacitor [exec handler](https://docs.influxdata.com/kapacitor/v1.5/event_handlers/exec/), support notify aggregation and whitelist features, can be used with [kapacitor-tasks](https://github.com/arstercz/kapacitor-tasks).

**currently only email notifications is support!**

## Overview

```
   +----------------+
   |                |
   |  +----------+  |  
   |  | telegraf |  | 
   |  +----------+  |
   |                |         +------------+         +-----------+
   |  ...           |         | influxdb   |         |           |  exec handler    +-----------------+
   |                |  -------> opentsdb   <-------  | kapacitor <----------------  | kapacitor-alarm |
   |                |         | prometheus |         |           |                  +-----------------+
   |                |         +--^---------+         +-----------+
   |                | 
   |  +----------+  |
   |  | telegraf |  | 
   |  +----------+  |
   |                |
   +----------------+

```

## How does kapacitor-alarm work

```
1. kapacitor-task send alarm message to kapacitor exec handler(kap-exec command).
2. kap-exec read and parse the alarm message to redis.
3. kap-exec send email to recievers based on the aggregation policy.
```

the `kap-white` command can be used to set whitelist to the redis. `kap-exec` will applay whitelist to the aggregation policy. the `kap-status` command can be used to report the current `kapacitor-alarm` status.

**kap-exec** use `2**(sendcnt) == recvcnt` to determin whether to send email or not, read more from [Rule](lib/Kapalarm/Rule.pm#L24):
```
 recvcnt: 1 2 3 4 5 6 7 8 ...
 sendcnt: 1 1 1 2 2 2 2 3 ...
 is_send: Y N N Y N N N Y....
```

## How to install kapacitor-alarm

### Dependency

`kapcitor-alarm` depend on the following package:
```
perl-Data-Dumper
perl-TimeDate
perl-Digest-MD5
perl-Redis
perl-JSON
perl-Log-Dispatch
perl-Config-IniFiles
perl-Authen-SASL     # if send mail by smtp server
mailx                # if send mail by mail command
redis-server
```

### INSTALL

```
make install
```

## How to set configure file

all of the `kap-xxxx` command will read the same configure file, default is `/etc/kapalarm/kap.conf`. such as:
```
# /etc/kapalarm/kap.conf
[kapalarm]
try_on_failure=3             # retry max times when send email failuer
send_boundary=20             # send max times every metric
enable_whitelist=1           # enable whitelist feature, kap-exec will ignore notify when metric unit meet the whitelist.

[email]
email_use_sasl=0                        # perl-Authen-SASL will be needed when enable this.
email_server=10.0.21.5                  # mail server
email_sender=kapacitor@monit.com        # sender email name    
email_receiver=arstercz@gmail.com       # receiver users, multi email can be used separated by comma.
email_user=                             # empty if no user
email_password=                         # empty if no password

[redis]
host=10.0.21.5:6379
password=
prefix=kap                                 # all of the kap-xxx command will set key with the prefix string.

[kap-exec]
default_dc=beijng                          # default data centor if kapacitor-task does not set dc value.
enable_record=1                            # whether record kapactior message or not.
logfile=/var/log/kapalarm/kap-exec.log

[kap-white]
dc=beijing                                 # crossponding to dc value. support multiple data centor.
logfile=/var/log/kapalarm/kap-white.log

[kap-status]
dc=beijing                                 # the same as kap-white
logfile=/var/log/kapalarm/kap-status.log
```

## How to use kapacitor-alarm

[kap-exec](#kap-exec)  
[kap-white](#kap-white)  
[kap-status](#kap-status)  

#### kap-exec

`kap-exec` must be set in `kapacitor tasks`, such as:
```
.exec('/usr/local/bin/kap-exec', '--conf, '/etc/kapalarm/kap.conf')
```

#### kap-white

`kap-white` can change whitelist status in a hierarchical manner:
```
dc:     enable/disable the whole dc hosts
host:   enable/disable only one dc/host
metric: enable/disable only one dc/host/metric
```
eg:
```
# get the whole beijing data centor whitelist status
$ kap-white --dc beijing

# change whole beijing data centor status:
$ kap-white --type dc --dc beijing --enable  # ignore notify
$ kap-white --type dc --dc beijing --enable  # notify

# get one host whitelist status, dc option must be set:
$ kap-white --type dc --dc beijing --host host1

# change host status:
$ kap-white --type host --dc beijing --host host1 --enable  # ignore notify
$ kap-white --type host --dc beijing --host host1 --disable # notity

# get only one metric status, dc and host must be set:
$ kap-white --type metric --dc beijing --host host1 --metric diskio

$ kap-white --type metric --dc beijing --host host1 --metric diskio --enable  # ignore notify
$ kap-white --type metric --dc beijing --host host1 --metric diskio --disable # notify
```

#### kap-status

`kap-status` can report the current `kapacitor-alarm` status:
```
# report all dc status if not set dc option
$ kap-status --dc beijing
[beijing]
  dc is white:       0
  hosts num:         2
  white hosts num:   2
  white metrics num: 1
  white hosts list:  host1, host2

# report one host status, dc must be set
$ kap-status --dc beijing --host host1
[beijing/host1]
  white metrics: memory, disk
```

## License

MIT/BSD
