###
  Парсер ставок с OddsPortal.com
###

DAY  = 24   * 3600 * 1000 # 24 часа в секундах.
HOUR = 3600 * 1000        # типа один час

Sync   = require 'sync'
parser = require './parser'
funcs = require './funcs'
oddsportal = 'http://www.oddsportal.com'
request = require 'request'
_ = require 'underscore'

# Результат поиска по матчу.
oddsportal_search_link = ($url) ->
  "http://www.oddsportal.com/search/results/#{encodeURI $url}/"

##
# Возвращает ссылку на кефы
# @id - ид матча
# @xhash - дополнительный хеш для матча
# http://fb.oddsportal.com/feed/match/1-1-dCDtCNDM-5-2-yjea1.dat?_=1392323882660
oddsportal_odds_link = (id, xhash, type) ->
  $type = switch type
    when Match.handicap
      '5-2'
    when Match.total
      '2-2'
    else
      throw 'Не известный тип ставки!'
  
  "http://fb.oddsportal.com/feed/match/1-1-#{id}-#{$type}-#{xhash}.dat?_=" + new Date().getTime()



Unknown = 'Unknown'
bookmakerName = (id) ->
  switch String id
    when '18'
      'Pinnacle Sports'
    when '16'
      'Bet365'
    else
      Unknown
  # add another
    

##
# Класс матча
class Match
  @handicap = 'handicap'
  @total = 'total'

  @home = 'home'
  @away = 'away'
  ##
  # @_params настройки матча
  #  - date         дата события.
  #  - link_result  ссылка на ресурс с прогнозами.
  constructor: (@_params) ->
    {@date, @event, @score, @bet, @betOnTeam, @type, @link_result} = @_params

    if @link_result
      @_id = @link_result.match(/-([^-]*)\/$/)?[1]
  ##
  # проверяется, не так ли далеко дата начало матча (не больше 24часов)
  # @match - прототип матча
  validateDateEvent: (match) ->
    Math.abs(@date - match.date) < DAY

  validateScore: (match) ->
    match.score is @score

  ##
  # Получить коэфиценты из текста (должен прийти )
  # @sourceText 
  parseOdds: (sourceText) ->
    params = null
    sourceText = sourceText?.replace 'globals.jsonpCallback', '$parse'

    # Зупускаем "eval" и обрабатываем что пришло
    $parse = (link, $params) -> params = $params
    eval sourceText

    $bet = funcs.handicapToSum @bet
    # Если не дома, тогда делаем реверс ставок
    if @betOnTeam is Match.away
      $bet = funcs.handicapToSum funcs.reverseHandicap @bet

    $bet = + $bet
    $pref = "E-5-2-0-#{$bet}-0" # "5-2" тут зависит от типа ставки - гандикап, 1-Х-2 нужно переделывать


    odds = params.d.oddsdata?.back[$pref]?.odds
    throw 'Не нашлось нужной информации о коэфицентов' unless odds

    # Сначало отберём пинакла и bet365
    $odd = null
    for idBook, odd of odds
      book_name = bookmakerName idBook
      if book_name isnt Unknown
        $odd = odd
        @bookmaker = book_name
        break

    @odds = $odd[ if @betOnTeam is Match.home then 0 else 1 ]



##
# получение списка результатов по матчу
# @match  {Match}
# @cb 
getResultsByMatch = (match, cb) ->
  Sync ->
    $ = parser.sync null, oddsportal_search_link match.event
    $match = $('.odd.deactivate').first()
    throw 'Не найдено никакого результата по матчу' unless $match
    $match
  , (err, res) ->
    cb err, res

##
# ФОрмируем ссылку для аякс запроса на ставками
getHandicap = (_id, link, type, cb) ->
  Sync ->
    $ = parser.sync null, link
    params = JSON.parse($('body').html()?.match(/new PageEvent\(([^)]*)\);/)[1])
    $xhash = params?.xhash
    throw 'Не подсчитался #хеш для ставки' unless $xhash

    # Получаем js файл с коэфицентами (в строке) 
    request.sync null, oddsportal_odds_link _id, $xhash, type
  , cb


##
# запуск парсинга
run = (match, cb) ->
  Sync ->
    $match = getMatch match, getResultsByMatch.sync null, match

    # проверяем дату события
    throw 'Не рассчитана дата матча или не найден матч вообще.' unless $match.validateDateEvent match
    # и счёт матча
    throw 'Счёт матчей не совпадают' unless $match.validateScore match
    
    $match.parseOdds (getHandicap.sync null, $match._id, $match.link_result, $match.type)[1]
    $match
  , cb

##
# 
getMatch = ($match, $el) ->
  $td = $el.find('td')
  # собираем новый матч 
  $match.event = $td.eq(1).find('a').text()
  $match.date = $checkDateMatchByClass $td.eq(0).attr 'class'
  $match.link_result = oddsportal + $td.eq(1).find('a').attr 'href'
  $match.score = $td.eq(2).text()?.replace ':', '-'
  new Match $match


##
# Из класса узнаём какой 
# @params classNames  
# @return {Date}
$checkDateMatchByClass = (classNames) ->
  unix_time = classNames?.match(/t(\d+)/)?[1] * 1000
  new Date unix_time


module.exports = {run, $checkDateMatchByClass, Match}




### 
  Test module
########
if process.env.NODE_ENV is 'test'
  # todo: просто тестим, потом удалим
  # $match = new Match
  #   event: 'Manchester City - Chelsea'
  #   date: new Date 'Sat Feb 15 2014  GMT+0400 (MSK)'
  #   score: '2-0'
  #   bet: '-0.25'
  #   betOnTeam: Match.home
  #   type: Match.handicap

  # run $match, (err, res) ->
  #   console.log err, res


  $match = new Match
    event: 'St. Pauli - Union Berlin'
    date: new Date 'Monday, 03 Mar 2014, 23:15'
    score: '2 - 1'
    bet: '0, +0.5'
    betOnTeam: Match.away
    type: Match.handicap

  run $match, (err, res) ->
    console.log '--->', err, res