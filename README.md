# Documentation: projects and posts

In this site there are projects and posts that I found relevant to write something about them

This site is published in https://oalfonso.com

Used [mkdocs](http://www.mkdocs.org/) to generate the site


## Projects

* [Patata](patata.md):
Python library to perform parallel and concurrent http requests using multiprocessing and coroutines to maximize the throughput of requests.

* [PySpark Diff](pyspark_diff.md):
Python library to compare two pyspark dataframes and their nested items recursively giving an output that explains which nested key differs.

* [Crossbox](https://oalfonso.com/projects/crossbox):
Django webapp with Stripe payments that scaled a gym business from 30 users
up to 500 users in matter of months automating all the manual work of handling
the group sessions, the reservations, the payments, etc. Now the bottleneck of the growth of this business is the physical space, is not the technology anymore. Once the gym owner rents a bigger space this app will allow him to scale without modifications.

* [Balaland](https://oalfonso.com/projects/balaland):
PyGame 2D shooter game that tries to emulate what would be to play a 3D 1st person shooter in case of being played from a 2D view like in GTA2. Balaland respects the angle of view like if the camera was set from a 3D 1st person point of view, that means if you don't peak a corner you will see black everything that's behind a wall. Using ray casting to achieve that. Also some basic AI for the enemies to make them a bit competitive.
Still work in progress.

* [Candlebot](https://oalfonso.com/projects/candlebot):
Experimental backtesting app to gather historical market crypto prices from multiple CEX sources like Binance, define custom investing strategies based on indicators and run these parametrized strategies to backtest them against the historical prices fluctuations and extract statistics of success. Interesting a fun project but nothing profitable at all.


## Posts
* [Mail Server with Postfix and Dovecot](https://oalfonso.com/posts/mailserver):
Walkthrough of the setup of a custom mailserver from scratch, explaining all the bases needed for sending your own emails to anywhere without being tagged as spam and also being able to receive mails from anyone.

* [Ansible](https://oalfonso.com/posts/ansible):
Tutorial with the basics of Ansible, explaining the importance of defining the configuration of a deployment as code.

* [Python coroutines and asyncio](https://oalfonso.com/posts/python_async):
Understanding how asyncio works and its benefits. Checking how much performance improvement we can get of a single thread when running multiple IO operations async in Python vs a single process with locking IO operations.

* [KISS](https://oalfonso.com/posts/kiss):
Keep It Simple, Stupid. Explaining the importance of understanding the problem before proposing a solution via fictional scenarios based on real life experiences.