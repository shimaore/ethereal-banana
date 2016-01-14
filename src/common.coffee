window.last_calls = (nl,gnum,limit = 20) ->
  $('.calls',nl).spin()

  db = new PouchDB "#{window.location.protocol}//#{window.location.host}/cdrs"

  db.query 'addon/cdr_by_number',
    endkey: [gnum]
    startkey: [gnum,'z']
    limit: limit
    include_docs: true
    descending: true
    stale: 'update_after'
  .then ({rows}) ->
    $('.calls',nl).empty()
    $('.calls',nl).append "<div>Last #{limit} calls:</div>"
    unless rows?
      $('.calls',nl).append '(none found)'
      return

    for row in rows
      do (row) ->
        doc = row.doc
        # FIXME: Add link to generate a trace based on to/from
        g3 = $ """
        <div class="call">
          #{doc.variables.start_stamp}
          (#{doc.variables.ccnq_direction}, #{doc.variables.ccnq_profile})
          #{doc.variables.ccnq_from_e164} → #{doc.variables.ccnq_to_e164}
          (billable: #{doc.variables.billsec}s,
           total: #{doc.variables.duration}s,
           #{doc.variables.hangup_cause})
        </div>
        """
        g3.data 'doc', doc
        $('.calls',nl).append g3
    return
  .catch (error) ->
    $('.calls',nl).empty().html "(no calls found for global number #{gnum}: #{error})"
  return

window.the_socket = socket = io()

zappa_prefix = '/zappa'
zappa_channel = '__local'

share = (channel_name,socket,next) ->
  zappa_prefix = zappa_prefix ? ""
  socket_id = socket.id
  if not socket_id?
    console.log "Missing socket_id"
    next? false
    return
  $.getJSON "#{zappa_prefix}/socket/#{channel_name}/#{socket_id}"
  .done ({key}) ->
    if key?
      console.log "Sending key #{key}"
      socket.emit '__zappa_key', {key}, next
    else
      console.log "Missing key: #{arguments}"
      next? false
  .fail ->
    next? false

socket.on 'connect', ->
  share zappa_channel, socket, (ok) ->
    console.log {ok}
    socket.emit 'join'

socket.on 'ready', ({roles}) ->
  console.log {roles}
