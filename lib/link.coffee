# Here is where we attach federated semantics to internal
# links. Call doInternalLink to add a new page to the display
# given a page name, a place to put it an an optional site
# to retrieve it from.

lineup = require './lineup'
active = require './active'
refresh = require './refresh'
{asTitle, asSlug, pageEmitter} = require './page'

createPage = (name, loc) ->
  site = loc if loc and loc isnt 'view'
  title = asTitle(name)
  $page = $ """
    <div class="page" id="#{name}" tabindex="-1">
      <div class="paper">
        <div class="twins"> <p> </p> </div>
        <div class="header">
          <h1> <img class="favicon" src="#{wiki.site(site).flag()}" height="32px"> #{title} </h1>
        </div>
      </div>
    </div>
  """
  $page.data('site', site) if site
  $page

showPage = (name, loc, $after) ->
  $page = createPage(name, loc)
  $page.appendTo('.main') if not $after
  $page.after if $after
  $page.each refresh.cycle
  return $page

openInternalLink = (name, $page, site=null, target) ->
  name = asSlug(name)
  $page = $($page)
  key = $page.data('key')
  if target == 'lineup'
    $page.nextAll().remove()
    lineup.removeAllAfterKey key
   `showPage(name, site, $page)
    return active.set($('.page').last())
  if target == 'end'
   `showPage(name, site, $page)
    return active.set($('.page').last())
  if target in ['current', 'next']
    lineup.addAfterKey key, $page
   `$newPage = showPage(name, site, $page)
    if target == 'replace'
      $page.remove()
      lineup.removeKey $page.data('key')
    return active.set $newPage
  console.log('openInternalLink: unknown target', target)

doInternalLink = (name, $page, site=null) ->
  target = 'end'
  target = 'remove' if $page
  openInternalLink(name, $page, site, target)

showResult = (pageObject, options={}) ->
  $(options.$page).nextAll().remove() if options.$page?
  lineup.removeAllAfterKey $(options.$page).data('key') if options.$page?
  slug = pageObject.getSlug()
  slug += "_rev#{options.rev}" if options.rev?
  $page = createPage(slug).addClass('ghost')
  $page.appendTo($('.main'))
  refresh.buildPage( pageObject, $page )
  active.set($('.page').last())

pageEmitter.on 'show', (page) ->
  console.log 'pageEmitter handling', page
  showResult page

module.exports = {createPage, doInternalLink, openInternalLink,
                  showPage, showResult}
