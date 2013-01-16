# https://developers.google.com/mobile/articles/fast_buttons
(($) ->
  EVENT_NAME = 'tapclick'

  # Save a reference ot the `touchstart` coordinate and start listening to
  # `touchmove` and `touchend` events.
  onTouchStart = (event) ->
    $(this).on('touchend', onClick).on('touchmove', onTouchMove)
    touch = event.originalEvent.touches[0]
    @startX = touch.clientX
    @startY = touch.clientY

  # When a `touchmove` event is invoked, check if the user has dragged past the
  # threshold of 10px.
  onTouchMove = (event) ->
    touch = event.originalEvent.touches[0]
    movedX = Math.abs(touch.clientX - @startX)
    movedY = Math.abs(touch.clientY - @startY)
    reset(this) if movedX > 10 or movedY > 10

  # Invoke the actual click handler and prevent ghost clicks if this was a
  # `touchend` event on an element with a handler for the special event. The
  # latter check is necessary to handle event delegation; we don't want to
  # absorb clicks on children of the delegated context element that aren't
  # receiving the special event.
  # `jQuery.event.dispatch` will set `event.currentTarget` to each handled
  # element, so to detect whether any handler was called, set it to `null`
  # before dispatching.
  onClick = (event) ->
    reset(this)
    wasTouch = event.type is 'touchend'
    event.type = EVENT_NAME
    event.currentTarget = null
    jQuery.event.dispatch.apply(this, arguments)
    if wasTouch and event.currentTarget
      event.stopPropagation()  # XXX
      clickbuster.preventGhostClick(@startX, @startY)

  reset = (el) ->
    $(el).off('touchend touchmove')

  clickbuster =
    coordinates: []

    # Call `preventGhostClick` to bust all click events that happen within 25px
    # of the provided (x, y) coordinates in the next 2.5s.
    preventGhostClick: (x, y) ->
      clickbuster.coordinates.push([x, y])
      setTimeout(clickbuster.pop, 2500)

    pop: ->
      clickbuster.coordinates.shift()

    # If we catch a click event inside the given radius and time threshold then
    # we call `stopPropagation` and `preventDefault`, which will stop links
    # from being activated.
    onClick: (event) ->
      for [x, y] in clickbuster.coordinates
        movedX = Math.abs(event.clientX - x)
        movedY = Math.abs(event.clientY - y)
        if movedX < 25 and movedY < 25
          event.stopPropagation()
          event.preventDefault()

  # Ignore old browsers, since clickbusting is only necessary for touch events
  # and we need `useCapture`.
  if document.addEventListener
    document.addEventListener('click', clickbuster.onClick, true)

  jQuery.event.special[EVENT_NAME] =
    setup: ->
      $(this).on('touchstart', onTouchStart).on('click', onClick)
)(jQuery)
