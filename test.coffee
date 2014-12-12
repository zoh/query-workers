
#Sync = require('sync');
#
#
#tipster_link = 'http://www.jackpotsoccertips.com/tips-records-2014.html'
#Sync ->
#  $ = parser.sync null, tipster_link
#  elements = $('.wsb-htmlsnippet-element table')
#    .first()
#    .find('tr[bordercolor="#000000"]')

global.globals = {}
globals.jsonpCallback = (link, params) ->
  console.log params.d.oddsdata

require './mock'