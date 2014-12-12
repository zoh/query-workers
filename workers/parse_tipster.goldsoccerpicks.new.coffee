###
  Парсинг новых ставок типстера http://www.goldsoccerpicks.com/
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
logger = require '../../logger'


tipster_short_name = 'goldsoccerpicks'
tipster_link = 'http://www.goldsoccerpicks.com/home/'

Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item, category) ->
    item = $ item
    if item.find('td').length is 0
      return

    td = (i) ->
      item.find('td').eq(i).text()

    date_event  : moment(td(0), 'DD/MM/YYYY').toDate()
    match       : td 1
    event       : td 1 # Полное событие вместе с соревнованием
    score       : td 4
    bet         : td 3
    betOnTeam   : td 3
    odds        : (td 2).replace ',', '.'
    result      : td(5).toLowerCase()
    type_section: category

  $('.mainTipsTable[width="700"] tr:first-child').remove()

  tips = $.map $('.mainTipsTable[width="700"]'), (table, i) ->
    $table = $ table
    $.map $table.find('tr'), (item) -> funcs.trim -> funcs.findTeam ->
      getMatch item, if i is 0 then 'AH Picks' else 'Gold Picks'

  unless tips
    logger.logger "Почему ничего не спарсилось с #{tipster_short_name}", logger.WARNING
    throw 'Нет ставок'


  tips.reverse().forEach (match) ->
    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, match
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date_event} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()