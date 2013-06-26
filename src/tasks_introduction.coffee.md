## Introduction to tasks

### About this document

This is a short introduction to the Task system.

This file is written in [Literate CoffeeScript](http://ashkenas.com/literate-coffeescript/).

The recommended way to read it is to view it at GitHub, so that the markup is rendered properly. (And after [this](https://github.com/github/markup/pull/192) will be merged, there will also be syntax highlighting for the code parts.)

To actually see the results of the code below, open **task_intro.html** in the root directory of this project.

### What is a task?

The purpose of the Task system is to provide an easy way to work with asynchronous, inter-dependent tasks.

It's based on jQuery's [Deferred / Promise API](http://api.jquery.com/jQuery.Deferred/), and adds a bunch of new features.

A task is an individual unit of work. It typically (but not necessarily) involves (or depends on) some asynchronous operation.

Tasks support automatic dependency management and scheduling.

All tasks are wrapped in a Task object, which is created by the task manager.

A task is always in one of the following states:
 * `waiting` - the task is waiting for dependencies.
 * `pending` - the task is working
 * `resolved` - the task has finished
 * `rejected` - the task (or one its dependencies) has failed

These states are the same as the values defined by [deferred.state()](http://api.jquery.com/deferred.state/), except the `waiting` state, which is only defined here.

All task are executed (at most) once. The same task can not be started again.

(If you need to do the same task more than once, you can use *task generators* for that, as described below.)

### Using the task system

The task system is implemented in a single coffee file: tasks.coffee

Dependencies:
 * jQuery
 * the xlog library from dom-text-mapper can be used, but that's not required.

There are no other dependencies.

You just need to include tasks.coffee, and you are all set.

### The task manager

To do anything with tasks, first you need a task manager:

    tasks = new TaskManager()

Usually you only need one task manager in a given application, but to avoid mixing the different test cases, we will use several.

Since in this demo, we would like to see what's going on with our tasks, we will register a generic progress notifier function on our task managers, which will be automatically attached to all the created tasks:

    tasks.addDefaultProgress (info) =>
      console.log info.task._name + ": " + info.progress + " - " + info.text

### Creating a task

Now let's create a task!

    case1 = ->

      task_A = tasks.create
        code: (taskCtrl) =>
          console.log "Here we go!"
          taskCtrl.resolve()

The task we created above is about the simplest task we can create. The `create` method takes a map of options; we will review the most important options shortly.

In this example, we only used the `code` option, which defines the function to run when the task is to be executed. It will receive a `taskCtrl` argument, which is a (tweaked) [jQuery Deferred Object](http://api.jquery.com/category/deferred-object/). It should be used by the code of the task to signal the changes in the state of the task, using the [resolve()](http://api.jquery.com/deferred.resolve/), [reject()](http://api.jquery.com/deferred.reject/) and [notify()](http://api.jquery.com/deferred.notify/) methods.

In this example, we simply signal that the task is resolved.

The object returned by the task manager's `create` method has the [jQuery Deferred Promise API](http://api.jquery.com/deferred.promise/). You can use it
 * as a dependency for other tasks
 * to observe the state of the task - `state()` method
 * to register callbacks [the](http://api.jquery.com/deferred.done/) [usual](http://api.jquery.com/deferred.fail/) [way](http://api.jquery.com/deferred.progress/):

      task_A.done -> console.log "Task A is done!"

### Executing a task

Creating a task does not automatically start it. (This is useful because you might want to modify with the dependencies before you execute it.) So to start available task, we must tell the task manager to "schedule" all defined tasks.

      tasks.schedule()

Since the task defined in our first example does not have any dependencies, it will be executed immediately. After it has finished, the callback we have registered will be run, too.

The output looks like this:

 * Nameless task #1: 0 - Starting
 * Here we go!
 * Nameless task #1: 1 - Finished in 7ms.
 *  Task A is done! 

### Two approach to dependencies

Let's define some more tasks:

    case2 = ->

      tasks.create
        name: "task B"
        deps: ["task C"]
        code: (taskCtrl) =>
          console.log "B"
          taskCtrl.resolve()
 
      task_C = tasks.create
        name: "task C"
        code: (taskCtrl) =>
          console.log "C"
          taskCtrl.resolve()

      task_C.done -> console.log "Task C is done!"

      tasks.schedule()

A few things to notify here:
 * We have added names to our tasks, using the `name` option. (Useful understanding debug output, and also for declaring dependencies.)
 * We have introduced two dependencies:
   * We have manually registered a callback on *task C*.
   * We have added a declarative dependency (with the `deps` option) to *task B*, so that *task B* won't be run until *task C* is finished.
   The second way of defining dependencies is more flexible; see below.

A task can depend on any number of other tasks, and its execution will only start when all the dependencies have been fulfilled.

In this example, `schedule` will first run *task C* (since it does not have any dependency), and when it's ready, it will execute (in an unspecified order) *Task B* and the manually registered callback. (If we cared for their order, we should add a dependency between them.)

The output will look like this:

 * task C: 0 - Starting
 * C
 * task C: 1 - Finished in 1ms. 
 * Task C is done!
 * task B: 0 - Starting
 * B
 * task B: 1 - Finished in 0ms. 

### Changing dependencies on the fly

When declaring dependencies using the `deps` option, you can specify a list. Each element can be an existing Task object, or the name of an existing Task object, or the name of a Task object to be created later.

You can also add and remove dependencies after the task have been created, like this:

    case3 = ->

      task_D = tasks.create
        name: "task D"
        code: (taskCtrl) =>
          console.log "D"
          taskCtrl.resolve()

      tasks.create
        name: "task E"
        code: (taskCtrl) =>
          console.log "E"
          taskCtrl.resolve()

      tasks.create
        name: "task F"
        code: (taskCtrl) =>
          console.log "F"
          taskCtrl.resolve()

      tasks.addDeps "task D", "task E"   # task D depends on task E
      task_D.addDeps "task F"            # task D depends on task F

      tasks.schedule()

This will make *task D* depend on *task B*, *task E* and *task F*. Both shown methods do the same; you can add dependencies both using the task manager, and using the task objects themselves. Both can accept individual tasks, or lists of tasks. They also have `removeDeps` methods, doing what the name says.

So, for this example, the output will look like this:
 * task E: 0 - Starting
 * E
 * task E: 1 - Finished in 1ms.
 * task F: 0 - Starting
 * F
 * task F: 1 - Finished in 0ms.
 * task D: 0 - Starting
 * D
 * task D: 1 - Finished in 0ms.

Please note that the changed dependencies only take effect if you `schedule` the tasks on the task manager. If a given task is already running, then changing it's dependencies won't have any effect.

Running `schedule` more than once has no ill effects. It's supposed to run after every change made to tasks. (Adding new tasks or changing the dependencies.)

### Asynchronous tasks

This is how to define asynchronous tasks:

    case4 = ->

      tasks.create
        code: (taskCtrl) =>
          console.log "Here we go!"
          setTimeout (=>
            taskCtrl.resolve()
          ), 500

      tasks.schedule()

      setTimeout (-> console.log "Go! Go!"), 200

In this case, the output will look like this:
 * Nameless task #1: 0 - Starting
 * Here we go!
 * Go! Go!
 * Nameless task #1: 1 - Finished in 501ms. 

### Failing tasks

Sometimes things don't work out as planned. In these cases, you can reject those tasks. This will automatically reject all other tasks depending on a given task, too.

    case5 = ->

      task_G = tasks.create
        name: "task G"
        deps: ["task H"]
        code: (taskCtrl) =>
          console.log "G"
          taskCtrl.resolve()
 
      tasks.create
        name: "task H"
        code: (taskCtrl) =>
          console.log "H"
          taskCtrl.reject "Oops"

      task_G.done( => 
        console.log "G done!"
      ).fail( =>
        console.log "G failed!"
      )

      tasks.schedule()

The output will look like this:
 * task H: 0 - Starting
 * H
 * task H: 1 - Failed in 2ms.
 * task G: 1 - Skipping, because Oops
 * G failed! 

### Composite tasks

Sometimes a task can be divided to smaller sub-tasks, but it's still useful the have a handle encompassing the whole process. This is what CompositeTasks are for. Example first, explanation later:

    case6 = ->
      
      task_H = tasks.createComposite
        name: "Big task"

      task_H.createSubTask
        name: "Small 1"
        code: (taskCtrl) =>
          setTimeout ( => taskCtrl.resolve()), 200

      task_H.createSubTask
        name: "Small 2"
        code: (taskCtrl) =>
          setTimeout ( => taskCtrl.resolve()), 100

      task_H.done => console.log "All done!"      

      tasks.schedule()

The output will be:

 * Big task: 0 - Starting
 * Big task: 0 - Small 1: Starting
 * Big task: 0 - Small 2: Starting
 * Big task: 0.5 - Small 2: Finished in 101ms.
 * Big task: 1 - Small 1: Finished in 201ms.
 * Big task: 1 - Finished in 204ms.
 * All done! 

The rules of composite tasks are:
 * No sub-task is started until the composite task itself has any unresolved dependencies
 * The sub-tasks can have dependencies over each other, or other other tasks.
 * The composite task is finished when all sub-tasks have finished (or failed.)
 * If any of the sub-tasks fail, the the composite task fails, too.
 * Any `notify` calls sent by any of the sub-tasks are cascading up to the composite task. The overall progress number is calculated based on the number of sub-tasks. 
 * You can change the weight of the sub-tasks by passing a `weight` option to the `createSubTask` call. If you don't specify any weight, it will be 1. These weights are factored into the calculation of overall progress.
 * You can add new sub-tasks even when a composite task is already running. However, you can not add new sub-tasks after the composite task was resolved or rejected.
 * You can `enslave` separately created tasks to a composite task by adding it as a sub-task. (In fact, sub-tasks are normal tasks, too, just automatically joined to a given composite task.)

Example for this:

    case7 = ->

      task_I = tasks.createComposite
        name: "Big task 2"

      task_I.createSubTask
        name: "Small 1"
        code: (taskCtrl) =>
          setTimeout ( => taskCtrl.resolve()), 100

      task_I.done => console.log "All done!"      

      tasks.schedule()

      task_J = tasks.create   # We create a separate task
        name: "Small 2"
        # We don't want automatic reporting, since data is 
        # cascaded to the parent task anyway
        useDefaultProgress: false 
        code: (taskCtrl) =>
          setTimeout ( => taskCtrl.resolve()), 200

      task_I.addSubTask       # Add this new task to task_I
         weight: 2
         task: task_J

      tasks.schedule()

Output will be:

 * Big task 2: 0 - Starting
 * Big task 2: 0 - Small 1: Starting
 * Big task 2: 0 - Small 2: Starting
 * Big task 2: 0.3333333333333333 - Small 1: Finished in 102ms.
 * Big task 2: 1 - Small 2: Finished in 201ms.
 * Big task 2: 1 - Finished in 205ms.
 * All done! 

As you can see, *Small 2* is added to the composite task after it is already running, but it will still wait for it. You can also see the effect of using a `weight`.

### Task generators (for repeating tasks)

Sometimes we are not dealing with singleton tasks, but with a whole army of tasks of the same kind. To make these more simple, we have the *Task generators*.

Example first, explanation later:

    case8 = ->

      greeterGen = tasks.createGenerator
        name: "greeting"
        code: (taskCtrl, data) =>
          setTimeout ( =>
            console.log "Hi there, " + data.name + "!"
            taskCtrl.resolve()
          ), Math.random() * 1000

      for chick in ["Jill", "Jane", "Veronica", "Clare", "Angel"]
        greeterGen.create
          instanceName: chick
          data:   # This is what will be passed to the code
            name: chick

      tasks.schedule()

The output will be something like this:

 * greeting #1: Jill: 0 - Starting
 * greeting #2: Jane: 0 - Starting
 * greeting #3: Veronica: 0 - Starting
 * greeting #4: Clare: 0 - Starting
 * greeting #5: Angel: 0 - Starting
 * Hi there, Jill!
 * greeting #1: Jill: 1 - Finished in 30ms.
 * Hi there, Angel!
 * greeting #5: Angel: 1 - Finished in 204ms.
 * Hi there, Jane!
 * greeting #2: Jane: 1 - Finished in 809ms.
 * Hi there, Veronica!
 * greeting #3: Veronica: 1 - Finished in 877ms.
 * Hi there, Clare!
 * greeting #4: Clare: 1 - Finished in 890ms. 

So, what happened here?
 * We created a *Task Generator* object, which can generate similar tasks on request. We have specified the generic name of this class of tasks, and the code that needs to be run in each case.
 * Then we used this generator to generate a bunch of tasks (one for each chick), and executed those tasks.

We can combine task generators and composite tasks:

    case9 = ->

      fetchGen = tasks.createGenerator
        name: "fetch"
        code: (taskCtrl, data) =>
          setTimeout ( =>
            console.log data.name + " has arrived."
            taskCtrl.resolve()
          ), Math.random() * 1000

      greeterGen = tasks.createGenerator
        name: "greeting"
        code: (taskCtrl, data) =>
          console.log "Hi there, " + data.name + "!"
          taskCtrl.resolve()

      task_H = tasks.createComposite
        name: "Greet everybody"

      task_H.createSubTask
        weight: 2
        name: "Greet the President"
        code: (taskCtrl) =>
          console.log "Welcome, Mr. President!"
          taskCtrl.resolve()

      for chick in ["Jill", "Jane", "Veronica", "Clare"]
        fetch = fetchGen.create
          instanceName: chick
          data: name: chick
          useDefaultProgress: false
        task_H.addSubTask task:fetch

        greet = greeterGen.create
          instanceName: chick
          data: name: chick
          useDefaultProgress: false
          deps: [fetch]
        task_H.addSubTask task:greet
     
      task_H.done => console.log "Everybody is here! Let's party!"

      tasks.schedule()

So, what do we have here?
 * We create two generators, for two class of tasks
 * We create a composite task
 * For each chick, we
   * create a fetch and a greet task
   * add a dependency (because we can greet then only when they have arrived)
   * add both generated tasks as sub-tasks.
 * When executing the tasks
   * it takes a random time to fetch each chick
   * each is greeted as she arrives
 * The composite task is resolved when all the fetch and greet tasks are resolved.

Output:

 * Greet everybody: 0 - Starting
 * Greet everybody: 0 - Greet the President: Starting
 * Welcome, Mr. President!
 * Greet everybody: 0.2 - Greet the President: Finished in 1ms.
 * Greet everybody: 0.2 - fetch #1: Jill: Starting
 * Greet everybody: 0.2 - fetch #2: Jane: Starting
 * Greet everybody: 0.2 - fetch #3: Veronica: Starting
 * Greet everybody: 0.2 - fetch #4: Clare: Starting
 * Veronica has arrived.
 * Greet everybody: 0.3 - fetch #3: Veronica: Finished in 101ms.
 * Greet everybody: 0.3 - greeting #3: Veronica: Starting
 * Hi there, Veronica!
 * Greet everybody: 0.4 - greeting #3: Veronica: Finished in 0ms.
 * Clare has arrived.
 * Greet everybody: 0.5 - fetch #4: Clare: Finished in 243ms.
 * Greet everybody: 0.5 - greeting #4: Clare: Starting
 * Hi there, Clare!
 * Greet everybody: 0.6 - greeting #4: Clare: Finished in 0ms.
 * Jill has arrived.
 * Greet everybody: 0.7 - fetch #1: Jill: Finished in 417ms.
 * Greet everybody: 0.7 - greeting #1: Jill: Starting
 * Hi there, Jill!
 * Greet everybody: 0.8 - greeting #1: Jill: Finished in 0ms.
 * Jane has arrived. 
 * Greet everybody: 0.9 - fetch #2: Jane: Finished in 728ms.
 * Greet everybody: 0.9 - greeting #2: Jane: Starting
 * Hi there, Jane!
 * Greet everybody: 1 - greeting #2: Jane: Finished in 0ms.
 * Greet everybody: 1 - Finished in 740ms.
 * Everybody is here! Let's party! 

Sometimes you may want to create sub-tasks in a composite tasks so that each task is only run when the previous one is finished. You can do it like this:

    case10 = ->

      dance = tasks.createGenerator
        name: "dance"
        code: (taskCtrl, data) =>
          console.log "Dancing with " + data.name + "..."
          taskCtrl.resolve()

      task_K = tasks.createComposite
        name: "Party"

      for chick in ["Jill", "Jane", "Veronica", "Clare"]
        task = dance.create
          instanceName: "with " + chick
          data: name: chick
          useDefaultProgress: false
          deps: [task_K.lastSubTask] # This is where we add the dependency

        task_K.addSubTask task:task

      task_K.done => console.log "Party is over. Let's go home."

      tasks.schedule()

As you can see, when we create the sub-tasks (with the generator), we always add
a dependency to the parent task's last sub-task. This means that the the tasks will be executed sequentially, and only one of them will be running at any given time. 

The output will be:
 * Party: 0 - Starting
 * Party: 0 - dance #1: with Jill: Starting
 * Dancing with Jill...
 * Party: 0.25 - dance #1: with Jill: Finished in 1ms.
 * Party: 0.25 - dance #2: with Jane: Starting
 * Dancing with Jane...
 * Party: 0.5 - dance #2: with Jane: Finished in 1ms.
 * Party: 0.5 - dance #3: with Veronica: Starting
 * Dancing with Veronica...
 * Party: 0.75 - dance #3: with Veronica: Finished in 1ms.
 * Party: 0.75 - dance #4: with Clare: Starting
 * Dancing with Clare...
 * Party: 1 - dance #4: with Clare: Finished in 0ms.
 * Party: 1 - Finished in 16ms.
 * Party is over. Let's go home. 

Compare this output with that of case 8. The difference is that in case 8, all sub-tasks were launched in parallel. Here, they are launched sequentially.

### Dummy tasks

Dummy tasks are for situations when you don't really need (or want) to do something, but you still want to signal that you are skipping something. They can be created with one line, and are always resolved immediately. You can use them as dummy dependencies, if the need arises.

Example:

    case11 = ->
      task_L = tasks.createDummy name: "Don't doing anything"

      task_L.done => console.log "Finished all the hard work."

      tasks.schedule()

Output:
 * Don't doing anything: 0 - Starting
 * Don't doing anything: 1 - Finished in 0ms.
 * Finished all the hard work.

You can also create dummy sub-tasks for composite tasks very easily:

    case12 = ->
      task_L = tasks.createComposite name: "Big task"

      task_L.createDummySubTask name: "dummy preparation"

      tasks.schedule()

Output:
 * Big task: 0 - Starting
 * Big task: 0 - dummy preparation: Starting
 * Big task: 1 - dummy preparation: Finished in 0ms.
 * Big task: 1 - Finished in 2ms. 

### When are tasks executed?

That is a tricky question. There is no easy answer, but the guidelines are the following:
 * Tasks are definitely not executed until all their dependencies are resolved.
 * Tasks are *usually* triggered ASAP.
 * When executing several tasks in a line, the system always introduces some small pauses, so that the browser does not block, and it can render the DOM, etc.
 * If finishing a task triggers the execution of more than one other tasks, there is no guarantee of their order of execution. It's also possible that some of them will be postponed. (This area of the code might change in the future, so I am hesitant to specify this any more now.)

### Other tricks

#### Overriding tasks

You can override a task by defining a new task with the same name. In this case, the code will be replaced with the new one. (The exact rules for this will be explained here later.)

### Tasks vs Promises

As explained in the opening section, tasks are based on Deferred Promises. After covering what the tasks do, the question naturally arises, could not we do the same with promises? The answer is that in sames cases, we could (albeit with more difficulty), but sometimes we could not.

#### The basic use-case

Let's see a very simple use-case, and analyze the differences!
Let's define 3 steps that must be executed in a fixed order,


With tasks:

    case13 = ->

      tasks.create			# Boilerplate 1
        name: "task L"			# Boilerplate 2
        code: (taskCtrl) =>		# Boilerplate 3
          setTimeout =>	 		# For fake async demo only
            console.log "L"		# Actually useful code 1
            # Do something here		# Actually useful code 2
            taskCtrl.resolve()		# Boilerplate 8

      tasks.create			# Boilerplate 5
        name: "task M"			# Boilerplate 6
        deps: ["task L"]		# Configuration 1
        code: (taskCtrl) =>		# Boilerplate 7
          setTimeout =>	 		# For fake async demo only
            console.log "M"		# Actually useful code 3
            # Do something here		# Actually useful code 4
            taskCtrl.resolve()		# Boilerplate 8

      tasks.create			# Boilerplate 9
        name: "task N"			# Boilerplate 10
        deps: ["task M"]		# Configuration 2
        code: (taskCtrl) =>		# Boilerplate 11
          setTimeout =>	 		# For fake async demo only
            console.log "M"		# Actually useful code 5
            # Do something here		# Actually useful code 6
            taskCtrl.resolve()		# Boilerplate 12

      tasks.schedule()

Definition with promises:

    case14 = ->

      feature_a = ->			# Boilerplate 1
        d = new jQuery.Deferred()	# Boilerplate 2
        setTimeout =>			# For fake async demo only  
          console.log "A"		# Actually useful code 1
          # Do something here		# Actually useful code 2	
          d.resolve()			# Boilerplate 3
        d.promise()			# Boilerplate 4

      feature_b = ->			# Boilerplate 5
        d = new jQuery.Deferred()	# Boilerplate 6
        setTimeout =>			# For fake async demo only
           console.log "B"		# Actually useful code 3
           # Do something here		# Actually useful code 4
           d.resolve()	 		# Boilerplate 7
        d.promise()			# Boilerplate 8

      feature_c = ->			# Boilerplate 9
        d = new jQuery.Deferred()	# Boilerplate 10
        setTimeout =>			# For fake async demo only
           console.log "C"		# Actually useful code 5
           # Do something here		# Actually useful code 6
           d.resolve()	 		# Boilerplate 11
        d.promise()			# Boilerplate 12

      feature_a().then(feature_b).then(feature_c)  # Configuration 1


Let's compare what we had to do, and what we got!

To wrap the same 6 lines of useful code, we had to to write:
 * Boiler-plate code: 
   * tasks: 13 lines
   * promises: 12 lines
 * configuration:
   * tasks: 2 lines (distributed to each task)
   * promises: 1 line (centralized)

The amount of needed boilerplate code is nearly identical. (Tasks require one more line total.)

What we got:
 * The desired workloads are executed in the wanted order?
   * Yes, in both versions
 * Between the execution of the three pieces of workloads, is the the control returned to the browser, so that it can handle the incoming events and stays responsive?
   * With tasks: yes, this is done automatically
   * With promises: only if you manually introduce timeouts
 * What kind of logging and monitoring do we have for debugging:
   * Tasks: the output will be like this:
     * task L: 0 - Starting 
     * L
     * task L: 1 - Finished in 2ms.
     * task M: 0 - Starting
     * M
     * task M: 1 - Finished in 2ms.
     * task N: 0 - Starting
     * M
     * task N: 1 - Finished in 5ms.
   * Promises: you only get what you have manually added. In our case:
     * A
     * B
     * C

So, with tasks we got some small benefits, but actually, it's no big deal, we could live without those benefits.

The real fun begins when we want to change or extend our already existing code. 

#### Change a task

Let's suppose that we need to override one of the tasks, and we would prefer to do this without having to modify the original code. (Defined in case13.)

Overriding the definition of a task:

    case15 = ->
      case13()    # We can simply add the original definitions
      # And override what we want
      tasks.create
        name: "task M"			# Boilerplate 6
        deps: ["task L"]
        code: (taskCtrl) =>
          setTimeout =>
            console.log "M override"
            # Do something here
            taskCtrl.resolve()

      tasks.schedule() # And re-schedule everything


With promises:

The thing is, working with the original code (defined in case 14), there is no straightforward way to do this. You could, for example, move out the pieces of code that actually do the work into separate functions, so that they can be overridden by later code, but this involves modifying the original code (not always feasible or desirable), or if is done indiscriminately, when writing the original code, this would involve adding lots of useless boilerplate code. With tasks, no further boilerplate code is necessary, since task manager already supports overriding the tasks.

#### Adding a new action

Let's suppose that you want to trigger a new action when an existing task has finished. (Again, preferably without touching the original code in case13)

Introducing a new task:

    case16 = ->
      case13()

      tasks.create
        name: "task O"
        deps: ["task L"]
        code: (taskCtrl) =>
          setTimeout =>
            console.log "O"
            # Do something here
            taskCtrl.resolve()

      tasks.schedule()

With promises:

The thing is, if you don't have a handle to the promise (for example, feature_a in our example), you can't easily do this. To attach a new trigger, you need to be able to get a reference to the handle of the original promise. So, you either have to put it into the global name-space, or channel it to the new code using some other method. With tasks, this is not required, since the name of the tasks can be resolved inside the task manager.

#### Adding a new dependency to an existing task

OK, now let's suppose that you want to insert some new action into an already defined chain of events in case13!

This how we do this:

    case17 = ->
      case13()

      tasks.create
        name: "task P"
        deps: ["task L"]
        code: (taskCtrl) =>
          setTimeout =>
            console.log "P"
            # Do something here
            taskCtrl.resolve()
 
      tasks.addDeps "task M", "task P"
      tasks.schedule()

With promises:

Again, you can not do this without modifying the original code.
Once you have registered the callback with the `then()` method of the promise, there is no way to make it wait for a new dependency which you want to add later. The only things you can do is to
 * Modify the original code, and add a hook for what you want
 * Override the entire method where the action was defined, and copy all the code, except the part where the sequence of events was defined.

#### Group dependencies

The situation is similar here.
Definition is very similar.

Definition with tasks:

    case18 = ->
      g = tasks.createComposite name: "big task"
      g.createSubTask
        name: "step 1"
        code: (taskCtrl) ->
          setTimeout =>
            console.log "Step 1"
            taskCtrl.resolve()

      g.createSubTask
        name: "step 2"
        code: (taskCtrl) ->
          setTimeout =>
            console.log "Step 2"
            taskCtrl.resolve()

      g.done => console.log "Big task done!"

      tasks.schedule()

Definition with promises:

    case19 = ->

      step_1 = ->
        d = new jQuery.Deferred()
        setTimeout =>
          console.log "Step 1"
          d.resolve()
        d.promise()

      step_2 = ->
        d = new jQuery.Deferred()
        setTimeout =>
          console.log "Step 1"
          d.resolve()
        d.promise()

      jQuery.when(step_1(), step_2()).then => console.log "Big task done!"
   
OK, now let's add a new assume we need to insert a new element to this existing group dependency!

With tasks:

    case20 = ->
      case18()
      tasks.lookup("big task").createSubTask
        name: "step 3"
        code: (taskCtrl) ->
          setTimeout =>
            console.log "Step 3"
            taskCtrl.resolve()

      tasks.schedule()

With promises:

There is no way to do this; the callback registered with the `jQuery.when()` method will be called, whatever you do. To override this, you need to change the original code.

#### Other tricks

With tasks, you can also
 * remove dependencies between previously defined tasks
 * add new dependencies between previously defined tasks
 * easily override previously defined tasks
... etc.

This flexibility is one of the main benefit (and purpose) of the Tasks. When adding new pieces of code to a task-using project, this makes it remarkably easy to insert and mix-and-match tasks any way you might want, including ways not foreseen when designing the old tasks.

The convenience features (like the sub-tasks with aggregating statistics) are just an added bonus.

