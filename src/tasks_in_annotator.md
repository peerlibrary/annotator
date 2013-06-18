## Using tasks in Annotator

The document at [tasks_introduction.coffee.md](tasks_introduction.coffee.md) describes the features and usage of the task system. In this document, I will describe how this is used in Annotator

### Constructor and initialization

#### Overview
Originally, the constructor of Annotator did everything that had to be done to set up Annotator; the returned Annotator instance was fully operational.

However, when working with longer documents, this init process might take too long. (In same cases, even minutes.) Locking the browser for this long can be a problem for the user in some cases.

Therefore, we have introduced the feature of asynchronous initialization.

However, we can't just break the previously existing API of Annotator (by returning a half-initialized instance from the constructor), so this feature is optional; Annotator can still be used exactly the way it was used before. For an example about the traditional usage, see [demo.html](../demo.html#L88) and [dev.html](../dev.html#L103).

#### Usage and API

The constructor of Annotator takes an argument called `options`. The following keys of this map are relevant:
 * `asyncInit`: if set to true, will use the asynchronous init process. (Default is false.) When using this, the created instance is not necessarily ready to be used upon the constructor's return. You can access the promise in the 'init' field. For an example of using Annotator this way, see [dev_async.html](../dev_async.html#L103).
 * `noInit`: don't run any init process. If this param is passed, the instance is no initiated at all by the constructor. It's up the the user to call either `initSync()` or `initAsync()` later on.
 * `noScan`: while initializing, skip scanning the document. (This works with both the sync and the async init process.) This scan is required for creating or re-attaching annotations, but there are situations which can benefit from postponing this process to some other time.

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
   * "wrapper" - Wraps the children of the selected element in a wrapper div, and remove any script elements inside these elements to prevent them re-executing.
   * "adder" - Add the adder button
   * "viewer & editor" - Creates an instance of `Annotator.Viewer` and of `Annotator.Editor`, and append them to the wrapper.
   * "scan document" - Traverse and scan the document, preparing the data structures required for reattaching annotations. (Since this is a repeating task, scanning is implemented as a task generator. The init process then creates a scan task with this generator, and inserts it to the init task.)
   * "document events" - Sets up the selection event listeners used for annotating
   Most of these functions have received their separate tasks, because they involve some kind of DOM operation which can be slow for bigger document, and therefore it's useful to break them up to smaller chunks, so that the browser can stay (relatively) responsive while there are working.

The dependencies between these events are explained in comments, see the code.

### Loading/initializing plugins

Initializing the plugins can happen in an asynchronous way, too. However, it must work in synchronous mode, too. Furthermore, it's not required that every plugin explicitly adds support for asynchronous operation; the ones that does not can still live in the new system.

So, we handle the following cases:
 * Annotator running in sync mode, loading any plugin: nothing changes, everything works like it used to. In the plugin, the `pluginInit()` method is executed (if exists).
 * Annotator running in async mode, loading a plugin that explicitly supports async init:
   * First, the plugin is instantiated, as usual.
   * Annotator checks whether it has an `initTaskInfo` field. This field marks the support of async init of this plugin.
   * A new task is created, according to the recipe contained in the initTaskInfo.
   * If the initialization task of Annotation has is still running (or has not yet started), then this new task is inserted as a sub-task into this composite task. (Otherwise, it is simple created as a separate task.) This means that if a plugin is loaded while initializing Annotator, it will be able to wait for any required dependencies, and the init process will only be declared finished if the plugin has finished initializing, too. The end result is that you can simply launch your events on completion of the init task; the requested plugins are guaranteed to be alive, too.
   
 * Annotator running in async mode, loading a legacy plugin (ie. one that does not have async support):
   * The plugin is instantiated
   * Annotator sees that it does not have an `initTaskInfo` field, which means it does not support for async init.
   * A new task is created as a wrapper around the plugin's `pluginInit()` method, using any task dependencies specified in the plugin's `deps` field.
   * If the init task is still in progress (or is waiting), the new task is inserted as a sub-task, the same way it's handled with async plugins, see above.


### Specific operations

#### Auth plugin

The async init task does this:
 * If a token was specified in the options, the task is resolved immediately.
 * Otherwise, a token request is sent out. The task is resolved/rejected according to the results of this request.

The name of this task is *"auth token"*.

Any operation that depends a valid auth token is supposed to depend on this task.

Earlier, there was a method to register callbacks to be called then the token becomes available: the `withToken()` method. This method of control is now redundant, and when running Annotator in async mode, it conflicts with the task system (because it meddles with the request), so using the withToken() method in asynchronous mode is now forbidden. (It will throw an exception.) Just depend on the "auth token" task.

#### Permissions plugin

The permissions plugin can use the auth token, but can be used independently, too. If you want to use it independently, specify the `ignoreToken` option for this plugin. If you don't do this, then a dependency to "auth token" is automatically added to the dependencies of this plugin. 

This changes earlier behaviour, because until now, whether or not the permission plugin uses the auth plugin was decided by the order of the loading of these plugins. Now the order does not count, since the init tasks are scheduled automatically, independently of the loading order. Therefore, you can now control this optional dependency by this new parameter on the permission plugin.

#### Store plugin

Since the loading of the annotations is a repeating task (for example, see login/logout), the async init task for the store plugin sets up a task generator for this, and then immediately creates a new task for the initial loading of annotations. (Except when the `noLoading` option is set, which means that no initial loading is required.) If this happens during init, then This initial loading task is inserted to the Annotator's init task, too.

Later, you can trigger a new loading using the `startLoading` method of the plugin. This method also accepts an optional list of extra URIs to look up for cross-document annotations. The method returns the new loading task (created by the loading task generator), so you can use it as a promise.

#### About scanning, again

To be able to create annotations, or to re-attach old ones, the dom-text-mapper library needs to have some data about document. The process where this data is collected is called *scanning*.

Usually, the DOM is scanned when initializing Annotator.

Scanning can be done synchronously (=blocking) and asynchronously (=non-blocking).
(The dom-text-mapper library supports both ways of operations.) 

During Annotator's init process,
 * if running in sync mode, a sync scan is launched.
 * if running in async more, an async scan is launched (as a task).
 * if the `noScan` option is set, no scan is launched.

If you need to manually launch a new scan later, you can do this
 * by calling the `_scanSync()` method (which does a blocking, sync scan)
 * by calling the `_scanAsync()` method (which does an unblocking, async scan, returning a promise)
 * by creating (and scheduling) a task using the task generator saved in the `_scanGen` field. (This is the recommended way to do it, because this way, you can easily add dependencies for this step, which is often useful during initializing the system.

The dom-text-mapper library needs to keep it's data structures current. It does not ([yet](https://github.com/hypothesis/dom-text-mapper/issues/3)) auto-detect changes in the DOM; for now, anybody who changes something in the DOM is supposed to call `DomTextMapper.changed()`, with the changed node. This will make all instances of d-t-m (containing the given node) to perform an incremental update of the DOM mapping data. Currently, this is done in a synchronous (=blocking) mode, but since local changes tend to be small, hopefully this won't cause too much waiting for the user.

#### Anchoring annotations

Anchoring annotations is a repeating task, so we have a generator for it.
Furthermore, it is done in batches (of 10); so actually, we have two kind of related tasks, and thus two generators:
 * one for the individual batches of annotations (stored in the field `loadBatchTaskGen`), and
 * one for the composite tasks, containing all the batch tasks as sub-tasks.

This is how the flow control of anchoring goes:
 * Annotator's `loadAnnotations()` is called by the Store plugin, delivering a list of annotations that it has loaded. (This may happen repeatedly, if the Store plugin was instructed to load annotations from several different sources, or for several different documents at once.)
 * `loadAnnotations()` checks whether there is an active load task. If there is none, it creates one (using the generator), and stores it in the field `pendingLoading`.
 * The newly received list of annotations is sliced to batches of 10, and for all batches, a new batch task is created (using the generator), for dealing with this batch of annotations. These batch tasks are added to the composite tasks as a sub-task. 
 * When all new tasks are prepared, they are scheduled.
 * As the batch tasks are executed, they call `setupAnnotation()` for each annotations.

#### Future directions

I have ported to tasks only the parts which were needed to make Hypothes.is work in async mode.
There are probably several more internal operations could be ported to promises / tasks.

(For example, setupAnnotation could return a task, which could be announced in the relevant events, etc.)

Please feel free to suggest / implement improvements.
