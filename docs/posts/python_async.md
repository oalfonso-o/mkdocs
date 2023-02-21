# Python coroutines and asyncio

What is this about? We want to make Python IO operations (http requests, database requests, disk operations...) non blocking. For example, let's say we have to fetch the data of 3 different URLs, by default it would be something like this:

- GET url1 -> wait 1 sec
- GET url2 -> wait 1 sec
- GET url3 -> wait 1 sec

Total wait time requesting the data sequentially: 3 secs

We want to do these 3 requests at the same time and wait a total time of 1 sec.

We can achieve this with *concurrency*, and a way of concurrency in a single thread in Python is using coroutines and the default library for this paradigm is [asyncio](https://docs.python.org/3/library/asyncio.html).

## Why not using threads?

Good question, using multiple threads in Python is another way of concurrency. In Java or Rust multithreading can parallelize the computation but in Python (CPython) because of the GIL only one thread can be working at the same time inside of the same process (concurrency).
So which are the differences? Let's mention the two main benefits of coroutines vs threads:

- coroutines live in a single thread and single process and can have millions of them working concurrently, but when doing threads we can't spawn this amount of threads per process because we have the OS limitation
- as coroutines work in a single thread there's much more control over race conditions and are easier to debug (when managed properly)

## And why not multiprocessing?

Multiprocessing is a good way to get advantage of the multiple CPUs available. For operations that are pure cpu it works perfectly. It also can parallelize IO operations but just as much as processes can handle the OS, so there's a limit. Also the communication between processes is not straightforward as each new process has to create a new stack and a new heap, memory is not shared so all the data to communicate between processes has to be serialized and deserialized. All of these has an extra cost that we don't have to face with coroutines.


## Ok, so what is a coroutine?

From the official [docs](https://docs.python.org/3/glossary.html#term-coroutine):

!!! info ""

    Coroutines are a more generalized form of subroutines. Subroutines are entered at one point and exited at another point. Coroutines can be entered, exited, and resumed at many different points. They can be implemented with the async def statement. See also [PEP 492](https://peps.python.org/pep-0492/).

In other words, are Python generators, so methods returning values with `yield` used wisely to take advantage of that `yield`, of that give away of the control of the execution to iterate multiple generators concurrently. So in a coroutine we can start an IO operation, return the control of the execution, call another coroutine, this other coroutine can start another IO operation and then we can go back to the first one and check if that IO operation has finished.

## Let's see an example, concurrent sleeps with vanilla Python

Before of seeing coroutines, it's interesting to see how we can achieve concurrency in Python without generators. And for that first let's see a classical IO operation that goes sequentially:

### Sequential sleeps

First the sequential example, of having to do 3 sequential `sleeps` of 3 seconds each one:

``` python
>>> import time
>>> 
>>> start_time = time.time()
>>> for i in range(3):
...     time.sleep(3)
...     print(f"Finish {i} time: {time.time() - start_time}")
... 

Finish 0 time: 3.004476308822632
Finish 1 time: 6.007846117019653
Finish 2 time: 9.0092191696167
>>> print(f"Total time: {time.time() - start_time}")
Total time: 9.010355710983276
```

It's pretty clear no? 3 sleeps of 3 seconds, 9 seconds in total.

### Concurrent sleeps

Now let's rewrite it, without coroutines yet, nor async frameworks, but in a way that can be performed concurrently. To achieve this we have to change the paradigm a lot, because we are not going to use the sleep blocking method, we are going to implement the logic in a different way, to check with our own logic if we reached the condition of waiting 3 seconds, entering into the task, checking if has passed 3 seconds, and leaving if not.

Let's see the code:

``` python
>>> import time
>>> 
>>> class Task:
...     def __init__(self, duration, id_):
...         self.ready = False
...         self.threshold = time.time() + duration
...         self.result = None
...         self.id_ = id_
...     def run(self):
...         now = time.time()
...         if now >= self.threshold:
...             self.ready = True
...             self.result = 'some result'
...             print(f"Finish {self.id_}")
... 
>>> 
>>> def wait(tasks):
...     original_tasks = list(tasks)
...     pending = set(original_tasks)
...     start_time = time.time()
...     while pending:
...         for task in list(pending):
...             task.run()
...             if task.ready:
...                 pending.remove(task)
...     print(f"Total time: {time.time() - start_time}")
...     return [t.result for t in original_tasks]
... 
>>> 
>>> def main():
...     tasks = [Task(duration=3, id_=i) for i in range(10)]
...     wait(tasks)
... 
>>> 
>>> main()
Finish 0
Finish 6
Finish 2
Finish 3
Finish 9
Finish 4
Finish 8
Finish 5
Finish 1
Finish 7
Total time: 2.999994993209839

```

What's happening here? These are the steps:

- Define a Task class that can manage it's own state of when it's completed and has a run method that won't block and has it's own way to decide if it's done or not
- Inits all the Tasks needed
- Create an event loop `main` where we are calling the `run` method of each task until their status changes to ready, at that point we remove that task

So we can concurrently have 10 "sleeps" in just 3 seconds. The sleep could be replaced by another IO operation.

This concept looks simple, but it can become extremely complicated when having to define this kind of tasks for other operations more complicated than a simple wait. For example doing an HTTP request or a query to a database.

For an HTTP request we normally use `requests` library or `urllib3` because it's the builtin, but both are blocking, so we will have to wait until each request finishes. To be able to do requests concurrently we need to implement something like what we've seen in this snippet but for performing an HTTP request non blocking. And this is what does `aiohttp` which uses sockets to retrieve the data of that request in a non-blocking manner. For more details of this library you can check the code on Github [https://github.com/aio-libs/aiohttp](https://github.com/aio-libs/aiohttp).

But here we are going too fast, let's not jump yet to `aiohttp`, let's try to understand better how coroutines work, because we've seen how to do sleeps concurrently but we've not seen any `yield` nor generator. Let's see another example and we will understand how `yield` plays in this game and what coroutines are.

### Python generator

Let's start with a simple generator:

``` python
>>> def mygen():
...     c = 0
...     for i in range(3):
...         yield i
...         print(f"Inside of generator value of i {i}")
... 
>>> x = mygen()
>>> 
>>> next(x)
0
>>> 
>>> list(x)
Inside of generator value of i 0
Inside of generator value of i 1
Inside of generator value of i 2
[1, 2]
```

No mistery here, a classical generator. You iterate it and it keeps yielding each value back. But the generator has a method called [`send`](https://docs.python.org/3/reference/expressions.html#generator.send) which we can use to provide a value to the generator.

### Python coroutines

``` python
>>> def mycoro():
...     c = 0
...     for i in range(10):
...         c += yield i
...         print(f"Inside of generator value of c {c}")
```

Here the difference is that instead of doing just a `yield` we are also expecting a value coming back from that `yield` and adding it to `c`.

Now we can't just call the `send` method yet, this is what happens if we do it:
```python
>>> x = mycoro()
>>> x.send(10)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: can't send non-None value to a just-started generator
```

We have to call the iterator once to make it arriving to the yield position, where then it can receive a value from `send`. It can be done with an initial `next(generator)` or with `generator.send(None)`:
```python
>>> x = mycoro()
>>> next(x)
0
>>> x = mycoro()
>>> x.send(None)
0
```

Now it comes the interesting part, once we have our generator started we can provide values from outside too, making it bidirectional:
```python
>>> def mycoro():
...     c = 0
...     for i in range(100):
...         c += yield i
...         print(f"Inside of generator value of c {c}")
... 
>>> x = mycoro()
>>> next(x)
0
>>> x.send(10)
Inside of generator value of c 10
1
>>> x.send(5)
Inside of generator value of c 15
2
>>> x.send(20)
Inside of generator value of c 35
3
>>> x.send(1.5)
Inside of generator value of c 36.5
4
```

Did you see? We are returning always the value of `i` which is defined by the `range` but we are also sending arbitrary numbers that change the behaviour of the generator. This is a really powerful feature of generators that is used to create coroutines.

### Replace the concurrent example with a generator

Let's replace our initial example of the `Task` and our event loop where we do concurrent sleeps, but now with a generator:

``` python
>>> import time
>>> 
>>> def sleep(duration, id_):
...     now = time.time()
...     threshold = now + duration
...     while now < threshold:
...         yield
...         now = time.time()
...     return id_
... 
>>> 
>>> def event_loop(tasks):
...     pending = list(tasks)
...     tasks = {task: None for task in tasks}
...     start_time = time.time()
...     while pending:
...         for gen in pending:
...             try:
...                 tasks[gen] = gen.send(tasks[gen])
...             except StopIteration as e:
...                 tasks[gen] = e.args[0]
...                 pending.remove(gen)
...     print(f"Total time: {time.time() - start_time}")
...     return list(tasks.values())
... 
>>> 
>>> def main():
...     tasks = [sleep(3, 1), sleep(3, 2), sleep(3, 3), sleep(3, 4), sleep(3, 5)]
...     print(event_loop(tasks))
... 
>>> 
>>> main()
Total time: 3.000023126602173
[1, 2, 3, 4, 5]
```

That's it, we can concurrently handle sleeps with generators, which can be called coroutines too, sending a value every time we call the generator (which in this case is a None) and getting back also a value which is yielded. This code here is performing a pretty simple `sleep` logic, but the important thing here is the fact that this paradigm allows us to implement more complicated concurrent logic using a single process and a single thread.

Ok, pretty nice, but we don't want to be the ones managing this complexity, so we can use better tools and this feature of having bidirectional communication is the one used under the hood of [`async` and `await`, the two new keywords added since Python 3.5](https://docs.python.org/3/whatsnew/3.5.html#whatsnew-pep-492). Also, this feature is the one used to build [asyncio](https://docs.python.org/3/library/asyncio.html), the default Python way to work with async.

So now we can forget everything about coroutines and focus on these beautiful tools that make everything much more friendly.

## async & await

Let's rewrite our sleep example with `async` and `await`:

``` python
>>> import asyncio
>>> import time
>>> 
>>> async def sleep(duration, id_):
...     await asyncio.sleep(duration)
...     print(id_)
...     return id_
... 
>>> async def main():
...     start_time = time.time()
...     tasks = [sleep(3, i) for i in range(5)]
...     results = await asyncio.gather(*tasks)
...     for result in results:
...         print(result)
...     print(f"Total time: {time.time() - start_time}")
... 
>>> 
>>> asyncio.run(main())
0
1
2
3
4
0
1
2
3
4
Total time: 3.0046119689941406
```

So now we can start using `awaitable` functionalities like `asyncio.sleep` which are already coroutines and can be called with the `await` keyword. If we want to create a function that has to be called in an async way, we need to add the `async` before the `def` keyword, like we are seeing in the `sleep` method.

To run multiple async methods we can use the `await asyncio.gather` providing all the coroutines, and it will run them asyncronously and return the control of the execution once they all resolve.

And then, the most important part here is how to start calling something async, we can't just call `main()`, we need to call a coroutine inside of an event loop, and there's a wrapper for this, we can use `asyncio.run` to call an async method without having to start ourselves the loop.

If we want to start it ourselves we should do something like this:

``` python
>>> import asyncio
>>> import time
>>> 
>>> async def sleep(duration, id_):
...     await asyncio.sleep(duration)
...     print(id_)
...     return id_
... 
>>> 
>>> start_time = time.time()
>>> loop = asyncio.get_event_loop()
>>> tasks = [loop.create_task(sleep(3, i)) for i in range(3)]
>>> loop.run_until_complete(asyncio.wait(tasks))
0
1
2
({<Task finished name='Task-2' coro=<sleep() done, defined at <stdin>:1> result=1>, <Task finished name='Task-3' coro=<sleep() done, defined at <stdin>:1> result=2>, <Task finished name='Task-1' coro=<sleep() done, defined at <stdin>:1> result=0>}, set())
>>> loop.close()
>>> print(f"Total time: {time.time() - start_time}")
Total time: 3.0085606575012207
```

So we use the `asyncio.get_event_loop` to create the event loop and then we add the tasks to the loop with `loop.create_task`. Then to await for all of them to finish we run `loop.run_until_complete(asyncio.wait(tasks))`.

## Async HTTP requests

Now, with `asyncio` and `aiohttp` we can implement a simple concurrent program to perform HTTP requests. Let's do an example doing requests to BMAT webpage first in sequential manner:

```python
>>> import requests
>>> import time
>>> 
>>> def run():
...     start_time = time.time()
...     for _ in range(3):
...         requests.get("https://www.bmat.com/")
...     print(f"Total time: {time.time() - start_time}")
... 
>>> run()
Total time: 3.1911020278930664
```

Ok, ~3 secs to load 3 times our web, each time we hit bmat.com we wait for the response, each request is 1 sec, so 3 times 3 secs, this is how we do an http request normally.

Now let's see how it's done async for doing a single request:

``` python
>>> import time
>>> import asyncio
>>> import aiohttp
>>> 
>>> async def main():
...     start_time = time.time()
...     async with aiohttp.ClientSession() as session:
...         async with session.get('https://www.bmat.com/') as resp:
...             await resp.text()
...     print(f"Total time: {time.time() - start_time}")
... 
>>> x = asyncio.run(main())
Total time: 0.973656177520752
```

Lot of stuff, for just a request, but the thing is that at every `async`/`await` step we are allowing the code to give away the control to schedule another IO call in the meantime.
It's important to understand that everything that is `async`, has to be defined with `async` and called with `await`.

And now running multiple requests concurrently would be something like this:

``` python
>>> import time
>>> import asyncio
>>> import aiohttp
>>> 
>>> async def fetch(session, id_):
...     async with session.get("https://www.bmat.com/") as response:
...         print(id_)
...         return await response.text()
... 
>>> async def main(num_requests):
...     start_time = time.time()
...     async with aiohttp.ClientSession() as session:
...         results = await asyncio.gather(*[fetch(session, i) for i in range(num_requests)])
...     print(f"Total time: {time.time() - start_time}")
... 
>>> x = asyncio.run(main(3))
1
0
2
Total time: 1.033045768737793
```

Notice that the order of the IDs is not sequential and the time instead of 3 seconds now is just 1 second. So we have it, we are doing HTTP requests concurrently.

But this is not pure magic, at the end there's only one single thread managing all the requests, and to be able to run the request and keep receiving the data while the Python code starts triggering a new request aiohttp has to bind the request somehow, for example using sockets, which open a file in disk. This has some overhead so we are not going to see these numbers when running 10, 1k or 100k concurrent requests, the amount of time is different. Let's see what happens with 4, 5, etc up to 10 requests:

``` python
>>> x = asyncio.run(main(4))
3
0
2
1
Total time: 1.4146854877471924
>>> x = asyncio.run(main(5))
1
4
3
2
0
Total time: 1.6316821575164795
>>> x = asyncio.run(main(6))
4
...
5
Total time: 1.8495571613311768
>>> x = asyncio.run(main(7))
0
...
4
Total time: 2.319329023361206
>>> x = asyncio.run(main(8))
7
...
5
Total time: 2.5303142070770264
>>> x = asyncio.run(main(9))
4
...
5
Total time: 2.90022611618042
>>> x = asyncio.run(main(10))
3
...
9
Total time: 3.095855236053467
```

We were expecting 1 second, but nope. With the `sleep` case we were having this scenario where 1 request is 1 sec and 10 requests are also 1 sec, just because it's an incredible simple example, but more complex logic is more expensive. For 10 requests instead of 1 second it's taking 3 seconds. Here the reason can be because of multiple factors but now the important is just to see that async is not magic and it's not going to "parallelize" everything. We are handling the async request from the client side, but we don't know how the server processes the requests, let's jump now to the server side.


## WSGI vs ASGI, Flask vs FastAPI

Now that we have the basics covered, let's see how to scale the throughput of our APIs. So let's talk about the most hyped Python HTTP microframeworks Flask and FastAPI:

[Flask](https://github.com/pallets/flask) is an amazing Python HTTP microframework that works perfectly fine under [`WSGI`](https://peps.python.org/pep-3333/). The problem with `WSGI` is that it can't process async requests, it can manage concurrency with threads and parallelization with multiple processes, but has no support for async. When you do a request to an API that speaks `WSGI`, with one single worker with one single thread with no buffer to keep incoming requests, that API gets blocked until the response is sent, so if in that endpoint there's a query to the database which takes 1 second and we are doing 2 requests per second, our API is going to take the first one at time 0, then another request will hit the API at 0.5 but our worker will be busy, so that request is not going to be answered, if the client has no retries then that request is lost (assuming our server has no buffer to retain incoming requests), then at second 1 our worker will be free again an will pick the new incoming request. At the best this is serving only 50% of the requests. Of course in production environments we have a web server in front with a buffer that can hold more incoming requests, we have multiple workers, each worker can have multiple threads, so normally this scenario shouldn't happen, it's for understanding the concept.

[FastAPI](https://github.com/tiangolo/fastapi) in the other hand comes by default as an async HTTP framework, with [`starlette`](https://github.com/encode/starlette) under the hood which works on top of [`anyio`](https://github.com/agronholm/anyio/) which comes on top of [`asyncio`](https://docs.python.org/3/library/asyncio.html). FastAPI is an [`ASGI`](https://asgi.readthedocs.io/) framework which removes the blocking that we mentioned that happens with `WSGI`. If we receive 2 requests per second and each request takes 1 second to process, in the previous scenario we could only serve 50% of the requests, but here we take advantage of the IO waiting time, we stop waiting for that response putting that request on hold and start serving another request for later coming back and checking if we got our answer.

Ok, all this theory is amazing but we want examples.

### Flask blocking example
Let's write a simple Flask server:

``` python linenums="1" title="syncflask.py"
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    return "Hello, World!"

app.run(host="localhost", port=5000, debug=True)
```

And to run it (you need Flask installed):
``` bash
python syncflask.py
```

### FastAPI non blocking example
Now the same but with FastAPI:

``` python linenums="1" title="asyncfastapi.py"
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    return "Hello, World!"
```

And to run it (with fastapi and uvicorn installed):
``` bash
uvicorn asyncfastapi:app --port 6000
```

From so on we assume that both servers are up and running:

- **Flask** on port **5000**
- **FastAPI** on port **6000**

### Flask vs FastAPI benchmarks

#### 1. No IO operation (sync client)
If we write a simple script to do multiple requests we can time how much it takes with each API:

``` python linenums="1" title="send_requests.py"
import time
import requests
from argparse import ArgumentParser

def do_requests(num_requests, port):
    time_start = time.time()
    for _ in range(num_requests):
        requests.get(f"http://localhost:{port}/")
    print(f"Total time: {time.time() - time_start}")


parser = ArgumentParser()
parser.add_argument("-n", type=int)
parser.add_argument("-p", "--port", type=int)
args = parser.parse_args()
do_requests(args.n, args.port)
```

And run it against the Flask one:
``` bash
$ python send_requests.py -n 1000 -p 5000
Total time: 7.125901222229004
$ python send_requests.py -n 1000 -p 5000
Total time: 6.348599672317505
$ python send_requests.py -n 1000 -p 5000
Total time: 7.197504043579102
$ python send_requests.py -n 1000 -p 5000
Total time: 7.170130968093872
$ python send_requests.py -n 1000 -p 5000
Total time: 5.129152774810791
$ python send_requests.py -n 1000 -p 5000
Total time: 6.3417487144470215

```

Here we see an average time of **~6.5 secs for 1k requests with a Flask app** with a default [Flask development web server](https://flask.palletsprojects.com/en/2.2.x/api/#flask.Flask.run) (later we will see what it means, but we keep it with default config for now).

Now let's run it against FastAPI:

``` bash
$ python send_requests.py -n 1000 --port 6000
Total time: 3.2903800010681152
$ python send_requests.py -n 1000 --port 6000
Total time: 5.905079126358032
$ python send_requests.py -n 1000 --port 6000
Total time: 3.923635959625244
$ python send_requests.py -n 1000 --port 6000
Total time: 5.07599663734436
$ python send_requests.py -n 1000 --port 6000
Total time: 5.8415305614471436
$ python send_requests.py -n 1000 --port 6000
Total time: 4.3278844356536865
```

Now we see an average **~4.7 secs with FastAPI** with a FastAPI API running with default [uvicorn](https://www.uvicorn.org/settings/) settings.

Some insights:

- We see an improvement in FastAPI but not significant
- There are no IO operations, so we can't see the real magic of async in place... so this example is not reflecting what we are looking for

#### 2. With IO operation: sleep (sync client)

Let's now do the same, but instead of with a `return "Hello World"` let's put a blocking operation. We will use the famous sleep (as we have it async with asyncio).

We will add only 0.01 sleep time, simulating a database query or a request to another API.

Flask:
``` python linenums="1" title="syncflask.py"
import time
from flask import Flask

app = Flask(__name__)

@app.route("/")
def hello_world():
    time.sleep(0.01)
    return "Hello, World!"

app.run(host="localhost", port=5000, debug=True)
```

FastAPI:
``` python linenums="1" title="asyncfastapi.py"
import asyncio
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
async def root():
    value = await asyncio.sleep(0.01, result="Hello, World!")
    return value

```

Now running the same test with Flask:
``` bash
$ python send_requests.py -n 1000 -p 5000
Total time: 19.909759759902954
$ python send_requests.py -n 1000 -p 5000
Total time: 19.927785873413086
$ python send_requests.py -n 1000 -p 5000
Total time: 19.863834381103516
```

**Average time of ~19.9 seconds with Flask**

And now running it with FastAPI:
``` bash
$ python send_requests.py -n 1000 -p 6000
Total time: 19.676589727401733
$ python send_requests.py -n 1000 -p 6000
Total time: 19.129466772079468
$ python send_requests.py -n 1000 -p 6000
Total time: 18.216043710708618
```

**Average time of ~19.5 seconds with FastAPI**

Mmmm... this doesn't look good, why we want async if it takes the same amount of time?

#### 3. Async client

Well, we have not changed how we are doing the requests yet. We are using a sync library to do the requests, our `requests` library is waiting in each request to get the response before running a new one. This goes against of what we want! We want to trigger multiple requests at the same time and with async we can do it, but our client has to support coroutines. So let's use `aiohttp` again:

``` python linenums="1" title="send_async_requests.py"
import time
import asyncio
import aiohttp
from argparse import ArgumentParser

async def fetch(session, url):
    async with session.get(url) as response:
        return await response.text()

async def main(num_requests, port):
    start_time = time.time()
    url = f"http://localhost:{port}/"
    async with aiohttp.ClientSession() as session:
        results = await asyncio.gather(*[fetch(session, url) for i in range(num_requests)])
    print(f"Total time: {time.time() - start_time}")


parser = ArgumentParser()
parser.add_argument("-n", type=int)
parser.add_argument("-p", "--port", type=int)
args = parser.parse_args()
x = asyncio.run(main(args.n, args.port))
```

Now let's run async requests against Flask which is not capable of handling async requests:
``` bash
$ python send_async_requests.py -n 1000 -p 5000
Total time: 1.348656415939331
$ python send_async_requests.py -n 1000 -p 5000
Total time: 1.3227081298828125
$ python send_async_requests.py -n 1000 -p 5000
Total time: 1.362738847732544
```

And with FastAPI:
``` bash
$ python send_async_requests.py -n 1000 -p 6000
Total time: 0.9639475345611572
$ python send_async_requests.py -n 1000 -p 6000
Total time: 0.8849890232086182
$ python send_async_requests.py -n 1000 -p 6000
Total time: 0.8873369693756104
```

Ok, there's a huge improvement when using an async client:

- Flask: from 19 secs to 1.3 (with 10k it's ~13 secs) -> **x14 times more requests with Flask**
- FastAPI: from 19 secs to 0.9 (with 10k it's ~9 secs) -> **x21 times more requests with FastAPI**

Ok, here we are in the same situation that we've seen, FastAPI is a bit faster than Flask but not this huge impact that we would expect by this complexity layer of the whole async world. Why this hype with async? Is it really only a 25-30% faster than Flask? What means faster?

Something being "faster" is relative, right? Let's see a different case, with different logic in the endpoint.

#### 4. Endpoint with multiple IO operations

Ok, let's now put an example where FastAPI really shines, where we can take advantage of async.

Let's put a total sleep time of 10 seconds, emulating a long time processing request, but with 10 sleeps of 1 second, like an endpoint that has to fetch data from multiple places, and repeat the test:

Flask:
``` python linenums="6" title="syncflask.py"
@app.route("/")
def hello_world():
    for _ in range(10):
        time.sleep(1)
```

FastAPI:
``` python linenums="6" title="asyncfastapi.py"
@app.get("/")
async def root():
    sleeps = [asyncio.sleep(1, result="Hello, World!") for _ in range(10)]
    values = await asyncio.gather(*sleeps)
```

And in the `send_async_request.py` let's specify to the `aiohttp.ClientSession` to send all the requests at once changing the limit of the connector:
``` python linenums="10" title="send_async_requests.py"
async def main(num_requests, port):
    start_time = time.time()
    url = f"http://localhost:{port}/"
    connector = aiohttp.TCPConnector(limit=num_requests)  # default is 100, let's send all at once
    async with aiohttp.ClientSession(connector=connector) as session:
        results = await asyncio.gather(*[fetch(session, url) for i in range(num_requests)])
    print(f"Total time: {time.time() - start_time}")
```

If we run it again we have:

Flask:
``` bash
$ python send_async_requests.py -n 1000 -p 5000
Total time: 11.881533145904541
$ python send_async_requests.py -n 1000 -p 5000
Total time: 13.658314943313599
$ python send_async_requests.py -n 1000 -p 5000
Total time: 11.199593782424927

```

FastAPI:
``` bash
$ python send_async_requests.py -n 1000 -p 6000
Total time: 2.330840826034546
$ python send_async_requests.py -n 1000 -p 6000
Total time: 2.3528292179107666
$ python send_async_requests.py -n 1000 -p 6000
Total time: 2.439707040786743
```

Here we start to see some improvements, we can perform 1k requests:

- **in FastAPI in ~2.4 secs**
- **in Flask in ~12 secs**

Much better performance now with FastAPI.

Also arrived to this point, it is worth to mention that Flask development web server is using threads by default (the amount of threads used depends on how many threads your machine can handle), that's the reason of seeing 1k requests with 10 secs of sleep each one resolved in 12 secs, in a totally synchronous program it would take 1_000 * 10 -> 10_000 secs.

What we are seeing here is the comparison of concurrency using coroutines in FastAPI and threads in Flask when having to process 10 IO operations * 1k requests, which means 10k IO operations concurrently.

We see in this specific case that FastAPI with coroutines has much higher throughput than Flask using threads, and in general, we can say that coroutines manage better the context switching than threads.

What is sure here is that after the learnings of WSGI and synchronous frameworks, smarter guys than us have decided to implement a new protocol called ASGI which replaces WSGI, and FastAPI has been released 8 years after Flask with all these learnings being totally async.

#### 5. Flask single-thread vs FastAPI single-thread (spoiler: this is the sexy chapter)

In FastAPI with uvicorn we are not processing the requests with threads, so for educational purposes, we can repeat this test disabling the threads of Flask adding `threaded=False`:

``` python linenums="12" title="syncflask.py"
app.run(host="localhost", port=5000, debug=True, threaded=False)
```

Now we see the reality, Flask with one single thread is taking 10 seconds per each request, and this will mean that some of them will die, our clients will have timeouts, or the web server in front of Flask could have another timeout (nginx default is 60 secs). When running now our async client to trigger 1000 concurrent requests we have this output:

``` bash
$ python send_async_requests.py -n 1000 -p 5000
Traceback (most recent call last):
  File "send_async_requests.py", line 27, in <module>
    results = loop.run_until_complete(do_requests(args.n, args.port, loop))
  File "/usr/lib/python3.8/asyncio/base_events.py", line 616, in run_until_complete
    return future.result()
  File "send_async_requests.py", line 15, in do_requests
    results = await asyncio.gather(
  File "send_async_requests.py", line 7, in fetch
    async with session.get(url) as response:
  File "/home/oalfonso/.virtualenvs/test/lib/python3.8/site-packages/aiohttp/client.py", line 1141, in __aenter__
    self._resp = await self._coro
  File "/home/oalfonso/.virtualenvs/test/lib/python3.8/site-packages/aiohttp/client.py", line 560, in _request
    await resp.start(conn)
  File "/home/oalfonso/.virtualenvs/test/lib/python3.8/site-packages/aiohttp/client_reqrep.py", line 899, in start
    message, payload = await protocol.read()  # type: ignore[union-attr]
  File "/home/oalfonso/.virtualenvs/test/lib/python3.8/site-packages/aiohttp/streams.py", line 616, in read
    await self._waiter
aiohttp.client_exceptions.ClientOSError: [Errno 104] Connection reset by peer
```

Which means that our Flask server is not answering to our requests.

This is the real problem, when our server is full loaded and can't take more requests there are requests that just die, and the worst of this is that the server is not really working, is just waiting! Is lazing around, waiting for a 3rd program to deliver the needed goods. Like a waiter that orders a dish to the kitchen and waits there idle for the whole 5 minutes that can take preparing that dish instead of doing other things in the meantime.

So:

With this scenario:

- 1 single thread and 1 single process in FastAPI
- 1 single thread and 1 single process in Flask
- 1000 async requests
- 10 IO operations, 1 sec each one

We have that:

- Flask:
    - takes 10_000 seconds to process
    - some requests can't be even answered, so clients get no response
- FastAPI:
    - takes 2.4 seconds to process
    - not a single request gets a timeout

I've not raised until now the fact that Flask is working with threaded mode by default because indeed comparing 1 thread of FastAPI vs 1 thread of Flask is not fair, because is very common to configure the wsgi app to work with threads, which perform a good concurrency job. When a thread hits networking it switches to another thread, so it's similar to how async await works. But I wanted to show it just to demonstrate the real difference of 1 thread async vs 1 thread sync.

## Conclusions

- There's no magic wand here, if we want to be able to process more requests concurrently we have to do a good job implementing an async API with all it's IO operations properly handled
- Async properly handled is really powerful
- APIs with not too many IO operations or IO operations poorly handled (not properly async handled) can have a similar performance than Flask, but even in those cases FastAPI usually performs better
- In the most strict (and artificial) case of 1 sync thread vs 1 async thread we've seen an humongous difference, FastAPI can process the same amount of requests 4000 times faster (again, with an artificial and forced example just to demonstrate the weakness of not using concurrency)
- There's no real/absolute benchmark, it depends on each endpoint and each case, but on the average, FastAPI performs better
