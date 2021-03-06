{doctype,html,head,meta,title,link,script,body,div,address} = require 'teacup'
pkg = require '../package.json'

module.exports = ->
  doctype 5
  html ->
    head ->
      meta charset: 'utf-8'
      title 'Telephony Support'
      link rel:'stylesheet', href:'index.css', type:'text/css'
      link rel:'stylesheet', href:'bower_components/js-sequence-diagrams/dist/sequence-diagram-min.css'
      script type:'text/javascript', src:'assets/coffeecup.js'
      script type:'text/javascript', src:'assets/jquery.min.js'
      script type:'text/javascript', src:'assets/jquery.spin.js'
      script type:'text/javascript', src:'assets/pouchdb.min.js'
      script type:'text/javascript', src:'assets/spin.min.js'
      script type:'text/javascript', src:'assets/moment.min.js'
      script type:'text/javascript', src:'assets/moment-timezone.min.js'
      script type:'text/javascript', src:'/socket.io/socket.io.js'
      script type:'text/javascript', src:'entry-to-local.js'
      script type:'text/javascript', src:'local-to-global.js'
      script type:'text/javascript', src:'config.js'
      script type:'text/javascript', src:'common.js'
      script type:'text/javascript', src:'gather.js'
      script type:'text/javascript', src:'trace.js'
      script type:'text/javascript', src:'bower_components/bower-webfontloader/webfont.js'
      script type:'text/javascript', src:'bower_components/snap.svg/dist/snap.svg-min.js'
      script type:'text/javascript', src:'bower_components/underscore/underscore-min.js'
      script type:'text/javascript', src:'bower_components/js-sequence-diagrams/dist/sequence-diagram-min.js'


    body ->
      div id:"main", ->
        div id:"entry"
        div id:"results"
      address ->
        "This is #{pkg.name} #{pkg.version}."
