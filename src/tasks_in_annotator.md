## Using tasks in Annotator

The document at [tasks_introduction.coffee.md](tasks_introduction.coffee.md) describes the features and usage of the task system. In this document, I will describe how this is used in Annotator

### Constructor and initialization

#### Overview
Originally, the constructor of Annotator did everything that had to be done to set up ANnotator; the returned Annotator instance was fully operational.

However, when working with longer documents, this init process might take too long. (In same cases, even minutes.) Locking the browser for this long can be a problem for the user in some cases.

Therefore, we have introduced the feature of asynchronous initialization.

However, we can't just break the previously existing API of Annotator (by returning a half-initializet instance from the constructor), so this feature is optional; Annotator can still be used exacly the way it was used before. For an example about the traditional usage, see the [../dev_async.html].

#### Usage and API

The constructor of Annotator takes an argument called `options`. The following keys of this map are relevant:
 * asyncInit: if set to true, will use the asynchronous init process. (Default is false.) When using this, the created instance is not necesseraly ready to be used upon the constructor's return. You can access the promise in the 'init' field. For an example of using Annotator this way, see the [../dev_async.html]
 * noInit: don't run any init process. If this param is passed, the instance is no initiated at all by the constructor. It's up the the user to call either initSync() or initAsync() later on.
 * noScan: while initializing, skip scanning the document. (This works with both the sync and the async init process.) This scan is required for creating or re-attaching annotations, but there are situations which can benefit from postpoing this process to some other time.

#### Implementation details

### Loading/initializing plugins

### Other operation
