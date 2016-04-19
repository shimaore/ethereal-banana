addon =
   _id: '_design/addon'
   language: 'coffeescript'
   views:
     cdr_by_number:
       map: '''
        (doc) ->
          return unless doc.variables?
          if doc.variables.ccnq_from_e164?
            emit [
              doc.variables.ccnq_from_e164
              doc.variables.start_stamp
            ]
          if doc.variables.ccnq_to_e164?
            emit [
              doc.variables.ccnq_to_e164
              doc.variables.start_stamp
            ]
          return
        '''

global_call = (row) ->
  doc = row.doc
  # FIXME: Add link to generate a trace based on to/from
  v = doc.variables
  g3 = $ """
  <div class="call #{v.ccnq_direction}">
    <a href="/_utils/document.html?cdrs/#{doc._id}">
    #{v.start_stamp}
    </a>
    (#{v.ccnq_direction}, #{v.ccnq_profile})
    #{v.ccnq_from_e164} → #{v.ccnq_to_e164}
    (billable: #{v.billsec}s,
     total: #{v.duration}s,
     #{v.hangup_cause})
  </div>
  """
  g3.data 'doc', doc
  g3

local_call = (row) ->
  doc = row.doc
  # FIXME: Add link to generate a trace based on to/from
  v = doc.variables
  g3 = $ """
  <div class="call #{v.ccnq_direction}">
    <a href="/_utils/document.html?cdrs-client/#{doc._id}">
    #{v.start_stamp}
    </a>
    (#{v.ccnq_direction})
    <b>#{v.ccnq_from_e164}</b> → <b>#{v.ccnq_to_e164}</b>
    <span class="failure">#{v.sip_invite_failure_status ? ''} #{v.sip_invite_failure_phrase ? ''}</span>
    (billable: #{v.billsec}s,
     progress: <b>#{v.progresssec}s</b>,
     answer: #{v.answersec}s,
     total: #{v.duration}s)
     #{v.hangup_cause}
     #{v.originate_disposition}
     #{v.endpoint_disposition}
     #{v.sip_hangup_disposition}
     #{v.sip_hangup_phrase ? ''}
    <div class="call-quality">
    Quality:
      <b>#{v.rtp_audio_in_mos}</b>
      (in:
      #{v.rtp_audio_in_media_bytes} bytes
      #{v.rtp_audio_in_media_packet_count} pkts
      #{v.rtp_audio_in_flaw_total} flaws
      #{v.rtp_audio_in_skip_packet_count} skip
      #{v.rtp_audio_in_dtmf_packet_count} dtmf
      #{v.rtp_audio_in_cng_packet_count} cng
    , jitter:
      #{v.rtp_audio_in_jitter_packet_count} pkts
      #{v.rtp_audio_in_jitter_min_variance} min
      #{v.rtp_audio_in_jitter_max_variance} max
      #{v.rtp_audio_in_jitter_loss_rate} loss
      #{v.rtp_audio_in_jitter_burst_rate} burst
    , out:
      #{v.rtp_audio_out_media_bytes} bytes
      #{v.rtp_audio_out_media_packet_count} pkts
      #{v.rtp_audio_out_skip_packet_count} skip
      #{v.rtp_audio_out_dtmf_packet_count} dtmf
      #{v.rtp_audio_out_cng_packet_count} cng
      )
    </div>
  </div>
  """
  g3.data 'doc', doc
  g3

run_global = (nl,gnum,limit) ->
  db = new PouchDB "#{window.location.protocol}//#{window.location.host}/cdrs"
  db
  .put addon
  .catch -> true
  .then ->
    db.query 'addon/cdr_by_number',
      endkey: [gnum]
      startkey: [gnum,'z']
      limit: limit
      include_docs: true
      descending: true
      stale: 'update_after'
  .then ({rows}) ->
    $('.calls',nl)
      .empty()
      .append "<div>Last #{limit} calls (global/carrier side):</div>"
    unless rows?
      $('.calls',nl).append '(none found)'
      return

    for row in rows
      do (row) ->
        $('.calls',nl).append global_call row
    return
  .catch (error) ->
    $('.calls',nl).empty().html "(no calls found for global number #{gnum}: #{error})"

run_local = (nl,gnum,limit) ->
  dbl = new PouchDB "#{window.location.protocol}//#{window.location.host}/cdrs-client"

  dbl
  .put addon
  .catch -> true
  .then ->
    dbl.query 'addon/cdr_by_number',
      endkey: [gnum]
      startkey: [gnum,'z']
      limit: limit
      include_docs: true
      descending: true
      stale: 'update_after'
  .then ({rows}) ->
    $('.calls-client',nl)
      .empty()
      .append "<div>Last #{limit} calls (local/client side):</div>"
    unless rows?
      $('.calls-client',nl).append '(none found)'
      return

    for row in rows
      do (row) ->
        $('.calls-client',nl).append local_call row
    return
  .catch (error) ->
    $('.calls-client',nl).empty().html "(no calls found for global number #{gnum}: #{error})"

window.last_calls = (nl,gnum,limit = 20) ->
  $('.calls',nl).spin()

  run_global nl, gnum, limit
  run_local nl, gnum, limit

  return

window.the_socket = socket = io()

log = -> console.log arguments...

zappa_prefix = '/zappa'
zappa_channel = '__local'

share = (channel_name,socket,next) ->
  zappa_prefix = zappa_prefix ? ""
  socket_id = socket.id
  if not socket_id?
    log "Missing socket_id"
    next? false
    return
  $.getJSON "#{zappa_prefix}/socket/#{channel_name}/#{socket_id}"
  .done ({key}) ->
    if key?
      log "Sending key #{key}"
      socket.emit '__zappa_key', {key}, next
    else
      log "Missing key: #{arguments}"
      next? false
  .fail ->
    next? false

socket.on 'connect', ->
  share zappa_channel, socket, (ok) ->
    log {ok}
    socket.emit 'join'

socket.on 'welcome', (data) ->
  log data

socket.on 'ready', ({roles}) ->
  log {roles}

socket.on 'joined', (room) ->
  log joined:room
