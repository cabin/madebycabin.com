#### AppRouter
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


# Persistent views
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
      'project': ProjectView
      'about': AboutView
      'admin-project': EditProjectView
    @_updatePageView(@content.data('page'))

  events:
    'click a[href^="/"]': 'internalLink'
    'touchstart a[href^="/"]': 'internalLink'
    'click nav .toggle': 'toggleSocial'
    'click nav': 'closeSplash'

  shortcuts:
    '⌥+l': -> navigator.id.request()

  render: ->
    @setTitle(@content.data('title'))
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


#### ProjectView
class ProjectView extends Backbone.View
  fullImageWidth: 1100

  initialize: (options) ->
    @router = options.router
    @tabs = @$('.tab-chooser a')
    @contents = @$('.tab-contents').children()
    @pageWidth = @$el.width()
    @heightRatio = @pageWidth / @fullImageWidth
    @loadImages()

  events:
    'click .tab-chooser a': 'selectTab'
    'click .social a': 'share'

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
        _.delay((-> placeholder.removeAttr('height')), 2000)
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
    @router.navigate(@$('.prev-next a').first().attr('href'), trigger: true)

  goNext: ->
    @router.navigate(@$('.prev-next a').last().attr('href'), trigger: true)

  goAdmin: ->
    @router.navigate('admin/' + Backbone.history.fragment, trigger: true)


#### AboutView
class AboutView extends Backbone.View

  initialize: ->
    @sections = @$('section')
    @menuArrow = @$('.top .menu .arrow')
    @adjustMenuArrow($('.menu a').first())
    _.defer => @menuArrow.show()
    # XXX remove on remove
    new ChartView(el: @sections.filter('.graph').find('div')).render()

  events:
    'click .menu a': 'selectSection'

  adjustMenuArrow: (relativeTo) ->
    elementCenter = (el) ->
      left = el.position().left + parseInt(el.css('margin-left'), 10)
      left + el.width() / 2
    @menuArrow.css(left: elementCenter(relativeTo))

  selectSection: (event) ->
    classMap =
      partners: '.partners, .graph'
      clients: '.clients, .services'
      connect: '.XXX'
    selected = $(event.currentTarget)
    @adjustMenuArrow(selected)
    @sections.removeClass('selected')
      .filter(classMap[selected.data('name')]).addClass('selected')


# Administrative views
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


# Data models
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


# Support
# -------

#### DropHandler
# A `Backbone.View` that creates the necessary event handlers for drag and drop
# on the document. Passing in a different `el` will listen to drag and drop on
# that element instead, while ignoring drops on the document itself.
class DropHandler extends Backbone.View
  el: document
  onError: (xhr) -> alert('Upload failed: ' + xhr.statusText)

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
    'dragover': 'cancel'  # necessary to catch the drop event
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

  # A helper method for uploading a file or files via XHR and accepting a JSON
  # response. The `options` argument must contain `url` and `files` attributes,
  # and may also contain one or more of the following callback attributes:
  #
  # - `onUpload`; called once when all files are completed, with the decoded
  #   JSON response as an argument.
  # - `onRead`; called once for each file, with the data-URL-encoded contents
  #   and the original index of the file in `files` as arguments.
  # - `onError`; called in case of a non-200 response from the upload URL, with
  #   the `XMLHttpRequest` object as an argument. Defaults to an alert.
  # - `onProgress`; assigned to the `XMLHttpRequest`'s `progress` event.
  uploadFiles: (options) =>
    xhr = new XMLHttpRequest
    xhr.open('POST', options.url)
    xhr.setRequestHeader('Accept', 'application/json')
    formData = new FormData
    files = options.files
    reader = null
    onError = options.onError or @onError

    if options.onProgress
      xhr.addEventListener('progress', options.onProgress)
    xhr.addEventListener 'load', ->
      if xhr.status is 200
        data = JSON.parse(xhr.response)
        options.onUpload?(data)
      else
        onError(xhr)

    _(files).each (file, n) ->
      formData.append('file', file)
      if options.onRead
        reader = new FileReader
        reader.addEventListener 'load', (event) ->
          options.onRead(event.target.result, n)
        reader.readAsDataURL(file)
    xhr.send(formData)


#### PersonaHandler
class @PersonaHandler extends Backbone.Events

  constructor: (currentUser) ->
    navigator.id.watch
      loggedInUser: currentUser
      onlogin: @login
      onlogout: @logout

  login: (assertion) ->
    $.ajax
      type: 'POST'
      url: '/auth/login'
      data: {assertion: assertion}
      success: (res, status, xhr) ->
        $('<a class="icon logout">').insertAfter('.copyright')
          .on('click', -> navigator.id.logout())
      error: (xhr, status, err) -> alert('Login failure: ' + err)

  logout: ->
    $.ajax
      type: 'POST'
      url: '/auth/logout'
      success: (res, status, xhr) ->
        $('footer .logout').remove()
      error: (xhr, status, err) -> alert('Logout failure: ' + err)
