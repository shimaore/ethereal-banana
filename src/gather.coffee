qs =
  escape: encodeURIComponent

socket = io()

$ ->
  log = -> console.log arguments...

  $('#entry').append '''
    <div id="tool-retrieve">
      Retrieve
      <label>Number:
        <input type="tel" name="number" id="number" size="16" />
      </label>
      <label>Endpoint:
        <input type="text" name="endpoint" id="endpoint" disabled />
      </label>
    </div>
  '''

  t = null
  $('body').on 'keyup', '#number', ->
    # Throttle
    if t? then clearTimeout t
    t = setTimeout run, 750

  run = ->

    t = null

    $('#results').spin()
    limit = $('#limit').val() or 3

    # Value will be the national part of the number
    value = $('#number').val().replace /[^\d]+/g, ''
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
            <div class="gnum"></div>
            <div class="lnum">
              Transfers:
              <ul>
                <li>all calls: <tt>#{doc.cfa ? ''}</tt></li>
                <li>on busy: <tt>#{doc.cdb ? ''}</tt></li>
                <li>no response: <tt>#{doc.cfda ? ''}</tt></li>
                <li>not registered: <tt>#{doc.cfnr ? ''}</tt></li>
              </ul>
            </div>
            <div class="endpoint"></div>
            <div class="locations"></div>
            <div class="calls"></div>
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
            return unless reg.username is username
            html = """
            <div class="location">
              Endpoint registration:
              <ul>
              <li>Endpoint: <tt>#{reg.username}@#{reg.domain}</tt></li>
              <li>Contact: <tt>#{reg.contact}</tt></li>
              <li>Valid for: <tt>#{reg.expires}</tt></li>
              <li>Received from: <tt>#{reg.received}</tt></li>
              <li>Call-ID: <tt>#{reg.callid}</tt></li>
              <li>User-Agent: <tt>#{reg.user_agent}</tt></li>
              </ul>
            </div>
            """
            g4 = $ html
            g4.data 'doc', reg
            $('.locations',nl).append g4
          socket.on 'location:response', display
          socket.on 'location', display
          for domain in registration_domains
            do (domain) ->
              socket.emit 'location', "#{username}@#{domain}"

        null
    .catch (error) ->
      log "Failed to get numbers starting with #{value}: #{error}"

return
