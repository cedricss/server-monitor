# Dropbox-as-a-Database, the tutorial #

Yesterday, our [Dropbox-as-a-Database](http://blog.opalang.org/2012/10/dropbox-as-database.html) blog post raised a lot of positive comments, in particular on [Hacker News](http://news.ycombinator.com/item?id=4723087) and Twitter. To get an idea of the DaaD concept, I created a [demo application](http://server-monitor.herokuapp.com) using this new database back-end. 

The demo arousing much interest, we decided not stop here! Today, we are introducing a tutorial to cover all steps of the creation of this application. Not all aspects all covered yet, but the goal is to explain in detail how the one-day demo app was built.

TL; DR: look at the [commits](https://github.com/cedricss/server-monitor/commits/master)

<a href="http://server-monitor.herokuapp.com/resources/img/screenshot.png"><img src="http://server-monitor.herokuapp.com/resources/img/screenshot.png"/></a>

The tutorial will walk you through:

- create the application View (with HTML templates),
- add event handlers (and play with client/server magic),
- configure the application (within the app),
- interact with the DOM (JavaScript on steroids),
- parse user inputs and urls,
- use modules, recursive functions, records, block notations, types and pattern matching,
- use the Opa path notation to handle data stored in a MongoDB database,
- switch from a MongoDB database to a Dropbox one.

<!-- more -->

# View #

## Initial User Interface ##

<a href="https://raw.github.com/cedricss/server-monitor/demo/resources/img/initial-view.png"><img src="https://raw.github.com/cedricss/server-monitor/demo/resources/img/initial-view.png"/></a>

Let's start with the UI. We create a `View` module with a `page` function inside. It will serve the HTML page to users:

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

As we can see, Opa allows to write HTML directly without quotes, which frees us from the troublesome single and double quotes in pure JavaScript. 
Also, Opa checks the HTML structure automatically. Try removing a closing tag!
Get the <a href="https://github.com/cedricss/server-monitor/blob/34985981fa40de13c5a9f371f32be2a172e70621/main.opa">full view code on github.</a>

## Http Server ##

We setup (outside of the `View` module) a http server configured to serve the page we just created:

    Server.start(
        Server.http,
        [ { register : { doctype : { html5 } } },
          { title : "hello", page : View.page }
        ]
    )

> With Opa, we can define the client views and events, the http server or even the database within the same file, without any extra directives for the compiler!

## Compile ##

We compile and see the result at the `http://localhost:8080` url:

    opa main.opa --
    Http serving on http://localhost:8080

> `--` means "compile and run". You can add extra runtime options, for example `opa main.opa -- --port 9090`
 
## Bootstrap theme ##

We want to use the default <a href="http://twitter.github.com/bootstrap/">bootstrap css theme</a> provided by Twitter. We just have to import the theme at the beginning of our file. We also import the glyphicons and the responsive css so the application can work well on different display sizes:

    import stdlib.themes.bootstrap.css
    import stdlib.themes.bootstrap.icons
    import stdlib.themes.bootstrap.responsive

Or shorter:

    import stdlib.themes.bootstrap.{css, icons, responsive}

We compile and restart the server to appreciate the easy style improvement!

Get the [source code at this step on github](https://github.com/cedricss/server-monitor/blob/34985981fa40de13c5a9f371f32be2a172e70621/main.opa).

# Add jobs (Client-side) #

## Update the Dom ##

We add a new `Action` module that will be responsible of the user interface updates. Opa dispatches the code on the server side and the client side automatically, and automates the calls between client and server. To get more control and optimize your code, you can use `server` and `client` directives to tweak the compiler default dispatch behavior.

For example, here we want all user interface related actions to be computed on the client side as much as possible. To do so, we just add a `client` directive on the module to affect all functions inside it. Let's create two functions inside this module, one to add a job in the list of jobs, one to add a message in the logs:

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

<a href="https://raw.github.com/cedricss/server-monitor/demo/resources/img/user-inputs.png"><img src="https://raw.github.com/cedricss/server-monitor/demo/resources/img/user-inputs.png"/></a>

Inside the `Job` module, we need to add functions to check the format of user inputs (is it a integer? is it an well formed url?). The following code is based on the default parsers defined in the [`Parser`](http://doc.opalang.org/module/stdlib.core.parser/Parser) module.

Those parsing functions return an `option`, which is either `{none}` (it failed to parse the value), or `{some:v}` where `v` is the constructed value after the parsing and with the expected type (int, url, etc).

        function submit_job(_) {

            function p(f, d, error){
                match (f(Dom.get_value(d))) {
                case {none}: 
                  msg("ERROR:", "label-error", error);
                  none
                case r: r
                // case {some:v}: {some:v} is equivalent
                }
            }

            // Parse form inputs and add the job
            uri  = p(Uri.of_string, #url,  "the url is invalid");
            name = p(Parser.ident,  #name, "the log name is not a valid ident name");
            freq = p(Parser.int,    #freq, "the frequency is not an integer");

            match ((uri, name, freq)) {
            case ({some:uri}, {some:name}, {some:freq}):
              add_job(name, Dom.get_value(#url), uri, freq)
            default: void // some invalid inputs, don't add the job
            }
        }

    }

> - `Dom.get_value(#url)` returns the value set in the input of id `url`
> - The `_` argument in the `submit_job` function means we don't care what is the name and the value of this argument. In this case, it is a value of type `Dom.event` given by events like `onclick` or `onready` (see below).

## Dom events ##

In the `View.page` function, we update the "Add and run" html button so the `submit_job` function is called when a user click on it. It's easy to deal with dom events with Opa: we just put the function to call inside curly brackets and attach it to the event:

    <a class="btn btn-primary" onclick={ Action.submit_job }>
      <i class="icon-plus icon-white"/> Add and run
    </a>

[See all the changes we made in this "Add Jobs" section](https://github.com/cedricss/server-monitor/commit/cd66d95c5f72d12b32e9f74fe2c7d1b57526aa07).

Compile and try the "Add an run" button providing both valid and invalid input values: jobs are added in the list of jobs or error messages are printed in the logs.

## To be continued ##

In the next article we'll discuss about how to monitor the servers behind the job urls and how to control those jobs (play, pause, edit and remove).

