body = $('body')
nav = $('nav')
content = $('.main')
showSplash = body.hasClass('splash')

toggleSplash = ->
  console.log('toggleSplash')
  contentOffset = ($(window).height() - nav.outerHeight()) + 'px'
  showSplash = !showSplash

  if showSplash
    window.scrollTo(0, 0)
    body.addClass('splash-transition')
    _.defer ->
      content.css(top: contentOffset)
      nav.css(top: contentOffset)
  else
    content.css(top: contentOffset)
    body.addClass('splash-transition')
    # XXX For some reason, using contentOffset here doesn't work, even though
    # its value is identical. Also, reordering the next two lines doesn't work.
    # It's all more reliable if these lines are deferred, but the amount of
    # deferral necessary differs ~100ms between browsers. Argh. Revisit this.
    nav.css(bottom: $(window).height() - nav.outerHeight())
    content.css(top: 0)

endTransition = ->
  console.log('endTransition')
  body.removeClass('splash-transition').toggleClass('splash', showSplash)
  nav.removeAttr('style')
  content.removeAttr('style')

nav.on('click touchstart', toggleSplash)
nav.on('transitionend webkitTransitionEnd oTransitionEnd', endTransition)







return  # TODO
iPhone = !!navigator.userAgent.match(/iPhone|iPod/)
fullscreen = navigator.standalone

# If we're in non-fullscreen iPhone and the user hasn't scrolled, we need to
# hide the address bar. If we're in splash mode, that means we'll need to
# increase the height of the splash to account for the extra space before using
# the scrolling trick. Special-case sadface :(
handleAddressBar = ->
  if !window.pageYOffset
    splash = body.children('header')
    newHeight = splash.height() + 60
    splash.css
      height: newHeight
      bottom: 'auto'
    nav.css
      top: newHeight
      bottom: 'auto'
    _.delay((-> window.scrollTo(0, 0)), 10)
### XXX BUSTED at least on orientation change
if (iPhone && !fullscreen) {
  handleAddressBar()
  window.addEventListener('orientationchange', handleAddressBar);
}
###
