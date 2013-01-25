#### HierView
# A `Backbone.View` that is aware of its subviews and removes them when it is
# removed. Use Backbone >=0.9.9's `listenTo` method to track bound events,
# which will also be removed along with the view.
class HierView extends Backbone.View

  # Add a new tracked child view.
  addChild: (view) ->
    @_children or= []
    @_children.push(view)
    view._parent = this
    view

  # Add a new child view and render it immediately. Return the child view's
  # `el` attribute. Convenient for adding and rendering a child in one fell
  # swoop; e.g., `this.$el.append(this.renderChild(new View))`.
  renderChild: (view) ->
    @addChild(view)
    view.render().el

  # Remove all children, tell our parent (if any) to stop tracking us, then
  # delegate to `Backbone.View.remove`. If `options.ignoreParent` is true, skip
  # the parent step---useful for avoiding unnecessary bookkeeping when the
  # parent is also being removed.
  remove: (options = {}) ->
    _(@_children).invoke('remove', ignoreParent: true) if @_children?
    @_parent?._emancipate?(this) unless options.ignoreParent
    super()

  # Stop tracking the given child.
  _emancipate: (child) ->
    @_children = _(@_children).without(child)


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
