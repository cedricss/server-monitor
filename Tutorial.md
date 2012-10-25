# Server Monitor - Opa Tutorial Part 1 #

# View #

I recently added in [Opa 1.0.7](http://opalang.org) a [new database back-end working on top of Dropbox](http://cedrics.tumblr.com/post/34171076153/opa-dropbox-database). I created a [demo application](http://server-monitor.herokuapp.com) using it: here a step by step tutorial. 

<img src="http://server-monitor.herokuapp.com/resources/img/screenshot.png"/>

In this tutorial, we will:

- create an application View using the native support of HTML in Opa,
- add event handlers, without thinking about where is running the code thanks to Opa automatic client/server code dispatcher,
- configure a http server and a database in a single file,
- interact with the DOM using some of the features enhancements Opa provided on top of JavaScript,
- parse user inputs and urls,
- discover some of the languages aspects like modules,  recursive functions, records, block notations, types and pattern matching,
- use the Opa path notation to handle data stored in a MongoDB database,
- switch from a MongoDB database to a Dropbox one.

## Initial User Interface ##

<img src="resources/img/initial-view.png"/>

Let's start with the user interface. We create a `View` module with a `page` function inside that will serve the HTML page:

    module View {

        function page() {
            <div class="navbar navbar-fixed-top">
              ...
            </div>
            <div style="margin-top:50px" class="container">
            <div class="row-fluid">
            <div class="span6">
                <h1>Monitor</h1>
                <form class="well">
                  ...
                </form>
            </div>
            <div class="span6">
                <h1>Logs</h1>
                  ...
                </div>
            </div>
            </div>
            <div class="row-fluid">
              ...
            </div>
            </div>
        }
    }

As we can see, Opa provides native support of HTML. We can try to write invalid HTML like deleting a closing tag: the compiler will raise a syntax error at compile time. Get the <a href="https://github.com/cedricss/server-monitor/blob/34985981fa40de13c5a9f371f32be2a172e70621/main.opa">full HTML view on github.</a>

## Http Server ##

Then, we add outside of the `View` module a http server configured to serve a default HTML5 page:

    Server.start(
        Server.http,
        [ { register : { doctype : { html5 } } },
          { title : "hello", page : View.page }
        ]
    )

With Opa, we can define the client template views and events, the http server or even the database within the same file, without any extra directives for the compiler!

## Compile ##

We compile and see the result at the `http://localhost:8080` url.

    opa main.opa --
    Http serving on http://localhost:8080

> `--` means "compile and run". You can add extra runtime options, for example `opa main.opa -- --port 9090`
 
## Bootstrap theme ##

We want to use the default <a href="http://twitter.github.com/bootstrap/">bootstrap css theme</a> provided by Tweeter. We just have to import the theme at the begining of our file. We also import the glyphicons and the responsive css so the application can work well on different display sizes:

    import stdlib.themes.bootstrap.css
    import stdlib.themes.bootstrap.icons
    import stdlib.themes.bootstrap.responsive

Or shorter:

    import stdlib.themes.bootstrap.{css, icons, responsive}

We compile and restart the server to appreciate the easy style improvement!

> Get the [full source code on github at this step](https://github.com/cedricss/server-monitor/blob/34985981fa40de13c5a9f371f32be2a172e70621/main.opa).

# Add jobs (Client-side) #

## Update the Dom ##

We add a new `Action` module that will be responsible of the user interface updates. Opa dispatches the code on the server and the client side automatically, and automates the calls between client and server. To get more control and optimize your code, you can use `server` and `client` directives to tweak the compiler default dispatch behavior. For example, here we want all user interface related actions to be computed on the client side as much as possible. To do so, we just add a `client` directive on the module to affect all functions inside it:

    client module Action {

        function msg(url, class, msg) {
            // Add a log on top of the logs list
            #info += <div>
                      <span class="label">
                        {Date.to_string_time_only(Date.now())}
                      </span>
                      <span class="label {class}">
                        {url} {msg}
                      </span>
                     </div>
        }

        function add_job(name, url, uri, freq) {
            // Add a new line on top of the job list
            #jobs += <tr id=#{name}>
                        <td>{url} each {freq} sec</td>
                        <td></td>
                     </tr>;

        }

    }

> **Dom Manipulation**: Opa provide many syntax and feature enhancements on top of JavaScript. There is native support of HTML, but also a special syntax to manipulate the Dom: `#dom_id = <div>Replace</div>`, `#dom_id += <div>Prepend</div>` and `#dom_id =+ <div>Append</div>`

## Parse User Inputs ##

<img src="resources/img/user-inputs.png"/>

Inside the `Job` module, we add functions to check the format of user inputs. The following code is based on the default parsers defined in the `(Parser)[http://doc.opalang.org/module/stdlib.core.parser/Parser]` module:

        function submit_job(_) {

            function p(f, d, error){
                match (f(Dom.get_value(d))) {
                case {none}: msg("ERROR:", "label-error", error); none
                case r: r
                }
            }

            // Parse formular inputs and add the job
            uri  = p(Uri.of_string, #url,  "the url is invalid");
            name = p(Parser.ident,  #name, "the log name is not a valid ident name");
            freq = p(Parser.int,    #freq, "the frequency is not an integer");

            match ((uri, name, freq)) {
            case ({some:uri}, {some:name}, {some:freq}): add_job(name, Dom.get_value(#url), uri, freq)
            default: void // some invalid inputs, don't add the job
            }
        }

    }

> **Unused arguments**
>
> The `_` argument in the `submit_job` funciton means we don't care what is the name and the value of this argument. In this case, it would be a value of type `Dom.event` given by events like `onclick` or `onready` (see below).

## Dom events ##

In the View.page function, we update the `Add and run` html button so the `submit_job` function is called when a user click on it. It's easy to deal with Dom events with Opa: we just put the function to call inside curly brackets and attach it to the event:

    <a class="btn btn-primary" onclick={ Action.submit_job }>
      <i class="icon-plus icon-white"/> Add and run
    </a>

> [See all the changes we made in this section](https://github.com/cedricss/server-monitor/commit/cd66d95c5f72d12b32e9f74fe2c7d1b57526aa07).

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

# Store jobs in MongoDB database ##

This is now serious business: we want to add persistence to our application!

## Database definition ##

We want to store jobs and logs in a database. A job is an url to monitor and an execution frequency. A log has the related job url, an event date and a status. Here are the corresponding type definitions:

	type status = { timeout } or { unreachable } or { unknown_error } or { error_simulation } or { ok }
	type log = { string url, status status, Date.date date }
	type job = { string url, int freq }

	database monitor {
	    stringmap(log) /logs
		  stringmap(job) /jobs
		  /logs[_]/status = { ok } // Define for example the default "status" value
	}

## Records definition and shortcuts ##

A job, as defined previously can be created this way:

	job = { url:"http://opalang.org", freq:10 };

The record can be based on `url` and `freq` previously defined value:

	url = "http://opalang.org"
	freq = 10
	job = { url:url, freq:freq };

The `url:url construction, when the field name and the value name are the same, can be shortened writting simply ~url:

	job = { ~url, ~freq };

When all fields shortened this way, you finally just write:

	job = ~{ url, freq }

## Add and remove elements in the database ##

The previously defined job value can be inserted inside the database just writing:

	/monitor/jobs[name] <- job

This is the special _path notation_ to access and update the database.

Inside the `Job` module add 3 functions to log events, get, add and remove a job.
Those function use the datatbase. All functions those use directly or indirectly the database are _protected_ by default. It means they can't be called from a client and that your data is protected by default. 

You have to explicitly add entry points on your server adding the _exposed_ directive on function: at the begining of those functions you will perform proper access controls like checking user crendentials. For this tutorial we keep it simple and unsecure:


    	exposed @async function log(name, label, url, status) {
	        date = Date.now();
	        name = "[{label}] {name} - {Date.in_milliseconds(date) / 1000}";
	        /monitor/logs[name] <- (~{ url, status, date }) // Add a log in the database logs list
	    }
	
	    exposed @async function add(name, url, freq){ /monitor/jobs[name] <- (~{ url, freq }) }
	    exposed @async function remove(name){ Db.remove(@/monitor/jobs[name]) }
		  exposed function get_all(){ /monitor/jobs }

We edit the `remove` function we definied earlier in the `add_job` function:

      function remove(_) { timer.stop(); Dom.remove(#{name}); Job.remove(name) }

## Load jobs on page startup ##

In the `Action` module add a function to load all jobs and add it in the user interface. Use the `@async` directive to load those jobs asynchronously, so the user can continue using the interface.

	  @async function load_all(_) {
	        Map.iter(
	            { function(name, job)
	                Option.switch(Action.add_job(name, job.url, _, job.freq), void, Uri.of_string(job.url))
	            }, Job.get_all()
	        )
	    }

> **Block notations**
>
> Note the special block notation to pass a function as an argument. You can write:
>
> 	function f1(v) { do_something(); }
> 	my_function(f1, argument2)
>
> Or directly:
>
> 	Map.iter(function(v) { do_something(); }, argument2)
>
> `function(v) { do_something(); }` is an anonymous function: it doesn't have a name (like `f1` in the first example) and you > pass it directly as an argument.
> You can also write it this way, which might be easier to read:
>
> 	Map.iter({ function(v) do_something(); }, argument2)
>
> The same principle applies for example to dom events, when you insert Opa expression inside curly brackets:
>
> 	<div onready={ function(v){ do_something(); } }/>
>
> can be written without the second block:
>
> 	<div onready={ function(v) do_something(); }/>

Now, just call the `load_all` function when the html table is ready:

	<table><tbody id=#jobs onready={Action.load_all}></tbody></table>


# Switch from MongoDB to Dropbox database, in just a few minutes #

## Database directives ##

Just add the `@dropbox` directive to the previous database definition:

	database monitor @dropbox {
	    stringmap(log) /logs
		    stringmap(job) /jobs
		    /logs[_]/status = { ok }
	}

Yes, that's all, your database now runs on top of Dropbox. You don't have to modify any function inside the `Job module.

      function test(name, url, status) { msg("", "label-inverse", "You should see a Dropbox popup on your desktop"); }
      function error_test(_) { test(Dom.get_value(#name), Dom.get_value(#url), { error_simulation }) }

    <a class="btn btn-small btn-inverse" onclick={Action.error_test}>
      <i class="icon-fire icon-white"/> Simulate a failure
    </a>

## Dropbox login page ##

<img src="resources/img/dropbox-login.png"/>

You need to add functions so the user can log into your app with his dropbox account. Let's take the opportunity to put it inside a `Controller` module:

	module Controller {
	
	    DropboxUser = DbDropbox.User(monitor)
	
	    private function access_page(raw_token) {
	        match (DropboxUser.get_access(raw_token)) {
	        case { success } -> Resource.default_redirection_page("/")
	        case { failure : error } -> Resource.html("Error", <>{error}</>)
	        }
	    }
	
	    private function login_page() {
	        redirect = "http://localhost:8080/dropbox/connect"
	        if (DropboxUser.is_authenticated()) {
	          Resource.page("Server monitor", View.page())
	        }else{
	          match (DropboxUser.get_login_url(redirect)) {
	          case { success : url } -> Resource.default_redirection_page(url)
	          case { failure : error } -> Resource.html("Error", <>{error}</>)
	          }
	        }
	    }
	
	    dispatch = parser {
	        case "/dropbox/connect?" raw_token=(.*) -> access_page(Text.to_string(raw_token))
	        case (.*) -> login_page()
	    }
	}

Those functions are pretty straightforward, it follows the `OAuth` protocol to retrieve the access tokens to the user Dropbox account.

## Custom Url Parser ##

`dispatch` is a url parser you will call in the `Server.start` function. Replace the simple and default url handler to use this custom parser:

	Server.start(
	    Server.http,
	    [ { register : { doctype : { html5 } } },
     		{ title : "hello", page : View.page }
   			{ custom : Controller.dispatch }
	    ]
	)


