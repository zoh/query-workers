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

oddsportal_matches = require '../lib/oddsportal_matches'
Match = oddsportal_matches.Match


tipster_short_name = 'best-asian-picks'
tipster_link = 'http://best-asian-picks.com/index.php/archive-picks'

Sync ->
  $ = parser.sync null, tipster_link

  count = 0
  getMatch = (item) ->
    item = $ item
    return if item.find('td').length is 0
    td = (i) -> item.find('td').eq(i).text()
    date_event  : moment(td(0), 'DD/MM/YYYY').toDate()
    match       : td 1
    betOn       : td 2
    handicap    : $.trim td(2).split(' ')?[1]
    # score       : td 5  -   пропали на странице счёт матчей ? 
    result      : td(3).toLowerCase().replace('loss', 'lose')


  $table = $('.caption tr')
  tips = $.map $table, (item) ->
    funcs.trim ->
      funcs.findTeam ->
        getMatch item

  ##
  # отбираем ставки с 2014 года.
  aimDate = new Date 'Jan 1 2014'
  matches = tips.reverse().filter (tip) ->  new Date(tip.date_event) > aimDate

  matchesList = matches.map (match) ->
    newMatch = new Match
      event   : match.team_home + ' - ' + match.team_away
      date    : match.date
      bet     : match.handicap
      type    : Match.handicap
      betOnTeam: if match.betOn.indexOf(match.team_home) > -1 then Match.home else Match.away
    # записываем того что было
    newMatch.$match = match
    newMatch

  for match in matchesList
    match.suspicious = false
    try
      res = oddsportal_matches.run.sync null, match
      match.score = res.score
      match.odds = res.odds
      match.date = res.date
    catch e
      console.log e
      match.suspicious = true


  matchesList?.forEach (match) ->
    options =
      tipster: tipster_short_name
      date_event: match.date
      event: match.event
      team_home: match.$match.team_home
      team_away: match.$match.team_away
      bet: match.$match.handicap
      typeBet: match.type
      betOnTeam: match.$match.betOn
      odds: match.odds
      score: match.score
      result: match.$match.result
      parseSource: 
        link_result: match?.parseSource?.link_result
        event: match?.parseSource?.event
        score: match?.parseSource?.score
      suspicious: match.suspicious

    _tips = funcs.addTipsToTipster.sync null, tipster_short_name, options
    process.send? "Добавлена ставка: #{_tips?.id}  #{match.date} #{_tips.event} >> #{_tips.betOnTeam}"

, (err) ->
  console.log err.stack if err
  logger.logger "Ошибка при парсинге типстера #{tipster_short_name}: #{err.stack}", logger.WARNING if err

  process.send?('Done')
  process.exit()
