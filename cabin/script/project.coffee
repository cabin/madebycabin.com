# Project-page views
# ------------------

ANIMATION_END = 'animationend webkitAnimationEnd oAnimationEnd MSAnimationEnd'


#### ProjectPageView
# The container view for project pages. It handles events and shortcut keys for
# the currently-displayed project, as well as eager-loading the next and
# previous projects (our images are big; it's nice to get a head start!) and
# managing prettier transitions between projects.
class ProjectPageView extends HierView

  # Only called on "page" transition; i.e., the first time any project is
  # viewed. Subsequent project views happen in the context of this view.
  initialize: (options) ->
    @router = options.router
    @currentProject = @addChild new ProjectView
      el: @$('.project').first()
      container: @$el
    @currentProject.title = @$el.data('title')
    # Cache of preloaded projects.
    @projects = {}
    @projects[location.pathname] = @currentProject
    @preloadNeighbors(@currentProject)

  render: ->
    @currentProject.render()

  preloadNeighbors: (project) ->
    @preloadProject(project.previousURL())
    @preloadProject(project.nextURL())

  preloadProject: (url) ->
    return if url of @projects
    view = @addChild(new ProjectView(container: @$el))
    @projects[url] = view
    $.ajax
      method: 'GET'
      url: url
      data: _pjax: 1
      headers: {'X-PJAX': 'true'}
      dataType: 'html'
      success: (data) -> view.preload(data)

  events:
    'tapclick .prev-next .arrow-left': 'showPreviousProject'
    'tapclick .prev-next .arrow-right': 'showNextProject'
    'tapclick .bottom .arrow-left': 'showPreviousProject'
    'tapclick .bottom .arrow-right': 'showNextProject'
    'touchstart': 'touchstart'
    'touchmove': 'touchmove'
    'touchend': 'touchend'

  shortcuts:
    'up': 'showPreviousImageOrHideShortlist'
    'down': 'showNextImageOrShortlist'
    'k': 'showPreviousImageOrHideShortlist'
    'j': 'showNextImageOrShortlist'
    'left': 'showPreviousProject'
    'right': 'showNextProject'
    '⌥+e': 'adminProject'

  incrImageOrToggleShortlist: (event, opts) ->
    event.preventDefault()
    shortlistView = @currentProject.contentView.shortlistView
    if shortlistView.$el.is(':visible')
      shortlistView.toggleClosed(opts.close)
    else
      @incrImage(opts.incrBy)

  showPreviousImageOrHideShortlist: (event) ->
    @incrImageOrToggleShortlist(event, close: true, incrBy: -1)

  showNextImageOrShortlist: (event) ->
    @incrImageOrToggleShortlist(event, close: false)

  showPreviousProject: (event) ->
    @navigateProject(event, @currentProject.previousURL(), 'right')

  showNextProject: (event) ->
    @navigateProject(event, @currentProject.nextURL(), 'left')

  adminProject: ->
    @router.navigate('admin/' + Backbone.history.fragment, trigger: true)

  # Scroll to the top of the `n`th next image. Uses the jQuery 'fx' animation
  # queue to handle multiple rapid calls; each new position isn't calculated
  # until the previous animation is complete.
  incrImage: (n = 1) ->
    topPadding = @$el.offset().top + parseInt($('.main').css('padding-left'), 10)
    @currentProject.$el.queue (next) =>
      # Compile a list of ordered scroll targets for each image, then insert
      # the current scroll position into the list. Scroll to the current scroll
      # position's index + n; this handles cases for being between images
      # nicely. Ignore hidden images, which appear on slideshows.
      images = @currentProject.$('.images .placeholder:visible')
      imageTargets = _(images).map (el) -> $(el).offset().top - topPadding
      scrollY = $(window).scrollTop()
      pos = _(imageTargets).sortedIndex(scrollY)
      imageTargets.splice(pos, 0, null)
      index = pos + n
      index += n if scrollY is imageTargets[index]
      # If we're above the first image, scroll to the top of the page. If below
      # the last image, scroll to the bottom of the page.
      scrollTo = if index < 0
        0
      else if index >= imageTargets.length
        document.body.scrollHeight
      else
        imageTargets[index]
      # Since we scroll two elements, the callback would be called twice;
      # that'll bounce us through our animations too fast. We also defer to
      # ensure the animation is *really* finished; without it, the callback was
      # being called while the scrollTop was still 1px away from its target!
      callback = _.once(-> _.defer(next))
      $('html, body').animate({scrollTop: scrollTo}, 300, callback)

  # Record where the touch began, and reset the movement axis.
  touchstart: (event) ->
    @swipeAxis = null
    touches = event.originalEvent.touches
    @singletouch = touches.length is 1
    if @singletouch
      @touchstartX = touches[0].clientX
      @touchstartY = touches[0].clientY

  # If the touch is a single-finger drag horizontally, prevent scrolling and
  # instead slide in a new project.
  touchmove: (event) ->
    return unless @singletouch
    t = event.originalEvent.touches[0]
    [deltaX, deltaY] = [t.clientX - @touchstartX, t.clientY - @touchstartY]
    if not @swipeAxis
      @swipeAxis = @determineTouchmoveAxis(deltaX, deltaY)
    # We're handling horizontal swipes; prevent the default scroll.
    event.preventDefault() if @swipeAxis is 'x'
    # Save this for use on touchend.
    @touchDeltaX = deltaX

  determineTouchmoveAxis: (dx, dy) ->
    [absX, absY] = [Math.abs(dx), Math.abs(dy)]
    distance = Math.sqrt((dx * dx) + (dy * dy))
    difference = Math.abs(absX - absY)
    if distance > 6 and difference > 3
      return if absX > absY then 'x' else 'y'
    return null

  # If this was a horizontal swipe and it swept far enough, transition to the
  # appropriate project.
  touchend: (event) ->
    if @swipeAxis is 'x'
      threshold = 100
      if Math.abs(@touchDeltaX) >= threshold
        if @touchDeltaX < 0
          @showNextProject(event)
        else
          @showPreviousProject(event)

  navigateProject: (event, url, direction) ->
    # If the next page hasn't loaded yet, ignore the event.
    next = @projects[url]
    return unless next?.title?
    # Avoid the site-wide `internalLink` behavior.
    if event.type is 'tapclick'
      event.stopPropagation()
      event.preventDefault()
    @router.navigate(url)
    # Swap in the new project and load neighbors.
    previous = @currentProject
    @currentProject = next
    @preloadNeighbors(next)
    @_parent.setTitle(next.title)

    container = @$('.projects')
    transition = ->
      # Add the next project to the container (so it can be rendered in order
      # to compute its height). Transitioning elements are positioned
      # absolutely, but we need to smoothly transition footer and .bottom
      # between projects. Set container and project height to the largest of
      # the transitioning projects. Set `next` width so sizing works properly,
      # and `previous` width so nothing falls out of place when it loses its
      # static positioning.
      container.append(next.$el.addClass('transition'))
      previous.$el.width(previous.$el.width())
      next.$el.width(previous.$el.width())
      next.render()
      projectHeight = Math.max(previous.$el.height(), next.$el.height())
      contentHeight = Math.max(
        previous.contentView.$el.height(), next.contentView.$el.height())
      container.height(projectHeight)
      previous.contentView.$el.height(contentHeight)
      next.contentView.$el.height(contentHeight)
      # Now that heights are set, pull the previous element out of static
      # positioning.
      previous.$el.addClass('transition')

      # Begin transition animations.
      previous.$el.addClass("transition-out transition-out-#{direction}")
      next.$el.addClass("transition-in transition-in-#{direction}")

      # Once all animations are complete (next.infoView gets the longest one),
      # it's safe to remove the old view and clean up after ourselves.
      next.infoView.$el.one ANIMATION_END, =>
        previous.$el.detach()
        previous.cleanup()
        previous.$el.add(next.$el).removeClass [
          "transition"
          "transition-out transition-out-#{direction}"
          "transition-in transition-in-#{direction}"
        ].join(' ')
        container.height('auto')
        previous.contentView.$el.height('auto')
        next.contentView.$el.height('auto')
        previous.$el.width('auto')
        next.$el.width('auto')

    # Scroll to the top first if needed.
    if $(window).scrollTop() > 0
      $('html, body').animate(scrollTop: 0, 300, transition)
    else
      transition()


#### ProjectView
# Manage a single project, mostly by composing a handful of subviews.
class ProjectView extends HierView
  fullImageWidth: 1100

  initialize: (options) ->
    @container = options.container
    @infoView = @addChild(new ProjectInfoView)
    options = fullImageWidth: @fullImageWidth
    @shareView = @addChild(new ProjectShareView(options))
    @contentView = @addChild(new ProjectContentView(options))

  preload: (data) ->
    el = $(data)
    @title = el.data('title')
    @setElement(el.find('.project').first())
    @render(preload: true)
    this

  render: (options = {}) ->
    @$el.toggleClass('preload', !!options.preload)
    @infoView.setElement(@$('.info')).render()
    @shareView.setElement(@$('.bottom')).render()
    # ProjectContentView needs to know the width at which it will be displayed,
    # but sometimes we are rendering into a detached element. Pass the parent's
    # width instead, as it will always be visible.
    width = @container.width()
    @contentView.setElement(@$('.project-content')).render(width)
    this

  # ProjectViews are cached, but some components need to be reset when not in
  # view (window resize handlers, slideshows, etc.). `cleanup` walks the view
  # hierarchy calling `cleanup` on any view which has the method.
  cleanup: ->
    recurse = (view) ->
      view.cleanup?()
      _(view._children).each(recurse)
    _(@_children).each(recurse)

  # Snarf the neighboring project URLs from the arrow links.
  previousURL: -> @$('.prev-next a').first().attr('href')
  nextURL: -> @$('.prev-next a').last().attr('href')


#### ProjectInfoView
# Handles the tab-like interface at the top of each project (brief, services,
# cohorts) and swapping between them.
class ProjectInfoView extends HierView

  initialize: ->
    @linkhunterView = @addChild(new LinkhunterView)

  events:
    'tapclick .tab-chooser a': 'selectTab'

  render: ->
    lhEl = @$('.linkhunter')
    @linkhunterView.setElement(lhEl).render() if lhEl.length
    this

  cleanup: ->
    @selectTab(currentTarget: @$('.tab-chooser a')[0])

  selectTab: (event) ->
    # Unselect the previous item; hide its hr temporarily to avoid a shrinking
    # transition.
    oldSelected = @$('.tab-chooser .selected')
      .find('hr').hide().end()
      .removeClass('selected')
    _.defer -> oldSelected.find('hr').show()
    # Select the new item and the appropriate tab contents from its data.
    name = $(event.currentTarget).addClass('selected').data('for')
    @$('.tab-contents').children().removeClass('selected')
      .filter(".#{name}").addClass('selected')


#### ProjectShareView
# Handles the facebook/twitter/pinterest share buttons at the bottom of each
# project page. Pops up the appropriate share URL in a new window. For project
# pages with multiple images, the pinterest button allows choosing which image
# to share.
class ProjectShareView extends HierView
  popupSizes:
    facebook: [580, 325]
    twitter: [550, 420]
    pinterest: [732, 320]
    pinterestPicker: [732, 320]

  initialize: (options) ->
    @fullImageWidth = options.fullImageWidth

  events:
    'tapclick .social > a': 'share'
    'tapclick .pinterest-image-picker a': 'sharePinterest'

  # Assigning commonly-used subelements in `render` rather than in
  # `initialize`, because the same view will have `setElement` called a number
  # of times for transitioning between projects.
  render: ->
    @pinterestPicker = @$('.pinterest-image-picker')
    this

  # Since we don't want to load a thousand external scripts and be forced to
  # display standard share buttons, this method catches clicks on our share
  # icons and pops up a centered, appropriately-sized window.
  share: (event, network) ->
    event.originalEvent.preventDefault()
    target = $(event.currentTarget)
    url = target.attr('href')
    # Browser extensions might have added extra classes.
    network = target.attr('class').split(' ')[0] unless network
    # If Pinterest was clicked and there are images to choose from, pop up the
    # image chooser; otherwise, just share the thumbnail from the target url.
    if network is 'pinterest' and @pinterestPicker.length
      return @togglePinterestPicker(event)
    # If we just shared from the Pinterest chooser, close it.
    if network is 'pinterestPicker'
      @togglePinterestPicker(target: @$('.pinterest'))
    [width, height] = @popupSizes[network]
    left = (screen.availWidth or screen.width) / 2 - width / 2
    top = (screen.availHeight or screen.height) / 2 - height / 2
    features = "width=#{width},height=#{height},left=#{left},top=#{top}"
    window.open(url, '_blank', features)

  # Size the picker to fit all of its images, if possible; otherwise, size it
  # to exactly fit the most possible images (the rest will wrap to following
  # lines). Add a bottom-margin to each landscape-orientation image to ensure
  # we wrap to clean rows. Don't bother to account for resizing the picker on
  # window resizes; hardly worth the overhead. If the picker is already
  # visible, just hide it.
  togglePinterestPicker: (event) ->
    if @pinterestPicker.not(':visible')
      images = @pinterestPicker.find('a')
      hMax = images.outerWidth()
      hRatio = hMax / @fullImageWidth
      images.each ->
        a = $(this)
        marginBottom = Math.ceil(hMax - (hRatio * a.data('height')))
        a.css(marginBottom: marginBottom) if marginBottom > 0
      w = images.outerWidth(true)
      extraPadding = 40
      containerWidth = @pinterestPicker.parent().width()
      maxWidth = Math.min(w * images.length + extraPadding, containerWidth)
      width = Math.floor((maxWidth - extraPadding) / w) * w + extraPadding
      @pinterestPicker.width(width)
        .css(marginLeft: -(@pinterestPicker.outerWidth() / 2))
    @pinterestPicker.toggle()
    $(event.target).toggleClass('selected')

  sharePinterest: (event) ->
    @share(event, 'pinterestPicker')


#### ProjectContentView
# Handle off to the appropriate subview based on the type of content for the
# given project; currently just images or a development "shortlist".
class ProjectContentView extends HierView

  initialize: (options) ->
    @imagesView = @addChild(new ProjectImagesView(options))
    @shortlistView = @addChild(new ProjectShortlistView(options))

  render: (width) ->
    images = @$('.images')
    shortlist = @$('.dev-shortlist')
    @imagesView.setElement(images).render(width) if images.length
    @shortlistView.setElement(shortlist).render() if shortlist.length
    this


#### ProjectImagesView
class ProjectImagesView extends HierView

  initialize: (options) ->
    @fullImageWidth = options.fullImageWidth

  render: (width) ->
    @cleanup()  # from any previous renderings
    width or= @$el.width()
    @heightRatio = width / @fullImageWidth
    @images = @$('.placeholder')
    @loadImages()
    @setupSlideshow() if @$el.data('slideshow')
    this

  cleanup: ->
    clearTimeout(@slideshowTimeout) if @slideshowTimeout

  remove: ->
    @cleanup()
    super

  # Because our work images are *huge* and Mobile Safari shows an ugly black
  # background while loading them, we set up placeholders here and swap in the
  # real image only after it's been completely loaded. Placeholder height must
  # be computed since the visible width depends on the browser viewport, so we
  # apply height/width attributes which are removed after the image is loaded
  # (following a brief delay so that scroll position is consistent). The
  # placeholder image should have data-src and data-height attributes, and can
  # have a data-class attribute for a class that will be applied after load.
  loadImages: ->
    @images.not('.sized').each (i, element) =>
      placeholder = $(element)
      loadingView = @addChild(new LoadingView)
      placeholder.prepend(loadingView.render().el)
      img = placeholder.find('img')
      realSrc = img.data('src')
      fullHeight = img.data('height')
      img.attr('height', Math.floor(fullHeight * @heightRatio))
      placeholder.addClass('sized')
      imgLoader = new Image
      imgLoader.onload = ->
        img.attr
          src: realSrc
          class: img.data('class')
        _.delay((-> img.removeAttr('height')), 200)
        loadingView.remove()
      imgLoader.src = realSrc

  # Some projects should cycle through their images one at a time, rather than
  # displaying all images at once.
  setupSlideshow: ->
    @images.hide().first().show()
    interval = 4000
    index = 0
    # If the placeholder has a `.loading-dots` child, the image hasn't yet
    # loaded. Check in every once in a while, and don't progress the slideshow
    # until it's ready.
    cycle = =>
      next = @images.eq(index)
      if next.find('.loading-dots').length
        wait = 200
      else
        @images.hide()
        next.show()
        index = (index + 1) % @images.length
        wait = interval
      @slideshowTimeout = setTimeout(cycle, wait)
    cycle()


#### ProjectShortlistView
# Sizes, cycles, opens, and closes the development shortlist.
class ProjectShortlistView extends HierView

  render: ->
    return unless @$el.is(':visible')
    @cycleIndex = 0
    @closed = true

    if not @$el.hasClass('loaded')
      items = @$('li')
      @itemCount = items.length
      return unless @itemCount > 0

      # Find the biggest shortlist element by wrapping each one in a `span` (so
      # we can measure the text width, wrather than the container). Assumes
      # `nowrap` on the items.
      biggest = null
      maxWidth = 0
      items.wrapInner('<span/>')
      items.find('span').each ->
        span = $(this)
        w = span.width()
        if w > maxWidth
          maxWidth = w
          biggest = span
      @biggest = biggest
      @visibleWindow = @$('.dev-shortlist-window')

      # Each item's opacity differs from the last by a set amount, variable
      # based on the number of items. The first item will be set to `opacity`,
      # and the last item will be set to `minOpacity`.
      opacity = 1
      minOpacity = 0.2
      delta = (opacity - minOpacity) / (@itemCount - 1)
      items.each ->
        $(this).css('opacity', opacity.toFixed(2))
        opacity -= delta

      # CSS hides the content until we've added our styles here.
      _.defer => @$el.addClass('loaded')

    # Set up styles for and begin the cycle.
    $(window).on('resize', @resize)
    @reposition()
    @toggleClosed(@closed)
    this

  cleanup: ->
    clearInterval(@cycleInterval) if @cycleInterval?
    @cycleInterval = null
    @$el.removeClass('loaded')
    $(window).off('resize', @resize)

  remove: ->
    @cleanup()
    super()

  events:
    'tapclick .dev-shortlist-toggle': 'toggleClosed'

  toggleClosed: (value) ->
    @closed = @$el.toggleClass('closed', value).hasClass('closed')
    @resize()
    if @closed
      if not @cycleInterval
        @cycleInterval = setInterval(@cycle, 2000)
    else
      clearInterval(@cycleInterval) if @cycleInterval?
      @cycleInterval = null
      @visibleWindow.css(height: @itemHeight * @itemCount)
    @reposition()

  # Adjust font size `1px` at a time, first increasing the size to ensure
  # it's too wide, then decreasing the size until it just fits.
  resize: =>
    targetWidth = @$el.width()
    fontSize = parseInt(@biggest.css('font-size'), 10)
    list = @$('ul')
    while @biggest.width() < targetWidth
      list.css(fontSize: fontSize += 1)
    while @biggest.width() > targetWidth
      list.css(fontSize: fontSize -= 1)
    @itemHeight = fontSize * 2
    windowHeight = if @closed then @itemHeight else @itemHeight * @itemCount
    @visibleWindow.css(height: windowHeight)
    @reposition()

  cycle: =>
    @cycleIndex += 1
    if @cycleIndex >= @itemCount
      @cycleIndex = 0
    @reposition()

  reposition: ->
    top = if @closed then (@cycleIndex * @itemHeight * -1) else 0
    @$('ul').css(top: top)


#### LinkhunterView
# Allows for inline installation of the extension for Chrome-using visitors.
# NOTE: Naughtily adds an element to the document head; this is semi-cleaned up
# in `remove`, but not reliably (it is not careful about only creating one).
class LinkhunterView extends HierView
  extensionID: 'ndjggnnohdkheiijjhbklkanjcpibbng'
  logoURL: 'browser-action.png'

  events:
    'click .lh-install': 'install'

  # There's no great way to check whether a Chrome extension is installed; apps
  # get a chrome.app.isInstalled, but it doesn't work for extensions. Instead,
  # we attempt to load a linkhunter resource into a hidden img and report
  # success or failure.
  render: ->
    return this unless window.chrome?.webstore?
    img = new Image
    img.onload = @renderInstalled
    img.onerror = @renderNotInstalled
    img.src = "chrome-extension://#{@extensionID}/#{@logoURL}"
    this

  cleanup: ->
    @headLink?.remove()

  remove: ->
    @cleanup()
    super()

  renderInstalled: =>
    @$el.html('<p class="lh-installed">Installed / ready to hunt</p>')

  # https://developers.google.com/chrome/web-store/docs/inline_installation
  renderNotInstalled: =>
    if not @headLink? or not @headLink.length
      @headLink = $('<link rel="chrome-webstore-item">').attr(
        'href', "https://chrome.google.com/webstore/detail/#{@extensionID}")
      $('head').append(@headLink)
    @$el.html('<button class="lh-install button-hl">Add to Chrome</button>')

  install: (event) ->
    chrome.webstore.install(undefined, @renderInstalled)
