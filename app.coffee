express = require("express")
http    = require("http")
path    = require("path")
url     = require("url")
imap    = require("dapple-imap")
app     = express()

global.Stackmotron = require("stackmotron-twilio")
global.Markmotron  = require("./markmotron")
Markmotron.reload()

# all environments
app.set "port", process.env.PORT
app.set "views", __dirname + "/views"
app.set "view engine", "jade"
app.use express.favicon()
app.use express.logger("dev")
app.use express.bodyParser()
app.use express.methodOverride()
app.use express.cookieParser("your secret here")
app.use express.session()
app.use app.router
app.use require("less-middleware")(src: __dirname + "/public")
app.use express.static(path.join(__dirname, "public"))

# development only
app.use express.errorHandler()  if "development" is app.get("env")

app.post "/reload", (req, res)->
  Markmotron.reload()
  res.json {status: "reloaded"}

eventUrl = (req)->
  reqUrl = url.parse(req.url).pathname
  eventPath = reqUrl.replace(/^\//, '').replace(/\//g, '.')
  if eventPath then ".#{event}" else ""

app.get /..*/, (req, res)->
  Markmotron.emit "http.get.#{eventUrl(req)}", req
  res.json 200, {message:"OK"}

app.post /..*/, (req, res)->
  # if it's twilio, is not a Stackmotron status request then work the stack.
  # if there's nothing on the stack, just treat it like a regular POST
  unless Stackmotron.handle(req)
    Markmotron.emit "http.post#{eventUrl(req)}", req
  res.json 200, {message:"OK"}

http.createServer(app).listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

imap.on 'mail', (mailMessage)->
  Markmotron.emit "mail", mailMessage
  Markmotron.emit "mail.to.#{mailMessage.headers.to[0].address}", mailMessage
  Markmotron.emit "mail.from.#{mailMessage.headers.from[0].address}", mailMessage

  console.log "mail.to.#{mailMessage.headers.to[0].address}"
  console.log "mail.from.#{mailMessage.headers.from[0].address}"
