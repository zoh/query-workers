###
  Функция парсит ставки с livescore за последние дни
  для кеширования используется редис
###

url = "http://www.livescore.in/"
livescore_handicap_link = "http://www.livescore.in/match/%s/#odds-comparison;asian-handicap;full-time"

util = require 'util'
phantom = require("phantom")
analizator = require("./analizator")
moment = require("moment")
fs = require("fs")
funcs = require './funcs'
redis = require "redis"
cfg = require '../../config'


cache_key = 'cache:livescore:line'

# Запускаем редиску для храненеия кеша
createRedisConnection = ->
  client = redis.createClient()
  client.auth cfg.redis.password
  client.on 'error', (e) ->
    throw new Error 'Error redis: ' + e
  client.select(8)
  client


# Функция для фантома, которая парсит главную таблицу
parseMainTable = ->
  res = []
  $("#fsbody .table-main tbody tr").each ->
    el = $ @
    timer = el.find('.timer span').html()
    unless timer in ['Fin', 'Awarded', 'Pen']
      return

    res.push
      match_id: el.attr("id").replace("g_1_", "")
      time: el.find(".time").html()
      team_home: el.find(".team-home span").html().replace(/<span class=".*">&nbsp;<\/span>/, "")
      team_away: el.find(".team-away span").html().replace(/<span class=".*">&nbsp;<\/span>/, "")
      score: el.find('td.score').html().replace /&nbsp;/g, ''
  res

# Парсинг гандигапа
parseScore = ->
  res = {}
  $('#block-asian-handicap-ft .odds.sortable').each ->
    # Если есть пинакл, берём его кефы
    if (tr = $(this).find 'a.elink[title="Pinnacle Sports"]').length is 1
      tr = tr.parent().parent().parent();
    else
      # Если нет, тогда первую максимальную
      tr = $(this).find('.kx.max').parent()
    res[tr.find('.ah').html()] =
      "team_home_odds": tr.find('.kx span').eq(0).html()
      "team_away_odds": tr.find('.kx span').eq(1).html()
  return res


module.exports.parseMatchesLine = ($callback) ->
  # Может что есть в кеше?
  client = createRedisConnection()
  client.get cache_key, (err, cache) ->
    $callback null, null if err

    if cache and (_cache = JSON.parse(cache))
      $callback null, _cache
      client.quit()
      return

    phantom.create (ph) ->
      matchs = []
      analiz = analizator(ph).openLink(url)

      # Прогоним чтобы мы спарсили несколько последних
      for i in [-7..0]
        do (i) ->
          analiz
            .nextEvaluate(new Function "set_calendar_date(#{i});")
            .wait(2000)
            .nextEvaluate(parseMainTable)
            .next (result, cb) ->
              if result then for match in result
                match.date = moment().add("days", i).format("DD/MM/YY")
                match.link_match = util.format livescore_handicap_link, match.match_id
                matchs.push match
              cb null, matchs

      analiz.end (err, result) ->
        fs.writeFileSync './file.json', JSON.stringify(matchs)
        client.set cache_key, JSON.stringify(matchs)
        client.expire cache_key, 6 * 3600 # Тупа на 6 часов
        client.quit()
        setTimeout (-> $callback err, matchs), 100
        ph.exit()

##
# Парсим гандикапы по выбранным #{matches}
# Массив из:
#   link_match: ''
#   team_home: ''
#   team_away: ''
#   betOn: ''
#   handicap: ''
module.exports.parseMatchScoreHandicap = (matches = [], $callback) ->
  phantom.create (ph) ->
    analizScores = analizator(ph)

    if matches then for match in matches
      do (match) ->
        analizScores
          .openLink(match.link_match)
          .wait(2000)
          .nextEvaluate(parseScore)
          .next (result, cb) ->
            if match.team_home is match.betOn
              match.handicapOdds = result[match.handicap]?.team_home_odds
            else if match.team_away is match.betOn
              # А если на гостей то нужно сделать реверт гандикапа
              match.handicapOdds = result[funcs.reverseHandicap match.handicap]?.team_away_odds
            cb null
    analizScores.end (err, result) ->
      setTimeout (-> $callback err, matches), 100
      ph.exit()