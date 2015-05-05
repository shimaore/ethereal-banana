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
