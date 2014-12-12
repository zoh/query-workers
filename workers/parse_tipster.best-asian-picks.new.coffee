###
  Парсинг новых ставок типстера http://best-asian-picks.com/
  с агрегацией коэфицентов
###

Sync = require('sync');
parser = require '../lib/parser'
funcs = require '../lib/funcs'
moment = require('moment')
matches = require '../lib/livescore_matches'
logger = require '../../logger'


tipster_short_name = 'best-asian-picks'
tipster_link = 'http://best-asian-picks.com/'

Sync ->
  $ = parser.sync null, tipster_link

  getMatch = (item) ->
    item = $ item
    return if item.find('td').length is 0
    td = (i) -> item.find('td').eq(i).text()
    date_event  : moment(td(0), 'DD/MM/YYYY').toDate()
    match       : td 1
    handicap    : $.trim td(2).split(' ')?[-1..]?.toString()
    # score       : td 5  -   пропали на странице счёт матчей ? 
    result      : td(3).toLowerCase().replace('loss', 'lose')

  tips = []

  $table = $('.caption').eq(0)
  $table.find('tr:first-child').remove()
  tips = tips.concat $.map $table.find('tr'), (item) ->
    funcs.trim ->
      funcs.findTeam ->
        getMatch item

  # Получаем данные из livescore, чтобы сравнить с нашими
  matches_livescore = matches.parseMatchesLine.sync null

  for match_tipster in tips
    # Устанавливаем флаг на совпадение
    match_tipster.compare = false
    for match_score in matches_livescore
      # compare лучше работает чем compareDiff
      if (funcs.compare(match_tipster.team_home, match_score.team_home) and
      funcs.compare(match_tipster.team_away, match_score.team_away))

        match_tipster.compare = true
        match_tipster.match_id = match_score.match_id
        match_tipster.link_match = match_score.link_match
        match_tipster.livescore = match_score # Ну и вкладываем матч спарсенный с livescore

    if not match_tipster.compare
      console.log "Матч #{match_tipster.date_event}:  '#{match_tipster.team_home}'  -  '#{match_tipster.team_away}'   не найден!"
      logger.logger "Матч #{match_tipster.date_event}:  '#{match_tipster.team_home}'  -  '#{match_tipster.team_away}'   не найден!",
        logger.WARNING, "parsing:#{tipster_short_name}"

  tipsWIthLiveScore = matches.parseMatchScoreHandicap.sync null, tips.filter (i) -> i.compare

  unless tips
    logger.logger "Почему ничего не спарсилось с #{tipster_short_name}", logger.WARNING
    throw 'Нет ставок'

  tips = tips.map (match) ->
    match.odds = match.handicapOdds
    match.parseSource = match.livescore
    match.event = match.team_home + ' - ' + match.team_away
    delete match.livescore
    match.betOnTeam = match.betOnWithHandicap
    match

  tips?.reverse().forEach (match) ->
    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, match
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date_event} #{_tips.event} >> #{_tips.betOnTeam}"
#

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()

