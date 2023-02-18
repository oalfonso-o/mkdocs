# Python coroutines and asyncio

What is this about? We want to make Python IO operations (http requests, database requests, disk operations...) non blocking. For example, let's say we have to fetch the data of 3 different URLs, by default it would be something like this:

- request.get(url1) -> 3 sec wait
- request.get(url2) -> 3 sec wait
- request.get(url3) -> 3 sec wait

Total wait time requesting the data sequentially: 9 secs

We want to do these 3 requests at the same time and wait a total time of 3 secs.

We can achieve this with *concurrency*, and a way of concurrency in a single thread in Python is using coroutines and the default library for this paradigm is [asyncio](https://docs.python.org/3/library/asyncio.html).

## Why not using threads?

Good question, using multiple threads in Python is another way of concurrency. In Java or Rust multithreading can parallelize the computation but in Python (CPython) because of the GIL only one thread can be working at the same time inside of the same process (concurrency).
So which are the differences? Let's mention the two main benefits of coroutines vs threads:

- coroutines live in a single thread and single process and can have millions of them working concurrently, but when doing threads we can't spawn this amount of threads per process because we have the OS limitation
- as coroutines work in a single thread there's much more control over race conditions (when managed properly) and easier debugging

## And why not multiprocessing?

Multiprocessing is a good way to get advantage of the multiple cpus available. For operations that are pure cpu it works perfectly. It also can parallelize IO operations but just as much as processes can handle the OS, so there's a limit. Also the communication between processes is not straightforward as each new process has to create a new stack and a new heap, memory is not shared so all the data has to be serialized. All of these has an extra cost that we don't have to face with coroutines.


## Ok, so what is a co-routine?

From the official [docs](https://docs.python.org/3/glossary.html#term-coroutine):

!!! info ""

    Coroutines are a more generalized form of subroutines. Subroutines are entered at one point and exited at another point. Coroutines can be entered, exited, and resumed at many different points. They can be implemented with the async def statement. See also [PEP 492](https://peps.python.org/pep-0492/).

In other words, are Python generators, so methods returning values with `yield` used wisely to take advantage of that `yield`, of that give away of the control of the execution to iterate multiple generators concurrently. So in a co-routine we can start an IO operation, return the control of the execution, call another co-routine, this other co-routine can start another IO operation and then we can go back to the first one and check if that IO operation has finished.

## Let's see an example, concurrent sleeps with vanilla Python

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

Now let's rewrite it, without coroutines yet, nor async frameworks, but in a way that can be performend concurrently. To achieve this we have to change the paradigm a lot, because we are not going to use the sleep blocking method, we are going to implement the logic in a different way, to check with our own logic if we reached the condition of waiting 3 seconds, entering into the task, checking if has passed 3 seconds, and leaving if not.

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

But here we are going to fast, let's not jump yet to `aiohttp`, let's try to understand better how coroutines work, because we've seen how to do sleeps concurrently but we've not seen any `yield` not generator. Let's see another example and we will understand how `yield` plays in this game and what coroutines are.

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

No mistery here, a classical generator. You iterate it and it keeps yielding each value back. But the generator has a method called [`send`](https://docs.python.org/3/reference/expressions.html#generator.send) which we can use to provide a value to the generator:

``` python

```
