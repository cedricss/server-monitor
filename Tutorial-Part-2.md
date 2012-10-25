# Server Monitor - Opa Tutorial Part 2 #

# Server Monitoring #

<img src="resources/img/check-servers.png"/>

We use `WebClient.Get.try_get(uri)` to check if a server behind an URL is reacheable. This funcion return variants, like `{ failure : { timeout } }`, depending on the server response. We use pattern matching (`match` and `case` keywords) to analyze each variant:

    module Job {

      exposed @async function check(name, url, uri) {
          match (WebClient.Get.try_get(uri)) {
          case { failure : { timeout } } :
            Action.down(name, url, "socket timeout", { timeout })
          case { failure : { network } } : 
            Action.down(name, url, "impossible to reach the server", { unreachable })
          case { failure : { uri : _, reason : _ } } :
            Action.down(name, url, "Invalid url. Missing http:// prefix?", { unknown_error })
          case { failure : f } : 
            Action.down(name, url, "other reason: {f}", { unknown_error })
          case { success : _ } :
            Action.up(url)
          }
      }

    }

> `_` in a pattern means we accept any possible variant. For example, to catch any possible failure reasons, the variant would be `{ failure : _ }`. To catch any possible failure reasons but still using the reason later, replace `_` with a value name: { failure : f } -> "other reason: {f}"

## Actions ##

Let's add the actions functions we need for the previous `Job.check` function.

      function up(url) { msg(url, "label-success", "is UP") }
      function invalid(url) { msg("ERROR: {url}", "label-inverse", "an invalid url") }
      function down(name, url, failure, status) { msg(url, "label-important", "is DOWN ({failure})"); }

## Timer ## ##

Now we can complet the `add_job` function to call the `Job.check` function regularly for each added url. We use [Scheduler.make_timer](http://doc.opalang.org/value/stdlib.core.rpc.core/Scheduler/make_timer) that returns an interruptible timer.

    function add_job(name, url, uri, freq) {
        timer = Scheduler.make_timer(freq*1000, function() { Job.check(name, url, uri) });
        Job.check(name, url, uri);
        timer.start();
        ...
    }

> [See all the changes we made in this section](https://github.com/cedricss/server-monitor/commit/b75288f6951102def2ae356728ea6ee12918814a).

# Add buttons #

<img src="resources/img/job-buttons.png"/>

## Edit and remove buttons ##

To remove a job we need to stop the timer and to remove it from the page:

    function remove(_) { timer.stop(); Dom.remove(#{name}); }

A HTML fragment for this remove button would be:

    remove_btn = <a class="btn-mini" onclick={remove}>
                  <i class="icon-remove"></i>
                 </a>

When we click on it, the `remove(_)` function is called. Again, `_` would be a `Dom.event` but we don't need it here.

The edit function stop the timer and fills again the job edition form:

    function edit(_) {
          timer.stop(); Dom.remove(#{name});
          Dom.set_value(#name, name); Dom.set_value(#url, url)
          Dom.set_value(#freq, String.of_int(freq))
    }

And similary, the edit button is:

    edit_btn = <a class="btn-mini" onclick={edit}><i class="icon-edit"></i></a>

We can put all those fragments inside the `add_job` function, after the timer definition. We'll add the buttons later in the interface.

## Add the play and pause buttons are recursive ##

For each line inside the list of jobs, we want to display a Play/Pause toggle button. Let's define a unique html ID for each job buttons:

      	player_id = "{name}_player";

> *String Inserts*: while string concatenation is possible with `+`, we can insert any value or expression into a string using curly braces. Opa will automatically convert the value to a string, if possible for the type of the value.

When we click on `Stop` the timer stop and the `Start` button is displayed instead. This is similar for the `Play` button. As you can see, those two states of the buttons depends on each other:

<img src="cyclic-defintion.png"/>

We use the `recursive` and `and` keywords to define such a cycle definition:

      	recursive function stop(_) { timer.stop(); #{player_id} = start_btn }
      	      and function start(_) { timer.start(); #{player_id} = stop_btn }
      	      and stop_btn = <a class="btn-mini" onclick={stop}><i class="icon-pause"></i></a>
      	      and start_btn = <a class="btn-mini" onclick={start}><i class="icon-play"></i></a>

## Add buttons to the interface ##

Great! We have created an edit, a remove and a play/stop toggle button. We just have to add them to our interface:

      	#jobs += <tr id=#{name}>
      	        <td>{url} each {freq} sec</td>
      	        <td><span id=#{player_id}>{stop_btn}</span>{edit_btn}{remove_btn}</td>
      	        </tr>;

> [See all the changes we made in this section](https://github.com/cedricss/server-monitor/commit/b75288f6951102def2ae356728ea6ee12918814a).
