{doctype,html,head,meta,title,link,script,body,div,address} = require 'teacup'
pkg = require '../package.json'

module.exports = ->
  doctype 5
  html ->
    head ->
      meta charset: 'utf-8'
      title 'Telephony Support'
      link rel:'stylesheet', href:'index.css', type:'text/css'
      script type:'text/javascript', src:'assets/coffee-script.js'
      script type:'text/javascript', src:'assets/coffeecup.js'
      script type:'text/javascript', src:'assets/jquery.min.js'
      script type:'text/javascript', src:'assets/jquery.spin.js'
      script type:'text/javascript', src:'assets/pouchdb.min.js'
      script type:'text/javascript', src:'assets/spin.min.js'
      script type:'text/javascript', src:'assets/moment.min.js'
      script type:'text/javascript', src:'assets/moment-timezone.min.js'
      script type:'text/javascript', src:'/socket.io/socket.io.js'
      script type:'text/coffeescript', src:'entry-to-local.coffee'
      script type:'text/coffeescript', src:'local-to-global.coffee'
      script type:'text/coffeescript', src:'config.coffee'
      script type:'text/coffeescript', src:'common.coffee'
      script type:'text/coffeescript', src:'gather.coffee'
      script type:'text/coffeescript', src:'trace.coffee'
    body ->
      div id:"main", ->
        div id:"entry"
        div id:"results"
      address ->
        "This is #{pkg.name} #{pkg.version}."
