# Markmotron

hi.  The markmotron started out as a sample campfire bot that would listen for words like "breakfast" and then and me a text message.  The if I failed to place an breafast order (yes, my employer buys breakfast some times.  They're amazing www.covermymeds.com/main/careers), it would order a default breakfast for me, acting as sort-if breakfast ordering dead-man's switch.

But why stop at breakfast?!  There's lots of little annoyances that can be scripted away.  How about this one: One I get an email that a bill is due from my insurance provider, send me a text of the bill amount, and ask me (y/n) if I want the markmotron to pay it?  If I say "yes", use phantomJS to manipulate the page and pay the bill.  If I say "no", then GTFO robot.

But I don't really want to commit code, and maintain a big code base of automation scripts.  I like github, and anyone will tell you that i _REALLLY_ like gists.  So what if we keep all the actual scripts in gists that can be reloaded by the markmotron dynamically?  Now that's something worth getting outta bed for (well that and free BLTs from the Warehouse Cafe).

So what started out as a ho-hum chatbot morphed into a framework for automating your life away with little gists.  And thanks to the encouragement of @justinrolston, it's opensource too.

----

## What is the markmotron in computer-speak?

- events. events. events.  All communication between markmotron components is done through events.  Just register and listen on the Markmotron global object.  You can of course register your own.  There are a few pre-bundled events for incomming email, HTTP GETs and POSTs done on the markmotron

- Building blocks included.  Your gist script files should be as simple as possible.  To help you out markmotron comes pre-bundled with shortcut modules for interacting with the world
  - `dapple-twilio  `: for sending text messages 
  - `dapple-aws     `: for putting files in and S3 bucket (has a hardcoded bucket name, you'll want to change that)
  - `dapple-imap    `: for working with email
  - `dapple-phantom `: for manipulating the bundled phantomJS process (advanced)
  - `dapple-sendgrid`: for sending email
  - `ranger         `: for interacting with Campfire chat rooms (staying true to roots!)
  - `bitly          `: for shortening URLs

  I recommended you store your credentials in ENV variables, which will be available to you through the global `env`

- When stateless communication isn't sufficient (like in the bill pay example) markmotron's sibling "Stackmotron" manages a communication stack. (read the source for control characters).  And there's stackmotron's love-child "Stackmotron-twilio" that's an SMS aware subclass

## How do I get scripts loaded?

- Set an ENV variable `WHEN_URL`.
- `WHEN_URL` should be a JSON array of objects that includes a `codeUrl` key and an optional `description` key.  E.g:
  ````
  [
    {
      codeUrl: "https://gist.github.com/dapplebeforedawn/c342/raw/markmotron-campfire.coffee",
      description: "Setup Campfire event bindings."
    },
    {
      codeUrl: "https://gist.github.com/dapplebeforedawn/ba07/raw/markmotron-orderDeadman.coffee",
      description: "Order a default breakfast if I haven't responded in 5 minutes."
    }
  ]
  ````
- Sorry h8ers, the script files need to be coffeescript, no raw javascript allowed.

## What's required of my scripts

- The need to be valid coffeescript.
- The markmotron contract:  When it's time for scripts to self-reload your script should know now to clean up by registering for `Markmotron`'s `destroy` event.  For example:

  ````
  destroy = ->
    console.log "destroying myscript.coffee"

    #clean up
    Markmotron.removeListener 'http.get.billPay' , initiateHttpGetBill
    Markmotron.removeListener 'bill-pay.pay-bill', initiateGetBill

    # don't forget to un-listen for destroy itself
    Markmotron.removeListener 'destroy'          , destroy
   
  # attach listeners to an event
  Markmotron.on 'http.get.billPay'  , initiateHttpGetBill
  Markmotron.on 'bill-pay.pay-bill' , initiateGetBill

  # and listen for destroy
  Markmotron.on 'destroy'           , destroy
  ````

## Working with PhantomJS

Since PhantomJS is it's own process, and has it's own event loop, it can't be run as a typical node module. (without some really ugly hacks).  Lucky-you, the markmotron handles all the messy IPC and named pipes for you.  Using the provided `dapple-phantom` module just give your `Phantom` object the URL of a coffeescript PhantomJS script, and environment to bind to (probably just use the affore-mentioned `env) and a callback.  When the script is done, the callback is holla' back.

````
Phantom = require 'dapple-phantom'

phantomCoffeeUrl  = 'https://gist.github.com/dapplebeforedawn/dc36/raw/markmotron-phantom-get-bill.coffee'
pEnv              = env
pEnv['billUrl']   = billUrl

gotBill = (err, data)->
  console.log "Got the bill!: ", JSON.parse(data)

Phantom phantomCoffeeUrl, pEnv, gotBill
````

## A sample script top-to-bottom

````
# all of nodes built in modules are available, plus some helpers
Twilio  = require 'dapple-twilio'
Phantom = require 'dapple-phantom'
AWS     = require 'dapple-aws'
Bitly   = require 'bitly'

aws     = new AWS("your-bucket-name")
smsTo   = '+15555375555'

# Get a bill amount using PhantomJS
getBillAmount = (billUrl)->
  phantomCoffeeUrl  = 'https://gist.github.com/dapplebeforedawn/dc36/raw/markmotron-phantom-get-bill.coffee'
  pEnv              = env # that `env` global I was talking about, derived from `Process.env`
  pEnv['billUrl']   = billUrl
  
  gotBill = (err, data)->
    billToSMS JSON.parse(data)
  
  Phantom phantomCoffeeUrl, pEnv, gotBill

# Send me an SMS with a shortened URL to the screen captured imaged that 
# we uploaded to my S3 bucket
billToSMS = (message)->
  sid  = env.TWILIO_SID
  auth = env.TWILIO_AUTH
  from = env.TWILIO_FROM
  to   = smsTo
  twilio = Twilio sid, auth, from

  saveToS3 message['screenshotPath'], (url)->  
    twilio.send to, "#{message['billAmount']} - #{url}", (err, resp)->
      return (console.log "TWILIO ERROR: ", err, resp) if err
      console.log resp
    
# This is SMS, we need a short URL
makeBitly = (longUrl, callback)->
  bitly = new Bitly(env.BITLY_USERNAME, env.BITLY_API_KEY)
  bitly.shorten longUrl, (err, response)->
    return console.log(err) if err
    callback(response.data.url)
    
# Save a tmp file to an S3 bucket for later viewing
saveToS3 = (filePath, callback)->
  aws.upload filePath, (err, url)->
    makeBitly url, (shortBillUrl)->
      callback shortBillUrl

initiateHttpGetBill = (req)->
  getBillAmount req.query.billUrl
  
initiateGetBill     = (url)->
  getBillAmount url

# Clean up
destroy = ->
 console.log "destroying bill-amount.coffee"
 Markmotron.removeListener 'http.get.billPay' , initiateHttpGetBill
 Markmotron.removeListener 'bill-pay.pay-bill', initiateGetBill
 Markmotron.removeListener 'destroy'          , destroy
 
# Regsister for events
Markmotron.on 'http.get.billPay'  , initiateHttpGetBill
Markmotron.on 'bill-pay.pay-bill' , initiateGetBill
Markmotron.on 'destroy'           , destroy
````
## Running the development server

You may have noticed the `Proc` file.  Start the development server with `foreman start`  (you'll need the [foreman gem](https://github.com/ddollar/foreman) if you don't alreday have it).  Then you can put your ENV variables in a `.env` file in the repository root (see `.env.sample`)

## TODO

I find my own lack of tests disturbing.  PRs accepted

## Parting words

Markmotron is all about having fun.  Don't use this in production.  Be nice.  Learn UNIX.

-- Love, Mark (Lorenz, not motron)

