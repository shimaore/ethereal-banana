{db} = require './local/config.json'
PouchDB = require ('pouchdb-core')
  .plugin require ('pouchdb-adapter-http')

db = new PouchDB db

_id = 'support'

files =
  '''
  bower_components/bower-webfontloader/webfont.js
  bower_components/snap.svg/dist/snap.svg-min.js
  bower_components/underscore/underscore-min.js
  bower_components/js-sequence-diagrams/dist/sequence-diagram-min.js
  bower_components/js-sequence-diagrams/dist/sequence-diagram-min.css
  bower_components/js-sequence-diagrams/fonts/daniel/danielbd.woff
  bower_components/js-sequence-diagrams/fonts/daniel/danielbd.woff2
  lib/trace.js
  lib/common.js
  lib/gather.js
  src/index.css
  lib/index.html
  lib/entry-to-local.js
  lib/local-to-global.js
  lib/config.js
  assets/spin.min.js
  assets/jquery.spin.js
  assets/jquery.min.js
  assets/coffeecup.js
  assets/pouchdb.min.js
  assets/moment.min.js
  assets/moment-timezone.min.js
  '''

files = files.split /\s+/

fs = require 'fs'
teacup = require 'teacup'
html = teacup.render require './src/index.coffee'
fs.writeFileSync 'lib/index.html', html

it = db.put {_id}
  .catch (error) -> console.log "#{error.message} (ignored)"

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
        else if f.match /\.json$/
          'application/json'
        else if f.match /\.woff2?$/
          'application/font-woff'

        name = f.replace /^(src|local|lib)\//, ''
        console.log "AT rev #{_rev}, going to push #{f} #{type} to #{name}"
        content = try fs.readFileSync(f)
        if content?
          db.putAttachment _id, name, _rev, content, type
        else
          console.log "Unable to read #{f}, skipping."
      .then ->
          console.log "Pushed #{f}"
