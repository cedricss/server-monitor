/*
    Copyright © 2012 Cedric Soulas, MLstate

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import stdlib.themes.bootstrap.{css, icons, responsive}

type status = { timeout } or { unreachable } or { unknown_error } or { error_simulation } or { ok }
type log = { string url, status status, Date.date date }
type job = { string url, int freq }

// Define two collections in the "monitor" database
database monitor @dropbox {
    stringmap(log) /logs
    stringmap(job) /jobs
    /logs[_]/status = { ok } // Define for example the default "status" value
}

module Job {

    exposed @async function check(name, url, uri) {
        match (WebClient.Get.try_get(uri)) {
        case { failure : { timeout } } : Action.down(name, url, "socket timeout", { timeout })
        case { failure : { network } } : Action.down(name, url, "impossible to reach the server", { unreachable })
        case { failure : { uri : _, reason : _ } } : Action.down(name, url, "Invalid url. Missing http:// prefix?", { unknown_error })
        case { failure : f }           : Action.down(name, url, "other reason: {f}", { unknown_error })
        case { success : _ }           : Action.up(url)
        }
    }

    exposed @async function log(name, label, url, status) {
        date = Date.now();
        name = "[{label}] {name} - {Date.in_milliseconds(date) / 1000}";
        /monitor/logs[name] <- (~{ url, status, date }) // Add a log in the database logs list
    }

    exposed @async function add(name, url, freq){ /monitor/jobs[name] <- (~{ url, freq }) }
    exposed @async function remove(name){ Db.remove(@/monitor/jobs[name]) }
    exposed function get_all(){ /monitor/jobs }
}

client module Action {

    function msg(url, class, msg) { // Add a log on top of the logs list
        #info += <div>
                    <span class="label label-inverse">{Date.to_string_time_only(Date.now())}</span>
                    <span class="label {class}">{url} {msg}</span>
                 </div>
    }

    function up(url) { msg(url, "label-info", "is UP") }
    function invalid(url) { msg("ERROR: {url}", "label-inverse", "an invalid url") }
    function down(name, url, failure, status) { msg(url, "label-important", "is DOWN ({failure})"); Job.log(name, "DOWN", url, status); }
    function test(name, url, status) { msg("", "label-inverse", "You should see a Dropbox popup on your desktop"); Job.log(name, "TEST", url, status); }
    function error_test(_) { test(Dom.get_value(#name), Dom.get_value(#url), { error_simulation }) }

    function add_job(name, url, uri, freq) {

        timer = Scheduler.make_timer(freq*1000, function() { Job.check(name, url, uri) });
        Job.check(name, url, uri); timer.start();

        function remove(_) { timer.stop(); Dom.remove(#{name}); Job.remove(name) }
        function edit(_) {
            timer.stop(); Dom.remove(#{name});
            Dom.set_value(#name, name); Dom.set_value(#url, url)
            Dom.set_value(#freq, String.of_int(freq))
        }
        edit_btn = <a class="btn-mini" onclick={edit}><i class="icon-edit"></i></a>
        remove_btn = <a class="btn-mini" onclick={remove}><i class="icon-remove"></i></a>
        player_id = "{name}_player";

        // Start and pause buttons definitions depend on each other:
        recursive function stop(_) { timer.stop(); #{player_id} = start_btn }
              and function start(_) { timer.start(); #{player_id} = stop_btn }
              and stop_btn = <a class="btn-mini" onclick={stop}><i class="icon-pause"></i></a>
              and start_btn = <a class="btn-mini" onclick={start}><i class="icon-play"></i></a>

        // Add a new line on top of the job list:
        #jobs += <tr id=#{name}>
                    <td>{url} each {freq} sec</td>
                    <td><span id=#{player_id}>{stop_btn}</span>{edit_btn}{remove_btn}</td>
                 </tr>;

        Job.add(name, url, freq)
    }

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

    server @async function load_all(_) {
        Dom.set_style(#progress, css { width: 100% }) // Animate the progress bar changing its width style
        jobs = Job.get_all()
        Dom.hide(#loading);
        Map.iter(
            { function(name, job)
                Option.switch(Action.add_job(name, job.url, _, job.freq), void, Uri.of_string(job.url))
            }, jobs
        )
    }
}

module View {

    headers =
<script type="text/javascript">{Xhtml.of_string_unsafe("
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-35889407-1']);
  _gaq.push(['_trackPageview']);
  (function() \{
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();
")}</script>

    function full_page(page) {
        Resource.full_page("Server Monitor", page, headers, {success}, [])
    }

    footer =
        <footer>
            <div class="container">
              <div class="row">
                  <div class="offset2 span4">
                      <p>Designed and built at <a href="http://opalang.org">Opalang</a> by <a href="https://github.com/cedricss">Cédric Soulas</a>.</p>
                      <p>Code licensed under MIT. <a href="https://github.com/cedricss/server-monitor">Source code on Github</a>.</p>
                  </div>
                  <div class="span5">
                      <p><strong>Caveat</strong>: This application is a proof of concept, aim to learn the <a href="http://opalang.org">Opa Framework</a> and to present a Dropbox-based database use case.</p><p>  The <a href="http://server-monitor.herokuapp.com/demo">demo</a> will stop monitoring your servers as soon as you close the  page:<br/><a href="https://github.com/cedricss/server-monitor">fork</a>  the code and make you own production-ready version!</p>
                  </div>
              </div>
            </div>
        </footer>

    function welcome() {
        <header class="centered">
            <div class="container">
                <h1>Server Monitoring <span class="label label-info">Proof of Concept</span></h1>
                <h2>Monitor the health of your servers.</h2>
                <h2>Receive alerts when something goes wrong.</h2>
                <p><br/>
                    <a class="button button-large" href="http://server-monitor.herokuapp.com/demo">Try the demo »</a>
                    <a class="button button-large" href="https://github.com/cedricss/server-monitor">Get on Github »</a>
                </p>
                <p class="note">The demo will create a folder named <strong>server-monitor</strong> in your Dropbox Apps folder.<br/>
                   It will <strong>only</strong> have access to this folder.
                </p>
          </div>
       </header>
        <div class="container">
          <hr/>
          <div class="row">
            <div class="offset1 span4">
              <h4>Dropbox Storage</h4>
              <p>All your jobs and logs are saved on your personal Dropbox account. Nothing is stored on the application server.</p>
              <p></p>
            </div>
            <div class="span4">
              <h4>Dropbox Alerts</h4>
              <p>If one of your sever goes down, a Dropbox popup will appear on your desktop.</p>
            </div>
            <div class="span3">
              <h4>Open Source</h4>
              <p>This demo is just a hundred line of code. Get the <a href="https://github.com/cedricss/server-monitor">source on Github</a>.</p>
              <p></p>
            </div>
          </div>
          <hr/>
          <div class="row centered">
            <div class="offset1 span10">
            <a href="resources/img/screenshot.png" target="_blank"><img class="screencap" src="resources/img/screenshot.png"/></a>
            </div>
          </div>
          <div class="row">
            <hr/>
            <div class="offset2 span8">
            <h4>Compile and run</h4>
            <p>This demo is developped with the <a href="http://opalang.org" target="_blank">Opa Framework for JavaScript</a>.
            </p>
            <ul>
            <li><a href="http://opalang.org" class="" target="_blank">Install Opa</a></li>
            <li><a href="https://www.dropbox.com/developers/apps" target="_blank">Create a Dropbox app</a> and use the app keys to start the application</li>
            <li>Get the source code, complie and run the application:</li>
            </ul>
            <pre class="code"><code>$ git clone https://github.com/cedricss/server-monitor.git
$ cd server-monitor
$ opa main.opa
$ ./main.js --db-remote:monitor appkey:appsecret
</code></pre>
            </div>
          </div>
        </div>
        <>{footer}</>
    }

    function page() {
        <div class="navbar navbar-fixed-top"><div class="navbar-inner"><div class="container">
                <a href="/" class="brand">Server Monitor</a><ul class="nav "><li><a href="/">Home</a></li></ul>
        </div></div></div>
        <div style="margin-top:50px" class="container">
        <div class="row-fluid">
        <div class="span6">
            <h1>Monitor</h1><form class="well">
                <div class="control-group">
                <label>Job Name</label><input type="text" id=#name value="opalang"/>
                <label>Monitored Url</label><input type="text" id=#url value="http://opalang.org"/><span class="help-inline"></span>
                <label>Frequency</label><input class="input-mini" type="text" id=#freq value="3"/><span class="help-inline">sec</span>
                </div>
                <a class="button" onclick={Action.submit_job}><i class="icon-plus icon-white"/> Add and run</a>
                <a class="button button-inverse" onclick={Action.error_test}><i class="icon-fire icon-white"/> Simulate a failure</a>
            </form>
        </div>
        <div class="span6">
            <h1>Logs</h1><div style="height: 232px; overflow: auto;"class="well"><p id=#info /></div>
        </div>
        </div>
        <div class="row-fluid">
            <h1>Jobs</h1>
            <div id="loading" style="width: 100%" class="progress progress-striped active">
                <div id="progress" class="bar" style="width: 0%;"></div>
            </div>
            <table class="table table-striped table-bordered"><tbody id=#jobs onready={Action.load_all}></tbody></table>
        </div>
        </div>
        <>{footer}</>
    }
}

module Controller {

    DropboxUser = DbDropbox.User(monitor)
    callback_domain = "http://server-monitor.herokuapp.com/demo"

    private function access_page(raw_token) {
        match (DropboxUser.get_access(raw_token)) {
        case { success } -> Resource.default_redirection_page("/demo")
        case { failure : error } -> Resource.html("Error", <>{error}</>)
        }
    }

    private function login_page() {
        redirect = "{callback_domain}/dropbox/connect"
        if (DropboxUser.is_authenticated()) {
          View.full_page(View.page())
        }else{
          match (DropboxUser.get_login_url(redirect)) {
          case { success : url } -> Resource.default_redirection_page(url)
          case { failure : error } -> Resource.html("Error", <>{error}</>)
          }
        }
    }

    dispatch = parser {
        case "/demo/dropbox/connect?" raw_token=(.*) -> access_page(Text.to_string(raw_token))
        case "/" -> View.full_page(View.welcome())
        case (.*) -> login_page()
    }
}

import-plugin unix

get_env = %% BslSys.get_env_var %%
port = Int.of_string(Option.default("8080", get_env("PORT")))

Server.start(
    { Server.http with ~port },
    [
      {resources: @static_resource_directory("resources")},
      { register : [ { doctype : { html5 } },
                     { css : [ "resources/css/style.css" ] }
                    ]
      },
      { custom : Controller.dispatch }
    ]
)
