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
