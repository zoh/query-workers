###
  Парсинг новых ставок типстера http://www.abrahamtips.com/
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
logger = require '../../logger'

current_year = moment().year()
tipster_short_name = 'abrahamtips'
tipster_link = 'http://www.abrahamtips.com/'

Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item) ->
    item = $ item
    return if item.find('td').length is 0

    td = (i) ->
      item.find('td').eq(i).text()

    date_event  : moment(td(0), 'DD.MM').year(current_year).format 'DD/MM/YY'
    match       : td 1
    event       : td 1 # Полное событие вместе с соревнованием
    score       : td 4
    bet         : td 2
    betOnTeam   : td 2
    odds        : td(3).replace ',', '.'
    result      : td(5).toLowerCase()?.replace('lost', 'lose')

  table = $('.entry-content.post_content table')
  table.find('tr:first-child').remove()
  tips = $.map table.find('tr'), (item) -> funcs.trim -> funcs.findTeam -> getMatch item

  unless tips
    logger.logger "Почему ничего не спарсилось с #{tipster_short_name}", logger.WARNING
    throw 'Нет ставок'

  tips.forEach (match) ->
    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, match
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date_event} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()