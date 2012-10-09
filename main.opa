import stdlib.themes.bootstrap.{css, icons, responsive}

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
                <a class="btn btn-primary"><i class="icon-plus icon-white"/> Add and run</a>
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
