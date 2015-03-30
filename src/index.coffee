{doctype,html,head,meta,title,link,script,body,div} = require 'teacup'
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
      script type:'text/javascript', src:'assets/jquery-1.8.3.min.js'
      script type:'text/javascript', src:'assets/jquery.spin.js'
      script type:'text/javascript', src:'assets/spin.min.js'
      script type:'text/javascript', src:'/socket.io/socket.io.js'
      script type:'text/coffeescript', src:'entry-to-local.coffee'
      script type:'text/coffeescript', src:'local-to-global.coffee'
      script type:'text/coffeescript', src:'common.coffee'
      script type:'text/coffeescript', src:'gather.coffee'
      script type:'text/coffeescript', src:'trace.coffee'
      script id='pkg', type:'application/json', JSON.stringify pkg
    body ->
      div id:"main", ->
        div id:"entry"
        div id:"results"
