# FIXME rewrite into riot.js and provide proper tz handling!
console.log 'Loading trace.coffee'

timezone = 'Europe/Paris'

qs =
  escape: encodeURIComponent

log = -> console.log arguments...

# Display all hosts at once

packets = []

TIME = '_ws.col.Time'

add_packets = (doc) ->
  new_packets = doc.packets
  packets = packets
    .concat new_packets
    .sort (a,b) -> a[TIME] - b[TIME]
    .splice -100

  ###
  endpoints = {}
  index = 0

  register_endpoint = (name) ->
    if name of endpoints
      return endpoints[name]
    endpoints[name] = index++
  ###

  for packet in packets
    src_endpoint = "#{packet['ip.src']} (#{packet['udp.srcport']})"
    dst_endpoint = "#{packet['ip.dst']} (#{packet['udp.dstport']})"
    # src_endpoint = packet['ip.src']
    # dst_endpoint = packet['ip.dst']
    packet.src_endpoint = src_endpoint.replace ',', ' '
    packet.dst_endpoint = dst_endpoint.replace ',', ' '
    ###
    src_i = register_endpoint src_endpoint
    dst_i = register_endpoint dst_endpoint
    ###

  ###
  columns = []
  for own k,v of endpoints
    columnts[v] = k
  ###

show_diagram = ->
  txt = ""
  started = false
  for packet in packets
    # Start on a Request
    started = true if packet['sip.Method']?
    continue unless started
    # description = packet['sip.Method'] ? packet['sip.Status-Code']
    description = packet['sip.Request-Line'] ? packet['sip.Status-Line']
    # txt += "Note over #{packet.src_endpoint}: #{packet['udp.srcport']} \r\n"
    # txt += "Note over #{packet.dst_endpoint}: #{packet['udp.dstport']} \r\n"
    txt += "Note over #{packet.src_endpoint}: #{packet[TIME]}\r\n"
    txt += "#{packet.src_endpoint} -> #{packet.dst_endpoint} : #{description} \r\n"

  d = Diagram.parse txt
  d.drawSVG 'diagram', theme: 'simple'

# Legacy display

display_host = (doc) ->
  user = doc.from_user ? '(any)'
  if doc.from_user isnt doc.to_user
    user += " / #{doc.to_user ? '(any)'}"
  el_host = $ """
    <div>
      <h2 class="host"><a name="#{doc.reference}/#{doc.host}">#{doc.host}</a></h2>
      <p class="query">#{user} / #{if doc.use_xref then doc.reference else '(any)'} / #{doc.call_id ? '(any)'} / #{doc.ip ? '(any)'} / #{doc.port ? '(any)' }/ #{doc.days_ago ? '(any)'} days ago.</p>
    </div>
  """
  el_host.data 'doc', doc

  if doc.packets? and doc.packets.length > 0

    # Compute Call-ID transitions
    last_callid = ''
    for packet in doc.packets
      callid = packet['sip.Call-ID']
      packet.is_new = callid isnt last_callid
      last_callid = callid

    # Content
    len = doc.packets.length

    el_link = $ pcap_link doc
    el_host.append el_link

    el_packets = $ "<div><button>Show all #{len} packets</button></div>"

    current = 0

    # Note how we match on starting `r` (since we are the ones defining the reference, see below).
    if m = window.location.hash?.match /// ^# (?:r[^/]+) / (?:[^/]+) / (\d+) ///
      current = parseInt m[1]
    for packet,i in doc.packets
      packet.number = i+1
      packet.reference = doc.reference
      packet.host = doc.host
      packet.current = packet.number is current

    limit = 50
    if len > limit
      el_packets.children('button').click ->
        el_packets.empty()
        display_packets el_packets, doc.packets
      display_packets el_packets, doc.packets[(len-limit)..]
    else
      el_packets.children('button').remove()
      display_packets el_packets, doc.packets

    el_host.append el_packets

  else

    el_host.append 'No packets'

  el_host

palette = {}
next_palette = 0
get_palette = (call_id) ->
  if palette[call_id]?
    "palette_#{palette[call_id]}"
  else
    "palette_#{palette[call_id] = next_palette++}"

sip_request = coffeecup.compile ->
  call_id = @['sip.Call-ID']
  link = "#{@reference}/#{@host}/#{@number}"
  a name:link
  div class:"packet request split-#{@is_new} #{@get_palette call_id} #{if @current then 'current' else ''}", ->
    a href:"##{link}", @number
    span ' '
    span class:"time",  -> @time
    span ' '
    span class:"src",   -> @['ip.src']+':'+ (@['udp.srcport'] ? @['tcp.srcport'])
    span ' → '
    span class:"dst",   -> @['ip.dst']+':'+ (@['udp.dstport'] ? @['tcp.dstport'])
    span ' '
    span class:"from", title: h(@['sip.From'] ? ''), -> @['sip.from.user']
    span ' → '
    span class:"to", title:h(@['sip.To'] ? ''), -> @['sip.to.user']
    span ' '
    span class:"method", title:h(@['sip.Request-Line'] ? ''), -> @['sip.Method']
    span ' '
    span class:"ruri",  -> @['sip.r-uri.user']+'@'+@['sip.r-uri.host']

sip_response = coffeecup.compile ->
  call_id = @['sip.Call-ID']
  link = "#{@reference}/#{@host}/#{@number}"
  a name:link
  div class:"packet response split-#{@is_new} #{@get_palette call_id} #{if @current then 'current' else ''}", ->
    a href:"##{link}", @number
    span ' '
    span class:"time",  -> @time
    span ' '
    span class:"dst",   -> @['ip.dst']+':'+ (@['udp.dstport'] ? @['tcp.dstport'])
    span ' ← '
    span class:"src",   -> @['ip.src']+':'+ (@['udp.srcport'] ? @['tcp.srcport'])
    span ' '
    span class:"from", title:h(@['sip.From'] ? ''), -> @['sip.from.user']
    span ' ← '
    span class:"to", title:h(@['sip.To'] ? ''), -> @['sip.to.user']
    span ' '
    span class:"status", title:h(@['sip.Status-Line'] ? ''), -> @['sip.Status-Code']

pcap_link = coffeecup.compile ->
  a href: "/logging/trace:#{@reference}:#{@host}/packets.pcap", ->
    'Download (PCAP)'

format_host_link = (h,v,r) ->
  switch v
    when true
      """
        <a href="##{r}/#{h}">#{h}</a>
      """
    when false
      """
        #{h}
      """
    when null
      """
        <em>#{h}</em>
      """

display_packets = (root,packets) ->
  for packet in packets
    packet.get_palette = get_palette
    # nifty-ground 2.x
    time = packet['_ws.col.Time']
    if time?
      packet.time = moment.tz(time,'UTC').tz(timezone).format()
    # nifty-ground 1.x
    else
      packet.time = packet['frame.time']
    if packet["sip.Method"]
      el = $ sip_request packet
    else
      el = $ sip_response packet
    el.data 'packet', packet
    root.append el

processed_host = {}

list_host = (doc,good) ->
  # Only show the response from each host once!
  processed_host[doc.host] = good
  $('#hosts').html 'Hosts: '
  for h in Object.keys(processed_host).sort()
    $('#hosts').append "  #{format_host_link h, processed_host[h], doc.reference}"

get_response = (reference) ->
  $('#results').html '''
    <div id="hosts">(no hosts yet)</div>
    <div id="traces">(no traces yet)</div>
    <div id="diagram">(diagram)</div>
  '''

  db = new PouchDB "#{window.location.protocol}//#{window.location.host}/logging"
  db.allDocs
    startkey: "trace:#{reference}:"
    endkey: "trace:#{reference};"
    include_docs: true
  .then ({rows}) ->
    for row in rows
      do (row) ->
        doc = row.doc

        list_host doc, true
        $('#traces').append display_host doc
        add_packets doc

  .catch (error) ->
    log 'Failed to retrieve trace documents'
    $('#traces').html 'There was an error retrieving traces.'
    log error
  .then ->
    show_diagram()

# Process response (callback)
socket = window.the_socket

socket.on 'trace_started', ({host,in_reply_to}) ->
  log 'trace started'
  log {host,in_reply_to}
  if in_reply_to.reference is our_reference
    list_host {host}, null

socket.on 'trace_completed', ({host,in_reply_to}) ->
  log 'trace completed'
  log {host,in_reply_to}
  if in_reply_to.reference is our_reference
    list_host {host}, true
    $('#traces').append display_host in_reply_to

socket.on 'trace_error', ({host,in_reply_to,error}) ->
  log 'trace error'
  log {host,in_reply_to,error}
  if in_reply_to.reference is our_reference
    list_host {host}, false

our_reference = null
send_request = (request,cb) ->
  our_reference = request.reference
  socket.emit 'join', "trace:#{our_reference}", ->
    socket.emit 'trace', request
    cb?()
    return
  return

show_query = ->

  # Add HTML form for query
  $('#entry').append '''
    <form id="trace">
      <label>Number:
        <input type="tel" name="user" id="user" size="16" class="focus" />
      </label>
      <label>xref:
        <input type="text" name="xref" id="xref" size="10"/>
      </label>
      <label>Call-ID:
        <input type="text" name="call_id" id="call_id" />
      </label>
      <label>IP:
        <input type="text" name="ip" id="ip" />
      </label>
      <label>Port:
        <input type="number" name="port" id="port" value="" size="5" />
      </label>
      <label>
        <input type="number" name="days_ago" id="days_ago" value="" size="2" />
        days ago
      </label>
      <input type="submit" />
    </form>
    <div class="calls"></div>
  '''
  $('.focus').focus()

  t = null
  $('body').on 'keyup', '#user', ->
    # Throttle
    if t? then clearTimeout t
    t = setTimeout run, 250

  run = ->

    t = null

    # Cleanup parameters
    user = $('#user').val()
    if user? and user isnt ''
      user = user.replace /[^\d]+/g, ''
      user = entry_to_local user
    if not user? or user is ''
      user = null

    return unless user?

    last_calls $('#trace'), user

  # Handle parameter in hash
  if window.location.hash? and m = window.location.hash.match /^#number=(\d+)/
    user = m[1]
    $('#user').val user
    $('#user').keyup()

  # Handle form submission
  t = null
  $('body').on 'submit', '#trace', (e) ->
    e.preventDefault()

    $('#traces').spin()

    # Cleanup parameters
    user = $('#user').val()
    if user
      user = user.replace /[^\d@a-z-]+/g, ''
    if not user or user is ''
      user = null

    xref = $('#xref').val()
    if xref? and xref isnt ''
      xref = xref.replace /^\s+|\s+$/g, ''
    if not xref? or xref is ''
      xref = null

    call_id = $('#call_id').val()
    if call_id? and call_id isnt ''
      call_id = call_id.replace /^\s+|\s+$/g, ''
    if not call_id? or call_id is ''
      call_id = null

    ip = $('#ip').val()
    if ip? and ip isnt ''
      ip = ip.replace /\s+/g, ''
    if not ip? or ip is ''
      ip = null

    port = $('#port').val()
    if port? and port isnt ''
      port = parseInt port
    if not port or port is ''
      port = null

    days_ago = $('#days_ago').val()
    if days_ago? and days_ago isnt ''
      days_ago = parseInt days_ago
    if not days_ago or days_ago is ''
      days_ago = null

    unless user? or xref? or call_id? or ip? or port?
      alert 'You must enter a criteria.'
      return

    $('#results').html '''
      <div id="hosts">(no hosts yet)</div>
      <div id="traces">&nbsp;</div>
      <div id="diagram">(diagram)</div>
    '''

    # _Our_ references start with the letter `r`.
    if xref?
      reference = xref
    else
      reference = 'r'+Math.random()

    # Send request
    request = {reference}
    request.from_user = user      if user?
    request.to_user   = user      if user?
    request.use_xref  = xref?
    request.call_id   = call_id   if call_id?
    request.ip        = ip        if ip?
    request.port      = port      if port?
    request.days_ago  = days_ago  if days_ago?
    send_request request, ->
      $('#entry').empty()
      window.location.hash = "#R=#{reference}"

    # No default
    return false

  # Links for xrefs
  $('body').on 'click', '.xref', (e) ->
    doc = $(@).parent().data 'doc'
    request = {reference}
    request.call_id = call_id   if doc.call_id?
    send_request request

  return

$ ->
  switch
    # Legacy format
    when window.location.hash? and m = window.location.hash.match /^#(r[\d.]+)/
      reference = m[1]
      get_response reference
    # New format
    when window.location.hash? and m = window.location.hash.match /^#R=(.+)/
      reference = m[1]
      get_response reference
    else
      do show_query

console.log 'Loaded trace.coffee'
