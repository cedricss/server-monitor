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