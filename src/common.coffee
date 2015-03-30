window.last_calls = (nl,gnum,limit = 20) ->
  $('.calls',nl).spin()
  $.ajax
    type: 'GET'
    url: "/cdrs/_design/addon/_view/cdr_by_number"
    dataType: 'json'
    data:
      endkey: JSON.stringify [gnum]
      startkey: JSON.stringify [gnum,'z']
      limit: limit
      include_docs: true
      descending: true
      stale: 'update_after'
    error: ->
      $('.calls',nl).empty().html "(no calls found for global number #{gnum})"
    success: (data) ->
      $('.calls',nl).empty()
      $('.calls',nl).append "<div>Last #{limit} calls:</div>"
      unless data?.rows?
        $('.calls',nl).append '(none found)'
        return

      for row in data.rows
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
  return
