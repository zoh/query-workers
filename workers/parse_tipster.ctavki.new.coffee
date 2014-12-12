###

###
funcs = require '../lib/funcs'
Sync = require('sync');
parser = require '../lib/parser'

moment = require 'moment'
logger = require '../../logger'

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'ctavki'
tipster_link = 'http://ctavki.com/'


Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item) ->
    item = $ item
    return  if item.find('td').length is 0
    td = (i) -> item.find('td').eq(i).text()

    date_event  : moment(td(0), 'DD.MM.YYYY').toDate()
    match       : td 1
    event       : "#{td 2}: #{td 1}"
    # betOnTeam   : td 2
    bet         : td 3
    odds        : + td 4
    score       : td 5
    result      : switch item.find('td').eq(5).css('color')
      when '#046931'
        'win'
      when '#e00000'
        'lose'
      else
        'draw'
    # todo: можно ещё определить тип ставки
    typeBet: do ->
      return 'total' if td(3).match 'ТМ|ТБ'
      return '1X2' if td(3).match('П|Х') 
      return 'handicap' if td(3).match('Ф') 


  tips = $.map $('.tabel table tbody tr'), (item) -> getMatch item
  tips = tips.filter (tip) ->
    tip
  .map (tip) -> funcs.trim -> funcs.findTeam -> tip


  tips?.forEach (match) ->
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

    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()
