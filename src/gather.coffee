qs =
  escape: encodeURIComponent

socket = window.the_socket

$ ->
  log = -> console.log arguments...

  t = null
  $('body').on 'keyup', '#user', ->
    # Throttle
    if t? then clearTimeout t
    t = setTimeout run, 750

  run = ->

    t = null

    $('#results').spin()
    limit = $('#limit').val() or 3

    # Value will be the national part of the number
    value = $('#user').val().replace /[^\d]+/g, ''
    value = entry_to_local value
    return unless value?

    # Build the list of numbers that match
    db = new PouchDB "#{window.location.protocol}//#{window.location.host}/provisioning"

    # Local numbers
    db.allDocs
      startkey: "number:#{value}"
      endkey: "number:#{value}_"
      limit:limit
      include_docs: true
    .then ({rows}) ->
      log rows
      return unless rows?
      $('#results').empty()
      for row in rows
        do (row) ->
          doc = row.doc
          [number,domain] = doc.number.split /@/
          # Format
          gnum = local_to_global domain, number
          el = $ """
          <div class="number">
            <ul>
              <li>Number: <tt>#{number}</tt></li>
              <li>Domain: <tt>#{domain ? '(global number)'}</tt></li>
            </ul>
            <div class="endpoint"></div>
            <div class="calls-client"></div>
            <div class="calls"></div>
            <div class="locations"></div>
          </div>
          """
          doc.gnum = gnum
          el.data 'doc', doc
          $('#results').append el

      $('div.number'). each ->
        nl = $(@)
        el_doc = nl.data 'doc'
        gnum = el_doc.gnum

        # Global Number
        if gnum?
          $('.gnum',nl).spin()
          db.get 'number:'+gnum
          .then (doc) ->
            $('.gnum',nl).empty()
            if registrant_host?
              registrant = if typeof registrant_host is 'string' then registrant_host else registrant_host[0]
            g1 = $ """
            <div class="gnum">
              <ul>
              <li>Incoming route: <tt>#{doc.inbound_uri}</tt></li>
              </ul>
            </div>
            """
            doc.registrant = registrant
            g1.data 'doc', doc
            $('.gnum',nl).append g1

            # FIXME Get registrant status
          .catch (error) ->
            $('.gnum',nl).empty().html "(global number #{gnum} not found)"
            log "Failed to get number gnum=#{gnum} #{error}"

        # Endpoint
        if el_doc.endpoint?
          $('.endpoint',nl).spin()
          db.get 'endpoint:'+el_doc.endpoint
          .then (doc) ->
            $('.endpoint',nl).empty()
            g2 = $ """
            <div class="endpoint">
              Endpoint:
              <ul>
              <li>Name: <tt>#{doc.endpoint}</tt></li>
              <li>Password: <tt>#{doc.password}</tt></li>
              </ul>
            </div>
            """
            g2.data 'doc', doc
            $('.endpoint',nl).append g2
          .catch (error) ->
            $('.endpoint',nl).empty().html "(endpoint #{el_doc.endpoint} not found)"
            log "Failed to get endpoint = #{el_doc.endpoint}"

        # Get last few calls to/from
        if gnum?
          last_calls nl, gnum

        if el_doc.endpoint?
          [username,domain] = el_doc.endpoint.split '@'
          $('.locations',nl).empty()
          $('.locations',nl).spin()
          display = (reg) ->
            console.log reg
            [reg_username,reg_domain] = reg._id.split '@'
            return unless reg_username is username
            registered = reg.username?

            now = new Date()
            still = ''
            if reg.expires?
              still = new Date(reg.expires.replace ' ', 'T') - now
              still /= 1000
              still = " (#{still}s)"

            html = """
            <div class="location #{if registered then 'registered' else 'not-registered'}">
              Endpoint registration on #{reg.hostname ? reg.query_data?.hostname}
              <ul>
              <li>Endpoint: <tt>#{reg_username}@#{reg_domain}</tt></li>
              <li>Contact: <tt>#{reg.contact ? '(not registered)'}</tt></li>
              <li>Valid for: <tt>#{reg.expires ? '(none)'}</tt>#{still}</li>
              <li>Received from: <tt>#{reg.received ? '(none)'}</tt></li>
              <li>Call-ID: <tt>#{reg.callid ? '(none)'}</tt></li>
              <li>User-Agent: <tt>#{reg.user_agent ? '(none)'}</tt></li>
              </ul>
            </div>
            """
            g4 = $ html
            g4.data 'doc', reg
            if registered
              $('.locations',nl).prepend g4
            else
              $('.locations',nl).append g4
          socket.on 'location:response', display
          socket.on 'location:update', display
          for domain in registration_domains
            do (domain) ->
              socket.emit 'location', "#{username}@#{domain}"

        null
    .catch (error) ->
      log "Failed to get numbers starting with #{value}: #{error}"

return
