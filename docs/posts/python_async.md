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
- as coroutines work in a single thread there's much more control over race conditions (when managed properly) and easier debugging

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

For an HTTP request we normally use `requests` library or `urllib3` because it's the builtin, but both are blocking, so we will have to wait until each request finishes. To be able to do requests concurrently we need to implement something like what we've seen in this snippet but for performing an HTTP request non blocking. And this is what does `aiohttp` which implements websockets to retrieve the data of that request in a non-blocking manner. For more details of this library you can check the code on github [https://github.com/aio-libs/aiohttp]().

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
def mycoro():
    c = 0
    for i in range(10):
        c += yield i
        print(f"Inside of generator value of c {c}")
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

Did you see? We are returning always the value of `i` which is defined by the `range` but we are also sending arbitrary numbers that change the behaviour of the generator.
This is now a coroutine!

### Replace the concurrent example with coroutines

Let's replace our initial example of the `Task` and our event loop where we do concurrent sleeps, but now with coroutines:

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

That's it, we can concurrently handle sleeps with coroutines, sending a value every time we call the coroutine (which in this case is a None) and getting back also a value which is yielded.

But we don't want to be the ones managing this complexity, so we can use better tools and this feature of having bidirectional communication is the one used under the hood of [`async` and `await`, the two new keywords added since Python 3.5](https://docs.python.org/3/whatsnew/3.5.html#whatsnew-pep-492). Also, this feature is the one used to build [asyncio](https://docs.python.org/3/library/asyncio.html), the default Python way to work with async.

So now we can forget everything about coroutines and focus on these beautiful improved tools that make everything much more friendly.

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

Now, with asyncio and aiohttp we can implement a simple concurrent program to perform HTTP requests. Let's do an example doing requests to BMAT webpage first in sequential manner:

```python
>>> import requests
>>> import time
>>> 
>>> start_time = time.time()
>>> for i in range(5):
...     iter_time = time.time()
...     _ = requests.get("https://www.bmat.com/")
...     print(f"Iteration {i}, time: {time.time() - iter_time}")
... 
Iteration 0, time: 1.0509614944458008
Iteration 1, time: 0.9052777290344238
Iteration 2, time: 1.0390279293060303
Iteration 3, time: 0.9445846080780029
Iteration 4, time: 1.001107931137085
>>> print(f"Total time: {time.time() - start_time}")
Total time: 4.945826292037964
```

Classical way of doing it.

Now let's see how it's done async for doing a single request:

``` python
import asyncio
import aiohttp

async def main():
    async with aiohttp.ClientSession() as session:
        async with session.get('https://www.bmat.com/') as resp:
            resp.status
            await resp.text()

asyncio.run(main())
```

Lot of stuff, for just a request, but the thing is that at every `async`/`await` step we are allowing the code to give away the control to schedule another IO call in the meantime.
But it's important to understand that everything that is `async`, has to be defined with `async`, and everything that is `async` has to be called with `await`.

So running multiple requests concurrently would be something like this:

``` python
>>> import asyncio
>>> import aiohttp
>>> import time
>>> 
>>> 
>>> async def fetch(session, url):
...     async with session.get(url) as response:
...         return await response.json()
... 
>>> 
>>> async def fetch_all(urls, loop):
...     async with aiohttp.ClientSession(loop=loop) as session:
...         results = await asyncio.gather(
...             *[fetch(session, url) for url in urls],
...             return_exceptions=True,
...         )
...         return results
... 
>>> 
>>> start_time = time.time()
>>> urls = ['https://www.bmat.com/' for _ in range(3)]
>>> loop = asyncio.get_event_loop()
>>> htmls = loop.run_until_complete(fetch_all(urls, loop))
>>> loop.close()
>>> print(len(htmls))
3
>>> print(f"Total time: {time.time() - start_time}")
Total time: 1.1772162914276123
```

So we have it! We can do HTTP requests concurrently!

But this is not pure magic, at the end there's only one single thread managing all the requests, and to be able to run the request and keep receiving the data while the Python code starts triggering a new request aiohttp has to bind the request somehow, and it's using websockets, which open a file in disk where the data is being streamed. This has some overhead so we are not going to see these numbers when running 100 concurrent requests, the amount of time is different, let's see what happens with 100:

``` python
>>> start_time = time.time()
>>> urls = ['https://www.bmat.com/' for _ in range(100)]
>>> loop = asyncio.get_event_loop()
>>> htmls = loop.run_until_complete(fetch_all(urls, loop))
>>> loop.close()
>>> print(len(htmls))
100
>>> print(f"Total time: {time.time() - start_time}")
Total time: 41.78710341453552
```

We were expecting 1 second, but nope. We can see that with the `sleep` case because it's an incredible simple example, but real world cases are much more complex.


## WSGI vs ASGI, Flask vs FastAPI

Now that we have the basics covered, let's move closer to the real world problems that we have in our jobs every day. How to scale the throughput of our APIs.

Flask is an amazing Python HTTP microframework that works perfectly fine under WSGI. The problem with WSGI is that it can't process async requests. When you do a request to an API that speaks WSGI, that worker gets blocked until the response is sent, so if there are hundreds of hits to the database and the request lasts 30 seconds to resolve, that process will be completely blocked for those full 30 seconds.

FastAPI in the other hand comes by default as an async HTTP framework, with starlette under the hood, an ASGI framework which removes the blocking that we mentioned that happens with WSGI. A request that will hit the database 100 times, if all of those requests are done with async clients we will be able to trigger the query to the database and then start serving another request in the meantime.

Ok, all this theory is amazing but we want examples.

### Flask blocking example
TODO

### FastAPI non blocking example
TODO

### Flask vs FastAPI benchmark
TODO
