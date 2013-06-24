# Heroku Bench

A build server in the cloud, heavily inspired by Vulcan.

## Install

    $ gem install herokubench

## Usage

    $ hb help
    ommands:
      hb ab URL           # Run apache-bench, using a single, one-off Heroku dyno
      hb create APP_NAME  # Create your personal bench-server on Heroku
      hb help [COMMAND]   # Describe available commands or one specific command
      hb multi URL        # Run apache-bench, using multiple one-off dynos
    
    Options:
      [--verbose]



## Examples

### Create a Bench Server
    $ hb create hbench-david
    Creating hbench-david... done, stack is cedar
    http://hbench-david.herokuapp.com/ | git@heroku.com:hbench-david.git
    ...

### Bench

    $ hb http://nodejssimple.herokuapp.com/
      Running one-off dyno, please be patient
      Running `ab -c 1000 -n 10000 http://nodejssimple.herokuapp.com/` attached to terminal... up, run.4045
      This is ApacheBench, Version 2.3 <$Revision: 1430300 $>
      Copyright 1996 Adam Twiss, Zeus Technology Ltd, http://www.zeustech.net/
      Licensed to The Apache Software Foundation, http://www.apache.org/

      Benchmarking nodejssimple.herokuapp.com (be patient)
      Completed 1000 requests
      Completed 2000 requests
      Completed 3000 requests
      Completed 4000 requests
      Completed 5000 requests
      Completed 6000 requests
      Completed 7000 requests
      Completed 8000 requests
      Completed 9000 requests
      Completed 10000 requests
      Finished 10000 requests


      Server Software:
      Server Hostname:        nodejssimple.herokuapp.com
      Server Port:            80

      Document Path:          /
      Document Length:        12 bytes

      Concurrency Level:      1000
      Time taken for tests:   9.687 seconds
      Complete requests:      10000
      Failed requests:        0
      Write errors:           0
      Total transferred:      1322840 bytes
      HTML transferred:       120000 bytes
      Requests per second:    1032.32 [#/sec] (mean)
      Time per request:       968.692 [ms] (mean)
      Time per request:       0.969 [ms] (mean, across all concurrent requests)
      Transfer rate:          133.36 [Kbytes/sec] received

      Connection Times (ms)
                    min  mean[+/-sd] median   max
      Connect:        1    8  12.8      3      70
      Processing:    75  513 742.4    297    5077
      Waiting:       75  512 742.5    296    5077
      Total:        121  520 743.3    301    5087

      Percentage of the requests served within a certain time (ms)
        50%    301
        66%    373
        75%    403
        80%    566
        90%    889
        95%   1805
        98%   3967
        99%   4041
       100%   5087 (longest request)
