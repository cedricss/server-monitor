import stdlib.themes.bootstrap.{css, icons, responsive}

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

}

client module Action {

    function msg(url, class, msg) {
        // Add a log on top of the logs list
        #info += <div>
                    <span class="label">{Date.to_string_time_only(Date.now())}</span>
                    <span class="label {class}">{url} {msg}</span>
                 </div>
    }

    function up(url) { msg(url, "label-success", "is UP") }
    function invalid(url) { msg("ERROR: {url}", "label-inverse", "an invalid url") }
    function down(name, url, failure, status) { msg(url, "label-important", "is DOWN ({failure})"); }
    function test(name, url, status) { msg("", "label-inverse", "You should see a Dropbox popup on your desktop"); }
    function error_test(_) { test(Dom.get_value(#name), Dom.get_value(#url), { error_simulation }) }

    function add_job(name, url, uri, freq) {
        timer = Scheduler.make_timer(freq*1000, function() { Job.check(name, url, uri) });
        Job.check(name, url, uri); timer.start();
        // Add a new line on top of the job list
        #jobs += <tr id=#{name}>
                    <td>{url} each {freq} sec</td>
                    <td></td>
                 </tr>;

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

}
module View {

    function page() {
        <div class="navbar navbar-fixed-top"><div class="navbar-inner"><div class="container">
                <a href="/hero" class="brand">Server Monitor</a><ul class="nav "></ul>
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
                <a class="btn btn-primary" onclick={Action.submit_job}><i class="icon-plus icon-white"/> Add and run</a>
                <a class="btn btn-small btn-inverse"><i class="icon-fire icon-white"/> Simulate a failure</a>
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
            <table class="table table-striped table-bordered"><tbody id=#jobs></tbody></table>
        </div>
        </div>
    }
}

Server.start(
    Server.http,
    [ { register : { doctype : { html5 } } },
      { title : "hello", page : View.page }
    ]
)
