## Introduction to tasks

### About this document

This is a short introduction to the Task system.

This file is written in [Literate CoffeeScript](http://ashkenas.com/literate-coffeescript/).

The recommended way to read it is to view it at GitHub, so that the markup is rendered properly. (And after [this](https://github.com/github/markup/pull/192) will be merged, there will also be syntax highlighting for the code parts.)

To actually see the results of the code bellow, open **task_intro.html** in the root directory of this project.

### What is a task?

The purpose of the Task system is to provice an easy way to work with asynchronous, inter-dependent tasks.

It's based on jQuery's [Deferred / Promise API](http://api.jquery.com/jQuery.Deferred/), and adds a bunch of new features.

A task is an individual unit of work. It typically (but not necesseraly) involves (or depends on) some asynchronous operation.

Tasks support automatic dependency management and scheduling.

### The task manager

To do anything with tasks, first you need a task manager:

    tasks = new TaskManager()

Usually you only need one task manager in a given application, but to avoid mixing the different test cases, we will use several.

Since in this demo, we would like to see what's going on with our tasks, we will register a generic progress notifier function on our task managers, which will be automatically attached to all the created tasks:

    tasks.addDefaultProgress (info) =>
      console.log info.task._name + ": " + 
        info.progress + " - " + info.text

### Creating a task

    case1 = ->

Now let's create a task!

      task_A = tasks.create
        code: (task) =>
          console.log "Here we go!"
          task.resolve()

The task we created above is the simplest task we can create. The `create` method takes a map of options; we will review the most important options shortly.

In this example, we only used the `code` key, which defines the function to run when the task is to be executed. It will receive a `task` argument, which is used to signal state changes in the task: [Resolve](http://api.jquery.com/deferred.resolve/), [reject](http://api.jquery.com/deferred.reject/), [notify](http://api.jquery.com/deferred.notify/). (It's basically a [Deferred object](http://api.jquery.com/category/deferred-object/), but some of it's methods are intercepted, so that the task manager is notified about changes, too.)

In this example, we simply signal that the task is ready.

The object returned by the `create` method is basically a [jQuery Deferred Promise](http://api.jquery.com/deferred.promise/), so you can register callbacks [the usual way](http://api.jquery.com/deferred.done/):

      task_A.done -> console.log "Task A is done!"

### Executing a task

Creating a task does not automatically start it. (This is useful because you might want to modify with the dependencies before you execute it.) So to start available task, we must tell the task manager to "schedule" all defined tasks.

      tasks.schedule()

Since the task defined in our first example does not have any dependencies, it will be executed immediately. After it has finished, the callback we have registeres will be run, too.

The output looks like this:

 * Nameless task #1: 0 - Starting tasks_introduction.js:8
 * Here we go! tasks_introduction.js:16
 * Nameless task #1: 1 - Finished in 7ms. tasks_introduction.js:8
 *  Task A is done! 

### Two approach to dependencies

    case2 = ->

Let's define some more tasks:

      tasks.create
        name: "task B"
        deps: ["task C"]
        code: (task) =>
          console.log "B"
          task.resolve()
 
      task_C = tasks.create
        name: "task C"
        code: (task) =>
          console.log "C"
          task.resolve()

      task_C.done -> console.log "Task C is done!"

      tasks.schedule()

A few things to notify here:
 * We have added names to our tasks, using the `name` option. (Useful understanding debug output, and also for declaring dependencies.)
 * We have introduced two dependencies:
   * We have manually registered a callback on *task C*.
   * We have added a declarative dependency (with the `deps` option) to *task B*, so that *task B* won't be run until *task C* is finished.
   The second way of defining dependencies is more flexible; see bellow.

A task can depend on any number of other tasks, and it's execution will only start when all the dependencies have been fulfilled.

In this example, `schedule` will first run *task C* (since it does not have any dependency), and when it's ready, it will execute (in an unspecified order) *Task B* and the manually registered callback.

The output will look like this:

 * task C: 0 - Starting tasks_introduction.js:8
 * C tasks_introduction.js:40
 * task C: 1 - Finished in 1ms. tasks_introduction.js:8
 * Task C is done! tasks_introduction.js:45
 * task B: 0 - Starting tasks_introduction.js:8
 * B tasks_introduction.js:33
 * task B: 1 - Finished in 0ms. 

### Changing dependencies on the fly

    case3 = ->

When declaring dependencies using the `deps` option, you can specify a list. Each element can be an existing Task object, or the name of an existing Task object, or the name of a Task object to be created later.

You can also add and remove dependencies after the task have been created, like this:

      task_D = tasks.create
        name: "task D"
        code: (task) =>
          console.log "D"
          task.resolve()

      tasks.create
        name: "task E"
        code: (task) =>
          console.log "E"
          task.resolve()

      tasks.create
        name: "task F"
        code: (task) =>
          console.log "F"
          task.resolve()

      tasks.addDeps "task D", "task E"   # task D depends on task E
      task_D.addDeps "task F"            # task D depends on task F

      tasks.schedule()

This will make *task D* depend on *task B*, *task E* and *task F*. Both shown methods do the same; you can add dependencies both using the task manager, and using the task objects themselves. Both can accept individual tasks, or lists of tasks. There also have `removeDeps` methods, doing what the name says.

Please note that the changed dependencies only take effect if you `schedule` the tasks on the task manager. If a given task is already running, then changing it's dependencies won't have any effect.

### Asynchronous tasks

    case4 = ->
 
This is how to run define asynchronous tasks:

      tasks.create
        code: (task) =>
          console.log "Here we go!"
          setTimeout (=>
            task.resolve()
          ), 500

      tasks.schedule()

      setTimeout (-> console.log "Go! Go1"), 200

In this case, the output will look like this:
 * 

### Failing tasks

### Composite tasks

### Task generators

### Dummy tasks

### Other tricks
