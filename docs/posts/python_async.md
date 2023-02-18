# Python co-routines and asyncio

What is this about? We want to make Python IO operations (http requests, database requests, disk operations...) non blocking. For example, let's say we have to fetch the data of 3 different URLs, by default it would be something like this:

- request.get(url1) -> 3 sec wait
- request.get(url2) -> 3 sec wait
- request.get(url3) -> 3 sec wait

Total wait time: 9 secs

We want to do the 3 requests at the same time and wait a total time of 3 secs.

To achieve this the default library is [asyncio](https://docs.python.org/3/library/asyncio.html) which under the hood uses co-routines.

## Why not using threads? Or multiprocessing?

Good question, two benefits of co-routines vs threads:

- co-routines live in a single thread and single process and can have millions of them working concurrently, but when doing threads we can't spawn this amount of threads per process because we have the OS limitation
- as co-routines work in a single thread there's much more control over race conditions (when managed properly) and easier debugging
