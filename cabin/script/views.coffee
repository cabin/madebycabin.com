#### AppRouter  {{{1
# This gets instantiated as `window.app`, and is the manager of all permanent
# views (`MainView` and `SplashView`). It tracks the current path and hands off
# to `MainView.pjax`.
class @AppRouter extends Backbone.Router

  initialize: (options) ->
    @mainView = new MainView(router: this)
    @splashView = new SplashView
    @on('all', @trackPageView)

  routes:
    '': 'splash'
    '*path': 'fetch'

  trackPageView: ->
    path = '/' + (Backbone.history.fragment or '')
    window._gaq?.push(['_trackPageview', path])

  # We track the current URL in order to skip unneeded PJAX calls, but we can't
  # initialize this value trivially because Backbone.history isn't available
  # until after our first route fires, and route events aren't emitted until
  # after the route callback is called. So we wrap each route callback in this
  # one-time method. As an optimization, the splash page (URL == '') loads
  # with the work page hidden in its contents, so default to that URL.
  initializePath: _.once ->
    @currentPath or= Backbone.history.fragment or 'work'

  route: (route, name, callback) ->
    callback or= @[name]
    wrapper = -> @initializePath(); callback.apply(this, arguments)
    super(route, name, wrapper)

  splash: ->
    return unless @splashView.show()
    @mainView.setTitle()

  closeSplash: -> @navigate(@currentPath, trigger: true)

  # The catch-all (where "all" ∌ the splash page) route handler. Ensure the
  # splash page is hidden, and load the URL via PJAX if necessary or just
  # re-render the view.
  fetch: (path) ->
    @splashView.hide()
    if path is @currentPath
      @mainView.render()
    else
      @currentPath = path
      @mainView.pjax(path)


# Persistent views  {{{1
# ----------------

#### SplashView
# Responsible for transitioning the splash header into/out of view. External
# API is just the `show` and `hide` methods, which will return false if they
# are called unnecessarily.
class SplashView extends Backbone.View
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
    fullscreen = navigator.standalone
    if iphone and not fullscreen
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
class MainView extends Backbone.View
  el: $('.main')

  initialize: (options) ->
    @router = options.router
    @title = $('head > title')
    @nav = @$('nav').first()
    @content = @$('.content')
    @views =
      'work': WorkView
      'project': ProjectView
      'about': AboutView
      'admin-project': EditProjectView
    @_updatePageView(@content.data('page'))

  events:
    'tapclick a[href^="/"]': 'internalLink'
    'tapclick nav .toggle': 'toggleSocial'
    'tapclick nav': 'closeSplash'

  shortcuts:
    '⌥+l': -> navigator.id.request()

  render: ->
    @setTitle(@content.data('title'))
    @pageView?.render?()
    this

  # Pass clicks on internal links through navigate, saving a page load.
  internalLink: (event) ->
    # Only act on left clicks with no modifiers.
    return if event.type is 'click' and (event.which isnt 1 or
      event.metaKey or event.ctrlKey or event.shiftKey or event.altKey)
    event.preventDefault()
    event.stopPropagation()
    @router.navigate($(event.currentTarget).attr('href'), trigger: true)
    $(event.target).blur()  # kill focus outline

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
    startTime = new Date
    @$el.addClass('loading')
    # Remove the old content immediately, which indicates that something is
    # happening, and scroll back to the top of the page.
    @content.empty()
    window.scroll(0, 0)
    $.ajax
      url: "/#{route}"
      headers: {'X-PJAX': 'true'}
      error: (xhr) => @_pjaxHandler(xhr.responseText, startTime)
      success: (data) => @_pjaxHandler(data, startTime)

  _pjaxHandler: (data, startTime) ->
    @content.replaceWith(data)
    @content = $(@content.selector)  # DOM changed; need a re-query
    @_endLoadingAnimation(startTime)
    @setTitle(@content.data('title'))
    page = @content.data('page')
    @_updatePageClass(page)
    @_updatePageView(page)

  # Remove the `loading` class on the next multiple of the animation duration,
  # so anything spinning finishes in a normal state. TODO: this will probably
  # change drastically once we have a final animation design.
  _endLoadingAnimation: (startTime) ->
    duration = 750
    finishDelay = (duration + (startTime - new Date)) % duration
    _.delay((=> @$el.removeClass('loading')), finishDelay)

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
      @pageView = new viewClass(el: @content, router: @router).render()
      @_assignShortcuts(@pageView)

  _assignShortcuts: (obj) ->
    for shortcut, method of obj.shortcuts
      callback = if _.isFunction(method) then method else obj[method]
      throw new Error("Method \"#{method}\" does not exist") unless callback
      key(shortcut, _.bind(callback, obj))


# Per-page views  {{{1
# --------------

#### WorkView
# Applies jQuery Masonry on the collection of work.
class WorkView extends Backbone.View
  containerSelector: '.bricks'
  itemSelector: '.work-thumb'
  itemWidth: 260
  gutterWidth: 20

  initialize: ->
    @masonryContainer = $(@containerSelector)
    @items = @masonryContainer.find(@itemSelector)
    @featuredItems = @items.filter('.feature')
    @options =
      itemSelector: @itemSelector
      columnWidth: @computeColumnWidth
      gutterWidth: @gutterWidth
      isFitWidth: true

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


#### ProjectView
class ProjectView extends HierView
  fullImageWidth: 1100

  initialize: (options) ->
    @router = options.router
    @tabs = @$('.tab-chooser a')
    @contents = @$('.tab-contents').children()
    @pageWidth = @$el.width()
    @heightRatio = @pageWidth / @fullImageWidth
    @loadImages()
    shortlist = @$('.dev-shortlist')
    @addChild(new DevShortlistView(el: shortlist)) if shortlist.length

  events:
    'tapclick .tab-chooser a': 'selectTab'
    'tapclick .social a': 'share'

  shortcuts:
    'left': 'goPrev'
    'right': 'goNext'
    '⌥+e': 'goAdmin'

  # Because our work images are *huge* and Mobile Safari shows an ugly black
  # background while loading them, we set up placeholders here and swap in the
  # real image only after it's been completely loaded. Placeholder height must
  # be computed since the visible width depends on the browser viewport, so we
  # apply height/width attributes which are removed after the image is loaded
  # (following a brief delay so that scroll position is consistent). The
  # placeholder image should have data-src and data-height attributes, and can
  # have a data-class attribute for a class that will be applied after load.
  loadImages: ->
    @$('img[data-src]').each (i, element) =>
      placeholder = $(element)
      realSrc = placeholder.data('src')
      fullHeight = placeholder.data('height')
      placeholder.attr('height', Math.floor(fullHeight * @heightRatio))
      img = new Image
      img.onload = ->
        placeholder.attr('src', realSrc)
        placeholder.attr('class', placeholder.data('class'))
        _.delay((-> placeholder.removeAttr('height')), 200)
      img.src = realSrc

  selectTab: (event) ->
    # Unselect the previous item; hide its hr temporarily to avoid a shrinking
    # transition.
    oldSelected = @tabs.filter('.selected')
      .find('hr').hide().end()
      .removeClass('selected')
    _.defer -> oldSelected.find('hr').show()
    # Select the new item and the appropriate tab contents from its data.
    name = $(event.currentTarget).addClass('selected').data('for')
    @contents.removeClass('selected')
      .filter(".#{name}").addClass('selected')

  # Since we don't want to load a thousand external scripts and be forced to
  # display standard share buttons, this method catches clicks on our share
  # icons and pops up a centered, appropriately-sized window.
  share: (event) ->
    event.preventDefault()
    target = $(event.currentTarget)
    url = target.attr('href')
    # Browser extensions might have added extra classes.
    network = target.attr('class').split(' ')[0]
    popup_sizes =
      facebook: [580, 325]
      twitter: [550, 420]
      pinterest: [632, 320]
    [width, height] = popup_sizes[network]
    left = (screen.availWidth or screen.width) / 2 - width / 2
    top = (screen.availHeight or screen.height) / 2 - height / 2
    features = "width=#{width},height=#{height},left=#{left},top=#{top}"
    window.open(url, '_blank', features)

  goPrev: ->
    url = @$('.prev-next a').first().attr('href')
    @router.navigate(url, trigger: true) if url

  goNext: ->
    url = @$('.prev-next a').last().attr('href')
    @router.navigate(url, trigger: true) if url

  goAdmin: ->
    @router.navigate('admin/' + Backbone.history.fragment, trigger: true)


#### DevShortlistView
class DevShortlistView extends HierView

  initialize: ->
    items = @$('li')
    @itemCount = items.length
    @closed = true

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
    $(window).on('resize', @resize); @resize()

    # Each item's opacity differs from the last by a set amount, variable based
    # on the number of items. The first item will be set to `opacity`, and the
    # last item will be set to `minOpacity`.
    opacity = 1
    minOpacity = 0.2
    delta = (opacity - minOpacity) / (@itemCount - 1)
    items.each ->
      $(this).css('opacity', opacity.toFixed(2))
      opacity -= delta

    # Set up styles for and begin the cycle.
    @cycleIndex = 0
    @reposition()
    @toggleClosed(@closed)

    # CSS hides the content until we've added our styles here.
    @$el.addClass('loaded')

  remove: ->
    if @cycleInterval
      clearInterval(@cycleInterval)
    super()

  events:
    'tapclick .dev-shortlist-toggle': 'toggleClosed'

  toggleClosed: (value) ->
    @closed = @$el.toggleClass('closed', value).hasClass('closed')
    @resize()
    if @closed
      @cycleInterval = setInterval(@cycle, 2000)
    else
      clearInterval(@cycleInterval)
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


#### AboutView
class AboutView extends Backbone.View

  initialize: ->
    @sections = @$('section')
    @menu = @$('.menu')
    @menuArrow = @menu.find('.arrow')
    @adjustMenuArrow(@menu.find('a').first())
    # XXX remove on remove
    @chartView = new ChartView(el: @sections.filter('.graph'))
    @chartView.render()

  events:
    'tapclick .menu a': 'selectSection'
    'tapclick .bio hgroup': 'toggleBio'

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
    @adjustMenuArrow(selected)
    @sections.removeClass('selected')
      .filter(classMap[selected.data('name')]).addClass('selected')
    @chartView.render()

  toggleBio: (event) ->
    $(event.currentTarget).parent('.bio').toggleClass('open')


#### ChartView
# Data are arrays of three-tuples: [float year, short city name, note].
class @ChartView extends Backbone.View
  bekData: [
    [1978.5, 'Santa Barbara', 'X']
    [1996.66, 'New York City', 'X']
    [1997.66, 'Santa Barbara', 'X']
    [2002.66, 'Los Angeles', 'X']
    [2006.5, 'San Francisco', 'X']
    [2008.66, 'New York City', 'X']
    [2010, 'Los Angeles', 'X']
    [2011.33, 'Idyllwild', 'X']
    [2011.83, 'Portland', 'X']
  ]
  zakData: [
    [1980.33, 'Brisbane, AU', 'X']
    [1984.5, 'San Diego', 'X']
    [1989.92, 'Portland', 'X']
    [2000, 'Washington, DC', 'X']
    [2004.33, 'San Francisco', 'X']
    [2010.75, 'Los Angeles', 'X']
    [2011.33, 'Idyllwild', 'X']
    [2011.83, 'Portland', 'X']
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
    $(window).on('resize', _.debounce(@render, 100))
    @graph = @$el.find('.svg').get(0)
    @notes = @$el.find('.notes')
    @bekSvg = d3.select(@graph).append('svg').datum(@decorateData(@bekData))
    @zakSvg = d3.select(@graph).append('svg').datum(@decorateData(@zakData))
    @bekChart = Charts.aboutInfographic().idPrefix('b')
    @zakChart = Charts.aboutInfographic().idPrefix('z').alignLeft(false)

  decorateData: (data) ->
    _(data).map (item) =>
      year: item[0]
      city: item[1].toUpperCase()
      abbrCity: @abbrCities[item[1]]
      note: item[2]

  events:
    'mouseover g': 'showDetails'

  setupCycle: ->
    return if @cycleItems?
    @cycleIndex = 0
    @cycleItems = _(@$('g.item')).sortBy (item) ->
      parseFloat($(item).attr('start'))
    @cycle()
    @cycleInterval = setInterval(@cycle, 5000)

  cycle: =>
    @select(@cycleItems[@cycleIndex])
    @cycleIndex = (@cycleIndex + 1) % @cycleItems.length

  showDetails: (event) ->
    clearInterval(@cycleInterval)
    @select(event.currentTarget)

  select: (element) ->
    # Using d3 instead of jQuery objects, since jQuery doesn't have any decent
    # support for SVG.
    target = d3.select(element)
    return unless target.classed('item')
    d3.select(@graph).selectAll('.item, .icon').classed('selected', false)
    d3.select(target.node().parentNode.parentNode).selectAll('.icon')
      .classed('selected', true)
    target.classed('selected', true).each (d) =>
      from = Math.floor(d.year)
      to = Math.floor(d.yearEnd)
      range = if from is to then from else "#{from}&ndash;#{to}"
      @notes.find('.year').html(range)
      @notes.find('.note').text(d.note)
    @notes.show()

  render: =>
    graph = $(@graph)
    return unless graph.is(':visible')
    width = graph.width()
    if width > 528  # iPhone 5 landscape - padding
      # Match the width of my half of the chart to my bio's current width.
      zakWidth = $('.bio.zak').width() + 15
      bekWidth = width - zakWidth
      textWidth = 100
      padding = 5
    else
      padding = 1
      bekWidth = Math.floor((width - padding) / 2)
      zakWidth = width - bekWidth
      textWidth = 25
    @bekChart.width(bekWidth).textWidth(textWidth).padding(padding)(@bekSvg)
    @zakChart.width(zakWidth).textWidth(textWidth).padding(padding)(@zakSvg)
    @setupCycle()


# Administrative views  {{{1
# --------------------

#### EditProjectView
# Handles drag and drop image/thumbnail upload, cohort fieldset management, and
# hands off to `EditProjectImageView` children for per-image options.
class EditProjectView extends Backbone.View

  initialize: ->
    # XXX remove thumbnailDropper and imageDropper on remove()
    thumbnailDropper = new DropHandler(el: @$('fieldset.thumbnail'))
    @listenTo(thumbnailDropper, 'drop', @dropThumbnail)
    imageDropper = new DropHandler(el: @$('fieldset.images .dropper'))
    @uploadFiles = imageDropper.uploadFiles
    @listenTo(imageDropper, 'drop', @dropImages)
    @previewContainer = @$('.images .preview')
    @projectImages = @initProjectImages(window.projectImages)
    @projectImages.each(@imageAdded)
    @listenTo(@projectImages, 'add', @imageAdded)
    @$('.preview').sortable(handle: '.move', forcePlaceholderSize: true)

  # Clean up any child views.
  remove: ->
    _(@imageViews).invoke('remove') if @imageViews
    super()

  events:
    'click .cohort a.trash': 'removeCohort'
    'click .cohorts button': 'addCohort'
    'change .select-multiple-files input': 'selectFiles'
    'sortupdate .preview': 'updateImageIndexes'

  # Create a `ProjectImageCollection` whose members each have an `index`
  # attribute indicating order in the source array.
  initProjectImages: (data) ->
    new ProjectImageCollection _(data).map (item, index) ->
      item.index = index
      item

  imageAdded: (model) =>
    view = new EditProjectImageView(model: model)
    @imageViews or= []
    @imageViews.push(view)
    @previewContainer.append(view.render().el)

  # When a new thumbnail is dropped, upload it immediately, update the preview,
  # and set the input's value to the filename from the upload response.
  dropThumbnail: (event) ->
    if event.dataTransfer.files.length > 1
      return alert('How about just one at a time?')
    figures = @$('fieldset.thumbnail figure')
    @uploadFiles
      url: '/admin/upload'
      files: event.dataTransfer.files
      onUpload: (data) ->
        $('input[name="thumbnail_file"]').val(data.files[0])
      onRead: (dataURL) ->
        figures.each ->
          f = $(this)
          img = f.find('img')
          img = $('<img>').appendTo(f) unless img.length
          img.attr('src', dataURL)

  removeCohort: (event) ->
    fieldset = $(event.target).parent('.cohort')
    name = fieldset.find('input').first().val()
    role = fieldset.find('input').eq(1).val()
    empty = not (name or role)
    # TODO: sitewide alert/confirm replacements?
    if empty or confirm("Are you sure you want to remove #{name}?")
      fieldset.remove()

  addCohort: (event) ->
    event.preventDefault()
    fieldset = @$('.cohort').last()
    oldPrefix = fieldset.data('prefix')
    newPrefix = oldPrefix.replace(/(\d+)$/, (match) -> parseInt(match, 10) + 1)
    clone = fieldset.clone(true).data('prefix', newPrefix)
    clone.children().each ->
      child = $(this)
      for attr in ['name', 'for', 'id']
        oldValue = child.attr(attr)
        child.attr(attr, oldValue.replace(oldPrefix, newPrefix)) if oldValue
      child.val('')
    clone.insertAfter(fieldset).children('input').first().focus()

  # Upload the given `files` as new project images; this is used by both the
  # drop handler and the "select files" button. We need to record the full
  # height of each image, so we create an `img` element outside of the DOM and
  # then record its size for the upload handler to apply to the new model.
  uploadProjectImages: (files) ->
    sizes = []
    collection = @projectImages
    @uploadFiles
      url: '/admin/upload'
      files: files
      onUpload: (data) =>
        _(data.files).each (file, n) ->
          sizes[n].then (width, height) ->
            # Rudimentary sanity-check.
            if width isnt 1100
              return alert("Width was #{width}!")
            indexes = collection.pluck('index')
            model = new ProjectImage
              file: file
              height: height
              index: Math.max.apply(null, indexes.concat([0])) + 1
            collection.add(model)
      onRead: (dataURL, i) ->
        img = new Image
        deferred = new jQuery.Deferred
        sizes[i] = deferred.promise()
        img.onload = -> deferred.resolve(img.width, img.height)
        img.src = dataURL

  dropImages: (event) ->
    @uploadProjectImages(event.dataTransfer.files)

  selectFiles: (event) ->
    @uploadProjectImages(event.currentTarget.files)
    # "Reset" the input to an empty state.
    oldInput = $(event.currentTarget)
    oldInput.replaceWith(oldInput.clone())

  updateImageIndexes: ->
    _(@imageViews).each (view) ->
      view.model.set('index', view.$el.index())


#### EditProjectImageView
# Handles display and modification of the project image previews on the admin
# page, including the (hidden) form fields for each.
class EditProjectImageView extends Backbone.View
  tagName: 'figure'
  className: 'image'
  template: _.template('
    <legend>
      <span class="filename"><%= file %></span>
      <a class="icon browser-shadow<%= shadow ? " selected" : "" %>"></a>
      <a class="icon trash"></a>
      <a class="icon move"></a>
    </legend>
    <img src="<%= url %>" alt>
    <input name="<%= name %>-file" type="hidden" value="<%= file %>">
    <input name="<%= name %>-height" type="hidden" value="<%= height %>">
    <input name="<%= name %>-shadow" type="hidden" value="<%= shadow %>">
  ')

  initialize: ->
    @listenTo(@model, 'change:index', @updateName)

  events:
    'click .browser-shadow': 'toggleShadow'
    'click .trash': 'confirmRemove'

  render: ->
    data = @model.toJSON()
    data.url = window.imageUrlPrefix + data.file
    data.name = 'images-' + data.index
    @$el.html(@template(data))
    this

  toggleShadow: ->
    @model.set('shadow', not @model.get('shadow'))
    @render()

  confirmRemove: ->
    if confirm("Are you sure you want to delete #{@model.get('file')}?")
      # XXX remove from parent? HierView?
      @remove()

  updateName: (event, index) ->
    @$('input').each ->
      input = $(this)
      name = input.attr('name').split('-')
      name[1] = index
      input.attr('name', name.join('-'))


# Data models  {{{1
# -----------

# Mostly we're just using Backbone for its views, doing simple manipulations on
# markup generated on the backend. However, it's handy to have a collection of
# project images mapped to subviews in the admin view, so they can be added,
# removed, and reorganized more easily.

class @ProjectImage extends Backbone.Model
  defaults:
    'index': 0
    'shadow': false


class @ProjectImageCollection extends Backbone.Collection
  model: ProjectImage
  comparator: (image) -> image.get('index')
