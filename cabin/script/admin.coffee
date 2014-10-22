# Views
# -----

#### EditProjectView
# Handles drag and drop image/thumbnail upload, cohort fieldset management, and
# hands off to `EditProjectImageView` children for per-image options.
class EditProjectView extends HierView

  initialize: ->
    thumbnailDropper = new DropHandler(el: @$('fieldset.thumbnail'))
    @addChild(thumbnailDropper)
    @listenTo(thumbnailDropper, 'drop', @dropThumbnail)

    imageDropper = new DropHandler(el: @$('fieldset.images .dropper'))
    @addChild(imageDropper)
    @uploadFiles = imageDropper.uploadFiles
    @listenTo(imageDropper, 'drop', @dropImages)

    @previewContainer = @$('.images .preview')
    @projectImages = @initProjectImages(window.projectImages)
    @projectImages.each(@imageAdded)
    @listenTo(@projectImages, 'add', @imageAdded)

  events:
    'click .cohort a.trash': 'removeCohort'
    'click .cohorts button': 'addCohort'
    'change .select-multiple-files input': 'selectFiles'
    'sortupdate .preview': -> @trigger('rearrange')

  # Create a `ProjectImageCollection` whose members each have an `index`
  # attribute indicating order in the source array.
  initProjectImages: (data) ->
    new ProjectImageCollection _(data).map (item, index) ->
      item.index = index
      item

  imageAdded: (model) =>
    view = @addChild(new EditProjectImageView(model: model))
    view.listenTo(this, 'rearrange', view.updateIndex)
    @previewContainer.append(view.render().el)
    @previewContainer.sortable(handle: '.move', forcePlaceholderSize: true)

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
            # Rudimentary sanity-check. Allow for 2200-wide images for retina
            # displays, but reduce ProjectImage height accordingly.
            if width not in [1100, 2200]
              return alert("Width was #{width}! Should be 1100 or 2200.")
            indexes = collection.pluck('index')
            model = new ProjectImage
              file: file
              height: if width is 2200 then height / 2 else height
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


#### EditProjectImageView
# Handles display and modification of the project image previews on the admin
# page, including the (hidden) form fields for each.
class EditProjectImageView extends HierView
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
      @remove()

  updateName: (event, index) ->
    @$('input').each ->
      input = $(this)
      name = input.attr('name').split('-')
      name[1] = index
      input.attr('name', name.join('-'))

  updateIndex: ->
    @model.set('index', @$el.index())


#### ManageWorkView
class ManageWorkView extends WorkView

  initialize: ->
    super
    @$('.rearrange').sortable(items: '.work-thumb', forcePlaceholderSize: true)

  events:
    'click .work-thumb img': 'preview'
    'change [name=is_public]': 'togglePublic'
    'change [name=is_featured]': 'toggleFeatured'
    'sortupdate': 'sortupdate'

  preview: (event) ->
    slug = $(event.target).parent('.work-thumb').data('slug')
    app.navigate('/work/' + slug, trigger: true)

  togglePublic: (event) ->
    target = $(event.target)
    work = target.parents('.work-thumb')
    @saveWork(work, is_public: target.is(':checked'))

  toggleFeatured: (event) ->
    target = $(event.target)
    work = target.parents('.work-thumb')
    @saveWork(work, is_featured: target.is(':checked'))

  sortupdate: (event, item) ->
    order = @$('.rearrange .work-thumb').map(-> $(this).data('id'))
    container = @$('.public .bricks')
    order.each (index, id) ->
      container.append(container.find("[data-id=#{id}]"))
    @masonryContainer.masonry('reload')
    @saveOrder(order.get())

  # HACK: I should really be using proper Backbone models here, and probably a
  # template for rendering them with. However, this is quick 'n' dirty to get
  # it out the door.
  # Given a `work` jQuery object (which should have a `data-slug` attribute),
  # sets all keys in `attributes` on the work, then pjax-reloads the page to
  # ensure our rendering is up to date.
  saveWork: (work, attributes) ->
    $.ajax
      type: 'PUT'
      url: "/admin/work/#{work.data('slug')}"
      data: attributes
      context: this
      complete: -> @_parent.pjax(Backbone.history.fragment)

  saveOrder: (order) ->
    $.ajax
      type: 'POST'
      url: '/admin/work'
      contentType: 'application/json; charset=utf-8',
      data: JSON.stringify({order: order})


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
