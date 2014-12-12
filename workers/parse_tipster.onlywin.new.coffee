###
  Парсинг ставок от Gloomer из xml'ок
###

funcs = require '../lib/funcs'
Sync = require('sync');
parser = require '../lib/parser'

moment = require 'moment'
logger = require '../../logger'

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'onlywin'
tipster_link = 'http://onlywin.ru'

Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (match) ->
    $match = {}
    match = $ match

    $bet = match.find('.preview_bet').text().match('(.*)\. (.*) кф. (.*)')
    $result = match.find('p:last-child')

    $match.date_event = moment(match.find('.preview_title').text().slice(0, 14).trim(), 'DD.MM.YYYY')?.toDate()
    $match.match = $match.event = $bet[1]
    $match.sport = 'football'
    $match.bet = $bet[2]
    $match.score = $result.text().split(',')[0]
    $match.odds = + $bet[3].replace(',', '.')
    $match.result = switch $result.attr('class')
      when 'preview_result_lose'
        'lose'
      when 'preview_result_win'
        'win'
      else
        'draw'
    $match.typeBet = do ->
      if $match.bet?.indexOf('отал') > -1
        return 'total'
      if $match.bet?.indexOf('Фора') > -1 or $match.bet?.indexOf('фора') > -1 
        return 'handicap'
      return '1X2'
    $match


  tips = $.map  $('div.preview').slice(3,5), (item) -> funcs.trim -> funcs.findTeam -> getMatch item

  tips.forEach (match) ->
    options =
      tipster     : tipster_short_name
      date_event  : match.date_event
      event       : match.event
      team_home   : match.team_home
      team_away   : match.team_away
      bet         : match.bet
      typeBet     : match.typeBet
      # betOnTeam   : match.betOnWithHandicap
      odds        : match.odds
      score       : match.score
      result      : match.result
      parseSource : match.parseSource

    if _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
      console.log _tips
      process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"
  

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()