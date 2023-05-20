The project makes heavy use of the crate [tokio](https://tokio.rs/tokio/tutorial) which is an *asynchronous runtime* for Rust. Tokio provides the infrastructure, building blocks, pieces, etc, for writing networked applications. At a high level Tokio provides:

  - A multi-threaded runtime to execute async code
  - An async version of the standard library
  - A larger ecosystem of libraries

It's important to note that async Rust code does not run by itself, and thus requires a runtime to execute it. 

There are some instances though where using Tokio is not appropriate: 

  - Speeding up CPU-bound computations by running them in parallel on several threads. Tokio is designed for IO-bound applications where each individual task spends most of its time waiting for IO. If the only thing your application does is run computations in parallel, you should be using rayon. That said, it is still possible to "mix & match" if you need to do both.

  - Reading a lot of files. Although it seems like Tokio would be useful for projects that simply need to read a lot of files, Tokio provides no advantage here compared to an ordinary threadpool. This is because operating systems generally do not provide asynchronous file APIs.

  - Sending a single web request. The place where Tokio gives you an advantage is when you need to do many things at the same time. If you need to use a library intended for asynchronous Rust such as reqwest, but you don't need to do a lot of things at once, you should prefer the blocking version of that library, as it will make your project simpler. Using Tokio will still work, of course, but provides no real advantage over the blocking API. If the library doesn't provide a blocking API, see the chapter on bridging with sync code.


