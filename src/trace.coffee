qs =
  escape: encodeURIComponent

log = -> console.log arguments...

display_host = (doc) ->
  user = doc.from_user ? '(any)'
  if doc.from_user isnt doc.to_user
    user += " / #{doc.to_user ? '(any)'}"
  el_host = $ """
    <div>
      <h2 class="host"><a name="#{doc.reference}/#{doc.host}">#{doc.host}</a></h2>
      <p class="query">#{user} / #{doc.call_id ? '(any)'} / #{doc.days_ago ? '(any)'} days ago.</p>
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
    if m = window.location.hash?.match /// ^# (?:[^/]+) / (?:[^/]+) / (\d+) ///
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
    span class:"time",  -> @['frame.time']
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
    span class:"time",  -> @['frame.time']
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

  .catch (error) ->
    log 'Failed to retrieve trace documents'
    $('#traces').html 'There was an error retrieving traces.'
    log error

# Process response (callback)
socket = window.the_socket

socket.on 'trace_started', ({host,in_reply_to}) ->
  console.log 'trace started'
  console.log {host,in_reply_to}
  if in_reply_to.reference is our_reference
    list_host {host}, null

socket.on 'trace_completed', ({host,in_reply_to}) ->
  console.log 'trace completed'
  console.log {host,in_reply_to}
  if in_reply_to.reference is our_reference
    list_host {host}, true
    $('#traces').append display_host in_reply_to

socket.on 'trace_error', ({host,in_reply_to,error}) ->
  console.log 'trace error'
  console.log {host,in_reply_to,error}
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
      <label>Call-ID:
        <input type="text" name="call_id" id="call_id" />
      </label>
      <label>IP:
        <input type="text" name="ip" id="ip" />
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
    limit = $('#limit').val()

    # Cleanup parameters
    user = $('#user').val()
    if user? and user isnt ''
      user = user.replace /[^\d]+/g, ''
      user = entry_to_local user
    if not user? or user is ''
      user = null

    return unless user?

    last_calls $('#trace'), user

  # Handle form submission
  t = null
  $('body').on 'submit', '#trace', (e) ->
    e.preventDefault()

    $('#traces').spin()

    reference = 'r'+Math.random()

    # Cleanup parameters
    user = $('#user').val()
    if user
      user = user.replace /[^\d]+/g, ''
    if not user or user is ''
      user = null

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

    days_ago = $('#days_ago').val()
    if days_ago? and days_ago isnt ''
      days_ago = parseInt days_ago
    if not days_ago or days_ago is ''
      days_ago = null

    unless user? or call_id? or ip?
      alert 'You must enter a criteria.'
      return

    $('#results').html '''
      <div id="hosts">(no hosts yet)</div>
      <div id="traces">&nbsp;</div>
    '''

    # Send request
    request = {reference}
    request.from_user = user      if user?
    request.to_user   = user      if user?
    request.call_id   = call_id   if call_id?
    request.ip        = ip        if ip?
    request.days_ago  = days_ago  if days_ago?
    send_request request, ->
      $('#entry').empty()
      window.location.hash = "##{reference}"

    # No default
    return false

  # Links for callids
  $('body').on 'click', '.callid', (e) ->
    doc = $(@).parent().data 'doc'
    reference = 'r'+Math.random()
    request = {reference}
    request.call_id   = call_id   if doc.call_id?
    send_request request

  return

$ ->
  if window.location.hash? and m = window.location.hash.match /^#(r[\d.]+)/
    reference = m[1]
    get_response reference
  else
    do show_query

return
