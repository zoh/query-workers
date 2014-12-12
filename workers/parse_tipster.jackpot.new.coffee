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

currentYear = moment().format 'YY'

# Краткое наименование тистера который он хранится в Монге
tipster_short_name = 'jackpot'

$format = 'DD/MM/YY'

tipster_link = 'http://jackpotsoccertips.com/'
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

  result = $.map elements, (item) ->
    funcs.handicap ->
      funcs.trim ->
        funcs.clearHtmlTag(['b', 'strong', 'br']) ->
          funcs.selectOnTeam ->
            funcs.findTeam ->
              getMatch(item)

  # TODO: должен быть критерий отбора
  # тоесть мы берём какое то условие по дате или просто колво
  result = result.slice 0, 3

  # Получаем последнюю ставку
  # last_tips_db = funcs.getLastMathTipster.sync null, tipster_short_name
  # if last_tips_db?.date_event
  #   # Тогда фильтруем
  #   result = result.filter (item) ->
  #     new Date(last_tips_db.date_event) < moment(item.date, $format).toDate()

  matches_livescore = matches.parseMatchesLine.sync null

  ##
  # Сверяем дату по смещению -1..+1
  compareDate = (score, tipster) ->
    $d2 = moment(tipster, $format).add(days: 1).format $format
    $d1 = moment(tipster, $format).add(days: -1).format $format
    score in [tipster, $d1, $d2]

  for match_tipster in result
    # Устанавливаем флаг на совпадение
    match_tipster.compare = false
    for match_score in matches_livescore

      if compareDate(match_score.date, match_tipster.date) and
            (funcs.compare(match_score.team_home, match_tipster.team_home) or
              funcs.compare(match_score.team_away, match_tipster.team_away))
        match_tipster.compare = true
        match_tipster.match_id = match_score.match_id
        match_tipster.link_match = match_score.link_match
        match_tipster.livescore = match_score # Ну и вкладываем матч спарсенный с livescore
    if not match_tipster.compare
      logger.logger "Матч #{match_tipster.date}:  '#{match_tipster.team_home}'  -  '#{match_tipster.team_away}'   не найден!",
        logger.WARNING

  # Берём совпавшие и считам для них коэф.ты по азиатскому гандигапу
  resultWithHandicapOdds = matches.parseMatchScoreHandicap.sync null, result.filter (i) -> i.compare
  # Осталось сохранить это в бд спаршенных ставок для конкретного тистера
  # И добавить в АПИ инфу
  # Попробуем подсчитать верен ли результат

  resultWithHandicapOdds.forEach (match_tipster) ->
    unless funcs.validateResult(match_tipster)
      match_tipster.suspicious = true
      logger.logger "Матч #{match_tipster.date}:  '#{match_tipster.team_home}'  -  '#{match_tipster.team_away}'" +
      " неправильно рассчитан типстером", logger.WARNING, "parsing:#{tipster_short_name}"

  result?.reverse().forEach (match) ->
    options =
      tipster: tipster_short_name
      date_event: moment(match.date, $format).toDate()
      event: match.match
      team_home: match.team_home
      team_away: match.team_away
      bet: match.handicap
      typeBet: 'handicap'
      betOnTeam: match.betOnWithHandicap
      odds: match.handicapOdds
      score: match.score
      result: match.result
      parseSource: match.livescore
      suspicious: match.suspicious
    if _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
      process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"
    # else log ?

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.ERROR if err

  process.send?('Done')
  process.exit()
