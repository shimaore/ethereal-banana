{db} = require './local/config.json'

db = (require 'pouchdb') db

_id = 'support'

files =
  '''
  src/trace.coffee
  src/common.coffee
  src/gather.coffee
  assets/coffee-script.js
  assets/spin.min.js
  assets/jquery.spin.js
  assets/jquery-1.8.3.min.js
  assets/coffeecup.js
  src/index.css
  local/index.html

  local/entry-to-local.coffee
  local/local-to-global.coffee
  '''

files = files.split /\s+/

fs = require 'fs'
teacup = require 'teacup'
html = teacup.render require './src/index.coffee'
fs.writeFileSync 'local/index.html', html

it = db.put {_id}
  .catch -> console.log 'ignored'

for f in files
  do (f) ->
    it = it
      .then ->
        db.get _id
      .then ({_rev}) ->
        type = if f.match /\.js$/
          'application/javascript'
        else if f.match /\.coffee$/
          'application/coffeescript'
        else if f.match /\.css$/
          'text/css'
        else if f.match /\.html$/
          'text/html'

        name = f.replace /^(src|local)\//, ''
        console.log "AT rev #{_rev}, going to push #{f} #{type} to #{name}"
        db.putAttachment _id, name, _rev, fs.readFileSync(f), type
      .then ->
          console.log "Pushed #{f}"
