# Persistent views
# ----------------

#### SplashView
# Responsible for transitioning the splash header into/out of view. External
# API is just the `show` and `hide` methods, which will return false if they
# are called unnecessarily.
class SplashView extends HierView
  visibleClass: 'splash'
  transitionClass: 'splash-transition'
  el: document.body

  initialize: ->
    @hideMobileAddressBar()
    @main = @$el.find('.main').first()
    @nav = @main.children('.nav-container').first()
    @visible = @$el.hasClass(@visibleClass)

  hideMobileAddressBar: ->
    ua = navigator.userAgent
    iphone = ~ua.indexOf('iPhone') or ~ua.indexOf('iPod')
    chrome = ~ua.indexOf('CriOS')
    fullscreen = navigator.standalone
    if iphone and not fullscreen and not chrome
      de = document.documentElement
      htmlWrapper = $('html')
      fullHeightElements = $('body, body > header')
      f = ->
        portrait = window.orientation is 0
        htmlWrapper.toggleClass('iphone', portrait)
        if portrait
          fullHeightElements.css('height', de.clientHeight + 60)
          _.defer -> window.scrollTo(0, 0) unless pageYOffset
        else
          fullHeightElements.removeAttr('style')
      window.onorientationchange = f; f()

  # Compute an appropriate value for the `.main` element's `top` which will
  # show only the site navigation bar and the splash page.
  topOffset: ->
    ($(window).height() - @nav.outerHeight()) + 'px'

  show: ->
    return false if @visible
    @visible = true
    _.defer -> window.scrollTo(0, 0)
    @$el.addClass(@transitionClass)
    @main.animate(top: @topOffset(), @endTransition)

  hide: ->
    return false unless @visible
    @visible = false
    @$el.addClass(@transitionClass)
    @main.css(top: @topOffset()).animate(top: 0, @endTransition)

  # `show` and `hide` animate `.main` using its `style` attribute, leaving the
  # `visibleClass` setting alone. Once the transition is complete, we can rely
  # on CSS to keep things in the same position.
  endTransition: =>
    @$el.toggleClass(@visibleClass, @visible).removeClass(@transitionClass)
    @main.removeAttr('style')


#### MainView
# This long-lived view is responsible for transitioning the main contents of
# the page via PJAX. This includes setting the document title, managing a
# `page-*` class on its element, and performing the PJAX `.content`-element
# replacement. It also manages a per-page view, when necessary.
class MainView extends HierView
  el: $('.main')

  initialize: (options) ->
    @router = options.router
    @title = $('head > title')
    @nav = @$('nav').first()
    @content = @$('.content')
    @views =
      'work': WorkView
      'project': ProjectPageView
      'about': AboutView
      'blog': BlogView
      'admin-project': EditProjectView
      'admin-work': ManageWorkView
      'labs-yoga': YogaView
    @_updatePageView(@content.data('page'))
    # iPhone only fires a scroll event on *completing* the scroll, so we also
    # watch for touchmoves.
    @window = $(window)
    @checkScrollPosition()
    @window.on('scroll touchmove', _.throttle(@checkScrollPosition, 50))

  events:
    'tapclick a[href^="/"]': 'internalLink'
    'tapclick nav .toggle': 'toggleSocial'
    'tapclick nav': 'closeSplash'

  shortcuts:
    '⌥+l': -> navigator.id.request(siteName: 'Cabin')

  render: ->
    @setTitle(@content.data('title'))
    @pageView?.render?()
    this

  # Pass clicks on internal links through navigate, saving a page load.
  internalLink: (event) ->
    # Only act on left clicks with no modifiers.
    return if event.originalEvent.type is 'click' and (event.which isnt 1 or
      event.metaKey or event.ctrlKey or event.shiftKey or event.altKey)
    event.preventDefault()
    event.stopPropagation()
    @router.navigate($(event.currentTarget).attr('href'), trigger: true)
    $(event.target).blur()  # kill focus outline

  checkScrollPosition: (event) =>
    @$el.toggleClass('scrolled', @window.scrollTop() > 5)

  toggleSocial: (event) ->
    event.stopPropagation()
    plus = $(event.currentTarget).addClass('transitioning')
    @nav.toggleClass('show-social')
    _.delay((-> plus.removeClass('transitioning')), 400)

  closeSplash: -> @router.closeSplash()

  # Set the page's title to its arguments joined by a delimiter, always
  # prepending "Cabin".
  setTitle: ->
    titleChunks = Array.prototype.slice.call(arguments)
    titleChunks.unshift('Cabin')
    @title.text(titleChunks.join(' · '))

  pjax: (route) ->
    # Remove the old content immediately, which indicates that something is
    # happening, and scroll back to the top of the page.
    @content.empty()
    window.scroll(0, 0)
    $.ajax
      url: "/#{route}?_pjax=1"
      headers: {'X-PJAX': 'true'}
      error: (xhr) => @_pjaxHandler(xhr.responseText)
      success: (data) => @_pjaxHandler(data)

  _pjaxHandler: (data) ->
    @content.replaceWith(data)
    @content = $(@content.selector)  # DOM changed; need a re-query
    @setTitle(@content.data('title'))
    page = @content.data('page')
    @_updatePageClass(page)
    @_updatePageView(page)
    @pageView.render()

  # Sets a `page-<name>` class, useful for per-page CSS.
  _updatePageClass: (name) ->
    @$el.removeClass (i, classes) ->
      _(classes.split(' '))
        .filter((cls) -> cls.match(/^page-/))
        .join(' ')
    @$el.addClass("page-#{name}")

  # Maintains a per-page view on `.content`, if any, with shortcut keys.
  _updatePageView: (name) ->
    @pageView?.remove()
    key.deleteScope('all')
    @_assignShortcuts(this)
    viewClass = @views[name]
    if viewClass
      @pageView = @addChild(new viewClass(el: @content, router: @router))
      @_assignShortcuts(@pageView)

  _assignShortcuts: (obj) ->
    for shortcut, method of obj.shortcuts
      callback = if _.isFunction(method) then method else obj[method]
      throw new Error("Method \"#{method}\" does not exist") unless callback
      key(shortcut, _.bind(callback, obj))


# Per-page views
# --------------

#### WorkView
# Applies jQuery Masonry on the collection of work.
class WorkView extends HierView
  containerSelector: '.bricks'
  itemSelector: '.work-thumb'
  itemWidth: 260
  gutterWidth: 20

  initialize: (options) ->
    @router = options.router
    @masonryContainer = $(@containerSelector)
    @items = @masonryContainer.find(@itemSelector)
    @featuredItems = @items.filter('.feature')
    @options =
      itemSelector: @itemSelector
      columnWidth: @computeColumnWidth
      gutterWidth: @gutterWidth
      isFitWidth: true

  shortcuts:
    '⌥+e': 'adminWork'

  adminWork: ->
    @router.navigate('admin/work', trigger: true)

  # Compute the page width required to display the given number of columns and
  # their gutters at full scale.
  maxWidthAt: (cols) ->
    @itemWidth * cols + @gutterWidth * (cols - 1)

  # Compute the best width for a column by filling the available container.
  # `itemWidth` is the effective maximum width for each column. Rather than
  # leaving additional horizontal whitespace, add one more column than will
  # fit and downscale all columns.
  # For very narrow viewports (e.g., iPhone portrait), convert to a single
  # column at full width.
  # Featured items display at double width, unless the viewport isn't tall
  # enough to view them appropriately (e.g., iPhone landscape) or we're using
  # a single column.
  computeColumnWidth: =>
    return @itemWidth unless @items.length
    singleColumn = window.innerWidth <= 320
    # iPhone 5 landscape will report its height at 321 temporarily when
    # scrolling through the address bar, despite never actually having that
    # much real estate. Workaround: cutoff at 321 instead of 320.
    doubleFeatured = not singleColumn and window.innerHeight > 321
    # Compute `columnWidth` and `maxWidth`.
    if singleColumn
      maxWidth = columnWidth = @$el.width()
    else
      maxColumns = @items.length
      maxColumns += @featuredItems.length if doubleFeatured
      maxWidth = Math.min(@$el.width(), @maxWidthAt(maxColumns))
      for n in [1..maxColumns]
        break if @maxWidthAt(n) >= maxWidth
      columnSpace = maxWidth - @gutterWidth * (n - 1)
      columnWidth = Math.floor(columnSpace / n)
    @masonryContainer.css('width', maxWidth)
      .toggleClass('single-column', singleColumn)
    @items.css('width', columnWidth)
    if doubleFeatured
      @featuredItems.css('width', columnWidth * 2 + @gutterWidth)
    columnWidth

  render: ->
    @masonryContainer.imagesLoaded => @masonryContainer.masonry(@options)
    this


#### AboutView
class AboutView extends HierView

  initialize: (options) ->
    @router = options.router
    @sections = @$('section')
    @menu = @$('.menu')
    @menuArrow = @menu.find('.arrow')
    @adjustMenuArrow(@menu.find('a').first())
    @setupChart()

  render: ->
    @loadPhotos()

  events:
    'tapclick .menu a': 'selectSection'
    'tapclick .bio hgroup': 'toggleBio'

  loadPhotos: ->
    urlMatch = /^url\(['"]?(.+)['"]?\)$/
    photos = @$('.photo')
    photos.each ->
      el = $(this)
      src = el.css('background-image').replace(urlMatch, '$1')
      if src and src isnt 'none'
        photos.add($('<img>').attr('src', src))
    @listenTo(@router, 'showSplash', -> photos.removeClass('loaded'))
    photos.imagesLoaded ->
      body = $('body')
      # Don't start animating the photos in until the splash transition is
      # complete.
      f = ->
        if body.hasClass('splash-transition')
          _.delay(f, 30)
        else
          photos.filter('.bek').addClass('loaded')
          _.delay((-> photos.filter('.zak').addClass('loaded')), 250)
      f()

  setupChart: ->
    @window = $(window)
    @chart = @$('.svg')
    @chartInterval = setInterval(@renderChartWhenVisible, 200)
    @renderChartWhenVisible()

  renderChartWhenVisible: =>
    if @isChartVisible()
      @chartView = @addChild(new ChartView(el: @sections.filter('.graph')))
      @chartView.render()
      clearInterval(@chartInterval)

  isChartVisible: ->
    @window.scrollTop() + @window.height() - @chart.offset().top > 100

  adjustMenuArrow: (relativeTo) ->
    elementCenter = (el) ->
      left = el.position().left + parseInt(el.css('margin-left'), 10)
      left + el.width() / 2
    @menuArrow.css(left: elementCenter(relativeTo))
    _.defer => @menuArrow.show()

  selectSection: (event) ->
    classMap =
      partners: '.partners, .graph'
      clients: '.clients, .services'
      connect: '.connect'
    window.scrollTo(0, 0)
    selected = $(event.currentTarget)
    selectedName = selected.data('name')
    @adjustMenuArrow(selected)
    @sections.removeClass('selected')
      .filter(classMap[selectedName]).addClass('selected')
    if selectedName is 'partners'
      @chartView.reanimate()

  toggleBio: (event) ->
    $(event.currentTarget).parent('.bio').toggleClass('open')


#### ChartView
# Data are arrays of three-tuples: [float year, short city name, note].
class @ChartView extends HierView
  bekData: [
    [1978.5, 'Santa Barbara', "A preacher's daughter, Bek's future as a black sheep was predestined by the gods."]
    [1996.66, 'New York City', "Vassar College—a detour, not a destination."]
    [1997.66, 'Santa Barbara', "Science is swapped for songwriting and an initial foray into design."]
    [2002.66, 'Los Angeles', "Years of exploration and refinement at Art Center College of Design."]
    [2006.5, 'San Francisco', "Bek joins Blurb and moves to Zak's neighborhood, unbeknownst to them both."]
    [2008.66, 'New York City', "Bek returns to New York, this time to lead design at Etsy. Zak and Bek meet."]
    [2010, 'Los Angeles', "Back to the best coast to lead design at GOOD."]
    [2011.33, 'Idyllwild', "An excursion to the woods to build Cabin."]
    [2011.83, 'Portland', "Silicon Forest—home to our favorite espresso, exquisite cuisine, and us."]
  ]
  zakData: [
    [1980.33, 'Brisbane, AU', "Zak springs forth, product of the unholy union between an Aussie and an American."]
    [1984.5, 'San Diego', "Australia cannot contain Zak and his family for long… though he still misses proper fish & chips."]
    [1989.92, 'Portland', "Clean air and green trees summon him northwards. A blur of school."]
    [2000, 'Washington, DC', "Zak kicks off an information security startup and loses faith in anyone’s ability to keep secrets."]
    [2004.33, 'San Francisco', "Venturing at last into full-time web development, Zak takes a job at Etsy, and later begins consulting."]
    [2010.75, 'Los Angeles', "Zak joins Bek at GOOD, having been lured back to southern California."]
    [2011.33, 'Idyllwild', "An excursion to the woods to build Cabin."]
    [2011.83, 'Portland', "Silicon Forest—home to our favorite espresso, exquisite cuisine, and us."]
  ]
  abbrCities:
    'Brisbane, AU': 'BNE'
    'Idyllwild': '6k′'
    'Los Angeles': 'LAX'
    'New York City': 'NYC'
    'Portland': 'PDX'
    'San Diego': 'SAN'
    'San Francisco': 'SFO'
    'Santa Barbara': 'SBA'
    'Washington, DC': 'DC'

  initialize: ->
    $(window).on('resize.pageview', _.debounce(@render, 100))
    @container = @$('.svg')
    @notes = @$('.notes')
    @chart = Charts.aboutInfographic()
        .selectedFill(['#ab7050', '#8a5a3a'])
    @svg = d3.select(@container.get(0)).append('svg')
        .datum([@decorateData(@bekData), @decorateData(@zakData)])

  decorateData: (data) ->
    _(data).map (item) =>
      year: item[0]
      city: item[1].toUpperCase()
      abbrCity: @abbrCities[item[1]]
      note: item[2]

  events:
    'mouseover g[class~=item]': 'showDetails'

  setupCycle: ->
    return if @cycleItems?
    f = =>
      @cycleIndex = 0
      @cycleItems = _(@$('g.item')).sortBy (item) ->
        parseFloat($(item).attr('start'))
      @cycle()
      @cycleInterval = setInterval(@cycle, 5000) unless @cycleInterval
    setTimeout(f, 2000)

  remove: ->
    clearInterval(@cycleInterval) if @cycleInterval
    $(window).off('.pageview')
    super()

  cycle: =>
    @select(@cycleItems[@cycleIndex])
    @cycleIndex = (@cycleIndex + 1) % @cycleItems.length

  showDetails: (event) ->
    if @cycleInterval
      clearInterval(@cycleInterval)
      delete @cycleInterval
    @select(event.currentTarget)

  select: (element) ->
    # Using d3 instead of jQuery objects, since jQuery doesn't have any decent
    # support for SVG.
    target = d3.select(element)
    @svg.selectAll('.item, .icon').classed('selected', false)
    target.classed('selected', true).each (d) =>
      @svg.select("##{d.side}-icon").classed('selected', true)
      from = Math.floor(d.year)
      to = Math.floor(d.yearEnd)
      range = if from is to then from else "#{from}&ndash;#{to}"
      @notes.find('.year').html(range)
      @notes.find('.note').text(d.note)
    @notes.show()

  reanimate: ->
    @svg.selectAll('.item, .icon').remove()
    @render()
    delete @cycleItems
    @setupCycle()

  render: =>
    return unless @container.is(':visible')
    width = @container.width()
    if width > 528  # iPhone 5 landscape - padding
      # Match the width of my half of the chart to my bio's current width.
      @chart
        .rightColumn(-> width - $('.bio.zak').width())
        .label(size: 10, padding: 6, adjust: '-.5em', attr: 'city')
        .textWidth(100)
        .height(350)
        .padding(5)
    else
      @chart
        .rightColumn(-> Math.floor(width / 2))
        .label(size: 10, padding: 2, adjust: '-.28em', attr: 'abbrCity')
        .textWidth(25)
        .height(250)
        .padding(1)
    @chart.width(width)(@svg)
    @setupCycle()


#### BlogView
# The blog is made up of three visible columns, one each for Tumblr, Instagram,
# and Flickr. The Instagram and Flickr columns contain elements of width `n`;
# Tumblr is (2n + margin). When there is enough room for the Instagram/Flickr
# columns to expand to (2n + margin) -- or (3n + 2margin), etc. -- they do so.
# When there is less room than (2n + margin), Instagram and Flickr tuck
# underneath.
class BlogView extends HierView
  columnWidth: 260
  gutterWidth: 20

  initialize: ->
    @tumblr = @$('section.tumblr')
    @instagram = @$('section.instagram')
    @flickr = @$('section.flickr')
    @masonryContainers = @$('section > .bricks')
    @masonryContainers.imagesLoaded =>
      @masonryContainers.masonry(gutterWidth: @gutterWidth, isResizable: false)
    @resize()
    $(window).on('resize.pageview', _.debounce(@resize, 100))

  remove: ->
    $(window).off('.pageview')

  resize: =>
    @$el.width('auto')
    width = @$el.width()
    for n in [1..100]
      break if @maxWidthAt(n) >= width
    columnSpace = width - @gutterWidth * (n - 1)
    columnWidth = Math.floor(columnSpace / n)
    cols = (n) => columnWidth * n + @gutterWidth * (n - 1)

    # Reset everything we might set below, so window resizes work.
    @$('section.tumblr, section.instagram, section.flickr')
      .show()
      .css(marginLeft: 0)
    switch n
      when 1
        @tumblr.width(cols(1))
        @instagram.width(cols(1))
        @flickr.width(cols(1))
      when 2
        @tumblr.width(cols(2))
        @instagram.width(cols(1))
        @flickr.width(cols(1)).css(marginLeft: @gutterWidth)
      when 3
        @tumblr.width(cols(2))
        @instagram.width(cols(1)).css(marginLeft: @gutterWidth)
        @flickr.hide()
      else
        @tumblr.width(cols(2))
        m = n - 2
        @instagram.width(cols(Math.ceil(m / 2))).css(marginLeft: @gutterWidth)
        @flickr.width(cols(Math.floor(m / 2))).css(marginLeft: @gutterWidth)
    @$el.addClass('loaded').width(width)

    # Update masonry and trim excess Instagram/Flickr items.
    @masonryContainers.imagesLoaded =>
      @masonryContainers
        .children().removeClass('overflow').width(cols(1)).end()
        .masonry(columnWidth: cols(1))
      return unless n >= 3  # only trim columns if they're next to tumblr
      cutoff = @tumblr.height() - @tumblr.children().first().position().top
      masonryHeight = 0
      @masonryContainers.children().each ->
        el = $(this)
        # jQuery returns the computed style, which will be changing as this
        # element is currently in transition. We want the masonry-set target
        # value.
        top = parseInt(this.style.top, 10)
        if top > cutoff
          el.addClass('overflow')
        else
          masonryHeight = Math.max(masonryHeight, top + el.outerHeight(true))
      @masonryContainers.css(height: masonryHeight)

  # Compute the page width required to display the given number of columns and
  # their gutters at full scale.
  maxWidthAt: (cols) ->
    @columnWidth * cols + @gutterWidth * (cols - 1)


#### YogaView
class YogaView extends HierView
  events:
    'click .authed tr:not(.past)': 'selectClass'

  selectClass: (event) ->
    row = $(event.currentTarget)
    $.ajax
      url: '/labs/yoga/select'
      method: 'POST'
      data:
        date: row.parents('table').data('date')
        index: row.index()
    @$('tr').removeClass('sel')
    row.addClass('sel')


# Helpers
# -------

#### LoadingView
# Renders a series of three dots that animate in color to indicate loading.
class LoadingView extends HierView
  className: 'loading-dots'

  render: ->
    @$el.html('<b></b><b></b><b></b><b class="x"></b>')
    this
