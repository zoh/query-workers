###
  Парсинг новых ставок http://settips.ru/bookmaker/bet365
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
matches = require '../lib/livescore_matches'
logger = require '../../logger'

tipster_short_name = 'settips'
tipster_link = 'http://settips.ru/com/statistics/'


Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item) ->
    item = $ item

    detail = item.next('.look2')
    td = (i) -> detail.find('.det_nk').find('.det_keep').eq(i).text()

    date_event    : moment(item.find('.fore-data').text(), 'DD.MM.YY').toDate()
    event         : td 0
    match         : td(0).match(".*:(.*)")[1]
    bet           : td 1
    bookie        : detail.find('.det_nk').find('.det_keep1').eq(0).text()
    odds          : detail.find('.det_nk').find('.det_keep2').eq(0).text()
    description   : detail.find('.det_nk2').find('.det_keep3').eq(0).text()
    score         : detail.find('.det_nk1').find('.det_keep2').eq(0).text()
    typeBet       : do ->
      return 'total' if td(1).match 'ТМ|ТБ'
      return '1X2' if td(1).match('П|Х') 
      return 'handicap' if td(1).match('Ф') 
    result        : switch item.find('img').eq(1).attr('src')
      when "/theme/vip-settips/images/minus.png"
        'lose'
      when "/theme/vip-settips/images/plus.png"
        'win'
      else
        'draw'
    sport         : do ->
      if item.find('.fore-sport').text().trim() is 'Теннис'
        'tennis'
      
    
  tips = $.map $('.fore-meta2, .fore-meta1'), (item) ->
    funcs.trim ->
      funcs.findTeam ->
        getMatch item

  tips?.reverse().forEach (match) ->
    options =
      tipster: tipster_short_name
      date_event: match.date_event
      event: match.event
      team_home: match.team_home
      team_away: match.team_away
      bet: match.bet
      typeBet: match.typeBet
      odds: match.odds
      score: match.score
      result: match.result
      sport: match.sport
      bookie : match.bookie

    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()