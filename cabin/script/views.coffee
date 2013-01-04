#### AppRouter
# This gets instantiated as `window.app`, and is the manager of all permanent
# views (`MainView` and `SplashView`). It tracks the current path and hands off
# to `MainView.pjax`.
class @AppRouter extends Backbone.Router

  initialize: (options) ->
    @mainView = new MainView(router: this)
    @splashView = new SplashView

  routes:
    '': 'splash'
    '*path': 'fetch'

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


# Persistent views
# --------------

#### SplashView
# Responsible for transitioning the splash header into/out of view. External
# API is just the `show` and `hide` methods, which will return false if they
# are called unnecessarily.
class SplashView extends Backbone.View
  visibleClass: 'splash'
  transitionClass: 'splash-transition'
  el: document.body

  initialize: ->
    @main = @$el.find('.main').first()
    @nav = @main.children('nav').first()
    @visible = @$el.hasClass(@visibleClass)

  # Compute an appropriate value for the `.main` element's `top` which will
  # show only the site navigation bar and the splash page.
  topOffset: ->
    ($(window).height() - @nav.outerHeight()) + 'px'

  show: ->
    return false if @visible
    @visible = true
    window.scrollTo(0, 0)
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
      'admin-project': EditProjectView
    @_updatePageView(@content.data('page'))

  events:
    'click a[href^="/"]': 'internalLink'
    'touchstart a[href^="/"]': 'internalLink'
    'click nav .toggle': 'toggleSocial'
    'click nav': 'closeSplash'

  render: ->
    @pageView?.render?()
    this

  # Pass clicks on internal links through navigate, saving a page load.
  internalLink: (event) ->
    # Only act on left clicks with no modifiers.
    return unless event.which is 1
    return if event.metaKey or event.ctrlKey or event.shiftKey or event.altKey
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
    $.ajax
      url: "/#{route}"
      headers: {'X-PJAX': 'true'}
      error: -> throw 'PJAX ERROR'  # XXX
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

  # Maintains a per-page view on `.content`, if any.
  _updatePageView: (name) ->
    @pageView?.remove()
    viewClass = @views[name]
    if viewClass
      @pageView = new viewClass(el: @content).render()


# Per-page views
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


#### EditProjectView
# Handles drag and drop and inline formsets.
class EditProjectView extends Backbone.View

  initialize: ->
    thumbnailDropper = new DropHandler(el: @$('fieldset.thumbnail'))
    @listenTo(thumbnailDropper, 'drop', @dropThumbnail)

  events:
    'click .cohort a.trash': 'removeCohort'
    'click .cohorts button': 'addCohort'

  # When a new thumbnail is dropped, upload it immediately, update the preview,
  # and set the input's value to the filename from the upload response.
  dropThumbnail: (event) ->
    xhr = new XMLHttpRequest
    xhr.open('POST', '/admin/upload')
    xhr.setRequestHeader('Accept', 'application/json')
    xhr.addEventListener 'progress', (event) ->
      console.log('progress', event)  # XXX
    xhr.addEventListener 'load', (event) ->
      if xhr.status is 200
        data = JSON.parse(xhr.response)
        $('input[name="thumbnail_file"]').val(data.files[0])
      else
        throw 'UPLOAD ERROR'  # XXX
    formData = new FormData
    files = event.dataTransfer.files
    _(files.length).times (n) ->
      reader = new FileReader
      reader.addEventListener 'load', (event) ->
        figures = $('fieldset.thumbnail figure')
        figures.each ->
          f = $(this)
          img = f.find('img')
          img = $('<img>').appendTo(f) unless img.length
          img.attr('src', event.target.result)
      reader.readAsDataURL(files[n])
      formData.append('file', files[n])
    xhr.send(formData)

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


# Support
# -------

#### DropHandler
# A `Backbone.View` that creates the necessary event handlers for drag and drop
# on the document. Passing in a different `el` will listen to drag and drop on
# that element instead, while ignoring drops on the document itself.
class DropHandler extends Backbone.View
  el: document

  initialize: ->
    jQuery.event.props.push('dataTransfer')
    @classableEl = @$el
    # Make sure we can add a class while dragging.
    if @el is document
      @classableEl = $(document).find('body').first()
    # Ignore drops outside the container.
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
