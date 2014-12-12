###
  Парсинг новых ставок http://theigrok.com/vipstats
  и со страницы http://theigrok.com/arch
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
matches = require '../lib/livescore_matches'
logger = require '../../logger'

tipster_short_name = 'theigrok'
tipster_link = 'http://theigrok.com/vipapr2014'


Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item) ->
    item = $ item
    return  if item.find('td').length is 0
    td = (i) -> item.find('td').eq(i).text()
    $nextRow = item.next('tr')

    [__, bet, odds] = td(2).match '(.*) кф. (.*)'
    odds = + odds.replace(',', '.')

    date_event      : moment(td(0) + '.2014', 'DD.MM.YYYY').toDate()
    event           : td(1)
    match           : td(1)
    score           : td(3)
    odds            : odds
    bet             : bet
    description     : $nextRow.find('td').html()
    result          : switch item.find('td').eq(4).find('font').attr('color')
      when '#00ad10'
        'win'
      when '#800000'
        'lose'
      else
        'draw'
    typeBet: do ->
      return 'total' if td(2).match 'ТМ|ТБ'
      return '1X2' if td(2).match('П|Х') 
      return 'handicap' if td(2).match('Ф') 
      
  $table = $('table').first().find('tr:first-child').remove()
  tips = $.map $('table').first().find('tr:nth-child(2n+1)'), (item) ->
    funcs.trim ->
      funcs.findTeam ->
        getMatch item

  return console.log tips

  tips?.forEach (match) ->
    options =
      tipster         : tipster_short_name
      date_event      : match.date_event
      event           : match.event
      team_home       : match.team_home
      team_away       : match.team_away
      bet             : match.bet
      typeBet         : match.typeBet
      odds            : match.odds
      score           : match.score
      result          : match.result
      type_section    : 'VIP'
      sport           : 'tennis'
      parseSource     : description: match.description

    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()