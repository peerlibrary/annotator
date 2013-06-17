## Using tasks in Annotator

The document at [tasks_introduction.coffee.md](tasks_introduction.coffee.md) describes the features and usage of the task system. In this document, I will describe how this is used in Annotator

### Constructor and initialization

#### Overview
Originally, the constructor of Annotator did everything that had to be done to set up ANnotator; the returned Annotator instance was fully operational.

However, when working with longer documents, this init process might take too long. (In same cases, even minutes.) Locking the browser for this long can be a problem for the user in some cases.

Therefore, we have introduced the feature of asynchronous initialization.

However, we can't just break the previously existing API of Annotator (by returning a half-initializet instance from the constructor), so this feature is optional; Annotator can still be used exacly the way it was used before. For an example about the traditional usage, see [demo.html](../demo.html#L88) and [dev.html](../dev.html#L103).

#### Usage and API

The constructor of Annotator takes an argument called `options`. The following keys of this map are relevant:
 * `asyncInit`: if set to true, will use the asynchronous init process. (Default is false.) When using this, the created instance is not necesseraly ready to be used upon the constructor's return. You can access the promise in the 'init' field. For an example of using Annotator this way, see [dev_async.html](../dev_async.html#L103).
 * `noInit`: don't run any init process. If this param is passed, the instance is no initiated at all by the constructor. It's up the the user to call either `initSync()` or `initAsync()` later on.
 * `noScan`: while initializing, skip scanning the document. (This works with both the sync and the async init process.) This scan is required for creating or re-attaching annotations, but there are situations which can benefit from postpoing this process to some other time.

#### Implementation details

Most of the code for initialization has been moved out from the constructor to different methods. There are now two code paths, triggered by the `initSync()` and `initAsync()` methods. (By default, the constructor will call `initSync()`, but see the options described above.)

When using the async code path (the `initAsync()` methods), this is what happens:
 * The `asyncMode` field is set to true. (This is used later to detect async operation.)
 * The default set of async init tasks are created by the `defineAsyncInitTasks()` method. The `init` field will hold the main task, which holds all other sub-tasks. You can use this field (as a promise) to schedule events to run when the initialization process is complete. (See below for more details on the tasks.)
 * `schedule()` is called on the task manager, thus executing all the tasks.
 
The point of putting the definition of the tasks into a separate method (`defineAsyncInitTasks()`) is to make it easier for derivative projects to add new parts, or override existing parts of the init process. (Hint: tasks can be overridden by defining a new task with the same name.)

So, here are the defined tasks:

 * "Booting Annotator" is a composite tasks, consisting of the following sub-tasks:
   * "dynamic CSS styles" - Sets up any dynamically calculated CSS for the Annotator.
   * "wrapper" - Wraps the children of the selecte delement in a wrapper div, and remove any script elements inside these elements to prevent them re-executing.
   * "adder" - Add the adder button
   * "viewer & editor" - Creates an instance of `Annotator.Viewer` and of `Annotator.Editor`, and append them to the wrapper.
   * "scan document" - Traverse and scan the document, preparing the data structures required for reattaching annotations.
   * "document events" - Sets up the selection event listeners used for annotating
   Most of these functions have received their separate tasks, because they involve some kind of DOM operation which can be slow for bigger document, and therefore it's useful to break them up to smaller chunks, so that the browser can stay (relatively) responsive while there are working.

The dependencies between these events are explained in comments, see the code.

### Loading/initializing plugins

### Other operation
