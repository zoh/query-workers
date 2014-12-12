###
  Парсинг новых ставок типстера http://goldtrustbets.com/
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
_ = require 'underscore'
logger = require '../../logger'

moment.lang('ru')

previous_month = moment().add(month: -1).format('MMMMYYYY')
current_month = moment().format('MMMMYYYY')
current_year = moment().format('YYYY')

tipster_short_name = 'goldtrustbets'
tipster_link = "http://goldtrustbets.com/statistics#{current_year}/"


getMatch = (item, $, type_section) ->
  item = $ item
  return if item.find('td').length is 0
  td = (i) ->
    item.find('td').eq(i).text()
  result = (i) ->
    val = td i
    switch val
      when '+++' then 'win'
      when '---' then 'lose'
      when '===' then 'draw'
      else
        'cancel'
  date_event: moment(td(0) + current_year, 'DD.MM.YYYY').format 'DD/MM/YY'
  match: td 2
  event: td 2 # Полное событие вместе с соревнованием
  score: td 5
  bet: td 3
  betOnTeam: td 3
  odds: td(4).replace ',', '.'
  result: result 6
  type_section: type_section

Sync ->
  $ = parser.sync null, tipster_link

  # Нужно выбрать секцию за текущий месяц
  section = []
  $.each $('.articles-category'), (i, item) ->
    el = $(item)
    _month = el.find('h2').text()?.replace(' ', '')?.toLowerCase()
    # Если нашли, то это то что нам нужно
    if _month in [current_month, previous_month]
      $.each el.find('ul.articles-list li'), (i, item2) ->
        el2 = $ item2
        a = el2.find('h3 a')
        section.push category: a.text(), link: a.attr('href')

  tips = []
  section.forEach (item) ->
    link = item.link
    category_tipster = item.category

    $ = parser.sync null, link
    table = $('table').not('.noborders')
    table.find('tr:first-child').remove()
    # удаляем нафиг первую строчку

    tips = tips.concat $.map table.find('tr'), (item) ->
      funcs.trim ->
        funcs.findTeam ->
          getMatch item, $, category_tipster

  # Чистим от пустоты
  tips = tips.filter (item) ->
    item.match?.replace(' ', '') isnt ''

  tips?.reverse().forEach (match) ->
    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, match
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date_event} #{_tips.event} >> #{_tips.betOnTeam}"

, (err, tips) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()