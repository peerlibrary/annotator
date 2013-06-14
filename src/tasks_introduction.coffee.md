## Introduction to tasks

### About this document

This is a short introduction to the Task system.

This file is written in [Literate CoffeeScript](http://ashkenas.com/literate-coffeescript/).

The recommended way to read it is to view it at GitHub, so that the markup is rendered properly. (And after [this](https://github.com/github/markup/pull/192) will be merged, there will also be syntax highlighting for the code parts.)

To actually see the results of the code bellow, open **task_demo.html** in the root directory of this project.

### What is a task?

The purpose of the Task system is to provice an easy way to work with asynchronous, inter-dependent tasks.

It's based on jQuery's [Deferred / Promise API](http://api.jquery.com/jQuery.Deferred/), and adds a bunch of new features.

A task is an individual unit of work. It typically (but not necesseraly) involves (or depends on) some asynchronous operation.

Tasks support automatic dependency management and scheduling.

### The task manager

To do anything with tasks, first you need a task manager:

    tasks = new TaskManager()

Usually you only need one task manager in a given application.

Since in this demo, we would like to see what's going on with our tasks, we register a generic progress notifier function on our task manager, which will be automatically attached to all the created tasks:

    tasks.addDefaultProgress (info) =>
      console.log info.task._name + ": " + info.progress + " - " + info.text

### Creating a task

Now let's create a task!

    task_A = tasks.create
      code: (task) =>
        console.log "Here we go!"
        task.ready()

The task we created above is the simplest task we can create. The `create` method takes a map of options; we will review the most important options shortly. In this example, we only used the `code` key, which defines the function to run when the task is to be executed. It will receive a `task` argument, which is used to signal state changes in the task. (Completion, failure, progress info.) It's similar to jQuery's Deferred object, but it's methods are intercepted, so that the task manager is notified about changes, too.

In this example, we simply signal that the task is ready.

The object returned by the `create` method is basically a [jQuery deferred promise](http://api.jquery.com/deferred.promise/), so you can register callbacks [the usual way](http://api.jquery.com/deferred.done/):

    task_A.done -> console.log "Task A is done!"

### Executing a task

Creating a task does not automatically start it. (This is useful because you might want to mess with the dependencies after you have created the task, but before you execute it.) So to start available task, we must tell the task manager to "schedule" all defined tasks.

    tasks.schedule()

Since the task defined in our first example does not have any dependencies, it will be executed immediately. After it has finished, the callback we have registeres will be run, too.

### Two approach to dependencies

Let's define some more tasks:

    tasks.create
      name: "task B"
      deps: ["task C"]
      code: (task) =>
        console.log "B"
        task.ready()
 
    task_C = tasks.create
      name: "task C"
      code: (task) =>
        console.log "C"
        task.ready()

    task_C.done -> console.log "Task C is done!"

    tasks.schedule()

A few things to notify here:
 * We have added names to our tasks, using the `name` option. (Useful understanding debug output, and also for declaring dependencies.)
 * We have introduced two dependencies:
   * We have manually registered a callback on *task C*.
   * We have added a declarative dependency (with the `deps` option) to *task B*: *task B* won't be run until *task C* is finished.

