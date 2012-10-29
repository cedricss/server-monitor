Server Monitoring using Dropbox as a Database
==================================

Overview
--------

Monitor the health of your servers and receive alerts when something goes wrong.
This web application is built with the Opa technology and runs on top of a Dropbox-based database.

Demo
----

Main website and live demo at <a href="http://server-monitor.herokuapp.com/">http://server-monitor.herokuapp.com/</a>

Dropbox Storage
---------------
- All your configured jobs and logs are saved on your personal Dropbox account. Nothing is stored on the application server.
- If one of your severs goes down, a Dropbox popup will appear on your desktop.

The following code is a Dropbox database in Opa. Change the `@dropbox` annotation with `@mongo` and the app will run on top of MongoDB instead. It's that simple.

	database monitor @dropbox {
	    stringmap(log) /logs
	    stringmap(job) /jobs
	    /logs[_]/status = { ok } // Define the default "status" value
	}

	function add(name, url, freq){
		/monitor/jobs[name] <- (~{ url, freq })
	}

__Note:__ This application is a proof of concept, aim to learn the <a href="http://opalang.org">Opa Framework</a> and to present a Dropbox-based database use case. The <a href="http://server-monitor.herokuapp.com/demo">demo</a> will stop monitoring your servers as soon as you close the  page: fork the project and make you own production-ready version!

Compile
-------

<a href="http://opa.io">Download and install Opa</a>, then compile the single file:

    opa main.opa


Run
---

<a href="https://www.dropbox.com/developers/apps">Create an app on Dropbox website</a> and use the app keys to start the application:

    ./main.js --db-remote:monitor app-key:app-secret


Tutorial
--------

- [Tutorial - Part 1](http://cedrics.tumblr.com/post/34566924859/server-monitor-opa-tutorial-part-1)
- Or have a look at the <a href="https://github.com/cedricss/server-monitor/commits/master">commits list</a>: this is how the application was built, step by step. 