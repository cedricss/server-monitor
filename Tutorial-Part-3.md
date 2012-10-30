# Server Monitor - Opa Tutorial Part 3 # #

## *Work in progress!* ##

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


