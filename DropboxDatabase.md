# Using Dropbox as a Database in Opa #

I added in [Opa 1.0.7](http://opalang.org) a new database back-end working on top of Dropbox and created a [demo application](http://server-monitor.herokuapp.com) using it. Here are some details about this new (and experimental) back-end.

## Introduction: Databases in Opa ##

Here is a type `job` (extracted from the [demo](http://server-monitor.herokuapp.com) above), defined with an url to monitor and an execution frequency:

    type job = { string url, int freq }

A database storing those jobs is defined this way in Opa:

    database monitor {
      stringmap(job) /jobs
    }

- `monitor` is the name of the database
- `/jobs` is the name of the collection
- `stringmap(job)` is the type of the collection: a map where the key is a string and the value is of type `job`.

A function to add a job in the database looks like:

	function add(name, url, freq) {
	    /monitor/jobs[name] <- { url:url, freq:freq }
	}

And to get all of them, it is simply:

	function get_all(){
		/monitor/jobs
	}

The default database back-end in Opa is [MongoDB](http://www.mongodb.org). Follow this [tutorial](https://github.com/MLstate/opalang/wiki/Hello%2C-database) to learn more about it or read the [database chapter](https://github.com/MLstate/opalang/wiki/The-database).

## <a name="use-case"></a> Storing Application Data in Dropbox ##

For some reasons, we may want to store data not in the application database, but on a personal user space like Dropbox. For example:

- to avoid storing sensible data on the application server, if the user trust Dropbox more,
- to save user data without hosting a database,
- to provide the user with a ready-to-use back-up of the server database.

To store the `job` above in a Dropbox folder, we can use a classic nodejs Dropbox library:

	client.put("path/to/directory/filename.json", serialize(job), callback)
	client.get(
		"path/to/directory/filename.json",
		function(status, data, metadata) { job = unserialize(data); ... }
	)

## Switching from MongoDB to Dropbox ##

What if we could use the Opa path notation seen in the introduction to perform Dropbox storage in a more elegant way, and closer to the usual file system representation:

	/path/to/directory[filename] <- "content"  // write 
	content = /path/to/directory[filename]     // read

This is now possible with the new Dropbox back-end. To switch the previous example from MongoDB to Dropbox, we just have to add a `@dropbox` annotation:

	database monitor @dropbox {
      stringmap(job) /jobs
    }

That's all. And all the other functions seen in the introduction remain unchanged!

## Path Notation and Automatic Json Serialization ##

<img src="file:///Users/cedric/git/github/server-monitor/resources/img/dropbox-storage.png"/>

How it works behind the scene? When we write:

	/monitor/jobs[name] <- { url:url, freq:freq }

It serialize the Opa record to json, for example:

	{"url":"http://opalang.org","freq":30}

> __Note__: the serialization works on more complex Opa structures like `list` or `options` and support embedded records

After the serialization, it puts this content in the Dropbox account, regarding the current user session, at this location:

	Apps/monitor/jobs/opalang.json

## Non-blocking by Default ##

To retrieve and display all job, we simply write:

	all_jobs = /monitor/jobs   // retrieve all the jobs
	display(all_jobs)          // do something

This will retrieve the list of json file stored in the `Apps/monitor/jobs/` folder, and request the content for all of them. 

All those requests are sent in parallel to the Dropbox API. The final `all_jobs` value is constructed progressively, as the responses arrive from Dropbox (they may arrive out of order).

What is really important here is Opa is non-blocking by default:

> Modern applications use a lot of asynchronous calls. Dealing with callbacks manually can be painful, and failing to do so properly blocks the application runtime.
> To make asynchronous programming easy without blocking the application, Opa-generated JavaScript code uses smart continuations. (http://opalang.org)

It means two things:

- in the previous example, we don't have to pass the `display` function as a callback, Opa compile it to the appropriate asynchronous and non-blocking JS code. In fact, we can even write simply `display(/monitor/jobs)` as if it were synchronous!
- our application server doesn't block during the treatment: all other computations and client requests are fairly handled, thanks to the [CPS](http://en.wikipedia.org/wiki/Continuation-passing_style) generated code and the Opa scheduler. This generation is automatic and transparent in Opa.

## Going Further ##

We are not limited to maps, simple value storage like is possible:

    database monitor @dropbox {
      int /counter
    }

I didn't detail here the user authentication process with Dropbox, it's just two functions you can read in the [source code](https://github.com/cedricss/server-monitor/blob/master/main.opa#L158) of the server-monitor demo.
 
Specify your [Dropbox App keys](https://www.dropbox.com/developers/apps) in the command line:

    ./app.js --db-remote:monitor appkey:appsecret

#### Notes ####

- This release is experimental. You can [submit issues on github](https://github.com/MLstate/opalang/issues).
- This back-end is of course limited compared to powerful MongoDB queries, but it can still be very useful in <a href="#use-case">some cases</a>.