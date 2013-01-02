class NavView extends Backbone.View

  initialize: (options) ->
    @router = options.router

  events:
    'click': 'closeSplash'
    'click .toggle': 'toggleSocial'
    #'touchstart': 'closeSplash'  # TODO fastclick?

  # For clicks on the background of the navigation bar, just close the splash.
  # TODO clicking the logo when showing the splash should close it
  closeSplash: (event) ->
    if event.target is @el
      @router.showPage()

  toggleSocial: (event) ->
    event.stopPropagation()
    plus = $(event.currentTarget).addClass('transitioning')
    @$el.toggleClass('show-social')
    _.delay((-> plus.removeClass('transitioning')), 400)


# TODO: when navigating route:x -> splash -> route:x, the second transition
# should use window.history.back() instead of pushState.
class SplashView extends Backbone.View
  splashVisibleClass: 'splash'
  transitionClass: 'splash-transition'

  initialize: (options) ->
    @body = $('body')
    # XXX refactor this; maybe el: body?
    @main = $('.main')
    @nav = @main.children('nav').first()
    @splashVisible = @body.hasClass(@splashVisibleClass)

  getMainOffset: ->
    ($(window).height() - @nav.outerHeight()) + 'px'

  show: ->
    return if @splashVisible
    @splashVisible = true
    mainOffset = @getMainOffset()
    window.scrollTo(0, 0)
    @body.addClass(@transitionClass)
    @main.animate(top: mainOffset, @finishTransition)

  hide: ->
    return unless @splashVisible
    @splashVisible = false
    mainOffset = @getMainOffset()
    @body.addClass(@transitionClass)
    @main.css(top: mainOffset).animate(top: 0, @finishTransition)

  finishTransition: =>
    @body
      .toggleClass(@splashVisibleClass, @splashVisible)
      .removeClass(@transitionClass)
    @main.removeAttr('style')


class MainView extends Backbone.View

  initialize: (options) ->
    @listenTo(options.router, 'route:showPage', @tXXX)

  tXXX: (page) =>
    if page is 'work'
      # XXX
      @masonry()
      @on('pjax:complete', @masonry)

  masonry: ->
    page = $('.content')
    container = $('.bricks')
    itemSelector = '.work-thumb'
    items = container.find(itemSelector)
    featuredItems = items.filter('.feature')
    itemWidth = 260
    gutterWidth = 20
    maxWidthAt = (cols) -> itemWidth * cols + gutterWidth * (cols - 1)

    # Compute the best width for a column by filling the available container.
    # `itemWidth` is the effective maximum width for each column. Rather than
    # leaving additional horizontal whitespace, add one more column than will
    # fit and downscale all columns.
    # For very narrow viewports (e.g., iPhone portrait), convert to a single
    # column at full width.
    # Featured items display at double width, unless the viewport isn't tall
    # enough to view them appropriately (e.g., iPhone landscape) or we're using
    # a single column.
    computeColumnWidth = ->
      singleColumn = window.innerWidth <= 320
      # iPhone 5 landscape will report its height at 321 temporarily when
      # scrolling through the address bar, despite never actually having that
      # much real estate. Workaround: cutoff at 321 instead of 320.
      doubleFeatured = not singleColumn and window.innerHeight > 321
      # Compute columnWidth and maxWidth.
      if singleColumn
        maxWidth = columnWidth = page.width()
      else
        maxColumns = items.length
        maxColumns += featuredItems.length if doubleFeatured
        maxWidth = Math.min(page.width(), maxWidthAt(maxColumns))
        for n in [1..maxColumns]
          break if maxWidthAt(n) >= maxWidth
        columnSpace = maxWidth - gutterWidth * (n - 1)
        columnWidth = Math.floor(columnSpace / n)
      container.css('width', maxWidth)
        .toggleClass('single-column', singleColumn)
      items.css('width', columnWidth)
      if doubleFeatured
        featuredItems.css('width', columnWidth * 2 + gutterWidth)
      columnWidth

    container.imagesLoaded ->
      container.masonry
        itemSelector: itemSelector
        columnWidth: computeColumnWidth
        gutterWidth: gutterWidth
        isFitWidth: true

  pjax: (page) ->
    now = new Date
    $('body').addClass('loading')
    handler = (data) =>
      $('.content').replaceWith(data)
      title = $('.content').data('title')
      @setTitle(title) if title
      # XXX temporary animation shenanigans
      duration = 750
      finishDuration = (duration + (now - new Date)) % duration
      _.delay((-> $('body').removeClass('loading')), finishDuration)
      # XXX update body page class; this should go in an event handler on a
      # page-wide view instead
      page = 'page-' + $('.content').data('page')
      $('body').removeClass((i, classes) ->
        _(classes.split(' '))
          .filter((cls) -> cls.match(/^page-/))
          .join(' ')
      ).addClass(page)
      @trigger('pjax:complete')
    $.ajax
      url: '/' + page
      headers: {'X-PJAX': 'true'}
      error: -> console.log('PJAX ERROR', arguments)  # XXX
      success: handler

  setTitle: ->
    titleChunks = Array.prototype.slice.call(arguments)
    titleChunks.unshift('Cabin')
    $('title').text(titleChunks.join(' · '))


#### DropHandler
# A `Backbone.View` that creates the necessary event handlers for drag and drop
# on the document. Passing in a different `el` will listen to drag and drop on
# that element instead, while ignoring drops on the document itself.
class @DropHandler extends Backbone.View
  el: document

  initialize: ->
    jQuery.event.props.push('dataTransfer')
    @classableEl = @$el
    # Make sure we can add a class while dragging.
    if @el is document
      @classableEl = $(document).find('body').first()
    # Ignore drops outside the container.  # XXX verify this
    else
      ignoreEvent = (event) -> event.preventDefault()
      document.ondragover = document.ondrop = ignoreEvent
    @enteredElements = 0

  events:
    'dragenter': 'dragEnter'
    'dragover': 'cancel'  # necessary to catch the drop element
    'dragleave': 'dragLeave'
    'drop': 'drop'

  cancel: (event) ->
    event.stopPropagation()
    event.preventDefault()

  dragEnter: (event) ->
    @cancel(event)
    @enteredElements += 1
    @classableEl.addClass('drag')

  dragLeave: (event) ->
    @cancel(event)
    @enteredElements -= 1
    @classableEl.removeClass('drag') if @enteredElements is 0

  drop: (event) ->
    @cancel(event)
    @classableEl.removeClass('drag')
    @trigger('drop', event)


class @AppRouter extends Backbone.Router

  initialize: ->
    getEl = (selector) -> $(selector).get(0)
    @splash = new SplashView(el: getEl('header'))
    @nav = new NavView(el: getEl('nav'), router: this)
    @main = new MainView(el: getEl('.main'), router: this)

    @currentPage = $('.content').data('page')
    $('body').on('click touchstart', 'a[href^="/"]', @internalLink)
    @on('all', @trackRoute)

  # Pass clicks on internal links through navigate, saving a page load.
  internalLink: (event) =>
    # Only act on left clicks with no modifiers.
    return unless event.which is 1
    return if event.metaKey or event.ctrlKey or event.shiftKey or event.altKey
    event.preventDefault()
    event.stopPropagation()
    @navigate($(event.currentTarget).attr('href'), trigger: true)
    $(event.target).blur()  # kill focus outline

  # Track the page currently display in the main content area, so we know when
  # we need to load new content.
  trackRoute: (route) ->
    if route is 'route:showPage'
      name = Backbone.history.getFragment()
      @currentPage = name

  routes:
    '': 'showSplash'
    ':page': 'showPage'
    'work/:slug': 'showProject'
    'admin/work/:slug': 'tXXX'

  showSplash: ->
    @main.setTitle()
    @splash.show()

  # TODO REFACTOR
  # body
  #   nav
  #   splash
  #   main
  # everybody is pissing in everyone else's water :(

  showPage: (page) ->
    # XXX refactor these setTitle shenanigans
    if not page
      @main.setTitle($('.content').data('title'))
      @navigate(@currentPage)
    else if @currentPage isnt page
      @main.pjax(page)
    else
      @main.setTitle($('.content').data('title'))
    @splash.hide()

  showProject: (slug) ->
    @main.pjax("work/#{slug}")
    @currentPage = null

  tXXX: ->
