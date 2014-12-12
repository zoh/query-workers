###
  Парсинг новых ставок типстера http://jackpotsoccertips.com/
###
###
    Должно чтото получится типа этого
{
    date: '19/04/13',
    match: 'Hull City vs Bristol City',
    handicap: '+1, +1.5',
    score: '0-0',
    result: 'win',
    team_home: 'Hull City',
    team_away: 'Bristol City',
    betOnWithHandicap: 'Bristol City +1/1.5',
    betOn: 'Bristol City',
    compare: true,
    match_id: '6TcEI5Um',
    link_match: 'http://www.livescore.in/match/6TcEI5Um/#odds-comparison;asian-handicap;full-time',
    livescore:
     { match_id: '6TcEI5Um',
       score: '0-0',
       team_away: 'Bristol City',
       team_home: 'Hull City',
       time: '22:45',
       date: '19/04/13',
       link_match: 'http://www.livescore.in/match/6TcEI5Um/#odds-comparison;asian-handicap;full-time' },
    handicapOdds: '1.78'
}
###

Sync = require('sync');
parser = require '../lib/parser'

matches = require '../lib/livescore_matches'
moment = require 'moment'
logger = require '../../logger'
funcs = require('../lib/funcs')
oddsportal_matches = require '../lib/oddsportal_matches'
Match = oddsportal_matches.Match

currentYear = moment().format 'YY'

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'jackpot'


tipster_link = 'http://www.jackpotsoccertips.com/tips-records-2014.html'
Sync ->
  $ = parser.sync null, tipster_link

  elements = $('.wsb-htmlsnippet-element').find('tr').not('[bgcolor="#bfbf00"]')

  getMatch = (item) ->
    tds = $(item).find 'td'
    "date"      : tds.eq(0).html()
    "match"     : tds.eq(1).html()
    "handicap"  : tds.eq(2).html()
    "score"     : tds.eq(3).html()
    "result"    : tds.eq(4).text()?.toLowerCase()

  makeDate = (fn) ->
    match = fn()
    match.date = moment(match.date, 'DD/MM/YY').toDate()
    match

  ##
  # Чистим лишние данные
  result = $.map elements, (item) ->
    makeDate ->
      funcs.handicap ->
        funcs.trim ->
          funcs.clearHtmlTag(['b', 'strong']) ->
            funcs.selectOnTeam ->
              funcs.trim ->
                funcs.findTeam ->
                  getMatch(item)

  ##
  # Собираем список объектов матчей.
  matchesList = result.map (match) ->
    newMatch = new Match
      event   : match.team_home + ' - ' + match.team_away
      date    : match.date
      score   : match.score
      bet     : match.handicap
      type    : Match.handicap
      betOnTeam: if match.team_home is match.betOn then Match.home else Match.away
    # записываем того что было
    newMatch.$match = match
    newMatch

  for match in matchesList
    match.suspicious = false
    try
      res = oddsportal_matches.run.sync null, match
      match.odds = res.odds
      match.date = res.date
    catch e
      console.log e
      match.suspicious = true

  matchesList?.reverse().forEach (match) ->
    options =
      tipster: tipster_short_name
      date_event: match.date
      event: match.event
      team_home: match.$match.team_home
      team_away: match.$match.team_away
      bet: match.$match.handicap
      typeBet: match.type
      betOnTeam: match.$match.betOnWithHandicap
      odds: match.odds
      score: match.$match.score
      result: match.$match.result
      parseSource: match
      suspicious: match.suspicious
    
    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"
    
, (err) ->
  console.log err if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.ERROR if err

  process.send?('Done')
  process.exit()
