# Heroku Bench

A distributed loadtesting and benchmarking package built ontop of Heroku's cloud and Apache's apachebench utility.

Capable of loads of millions of requests per second, for free.

![screen shot 2014-06-02 at 3 59 03 pm](https://cloud.githubusercontent.com/assets/446889/3154424/b4f6ceb6-eaa9-11e3-9de8-3b65bf379b45.png)



## Install

    $ gem install herokubench

## Usage

    $ hbench help
    commands:
      hbench ab [options] [http[s]://]hostname[:port]/path            # Run apache-bench using a single one-off dyno
      hbench create APP_NAME                                          # Create your personal bench-server on Heroku
      hbench help [COMMAND]                                           # Describe available commands or one specific command
      hbench multi NUMBER [options] [http[s]://]hostname[:port]/path  # Run apache-bench, using multiple one-off dynos
      hbench update                                                   # Updates your remote bench server

    Options:
      [--verbose]


## Examples

### Create a Bench Server
```sh
$ hbench create hbench-david
Creating hbench-david... done, stack is cedar
http://hbench-david.herokuapp.com/ | git@heroku.com:hbench-david.git
...
```

### Bench
Make 10,000 requests using 100 concurrent connections
```sh
$ hbench -c 100 -n 10000 http://simplewsgi.herokuapp.com/
```

Result:
```sh
$ hbench -c 100 -n 10000 http://simplewsgi.herokuapp.com/
Benching: |====================================================================|
Cumulative results, summed across dynos
Server Port:         80
Document Length:     12
Concurrency Level:   5000
Time taken for tests: 338.7
Complete requests:   5000000
Failed requests:     1715
Write errors:        0
Total transferred:   773280562
HTML transferred:    60553444
Requests per second: 14930.630000000001
Time per request:    3.4
Transfer rate:       47.62

Connection Times (ms), median across dynos
                     min      mean     [+/-sd]  median
Connect:             1.2      2.8      5.5      1.8
Processing:          2.3      332.8    1013.0   113.6
Waiting:             0.0      332.1    1012.7   112.8
Total:               4.1      335.7    1013.1   116.6

Percentage of the requests served within a certain time (ms) across dynos
	50%                  219
	66%                  305
	75%                  378
	80%                  430
	90%                  605
	95%                  983
	98%                  3636
	99%                  6202
	100%                 20933
```


## Questions? Comments? Contributions?
Please don't hesitate to ask, comment, contribute or critique! I am all ears!
