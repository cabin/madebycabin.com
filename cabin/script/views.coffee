class NavView extends Backbone.View

  initialize: (options) ->
    @router = options.router

  events:
    'click': 'closeSplash'
    'touchstart': 'closeSplash'

  closeSplash: (event) ->
    if event.target is @el
      return  # XXX think harder about this
      #@router.showPage()


# TODO: when navigating route:x -> splash -> route:x, the second transition
# should use window.history.back() instead of pushState.
class SplashView extends Backbone.View
  splashVisibleClass: 'splash'
  transitionClass: 'splash-transition'

  initialize: (options) ->
    @body = $('body')
    # XXX refactor this; maybe el: body?
    @nav = $('body > nav')
    @main = $('.main')
    @splashVisible = @body.hasClass(@splashVisibleClass)

  getMainOffset: ->
    ($(window).height() - @nav.outerHeight()) + 'px'

  show: ->
    return if @splashVisible
    @splashVisible = true
    mainOffset = @getMainOffset()
    window.scrollTo(0, 0)
    @body.addClass(@transitionClass)
    @nav.animate(top: mainOffset)
    @main.animate(top: mainOffset, @finishTransition)

  hide: ->
    return unless @splashVisible
    @splashVisible = false
    mainOffset = @getMainOffset()
    @body.addClass(@transitionClass)
    @nav.css(top: mainOffset, bottom: 'auto').animate(top: 0)
    @main.css(top: mainOffset).animate(top: 0, @finishTransition)

  finishTransition: =>
    @body
      .toggleClass(@splashVisibleClass, @splashVisible)
      .removeClass(@transitionClass)
    @nav.removeAttr('style')
    @main.removeAttr('style')


class @AppRouter extends Backbone.Router

  initialize: ->
    @nav = new NavView(el: $('body > nav').get(0), router: this)
    @splash = new SplashView(el: $('body > header').get(0))
    @on('all', @trackRoute)
    $('body').on('click', 'a[href^="/"]', @internalLink)
    @currentPage = $('.content').data('page')

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
    $.ajax
      url: '/' + page
      headers: {'X-PJAX': 'true'}
      error: -> console.log('PJAX ERROR', arguments)  # XXX
      success: handler

  routes:
    '': 'showSplash'
    ':page': 'showPage'

  setTitle: ->
    titleChunks = Array.prototype.slice.call(arguments)
    titleChunks.unshift('Cabin')
    $('title').text(titleChunks.join(' · '))

  showSplash: ->
    @setTitle()
    @splash.show()

  showPage: (page) ->
    if not page
      @setTitle($('.content').data('title'))
      @navigate(@currentPage)
    else if @currentPage isnt page
      @pjax(page)
    else
      @setTitle($('.content').data('title'))
    @splash.hide()
