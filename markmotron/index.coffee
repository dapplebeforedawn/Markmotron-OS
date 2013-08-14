https         = require("https")
events        = require("events")
moduleLoader  = require "../module_loader"

class Markmotron
  emitter = new events.EventEmitter
  emitter.setMaxListeners 0

  #proxy on and emit to the underlying emitter
  @on: (event, listener)->
    emitter.on event, listener
  @once: (event, listener)->
    emitter.once event, listener
  @emit: (event)->
    #Array.prototype.slice.call to turn arguments into a real array
    #and then slice again to get the caddr
    console.log "Markmotron Emit: ", event
    args = Array.prototype.slice.call(arguments).slice(1, arguments.length)
    emitter.emit event, args...
  @removeListener: (event, listener)->
    emitter.removeListener event, listener
  
  # send destroy to any current hot modules
  # register the system listeners to download the 
  # appropriate hot modules and run them.
  @reload: ->
    emitter.emit 'destroy'
    https.get process.env.WHEN_URL, (res)->
      hotModulesData = ""
      res.on 'data', (data)->
        hotModulesData += data

      res.on 'end', ()->
        hotModules = JSON.parse hotModulesData
        for hotModule in hotModules
          moduleLoader.load hotModule

module.exports = Markmotron
