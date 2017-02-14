# FIXME rewrite into riot.js and provide proper tz handling!
timezone = 'Europe/Paris'

time_of = (uepoch) ->
  moment(uepoch.replace(/(...)$/,'.$1'),'x').tz(timezone).format()

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
  failure = v.sip_invite_failure_status? or v.sip_invite_failure_phrase?
  g3 = $ """
  <div class="call #{v.ccnq_direction} #{if failure then 'failure' else ''}">
    <a href="/_utils/document.html?cdrs/#{doc._id}">
    #{time_of v.start_uepoch}
    </a>
    (#{v.ccnq_direction}, #{v.ccnq_profile})
    #{v.ccnq_from_e164} → #{v.ccnq_to_e164}
    (<span class="billable">billable: #{v.billsec}s</span>,
     <span class="duration">total: #{v.duration}s</span>,
     #{v.hangup_cause})
  </div>
  """
  g3.data 'doc', doc
  g3

local_call = (row) ->
  doc = row.doc
  # FIXME: Add link to generate a trace based on to/from
  v = doc.variables
  failure = v.sip_invite_failure_status? or v.sip_invite_failure_phrase?
  mos = parseInt v.rtp_audio_in_mos
  failure = true if not isNaN(mos) and mos < 4.00
  g3 = $ """
  <div class="call #{v.ccnq_direction} #{if failure then 'failure' else ''}">
    <a href="/_utils/document.html?cdrs-client/#{doc._id}">
    #{time_of v.start_uepoch}
    </a>
    (#{v.ccnq_direction})
    <b>#{v.ccnq_from_e164}</b> → <b>#{v.ccnq_to_e164}</b>
    <span class="failure">#{v.sip_invite_failure_status ? ''} #{v.sip_invite_failure_phrase ? ''}</span>
    (<span class="billable">billable: #{v.billsec}s</span>,
     <span class="progress">progress: #{v.progresssec}s</span>,
     <span class="answer">answer: #{v.answersec}s</span>,
     <span class="total">total: #{v.duration}s</span>)
     <span class="cause">#{v.hangup_cause}</span>
     <span class="originate_disposition">#{v.originate_disposition}</span>
     <span class="endpoint_disposition">#{v.endpoint_disposition}</span>
     <span class="hangup_disposition">#{v.sip_hangup_disposition}</span>
     <span class="hangup_phrase">#{v.sip_hangup_phrase ? ''}</span>
    <div class="call-quality">
    <span class="in_mos">Quality:
      #{v.rtp_audio_in_mos}</span>
      (in:
      <span class="in_bytes">#{v.rtp_audio_in_media_bytes} bytes</span>
      <span class="in_packets">#{v.rtp_audio_in_media_packet_count} pkts</span>
      <span class="in_flaws">#{v.rtp_audio_in_flaw_total} flaws</span>
      <span class="in_skip">#{v.rtp_audio_in_skip_packet_count} skip</span>
      <span class="in_dtmf">#{v.rtp_audio_in_dtmf_packet_count} dtmf</span>
      <span class="in_cng">#{v.rtp_audio_in_cng_packet_count} cng</span>
    , jitter:
      <span class="in_jitter">#{v.rtp_audio_in_jitter_packet_count} pkts</span>
      <span class="in_jitter_min">#{v.rtp_audio_in_jitter_min_variance} min</span>
      <span class="in_jitter_max">#{v.rtp_audio_in_jitter_max_variance} max</span>
      <span class="in_jitter_loss">#{v.rtp_audio_in_jitter_loss_rate} loss</span>
      <span class="in_jitter_burst">#{v.rtp_audio_in_jitter_burst_rate} burst</span>
    , out:
      <span class="out_bytes">#{v.rtp_audio_out_media_bytes} bytes</span>
      <span class="out_packets">#{v.rtp_audio_out_media_packet_count} pkts</span>
      <span class="out_skip">#{v.rtp_audio_out_skip_packet_count} skip</span>
      <span class="out_dtmf">#{v.rtp_audio_out_dtmf_packet_count} dtmf</span>
      <span class="out_cng">#{v.rtp_audio_out_cng_packet_count} cng</span>
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

window.last_calls = (nl,gnum,limit = 40) ->
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
