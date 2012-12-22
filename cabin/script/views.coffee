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
    $('body').on('click', 'a[href^="/"]', @internalLink)

  # Pass clicks on internal links through navigate, saving a page load.
  internalLink: (event) =>
    event.preventDefault()
    event.stopPropagation()
    @navigate($(event.target).attr('href'), trigger: true)
    $(event.target).blur()  # kill focus outline

  routes:
    '': 'showSplash'
    ':page': 'showPage'

  showSplash: ->
    #console.log('--> showSplash', arguments)
    @splash.show()

  showPage: (page) ->
    #console.log('showPage', arguments)
    #if page isnt currentPage
    #  load page
    @splash.hide()

  work: -> showMain('work')
  about: -> showMain('about')
  lab: -> showMain('lab')
