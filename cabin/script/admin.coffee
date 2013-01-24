# Views
# -----

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
